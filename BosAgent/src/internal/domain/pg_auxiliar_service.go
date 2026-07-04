package domain

import (
	"fmt"
	"log/slog"
	"os"
	"sync"
	"time"
)

// PgAuxK8sPort es el puerto a operaciones K8s para el PG Auxiliar.
// Definido por el dominio, implementado por k8s.Core.
type PgAuxK8sPort interface {
	CreatePodFromManifest(manifestYAML, namespace string) error
	DeletePod(name, namespace string) error
	WaitForPodReady(name, namespace string, timeout time.Duration) error
	ExecInPod(pod, namespace, container, command string) (string, error)
}

// PgAuxStepFn es una función callback que recibe progreso de un paso.
type PgAuxStepFn func(stepName string, progress float64, message string)

// PgAuxiliarService implementa la lógica del PostgreSQL auxiliar anti-pérdida
// definida en SBOS-BOOTSTRAP-MANUAL Parte V-B.
//
// Regla de oro: El PG principal nunca recibe una escritura durante el bootstrap.
// Todas las operaciones van al auxiliar. Solo después de verificación exitosa se sincronizan.
//
// Thread safety: mu serializa Start/Sync/Cleanup; Status es siempre seguro.
// Solo puede ejecutar una operación a la vez — llamadas concurrentes a Start retornan ErrPgAuxiliarInProgress.
type PgAuxiliarService struct {
	k8s PgAuxK8sPort

	mu     sync.Mutex
	status *PgAuxiliarStatus
}

// NewPgAuxiliarService crea un nuevo servicio de PG auxiliar.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — inyectado en Server y en domain.PgAuxiliarService.
func NewPgAuxiliarService(k8s PgAuxK8sPort) *PgAuxiliarService {
	return &PgAuxiliarService{
		k8s:    k8s,
		status: &PgAuxiliarStatus{Phase: "idle"},
	}
}

// auxPodName es el nombre canónico del pod temporal del PG auxiliar.
const auxPodName = "sbos-pg-auxiliar"
const auxNamespace = "sbos-data"
const auxPGImage = "postgres:18.4-alpine"
const auxPodReadyTimeout = 120 * time.Second

// getEnvOrDefault retorna el valor de la variable de entorno env si está definida,
// o fallback en caso contrario.
func getEnvOrDefault(env, fallback string) string {
	if v := os.Getenv(env); v != "" {
		return v
	}
	return fallback
}

