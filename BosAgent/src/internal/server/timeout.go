package server

// timeout.go — F6.2: timeout por categoría de método JSON-RPC.
//
// Tres categorías (BOS-REPAIR Plan Maestro v3 §FASE-6):
//
//	lectura   →   5s  (status, list, read, check, query, validate)
//	escritura →  30s  (mutaciones del Context Plane, cleanup)
//	saga      → 600s  (install/update/repair/remove, bootstrap, pg_auxiliar)
//
// El handler corre en una goroutine; si el plazo expira el cliente recibe
// -32006 inmediatamente. La goroutine termina sola y su respuesta se
// descarta (canal con buffer 1 — nunca bloquea).

import "time"

// Códigos de categoría para methodCategory.
type rpcCategory int

const (
	catLectura rpcCategory = iota
	catEscritura
	catSaga
)

// timeoutByCategory define el plazo de cada categoría. Variable de paquete
// (no const) para que los tests puedan acortar plazos sin esperas reales.
var timeoutByCategory = map[rpcCategory]time.Duration{
	catLectura:   5 * time.Second,
	catEscritura: 30 * time.Second,
	catSaga:      600 * time.Second,
}

// sagaMethods: operaciones largas con compensación — plazo 600s.
var sagaMethods = map[string]bool{
	"bos.ficha.install":               true,
	"bos.ficha.update":                true,
	"bos.ficha.repair":                true,
	"bos.ficha.remove":                true,
	"bos.ficha.probe":                 true,
	"bos.saga.execute":                true,
	"bos.bootstrap.start":             true,
	"bos.bootstrap.resume":            true,
	"bos.bootstrap.pg_auxiliar_start": true,
	"bos.bootstrap.pg_auxiliar_sync":  true,
	// F9: drain y mantenimiento son sagas largas (drain_timeout + op)
	"bos.k8s.node.drain":    true,
	"bos.maintenance.start": true,
	// F10: el agente puede llamar al LLM + encadenar acciones
	"bos.ai.ask":     true,
	"bos.ai.run":     true,
	"bos.ai.confirm": true,
}

// writeMethods: mutaciones rápidas (Context Plane, limpieza) — plazo 30s.
var writeMethods = map[string]bool{
	"bos.ctx.create":                    true,
	"bos.ctx.device.register":           true,
	"bos.ctx.promote":                   true,
	"bos.ctx.switch":                    true,
	"bos.ctx.invalidate":                true,
	"bos.ctx.tenant.suspend":            true,
	"bos.bootstrap.pg_auxiliar_cleanup": true,
	// F9: mutadores rápidos del cluster
	"bos.k8s.node.cordon":    true,
	"bos.k8s.node.uncordon":  true,
	"bos.k8s.pod.evict":      true,
	"bos.k8s.pod.restart":    true,
	"bos.k8s.scale":          true,
	"bos.k8s.rollout.undo":   true,
	"bos.k8s.resources.set":  true,
	"bos.maintenance.cancel": true,
}

// methodCategory clasifica un método. Todo lo no listado es lectura —
// la categoría más restrictiva (deny-by-default aplicado a plazos).
func methodCategory(method string) rpcCategory {
	switch {
	case sagaMethods[method]:
		return catSaga
	case writeMethods[method]:
		return catEscritura
	default:
		return catLectura
	}
}

// methodTimeout retorna el plazo máximo de ejecución del método.
func methodTimeout(method string) time.Duration {
	return timeoutByCategory[methodCategory(method)]
}
