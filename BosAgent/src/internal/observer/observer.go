// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package observer

import (
	"fmt"
	"net"
	"sort"
	"sync"
	"time"

	"bos/internal/audit"
	"bos/internal/ficha"
	"bos/internal/installer"
	"bos/internal/paths"
	"bos/internal/plugin"
	"bos/internal/resources"
	"bos/internal/state"
	"github.com/rs/zerolog/log"
)

// SystemMaintainer es la interfaz que ejecuta mantenimiento proactivo del sistema.
// Implementada por k8s.Core en producción; nil-safe en tests.
type SystemMaintainer interface {
	// RunMaintenance ejecuta una pasada de mantenimiento y retorna el número
	// de recursos del sistema que fueron limpiados en esta pasada.
	RunMaintenance() int
	// IsClusterReady verifica si el cluster K8s puede aceptar nuevos pods.
	// Retorna (true, "") si está listo; (false, reason) si algún nodo está NotReady.
	IsClusterReady() (bool, string)
}

// Config agrupa las dependencias necesarias para crear un Loop.
//
// Thread safety: Config se pasa por valor en New(); no se comparte tras la construcción.
type Config struct {
	Orchestrator *installer.Orchestrator // orquestador de sagas (install/repair)
	Loader       *plugin.Loader          // cargador de manifests de fichas
	StateMgr     *state.Manager          // gestor de estado centralizado
	Maintainer   SystemMaintainer        // mantenimiento proactivo del sistema (nil = omitir)
	// Interval: frecuencia del tick de observación. 0 → usa 5 segundos.
	Interval time.Duration
}

// Loop observa estados de fichas cada Interval segundos y reacciona a transiciones.
//
// Thread safety: Run() y Stop() son seguros para llamar desde goroutines distintas.
// Stop() es idempotente gracias a sync.Once.
// failCount y failCooldown implementan backoff exponencial por ficha: una ficha
// con fallos repetidos cede el slot de instalación a fichas más saludables.
type Loop struct {
	cfg          Config
	stopCh       chan struct{}
	once         sync.Once
	failMu       sync.Mutex
	failCount    map[string]int       // fallos consecutivos por ID de ficha
	failCooldown map[string]time.Time // hasta cuándo está en cooldown la ficha
	tickCount    int                  // contador de ticks para logs periódicos de recursos
}

// New crea un Loop con la configuración dada.
//
// Recibe:
//   - cfg Config — dependencias del loop. Si cfg.Interval es 0, se usa 5 segundos.
//
// Retorna: *Loop listo para usar. Llamar Run() para iniciar, Stop() para terminar.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — paso 5.5.
//
// Efectos secundarios: ninguno — solo inicialización.
//
// Estándares: SBOS-018 §5, ADR-021.
func New(cfg Config) *Loop {
	if cfg.Interval == 0 {
		cfg.Interval = 5 * time.Second
	}
	return &Loop{
		cfg:          cfg,
		stopCh:       make(chan struct{}),
		failCount:    make(map[string]int),
		failCooldown: make(map[string]time.Time),
	}
}

// Run ejecuta el loop de observación. Bloquea hasta que Stop() sea llamado.
// Diseñado para ejecutarse como goroutine: go loop.Run().
//
// Recibe: ninguno.
//
// Retorna: cuando Stop() cierra stopCh.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — llamado como goroutine en paso 5.5.
//
// Efectos secundarios:
//   - Puede transicionar estados de fichas en state.Manager.
//   - Puede invocar Install() y Repair() del orquestador.
//   - Escribe entradas en audit log para cada install completado.
//
// Estándares: SBOS-018 §5, ADR-021 (máquina de 18 estados).
func (l *Loop) Run() {
	fichaIndex := make(map[string]*plugin.FichaManifest)
	rebuild := func() {
		for _, f := range l.cfg.Loader.List() {
			fichaIndex[f.ID] = f
		}
	}
	rebuild()

	log.Info().Int("count", len(fichaIndex)).Msg("observer: vigilando estados de fichas")

	if l.cfg.Maintainer != nil {
		go func() {
			mt := time.NewTicker(60 * time.Second)
			defer mt.Stop()
			for {
				select {
				case <-l.stopCh:
					return
				case <-mt.C:
					if n := l.cfg.Maintainer.RunMaintenance(); n > 0 {
						log.Info().Int("n", n).Msg("observer: mantenimiento automatico completado")
					}
					// CleanStuckTerminating: limpieza opcional si el Maintainer la implementa
					type stuckCleaner interface {
						CleanStuckTerminating() (int, error)
					}
					if sc, ok := l.cfg.Maintainer.(stuckCleaner); ok {
						if p, _ := sc.CleanStuckTerminating(); p > 0 {
							log.Info().Int("n", p).Msg("observer: pods stuck-terminating eliminados")
						}
					}
					resources.SignalZombieParents()
				}
			}
		}()
	}

	ticker := time.NewTicker(l.cfg.Interval)
	defer ticker.Stop()

	for {
		select {
		case <-l.stopCh:
			log.Info().Msg("observer: loop detenido")
			return
		case <-ticker.C:
			if len(fichaIndex) != l.cfg.Loader.Count() {
				rebuild()
			}
			l.tick(fichaIndex)
		}
	}
}

