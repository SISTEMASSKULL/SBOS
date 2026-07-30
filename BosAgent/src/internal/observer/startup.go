// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

package observer

import (
	"math/rand"
	"time"

	"bos/internal/health"
	"bos/internal/plugin"
	"bos/internal/state"
	"github.com/rs/zerolog/log"
)

// K8sProbeFunc es la firma de la función que hace probe K8s durante P15.
// Retorna el mapa ficha_id → FichaState descubierto en el cluster.
// Si k8sCore no está disponible (nil o sin acceso), debe retornar nil.
type K8sProbeFunc func() map[string]state.FichaState

// SystemctlFn es la firma de la función para ejecutar comandos systemctl.
//
// Abstracción inyectable para evitar dependencia directa de os/exec en este
// paquete y permitir mocks en tests.
type SystemctlFn func(action, service string) error

// InitializeFichaStates registra todas las fichas descubiertas en STATE_MANAGER
// con sus estados iniciales derivados del manifest.yml.
//
// Las fichas con auto_install: true y sin dependencias arrancan en LISTA.
// Las fichas con auto_install: true y dependencias arrancan en PENDIENTE.
// Las fichas sin auto_install (opcionales) arrancan en PENDIENTE — el admin
// las activa explícitamente vía bosctl o Core UI.
//
// Recibe:
//   - loader: *plugin.Loader — fuente de manifests de fichas.
//   - stateMgr: *state.Manager — destino del registro.
//
// Retorna: ninguno. Errores de registro individual se logean como Warn y se omiten.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — paso 5.5, antes de runObserverLoop.
//
// Efectos secundarios:
//   - Escribe registros en state.Manager para cada ficha descubierta.
//   - Idempotente si la ficha ya estaba registrada (Manager.Register ignora duplicados).
//
// Estándares: ADR-021 (estados iniciales de ficha), SBOS-018 §5.
func InitializeFichaStates(loader *plugin.Loader, stateMgr *state.Manager) {
	fichas := loader.List()
	if len(fichas) == 0 {
		return
	}

	for _, f := range fichas {
		initialState := state.StatePendiente
		if f.AutoInstall {
			if len(f.Dependencies) > 0 {
				initialState = state.StatePendiente
			} else {
				initialState = state.StateLista
			}
		}

		if err := stateMgr.Register(f.ID, initialState, f.Version, f.Criticality, f.Server, f.Category, f.Backend); err != nil {
			log.Warn().Err(err).Str("ficha", f.ID).Msg("observer: error al registrar estado inicial")
		} else {
			log.Debug().Str("ficha", f.ID).Str("state", string(initialState)).Msg("observer: estado inicial registrado")
		}
	}

	log.Info().Int("count", len(fichas)).Msg("observer: estados de fichas inicializados")
}

// P15ReconcileAfterRebuild protege fichas ya instaladas cuando el state.json fue
// reconstruido desde cero (RecoveryRebuilt). Sin esta función, el observer vería
// todas las fichas en LISTA y las reinstalaría, destruyendo datos existentes (Gap A2).
//
// Flujo:
//  1. Solo actúa si stateMgr.Recovery == RecoveryRebuilt.
//  2. Llama probeK8s() para obtener el mapa ficha_id → FichaState real del cluster.
//  3. Para cada ficha descubierta como INSTALADA → SetK8sDiscoveredState actualiza
//     el estado de LISTA a INSTALADA, evitando que el observer la reinstale.
//
// Recibe:
//   - stateMgr: gestor de estado (fuente de verdad de fichas).
//   - probeK8s: función que retorna el estado real del cluster K8s.
//     Debe retornar nil si K8s no está disponible (daemon no llamará install).
//
// Efectos secundarios: puede actualizar estados en stateMgr.
//
// Estándares: P15 (idempotencia del instalador), ADR-021, SBOS-018 P1.
func P15ReconcileAfterRebuild(stateMgr *state.Manager, probeK8s K8sProbeFunc) {
	if stateMgr.Recovery != state.RecoveryRebuilt {
		return
	}

	log.Warn().Msg("P15: state.json reconstruido — ejecutando K8s discovery preventivo para proteger fichas existentes")

	discovered := probeK8s()
	if len(discovered) == 0 {
		log.Info().Msg("P15: K8s discovery sin resultados — sin fichas que proteger")
		return
	}

	protegidas := 0
	for fichaID, fichaState := range discovered {
		if err := stateMgr.SetK8sDiscoveredState(fichaID, fichaState); err != nil {
			log.Warn().Err(err).Str("ficha", fichaID).Msg("P15: error actualizando estado K8s")
			continue
		}
		if fichaState == state.StateInstalada {
			protegidas++
			log.Info().Str("ficha", fichaID).Msg("P15: ficha protegida — ya instalada en K8s, no se reinstalará")
		}
	}

	log.Info().Int("protegidas", protegidas).Int("descubiertas", len(discovered)).
		Msg("P15: K8s discovery preventivo completado")
}

// StartupReconcile verifica si K8s estaba activo antes del último reinicio del daemon
// y, si es así, dispara una reconciliación inmediata para evitar la ventana de hasta
// 300s del reconcile.Scheduler.
//
// Aplica jitter aleatorio (0–30s) cuando K8s ya está activo para evitar el efecto
// thundering herd si múltiples nodos arrancan simultáneamente tras un corte de energía.
//
// Recibe:
//   - stateMgr: *state.Manager — para leer el estado registrado de las fichas.
//   - healthChecker: *health.Checker — para disparar el health check inmediato.
//   - systemctl: SystemctlFn — función para ejecutar comandos systemctl (inyectable en tests).
//
// Retorna: ninguno. Errores de lectura de estado se logean como Warn y terminan la función.
//
// Callers conocidos:
//   - cmd/bos/main.go:runNormal — paso 10.5, justo antes de sdNotify("READY=1").
//
// Efectos secundarios:
//   - Puede hacer time.Sleep(jitter) si K8s está activo.
//   - Llama healthChecker.CheckNow() en ambos casos (kubelet activo o no).
//
// Estándares: SBOS-018 §5, BOS-REPAIR-01 §C-01.
func StartupReconcile(stateMgr *state.Manager, healthChecker *health.Checker, systemctl SystemctlFn) {
	st, err := stateMgr.Read()
	if err != nil {
		log.Warn().Err(err).Msg("startup reconcile: no se puede leer estado — omitiendo")
		return
	}

	k8sFicha, ok := st.Fichas["sbos-bootstrap-k8s"]
	if !ok || (k8sFicha.State != state.StateInstalada && k8sFicha.State != state.StateDegradada) {
		log.Info().Msg("startup reconcile: K8s no instalado previamente — el loop observer lo manejará")
		return
	}

	kubeletActive := systemctl("is-active", "kubelet") == nil

	if !kubeletActive {
		log.Warn().Msg("startup reconcile: kubelet NO activo — disparando reparación inmediata")
	} else {
		// K8s activo: aplicar jitter para evitar thundering herd
		jitter := time.Duration(rand.Intn(30)) * time.Second
		log.Info().Dur("jitter", jitter).Msg("startup reconcile: K8s activo — aplicando jitter antes de reconciliar")
		time.Sleep(jitter)
	}

	log.Info().Msg("startup reconcile: ejecutando health check inicial")
	healthChecker.CheckNow()
	log.Info().Msg("startup reconcile: completado")
}
