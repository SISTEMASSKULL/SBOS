// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package observer

import (
	"sort"
	"sync"
	"time"

	"bos/internal/audit"
	"bos/internal/installer"
	"bos/internal/paths"
	"bos/internal/plugin"
	"bos/internal/state"
	"github.com/rs/zerolog/log"
)

// Config agrupa las dependencias necesarias para crear un Loop.
//
// Thread safety: Config se pasa por valor en New(); no se comparte tras la construcción.
type Config struct {
	Orchestrator *installer.Orchestrator // orquestador de sagas (install/repair)
	Loader       *plugin.Loader          // cargador de manifests de fichas
	StateMgr     *state.Manager          // gestor de estado centralizado
	// Interval: frecuencia del tick de observación. 0 → usa 5 segundos.
	Interval time.Duration
}

// Loop observa estados de fichas cada Interval segundos y reacciona a transiciones.
//
// Thread safety: Run() y Stop() son seguros para llamar desde goroutines distintas.
// Stop() es idempotente gracias a sync.Once.
type Loop struct {
	cfg    Config
	stopCh chan struct{}
	once   sync.Once
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
		cfg:    cfg,
		stopCh: make(chan struct{}),
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
	st, err := l.cfg.StateMgr.Read()
	if err != nil {
		log.Warn().Err(err).Msg("observer: no se puede leer estado")
		return
	}

	// Fase 1 — desbloquear fichas con dependencias satisfechas (PENDIENTE → LISTA)
	for name, ficha := range st.Fichas {
		if ficha.State != state.StatePendiente {
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
	next := FindNextAutoInstall(st, fichaIndex)
	if next != nil {
		log.Info().Str("ficha", next.ID).Str("version", next.Version).Msg("observer: iniciando instalación automática")
		audit.Log(paths.AuditLog, "OBSERVER_INSTALL",
			"user=root",
			"ficha="+next.ID,
			"version="+next.Version)

		// LISTA → INSTALANDO (ADR-021 #2→#3)
		if err := l.cfg.StateMgr.Transition(next.ID, state.StateInstalando); err != nil {
			log.Warn().Err(err).Str("ficha", next.ID).Msg("observer: transición a INSTALANDO falló")
			return
		}

		result, err := l.cfg.Orchestrator.Install(next.ID, next.Version)
		if err != nil || !result.Success {
			log.Error().Err(err).Str("ficha", next.ID).Int("exit", result.ExitCode).Msg("observer: instalación falló")
			// INSTALANDO → FALLA_INSTALACION (ADR-021 #3→#13)
			_ = l.cfg.StateMgr.Transition(next.ID, state.StateFallaInstalacion)
			return
		}

		// INSTALANDO → INSTALADA (ADR-021 #3→#4)
		if err := l.cfg.StateMgr.Transition(next.ID, state.StateInstalada); err != nil {
			log.Warn().Err(err).Str("ficha", next.ID).Msg("observer: transición a INSTALADA falló")
		}

		log.Info().Str("ficha", next.ID).Dur("duration", result.Duration).Msg("observer: instalación completada")
		audit.Log(paths.AuditLog, "OBSERVER_INSTALL_OK",
			"user=root",
			"ficha="+next.ID)

		if err := l.cfg.StateMgr.RegisterHashes(next.ID, next.Hashes()); err != nil {
			log.Warn().Err(err).Str("ficha", next.ID).Msg("observer: registro de hashes falló")
		}
		return
	}

	// Fase 3 — reparar fichas DEGRADADA (solo auto_install, secuencial)
	for name, ficha := range st.Fichas {
		if ficha.State != state.StateDegradada && ficha.State != state.StateReparando {
			continue
		}
		mf, ok := fichaIndex[name]
		if !ok || !mf.AutoInstall {
			continue
		}

		log.Info().Str("ficha", name).Msg("observer: iniciando auto-reparación")
		if ficha.State != state.StateReparando {
			// DEGRADADA → REPARANDO (ADR-021 #8→#11)
			if err := l.cfg.StateMgr.Transition(name, state.StateReparando); err != nil {
				log.Warn().Err(err).Str("ficha", name).Msg("observer: transición a REPARANDO falló")
				continue
			}
		}

		result, err := l.cfg.Orchestrator.Repair(name)
		if err != nil || !result.Success {
			// Repair fallido → volver a DEGRADADA para reintentar en siguiente tick
			log.Error().Err(err).Str("ficha", name).Msg("observer: reparación falló — volviendo a DEGRADADA")
			_ = l.cfg.StateMgr.Transition(name, state.StateDegradada)
			continue
		}

		// REPARANDO → INSTALADA (ADR-021 #11→#4)
		_ = l.cfg.StateMgr.Transition(name, state.StateInstalada)
		log.Info().Str("ficha", name).Msg("observer: reparación exitosa")
	}
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
func FindNextAutoInstall(st *state.SBOSState, index map[string]*plugin.FichaManifest) *plugin.FichaManifest {
	var candidates []*plugin.FichaManifest

	for _, mf := range index {
		if !mf.AutoInstall {
			continue
		}
		ficha, ok := st.Fichas[mf.ID]
		if !ok {
			continue
		}
		if ficha.State != state.StateLista {
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
		if ficha.State != state.StateInstalada {
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