// Stop señaliza a Run() para que retorne. Seguro de llamar múltiples veces.
//
// Recibe: ninguno.
//
// Retorna: ninguno. El canal se cierra exactamente una vez gracias a sync.Once.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — defer loop.Stop() tras construcción.
//
// Efectos secundarios: cierra stopCh (una sola vez). Run() retornará en el
// siguiente ciclo select.
func (l *Loop) Stop() {
	l.once.Do(func() { close(l.stopCh) })
}

// tick ejecuta un ciclo de observación completo (3 fases).
//
// Efectos (riesgo P9 — operaciones de estado sin rollback):
//   - Fase 1: transiciona fichas de PENDIENTE a LISTA si las deps están satisfechas.
//   - Fase 2: instala la siguiente ficha elegible (una por tick, secuencial).
//   - Fase 3: repara fichas en DEGRADADA (secuencial, sin goroutines — ver doc.go §invariante).
func (l *Loop) tick(fichaIndex map[string]*plugin.FichaManifest) {
	l.tickCount++

	// Log periódico del estado del sistema cada 60 ticks (~5 min con interval=5s).
	if l.tickCount%60 == 1 {
		resources.LogSystemStatus()
	}

	st, err := l.cfg.StateMgr.Read()
	if err != nil {
		log.Warn().Err(err).Msg("observer: no se puede leer estado")
		return
	}

	// Fase 0 — detectar actualizaciones de versión (P15-A3)
	// Para cada ficha INSTALADA, compara la versión del manifest con la versión instalada.
	// Si manifest.Version > state.Version → ACTUALIZACION_DISPONIBLE (nunca reinstalar).
	for name, fichaEntry := range st.Fichas {
		if fichaEntry.State != state.StateInstalled {
			continue
		}
		mf, ok := fichaIndex[name]
		if !ok || mf.Version == fichaEntry.Version || fichaEntry.Version == "" {
			continue
		}
		manifestVer, err1 := ficha.ParseVersion(mf.Version)
		installedVer, err2 := ficha.ParseVersion(fichaEntry.Version)
		if err1 != nil || err2 != nil {
			continue
		}
		if manifestVer.GreaterThan(installedVer) {
			if err := l.cfg.StateMgr.Transition(name, state.StateUpdateAvailable); err != nil {
				log.Warn().Err(err).Str("ficha", name).Msg("observer: transición a ACTUALIZACION_DISPONIBLE falló")
			} else {
				log.Info().
					Str("ficha", name).
					Str("instalada", fichaEntry.Version).
					Str("disponible", mf.Version).
					Msg("observer: actualización de versión detectada — esperando aprobación")
				audit.Log(paths.AuditLog, "OBSERVER_UPDATE_AVAILABLE",
					"ficha="+name,
					"instalada="+fichaEntry.Version,
					"disponible="+mf.Version)
			}
		}
	}

	// Fase 1 — desbloquear fichas con dependencias satisfechas (PENDIENTE → LISTA)
	for name, fichaEntry := range st.Fichas {
		if fichaEntry.State != state.StatePending {
			continue
		}
		mf, ok := fichaIndex[name]
		if !ok || !mf.AutoInstall {
			continue
		}
		if DepsSatisfied(mf.Dependencies, st) {
			if err := l.cfg.StateMgr.Unblock(name); err != nil {
				log.Warn().Err(err).Str("ficha", name).Msg("observer: error al desbloquear")
			} else {
				log.Info().Str("ficha", name).Msg("observer: desbloqueada (dependencias satisfechas)")
			}
		}
	}

	// Fase 2 — instalar siguiente ficha elegible (una sola por tick, secuencial)
	// Fichas en cooldown de backoff se excluyen para no bloquear el slot.
	l.failMu.Lock()
	excluded := make(map[string]bool)
	now := time.Now()
	for id, until := range l.failCooldown {
		if now.Before(until) {
			excluded[id] = true
		}
	}
	l.failMu.Unlock()

	next := findNextAutoInstall(st, fichaIndex, excluded)
	if next != nil {
		// Verificación de cluster K8s ANTES de instalar.
		// Se omite para fichas con requires_k8s: false (ej: sbos-bootstrap-k8s)
		// que son precisamente las que instalan el cluster.
		// Si el nodo no está Ready, diferimos sin consumir reintentos (no es un fallo
		// de la ficha — es un fallo de infraestructura). El log limita a 1 por minuto
		// usando tickCount para no saturar los logs.
		if l.cfg.Maintainer != nil && next.RequiresK8s {
			if ok, reason := l.cfg.Maintainer.IsClusterReady(); !ok {
				if l.tickCount%12 == 1 {
					log.Warn().
						Str("ficha", next.ID).
						Str("motivo", reason).
						Msg("observer: instalación diferida — cluster K8s no está listo")
				}
				return
			}
		}

		// Verificación de recursos ANTES de instalar.
		// Si no hay suficiente memoria, el instalador intenta recuperarla (drop_caches).
		// Si tras la recuperación aun no alcanza, se difiere esta ficha un tick
		// para que el observer pueda instalar otra ficha de menor consumo.
		// El instalador NUNCA se detiene — solo reordena la instalación.
		if next.MemoryRequest != "" || next.CPURequest != "" {
			memOK, availMiB := resources.CheckAndRecover(next.ID, next.MemoryRequest)
			cpuOK := !resources.CPUOverloaded()
			if !memOK || !cpuOK {
				reason := "memoria"
				if !cpuOK {
					reason = "cpu"
				}
				log.Warn().
					Str("ficha", next.ID).
					Str("memory_request", next.MemoryRequest).
					Int64("available_mib", availMiB).
					Str("motivo", reason).
					Msg("observer: instalación diferida — recursos insuficientes, reintentando próximo tick")
				audit.Log(paths.AuditLog, "OBSERVER_INSTALL_DEFERRED",
					"ficha="+next.ID,
					"motivo="+reason)
				return
			}
		}

		// Verificación de puertos del host ANTES de instalar (motor de puertos SO).
		// Solo aplica a fichas de aplicación (requires_k8s=true). Las fichas de
		// bootstrap (requires_k8s=false) gestionan sus propios puertos internamente
		// porque son las responsables de inicializar la infraestructura.
		if next.RequiresK8s && len(next.HostPortsRequired) > 0 {
			if blocked := checkHostPorts(next.HostPortsRequired); len(blocked) > 0 {
				if l.tickCount%12 == 1 {
					log.Warn().
						Str("ficha", next.ID).
						Str("puertos_bloqueados", fmt.Sprintf("%v", blocked)).
						Msg("observer: instalación diferida — puertos del host ocupados")
				}
				return
			}
		}

		log.Info().Str("ficha", next.ID).Str("version", next.Version).Msg("observer: iniciando instalación automática")
		audit.Log(paths.AuditLog, "OBSERVER_INSTALL",
			"user=root",
			"ficha="+next.ID,
			"version="+next.Version)

		// LISTA → INSTALANDO (ADR-021 #2→#3)
		if err := l.cfg.StateMgr.Transition(next.ID, state.StateInstalling); err != nil {
			log.Warn().Err(err).Str("ficha", next.ID).Msg("observer: transición a INSTALANDO falló")
			return
		}

		result, err := l.cfg.Orchestrator.Install(next.ID, next.Version)
		if err != nil || !result.Success {
			log.Error().Err(err).Str("ficha", next.ID).Int("exit", result.ExitCode).Msg("observer: instalación falló")
			// INSTALANDO → FALLA_INSTALACION (ADR-021 #3→#13)
			_ = l.cfg.StateMgr.Transition(next.ID, state.StateInstallFailed)

			// Backoff exponencial: cede el slot a otras fichas tras fallos repetidos.
			l.failMu.Lock()
			l.failCount[next.ID]++
			cnt := l.failCount[next.ID]
			bd := installBackoff(cnt)
			if bd > 0 {
				l.failCooldown[next.ID] = time.Now().Add(bd)
				log.Warn().
					Str("ficha", next.ID).
					Int("intento", cnt).
					Dur("cooldown", bd).
					Msg("observer: backoff — slot liberado para otras fichas")
			}
			l.failMu.Unlock()
			return
		}

		// INSTALANDO → INSTALADA (ADR-021 #3→#4)
		if err := l.cfg.StateMgr.Transition(next.ID, state.StateInstalled); err != nil {
			log.Warn().Err(err).Str("ficha", next.ID).Msg("observer: transición a INSTALADA falló")
		}

		// Instalación exitosa — resetear contadores de backoff
		l.failMu.Lock()
		delete(l.failCount, next.ID)
		delete(l.failCooldown, next.ID)
		l.failMu.Unlock()

		log.Info().Str("ficha", next.ID).Dur("duration", result.Duration).Msg("observer: instalación completada")
		audit.Log(paths.AuditLog, "OBSERVER_INSTALL_OK",
			"user=root",
			"ficha="+next.ID)

		if err := l.cfg.StateMgr.RegisterHashes(next.ID, next.Hashes()); err != nil {
			log.Warn().Err(err).Str("ficha", next.ID).Msg("observer: registro de hashes falló")
		}
		return
	}

	// Fase 3 — reparar fichas DEGRADADA o PHYSICAL_ERROR (solo auto_install, secuencial)
	for name, fichaEntry := range st.Fichas {
		if fichaEntry.State != state.StateDegraded &&
			fichaEntry.State != state.StateRepairing &&
			fichaEntry.State != state.StatePhysicalError {
			continue
		}
		mf, ok := fichaIndex[name]
		if !ok || !mf.AutoInstall {
			continue
		}

		log.Info().Str("ficha", name).Msg("observer: iniciando auto-reparación")
		if fichaEntry.State != state.StateRepairing {
			// DEGRADADA → REPARANDO (ADR-021 #8→#11)
			if err := l.cfg.StateMgr.Transition(name, state.StateRepairing); err != nil {
				log.Warn().Err(err).Str("ficha", name).Msg("observer: transición a REPARANDO falló")
				continue
			}
		}

		result, err := l.cfg.Orchestrator.Repair(name)
		if err != nil || !result.Success {
			// Repair fallido → volver a DEGRADADA para reintentar en siguiente tick
			log.Error().Err(err).Str("ficha", name).Msg("observer: reparación falló — volviendo a DEGRADADA")
			_ = l.cfg.StateMgr.Transition(name, state.StateDegraded)
			continue
		}

		// REPARANDO → INSTALADA (ADR-021 #11→#4)
		_ = l.cfg.StateMgr.Transition(name, state.StateInstalled)
		log.Info().Str("ficha", name).Msg("observer: reparación exitosa")
	}
}