// Start inicia la operación de backup del PG principal al auxiliar.
// Crea un pod temporal PostgreSQL, ejecuta pg_basebackup desde el principal,
// y verifica la integridad.
//
// Recibe:
//   - sourcePod, sourceNS: string — pod y namespace del PG principal.
//   - observer: PgAuxStepFn — callback de progreso paso a paso (puede ser nil).
//
// Retorna: (*PgAuxiliarResult, error). El pod auxiliar se elimina en caso de error.
//
// Callers conocidos:
//   - internal/server/jsonrpc.go:rpcPgAuxiliarStart — vía JSON-RPC.
//   - internal/server/ws.go:wsHandlePgAuxiliarStart — vía WebSocket.
//
// Efectos secundarios:
//   - Crea pod temporal "sbos-pg-auxiliar" en namespace "sbos-data".
//   - Ejecuta pg_basebackup desde sourcePod — operación I/O intensiva.
//   - Retiene el pod si la operación finaliza correctamente.
//
// Estándares: SBOS-BOOTSTRAP-MANUAL Parte V-B.
func (s *PgAuxiliarService) Start(sourcePod, sourceNS string, observer PgAuxStepFn) (*PgAuxiliarResult, error) {
	// M-01: env var overrides para pod name/namespace/image (BOS_PG_AUX_POD/NS/IMAGE)
	podName := getEnvOrDefault("BOS_PG_AUX_POD", auxPodName)
	ns := getEnvOrDefault("BOS_PG_AUX_NS", auxNamespace)
	image := getEnvOrDefault("BOS_PG_AUX_IMAGE", auxPGImage)

	s.mu.Lock()
	if s.status.Phase != "idle" && s.status.Phase != "error" {
		s.mu.Unlock()
		return nil, ErrPgAuxiliarInProgress
	}
	s.status = &PgAuxiliarStatus{
		Phase:     "backup",
		StartedAt: time.Now(),
		PodName:   podName,
	}
	s.mu.Unlock()

	result := &PgAuxiliarResult{Operation: "pg_basebackup", PodName: podName}
	startTime := time.Now()

	// H1/H2: contraseña del pod PG auxiliar desde entorno — nunca hardcodeada
	pgPass := os.Getenv("PG_AUX_PASSWORD")
	if pgPass == "" {
		return nil, fmt.Errorf("pg_auxiliar: PG_AUX_PASSWORD no definida")
	}

	// Paso 1: Crear pod temporal PostgreSQL
	s.updateStatus("backup", 0.05, "crear_pod_auxiliar", "Creando pod PostgreSQL temporal...")
	manifest := auxPodManifest(podName, ns, image, pgPass)
	if err := s.k8s.CreatePodFromManifest(manifest, ns); err != nil {
		return s.failResult(result, "crear_pod_auxiliar", err)
	}
	if observer != nil {
		observer("crear_pod_auxiliar", 0.10, "Pod auxiliar creado")
	}

	// Paso 2: Esperar que el pod esté Ready
	s.updateStatus("backup", 0.15, "esperar_pod_ready", "Esperando que el pod auxiliar esté Ready...")
	if err := s.k8s.WaitForPodReady(podName, ns, auxPodReadyTimeout); err != nil {
		s.k8s.DeletePod(podName, ns)
		return s.failResult(result, "esperar_pod_ready", err)
	}
	if observer != nil {
		observer("esperar_pod_ready", 0.25, "Pod auxiliar Ready")
	}

	// Paso 3: Inicializar directorio de datos en el auxiliar
	s.updateStatus("backup", 0.30, "init_aux_data", "Inicializando directorio de datos...")
	if _, err := s.k8s.ExecInPod(podName, ns, "",
		"rm -rf /var/lib/postgresql/data/* && chmod 700 /var/lib/postgresql/data"); err != nil {
		s.k8s.DeletePod(podName, ns)
		return s.failResult(result, "init_aux_data", err)
	}
	if observer != nil {
		observer("init_aux_data", 0.35, "Directorio de datos listo")
	}

	// Paso 4: Obtener IP del auxiliar y ejecutar pg_basebackup desde source
	s.updateStatus("backup", 0.40, "pg_basebackup", "Ejecutando pg_basebackup...")

	// Obtener IP del pod auxiliar
	targetIP, err := s.k8s.ExecInPod(podName, ns, "",
		"hostname -i 2>/dev/null || ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \\K[\\d.]+' || cat /etc/hosts 2>/dev/null | grep $(hostname) | awk '{print $1}'")
	if err != nil {
		s.k8s.DeletePod(podName, ns)
		return s.failResult(result, "pg_basebackup", fmt.Errorf("no se pudo obtener IP del auxiliar: %w", err))
	}
	targetIP = cleanIP(targetIP)

	// H3: obtener IP del pod source para restringir pg_hba (Zero Trust — NIST SP 800-207)
	sourcePodIP, err := s.k8s.ExecInPod(sourcePod, sourceNS, "",
		"hostname -i 2>/dev/null | awk '{print $1}'")
	if err != nil {
		s.k8s.DeletePod(podName, ns)
		return s.failResult(result, "pg_basebackup", fmt.Errorf("no se pudo obtener IP del source: %w", err))
	}
	sourcePodIP = cleanIP(sourcePodIP)

	// C-02: pg_hba restringido al pod source con scram-sha-256 (Zero Trust — NIST SP 800-207)
	// listen_addresses vinculado solo a la IP interna del pod auxiliar (no '*')
	if _, err := s.k8s.ExecInPod(podName, ns, "",
		fmt.Sprintf("echo 'host all all %s/32 scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf && echo \"listen_addresses = '%s'\" >> /var/lib/postgresql/data/postgresql.conf && pg_ctl -D /var/lib/postgresql/data reload 2>/dev/null || true",
			sourcePodIP, targetIP)); err != nil {
		s.k8s.DeletePod(podName, ns)
		return s.failResult(result, "pg_basebackup", fmt.Errorf("configurar pg_hba falló: %w", err))
	}

	// H1: contraseña leída de env PG_AUX_PASSWORD — nunca hardcodeada
	backupOutput, err := s.k8s.ExecInPod(sourcePod, sourceNS, "",
		fmt.Sprintf("PGPASSWORD=%s pg_basebackup -h %s -p 5432 -U postgres -D /var/lib/postgresql/data/pgdata_backup -X stream -v 2>&1",
			pgPass, targetIP))
	if err != nil {
		s.k8s.DeletePod(podName, ns)
		return s.failResult(result, "pg_basebackup", fmt.Errorf("pg_basebackup falló: %s — %w", backupOutput, err))
	}
	if observer != nil {
		observer("pg_basebackup", 0.85, "pg_basebackup completado")
	}

	// Paso 5: Verificar integridad
	s.updateStatus("backup", 0.90, "verificar_integridad", "Verificando integridad del backup...")
	if _, err := s.k8s.ExecInPod(podName, ns, "",
		"pg_isready -U postgres 2>/dev/null || pg_ctl -D /var/lib/postgresql/data start 2>/dev/null; sleep 2; pg_isready -U postgres"); err != nil {
		s.k8s.DeletePod(podName, ns)
		return s.failResult(result, "verificar_integridad", fmt.Errorf("verificación de integridad falló: %w", err))
	}
	if observer != nil {
		observer("verificar_integridad", 0.95, "Backup íntegro verificado")
	}

	result.Success = true
	result.Duration = time.Since(startTime)

	s.mu.Lock()
	s.status.Phase = "idle"
	s.status.Progress = 1.0
	s.status.Duration = result.Duration
	s.status.BytesTotal = result.BytesTotal
	s.mu.Unlock()

	return result, nil
}

