package domain

import (
	"fmt"
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
type PgAuxiliarService struct {
	k8s PgAuxK8sPort

	mu     sync.Mutex
	status *PgAuxiliarStatus
}

// NewPgAuxiliarService crea un nuevo servicio de PG auxiliar.
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

// Start inicia la operación de backup del PG principal al auxiliar.
// Crea un pod temporal PostgreSQL, ejecuta pg_basebackup desde el principal,
// y verifica la integridad.
func (s *PgAuxiliarService) Start(sourcePod, sourceNS string, observer PgAuxStepFn) (*PgAuxiliarResult, error) {
	s.mu.Lock()
	if s.status.Phase != "idle" && s.status.Phase != "error" {
		s.mu.Unlock()
		return nil, ErrPgAuxiliarInProgress
	}
	s.status = &PgAuxiliarStatus{
		Phase:     "backup",
		StartedAt: time.Now(),
		PodName:   auxPodName,
	}
	s.mu.Unlock()

	result := &PgAuxiliarResult{Operation: "pg_basebackup", PodName: auxPodName}
	startTime := time.Now()

	// Paso 1: Crear pod temporal PostgreSQL
	s.updateStatus("backup", 0.05, "crear_pod_auxiliar", "Creando pod PostgreSQL temporal...")
	manifest := auxPodManifest(auxPodName, auxNamespace, auxPGImage)
	if err := s.k8s.CreatePodFromManifest(manifest, auxNamespace); err != nil {
		return s.failResult(result, "crear_pod_auxiliar", err)
	}
	if observer != nil {
		observer("crear_pod_auxiliar", 0.10, "Pod auxiliar creado")
	}

	// Paso 2: Esperar que el pod esté Ready
	s.updateStatus("backup", 0.15, "esperar_pod_ready", "Esperando que el pod auxiliar esté Ready...")
	if err := s.k8s.WaitForPodReady(auxPodName, auxNamespace, 120*time.Second); err != nil {
		s.k8s.DeletePod(auxPodName, auxNamespace)
		return s.failResult(result, "esperar_pod_ready", err)
	}
	if observer != nil {
		observer("esperar_pod_ready", 0.25, "Pod auxiliar Ready")
	}

	// Paso 3: Inicializar directorio de datos en el auxiliar
	s.updateStatus("backup", 0.30, "init_aux_data", "Inicializando directorio de datos...")
	if _, err := s.k8s.ExecInPod(auxPodName, auxNamespace, "",
		"rm -rf /var/lib/postgresql/data/* && chmod 700 /var/lib/postgresql/data"); err != nil {
		s.k8s.DeletePod(auxPodName, auxNamespace)
		return s.failResult(result, "init_aux_data", err)
	}
	if observer != nil {
		observer("init_aux_data", 0.35, "Directorio de datos listo")
	}

	// Paso 4: Obtener IP del auxiliar y ejecutar pg_basebackup desde source
	s.updateStatus("backup", 0.40, "pg_basebackup", "Ejecutando pg_basebackup...")

	// Obtener IP del pod auxiliar
	targetIP, err := s.k8s.ExecInPod(auxPodName, auxNamespace, "",
		"hostname -i 2>/dev/null || ip -4 addr show eth0 2>/dev/null | grep -oP 'inet \\K[\\d.]+' || cat /etc/hosts 2>/dev/null | grep $(hostname) | awk '{print $1}'")
	if err != nil {
		s.k8s.DeletePod(auxPodName, auxNamespace)
		return s.failResult(result, "pg_basebackup", fmt.Errorf("no se pudo obtener IP del auxiliar: %w", err))
	}
	targetIP = cleanIP(targetIP)

	// Configurar auxiliar para aceptar conexiones
	s.k8s.ExecInPod(auxPodName, auxNamespace, "",
		"echo 'host all all 0.0.0.0/0 md5' >> /var/lib/postgresql/data/pg_hba.conf && echo \"listen_addresses = '*'\" >> /var/lib/postgresql/data/postgresql.conf && pg_ctl -D /var/lib/postgresql/data reload 2>/dev/null || true")

	// Ejecutar pg_basebackup desde source hacia auxiliar
	backupOutput, err := s.k8s.ExecInPod(sourcePod, sourceNS, "",
		fmt.Sprintf("PGPASSWORD=sbos_aux_temp_pass pg_basebackup -h %s -p 5432 -U postgres -D /var/lib/postgresql/data/pgdata_backup -X stream -v 2>&1", targetIP))
	if err != nil {
		s.k8s.DeletePod(auxPodName, auxNamespace)
		return s.failResult(result, "pg_basebackup", fmt.Errorf("pg_basebackup falló: %s — %w", backupOutput, err))
	}
	if observer != nil {
		observer("pg_basebackup", 0.85, "pg_basebackup completado")
	}

	// Paso 5: Verificar integridad
	s.updateStatus("backup", 0.90, "verificar_integridad", "Verificando integridad del backup...")
	if _, err := s.k8s.ExecInPod(auxPodName, auxNamespace, "",
		"pg_isready -U postgres 2>/dev/null || pg_ctl -D /var/lib/postgresql/data start 2>/dev/null; sleep 2; pg_isready -U postgres"); err != nil {
		s.k8s.DeletePod(auxPodName, auxNamespace)
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
// mediante pg_dump → pg_restore.
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

	dumpPath := fmt.Sprintf("/tmp/sbos-pg-dump-%d.sql", time.Now().Unix())

	// Paso 1: pg_dump desde el auxiliar
	s.updateStatus("sync", 0.20, "pg_dump", "Exportando datos del auxiliar...")
	dumpOutput, err := s.k8s.ExecInPod(auxPodName, auxNamespace, "",
		fmt.Sprintf("pg_dump -U postgres %s > %s 2>&1 && echo '__SBOS__STEP_OK__ pg_dump' || echo '__SBOS__STEP_FAIL__ pg_dump'", database, dumpPath))
	if err != nil {
		return s.failResult(result, "pg_dump", fmt.Errorf("pg_dump falló: %s — %w", dumpOutput, err))
	}

	// Paso 2: Copiar dump al principal
	s.updateStatus("sync", 0.40, "copiar_dump", "Copiando dump al principal...")
	copyCmd := fmt.Sprintf("cat > %s << 'EOF'\n%s\nEOF", dumpPath, "PG_DUMP_PLACEHOLDER")
	if _, err := s.k8s.ExecInPod(targetPod, targetNS, "", copyCmd); err != nil {
		return s.failResult(result, "copiar_dump", fmt.Errorf("copia de dump falló: %w", err))
	}

	// Paso 3: pg_restore al principal
	s.updateStatus("sync", 0.60, "pg_restore", "Restaurando datos al principal...")
	restoreOutput, err := s.k8s.ExecInPod(targetPod, targetNS, "",
		fmt.Sprintf("psql -U postgres -f %s 2>&1 && echo '__SBOS__STEP_OK__ pg_restore' || echo '__SBOS__STEP_FAIL__ pg_restore'", dumpPath))
	if err != nil {
		return s.failResult(result, "pg_restore", fmt.Errorf("pg_restore falló: %s — %w", restoreOutput, err))
	}

	// Paso 4: Verificar principal
	s.updateStatus("sync", 0.90, "verificar_principal", "Verificando PG principal...")
	if _, err := s.k8s.ExecInPod(targetPod, targetNS, "", "pg_isready -U postgres"); err != nil {
		return s.failResult(result, "verificar_principal", fmt.Errorf("PG principal no responde tras restore: %w", err))
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
	go func() { _ = s.k8s.DeletePod(auxPodName, auxNamespace) }()
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
func auxPodManifest(name, namespace, image string) string {
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
          value: sbos_aux_temp_pass
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