// installBackoff devuelve el tiempo de espera según el número de fallos consecutivos.
// Primer fallo: reintento inmediato; fallos siguientes: backoff 60s→120s→240s→600s.
func installBackoff(failCount int) time.Duration {
	switch failCount {
	case 0, 1:
		return 0
	case 2:
		return 60 * time.Second
	case 3:
		return 120 * time.Second
	case 4:
		return 240 * time.Second
	default:
		return 600 * time.Second
	}
}

// findNextAutoInstall es la implementación interna que acepta un conjunto de IDs excluidos.
// Las fichas en ese conjunto no se seleccionarán aunque sean elegibles (backoff activo).
func findNextAutoInstall(st *state.SBOSState, index map[string]*plugin.FichaManifest, excluded map[string]bool) *plugin.FichaManifest {
	var candidates []*plugin.FichaManifest

	for _, mf := range index {
		if !mf.AutoInstall {
			continue
		}
		if excluded[mf.ID] {
			continue
		}
		fichaEntry, ok := st.Fichas[mf.ID]
		if !ok {
			continue
		}
		if fichaEntry.State != state.StateReady && fichaEntry.State != state.StateInstallFailed {
			continue
		}
		if !DepsSatisfied(mf.Dependencies, st) {
			continue
		}
		candidates = append(candidates, mf)
	}

	if len(candidates) == 0 {
		return nil
	}

	sort.Slice(candidates, func(i, j int) bool {
		return candidates[i].ExecutionOrder < candidates[j].ExecutionOrder
	})

	return candidates[0]
}