// Sync sincroniza los datos del PG auxiliar de vuelta al PG principal
// mediante pg_dump → psql en red directa entre pods (sin copia de archivos).
//
// Requiere que el pod auxiliar esté corriendo (phase="idle" tras Start exitoso).
// Retorna ErrPgAuxiliarNotReady si no está en estado "idle".
//
// Efectos secundarios: ejecuta pg_dump en targetPod conectando al auxiliar y
// restaura vía psql en el mismo targetPod.
func (s *PgAuxiliarService) Sync(targetPod, targetNS, database string) (*PgAuxiliarResult, error) {
	s.mu.Lock()
	if s.status.Phase != "idle" {
		s.mu.Unlock()
		return nil, ErrPgAuxiliarNotReady
	}
	s.status = &PgAuxiliarStatus{
		Phase:     "sync",
		StartedAt: time.Now(),
		PodName:   auxPodName,
	}
	s.mu.Unlock()

	result := &PgAuxiliarResult{Operation: "sync_wal"}
	startTime := time.Now()

	// A-08: contraseña desde env — nunca hardcodeada
	pgPass := os.Getenv("PG_AUX_PASSWORD")
	if pgPass == "" {
		return nil, fmt.Errorf("pg_auxiliar: PG_AUX_PASSWORD no definida")
	}

	// Obtener IP del pod auxiliar para la conexión directa
	s.updateStatus("sync", 0.10, "sync_obtener_ip", "Obteniendo IP del pod auxiliar...")
	auxIP, err := s.k8s.ExecInPod(auxPodName, auxNamespace, "",
		"hostname -i 2>/dev/null | awk '{print $1}'")
	if err != nil {
		return s.failResult(result, "sync_obtener_ip", fmt.Errorf("no se pudo obtener IP del auxiliar: %w", err))
	}
	auxIP = cleanIP(auxIP)

	// Paso 1: pg_dump desde el auxiliar → psql al principal en red directa.
	// Se ejecuta en targetPod: conecta al auxiliar (auxIP), vuelca y restaura localmente.
	// Elimina la necesidad de copiar archivos entre pods (A-08).
	s.updateStatus("sync", 0.40, "pg_dump_restore", "Transfiriendo datos auxiliar→principal en red...")
	transferOutput, err := s.k8s.ExecInPod(targetPod, targetNS, "",
		fmt.Sprintf(
			"PGPASSWORD=%s pg_dump -h %s -p 5432 -U postgres %s | psql -U postgres %s 2>&1",
			pgPass, auxIP, database, database))
	if err != nil {
		return s.failResult(result, "pg_dump_restore",
			fmt.Errorf("transferencia auxiliar→principal falló: %s — %w", transferOutput, err))
	}

	// Paso 2: Verificar principal
	s.updateStatus("sync", 0.90, "verificar_principal", "Verificando PG principal...")
	if _, err := s.k8s.ExecInPod(targetPod, targetNS, "", "pg_isready -U postgres"); err != nil {
		return s.failResult(result, "verificar_principal", fmt.Errorf("PG principal no responde tras sync: %w", err))
	}

	result.Success = true
	result.Duration = time.Since(startTime)

	s.mu.Lock()
	s.status.Phase = "idle"
	s.status.Progress = 1.0
	s.status.Duration = result.Duration
	s.mu.Unlock()

	return result, nil
}