// FindNextAutoInstall retorna la siguiente ficha elegible para instalación automática.
//
// Criterios de elegibilidad (todos deben cumplirse):
//   - auto_install: true en el manifest.
//   - Estado actual: LISTA (dependencias satisfechas, esperando slot en DAG).
//   - Todas las dependencias declaradas en INSTALADA.
//
// Entre las candidatas, elige la de menor ExecutionOrder (orden Kahn).
//
// Recibe:
//   - st: *state.SBOSState — snapshot del estado actual (no se modifica).
//   - index: map[string]*plugin.FichaManifest — índice de manifests cargados.
//
// Retorna:
//   - *plugin.FichaManifest si hay candidata elegible.
//   - nil si no hay ninguna ficha lista para instalar.
//
// Efectos secundarios: ninguno — función pura.
//
// Estándares: ADR-021 #2→#3, SBOS-018 §5.
// FindNextAutoInstall retorna la siguiente ficha elegible sin filtro de backoff.
// Usada directamente en tests. El observer usa findNextAutoInstall con el mapa
// de cooldowns para implementar backoff exponencial.
func FindNextAutoInstall(st *state.SBOSState, index map[string]*plugin.FichaManifest) *plugin.FichaManifest {
	return findNextAutoInstall(st, index, nil)
}

// DepsSatisfied retorna true si todas las dependencias declaradas están en INSTALADA.
//
// Recibe:
//   - deps: []string — lista de IDs de fichas que deben estar en INSTALADA.
//   - st: *state.SBOSState — snapshot del estado actual.
//
// Retorna:
//   - true si deps está vacío o si todas las fichas listadas están en INSTALADA.
//   - false si alguna dependencia no está registrada o no está en INSTALADA.
//
// Efectos secundarios: ninguno — función pura.
//
// Estándares: ADR-021 #4 (estado INSTALADA como señal de dependencia satisfecha).
func DepsSatisfied(deps []string, st *state.SBOSState) bool {
	for _, dep := range deps {
		ficha, ok := st.Fichas[dep]
		if !ok {
			return false
		}
		if ficha.State != state.StateInstalled {
			return false
		}
	}
	return true
}

// TopologicalSort ordena fichas de forma que las dependencias aparezcan antes
// que los dependientes. Usa el algoritmo de Kahn con ExecutionOrder como
// desempate para garantizar un orden determinista.
//
// Recibe:
//   - fichas: []*plugin.FichaManifest — lista de fichas a ordenar.
//
// Retorna:
//   - []*plugin.FichaManifest ordenada: dependencias primero, dependientes después.
//     Si hay dependencias circulares, los nodos afectados se añaden al final
//     ordenados por ExecutionOrder. Nunca retorna nil.
//
// Efectos secundarios: ninguno — función pura (no modifica la slice de entrada).
//
// Callers conocidos: disponible para uso futuro en bootstrap y planificador.
//
// Estándares: SBOS-018 §5 (orden de instalación por dependencias), ADR-021.
func TopologicalSort(fichas []*plugin.FichaManifest) []*plugin.FichaManifest {
	if len(fichas) == 0 {
		return []*plugin.FichaManifest{}
	}
	byID := make(map[string]*plugin.FichaManifest, len(fichas))
	inDegree := make(map[string]int, len(fichas))
	for _, f := range fichas {
		byID[f.ID] = f
		if _, ok := inDegree[f.ID]; !ok {
			inDegree[f.ID] = 0
		}
	}
	for _, f := range fichas {
		for _, dep := range f.Dependencies {
			if _, ok := byID[dep]; ok {
				inDegree[f.ID]++
			}
		}
	}

	sortByOrder := func(slice []*plugin.FichaManifest) {
		sort.Slice(slice, func(i, j int) bool {
			return slice[i].ExecutionOrder < slice[j].ExecutionOrder
		})
	}

	var queue []*plugin.FichaManifest
	for _, f := range fichas {
		if inDegree[f.ID] == 0 {
			queue = append(queue, f)
		}
	}
	sortByOrder(queue)

	var result []*plugin.FichaManifest
	for len(queue) > 0 {
		sortByOrder(queue)
		f := queue[0]
		queue = queue[1:]
		result = append(result, f)

		for _, other := range fichas {
			for _, dep := range other.Dependencies {
				if dep == f.ID {
					inDegree[other.ID]--
					if inDegree[other.ID] == 0 {
						queue = append(queue, other)
					}
				}
			}
		}
	}

	// Nodos restantes (deps circulares o no resueltas) — al final por orden
	seen := make(map[string]bool, len(result))
	for _, r := range result {
		seen[r.ID] = true
	}
	var remaining []*plugin.FichaManifest
	for _, f := range fichas {
		if !seen[f.ID] {
			remaining = append(remaining, f)
		}
	}
	sortByOrder(remaining)
	result = append(result, remaining...)

	return result
}

// checkHostPorts verifica que los puertos del host estén disponibles.
// Retorna la lista de puertos bloqueados (vacía = todos disponibles).
// Usa net.Listen para verificación portátil sin depender de herramientas externas.
func checkHostPorts(ports []int) []int {
	var blocked []int
	for _, p := range ports {
		addr := fmt.Sprintf(":%d", p)
		ln, err := net.Listen("tcp", addr)
		if err != nil {
			blocked = append(blocked, p)
			continue
		}
		_ = ln.Close()
	}
	return blocked
}