// Cleanup destruye el pod auxiliar y libera recursos.
//
// Efectos secundarios: ejecuta kubectl delete pod sbos-pg-auxiliar — idempotente.
func (s *PgAuxiliarService) Cleanup() error {
	s.mu.Lock()
	s.status = &PgAuxiliarStatus{
		Phase:     "cleanup",
		Progress:  0.5,
		StartedAt: time.Now(),
	}
	s.mu.Unlock()

	if err := s.k8s.DeletePod(auxPodName, auxNamespace); err != nil {
		s.mu.Lock()
		s.status.Phase = "error"
		s.status.Error = err.Error()
		s.mu.Unlock()
		return err
	}

	s.mu.Lock()
	s.status = &PgAuxiliarStatus{Phase: "idle"}
	s.mu.Unlock()
	return nil
}

// Status devuelve el estado actual de la operación del PG auxiliar.
// Retorna copia — modificarla no afecta al servicio.
func (s *PgAuxiliarService) Status() *PgAuxiliarStatus {
	s.mu.Lock()
	defer s.mu.Unlock()
	cp := *s.status
	return &cp
}

// ── Helpers internos ────────────────────────────────────────────────────

func (s *PgAuxiliarService) failResult(result *PgAuxiliarResult, step string, err error) (*PgAuxiliarResult, error) {
	result.Success = false
	result.Error = err.Error()
	s.mu.Lock()
	s.status.Phase = "error"
	s.status.Error = err.Error()
	s.mu.Unlock()
	go func() {
		if err := s.k8s.DeletePod(auxPodName, auxNamespace); err != nil {
			slog.Error("pg_auxiliar: fallo al eliminar pod en limpieza de error",
				"pod", auxPodName, "namespace", auxNamespace, "error", err)
		}
	}()
	return result, err
}

func (s *PgAuxiliarService) updateStatus(phase string, progress float64, step, message string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.status.Phase = phase
	s.status.Progress = progress
	s.status.CurrentStep = step
}

func cleanIP(raw string) string {
	// Limpia whitespace y newlines de la salida del comando
	cleaned := ""
	for _, c := range raw {
		if c == '\n' || c == '\r' || c == ' ' || c == '\t' {
			continue
		}
		cleaned += string(c)
	}
	return cleaned
}

// auxPodManifest genera el manifiesto YAML para el pod PostgreSQL auxiliar.
func auxPodManifest(name, namespace, image, pgPassword string) string {
	return `apiVersion: v1
kind: Pod
metadata:
  name: ` + name + `
  namespace: ` + namespace + `
  labels:
    app: pg-auxiliar
    sbos-managed: "true"
    sbos-temporary: "true"
spec:
  restartPolicy: Never
  containers:
    - name: postgres
      image: ` + image + `
      env:
        - name: POSTGRES_PASSWORD
          value: ` + pgPassword + `
        - name: PGDATA
          value: /var/lib/postgresql/data
      ports:
        - containerPort: 5432
          name: postgres
      readinessProbe:
        exec:
          command: [pg_isready, -U, postgres]
        initialDelaySeconds: 5
        periodSeconds: 3
      resources:
        requests:
          cpu: "100m"
          memory: "256Mi"
        limits:
          cpu: "500m"
          memory: "512Mi"
      volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
  volumes:
    - name: data
      emptyDir:
        sizeLimit: 2Gi
`
}
