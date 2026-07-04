package biaos

// agent.go — F10.5/F10.6: agente ReAct OS-only (BOS-REPAIR-10 §2.3, §3).
//
// El ciclo Thought→Action→Observation NO genera comandos: en cada
// iteración consulta el ICAP, ejecuta la acción propuesta vía el dispatcher
// RPC del bos, observa el resultado y decide si continuar. TIPO A (lectura)
// se ejecuta directo; TIPO B (escritura, riesgo>bajo) se detiene en HITL.
// Tope de iteraciones (≤6) — un agente de infraestructura no diverge.

import (
	"fmt"

	"bos/internal/biaos/audit"
	"bos/internal/biaos/icap"
)

// MaxIteraciones acota el ciclo ReAct (BOS-REPAIR-10: ≤6).
const MaxIteraciones = 6

// RPCExecutor ejecuta un método del bos y devuelve su resultado serializable
// (lo implementa el dispatcher del server; en tests, un stub).
type RPCExecutor func(metodo string, params map[string]interface{}) (interface{}, error)

// Paso es una entrada de la trayectoria ReAct (se exporta como JSONL en F10.9).
type Paso struct {
	Iteracion   int         `json:"iteracion"`
	Pensamiento string      `json:"pensamiento"`
	AccionID    string      `json:"accion_id,omitempty"`
	Metodo      string      `json:"metodo,omitempty"`
	Observacion interface{} `json:"observacion,omitempty"`
}

// Resultado de una corrida del agente.
type Resultado struct {
	Intencion    string `json:"intencion"`
	Trayectoria  []Paso `json:"trayectoria"`
	Conclusion   string `json:"conclusion"`
	RequiereHITL bool   `json:"requiere_hitl"`
	SesionHITL   string `json:"sesion_hitl,omitempty"`
	Completado   bool   `json:"completado"`
}

// Agente es el ReAct loop. Sus dependencias se inyectan (hexagonal).
type Agente struct {
	catalogo *icap.Catalogo
	exec     RPCExecutor
	rbac     RBACPort
	sesiones *sesionStore
	auditor  *audit.Logger
}

// NewAgente construye el agente con sus colaboradores. Si sesiones es nil,
// crea uno propio — el agente siempre necesita store HITL para TIPO B.
func NewAgente(cat *icap.Catalogo, exec RPCExecutor, rbac RBACPort, sesiones *sesionStore, auditor *audit.Logger) *Agente {
	if sesiones == nil {
		sesiones = newSesionStore()
	}
	return &Agente{catalogo: cat, exec: exec, rbac: rbac, sesiones: sesiones, auditor: auditor}
}

// logEv registra un evento si hay auditor (nil-safe).
func (a *Agente) logEv(ev audit.Evento) {
	if a.auditor != nil {
		a.auditor.Log(ev)
	}
}

// Run ejecuta el ciclo ReAct sobre la intención del operador (sin params).
func (a *Agente) Run(user, intencion string) (*Resultado, error) {
	return a.RunConParams(user, intencion, nil)
}

// RunConParams ejecuta el ciclo ReAct con parámetros estructurados para la
// acción (BOS-REPAIR-10 §2.3: el ICAP elige la acción, el caller provee los
// argumentos — el agente NO inventa parámetros de infraestructura).
//
// Barreras antes de tocar nada: guardia de dominio (F10.7). Luego: ICAP
// propone → si riesgo>bajo, HITL preservando params y se detiene → si no,
// RBAC + ejecuta + observa.
func (a *Agente) RunConParams(user, intencion string, params map[string]interface{}) (*Resultado, error) {
	res := &Resultado{Intencion: intencion}

	a.logEv(audit.Evento{Tipo: "intent", User: user, Intencion: intencion})

	if err := GuardiaDominio(intencion); err != nil {
		a.logEv(audit.Evento{Tipo: "denegado", User: user, Intencion: intencion, Detalle: err.Error()})
		return nil, err
	}

	prop, err := a.catalogo.Buscar(intencion)
	if err != nil {
		res.Conclusion = "No encontré una acción de infraestructura para esa intención. " +
			"Reformula con el objetivo operativo (diagnosticar, reparar, escalar, mantener)."
		a.logEv(audit.Evento{Tipo: "final", User: user, Intencion: intencion, Detalle: "sin coincidencia ICAP"})
		return res, nil
	}

	accion := prop.Accion
	res.Trayectoria = append(res.Trayectoria, Paso{
		Iteracion:   1,
		Pensamiento: fmt.Sprintf("La intención mapea a %q (%s, riesgo %s).", accion.ID, accion.MetodoRPC, accion.Riesgo),
		AccionID:    accion.ID,
		Metodo:      accion.MetodoRPC,
	})
	a.logEv(audit.Evento{Tipo: "propuesta", User: user, Intencion: intencion,
		AccionID: accion.ID, Metodo: accion.MetodoRPC})

	// TIPO B (riesgo>bajo): detener en HITL preservando los params
	if accion.Confirmacion {
		ses := a.sesiones.Crear(user, intencion, accion, params)
		res.RequiereHITL = true
		res.SesionHITL = ses.ID
		res.Conclusion = fmt.Sprintf("La acción %q (riesgo %s) requiere confirmación. "+
			"Confirmar con: bosctl ai confirm %s", accion.ID, accion.Riesgo, ses.ID)
		if accion.Advertencia != "" {
			res.Conclusion += " ⚠️ " + accion.Advertencia
		}
		a.logEv(audit.Evento{Tipo: "hitl", User: user, SesionID: ses.ID,
			AccionID: accion.ID, Metodo: accion.MetodoRPC})
		return res, nil
	}

	// TIPO A (lectura): RBAC + ejecutar
	obs, err := a.ejecutarAccion(user, accion, params)
	res.Trayectoria[0].Observacion = obs
	if err != nil {
		res.Conclusion = "La acción falló: " + err.Error()
		return res, nil
	}
	res.Completado = true
	res.Conclusion = fmt.Sprintf("Ejecuté %s. %s", accion.MetodoRPC, resumirObservacion(obs))
	return res, nil
}

// Confirmar reanuda una sesión HITL: ejecuta la acción confirmada (F10.6).
func (a *Agente) Confirmar(user, sesionID string) (*Resultado, error) {
	ses, err := a.sesiones.Reclamar(sesionID)
	if err != nil {
		return nil, err
	}
	res := &Resultado{Intencion: ses.Intencion}
	obs, err := a.ejecutarAccion(user, ses.Accion, ses.Params)
	res.Trayectoria = append(res.Trayectoria, Paso{
		Iteracion: 1, Pensamiento: "Confirmada por el operador — ejecutando.",
		AccionID: ses.Accion.ID, Metodo: ses.Accion.MetodoRPC, Observacion: obs,
	})
	if err != nil {
		res.Conclusion = "La acción confirmada falló: " + err.Error()
		return res, nil
	}
	res.Completado = true
	res.Conclusion = fmt.Sprintf("Ejecuté %s (confirmada). %s", ses.Accion.MetodoRPC, resumirObservacion(obs))
	return res, nil
}

// ejecutarAccion aplica RBAC, audita ANTES de ejecutar, y ejecuta.
func (a *Agente) ejecutarAccion(user string, accion *icap.Accion, params map[string]interface{}) (interface{}, error) {
	if err := VerificarRBAC(a.rbac, user, accion.MetodoRPC); err != nil {
		a.logEv(audit.Evento{Tipo: "denegado", User: user, AccionID: accion.ID,
			Metodo: accion.MetodoRPC, Detalle: err.Error()})
		return nil, err
	}
	// auditar ANTES de ejecutar (A.8.15: registro previo a la intervención)
	a.logEv(audit.Evento{Tipo: "ejecucion", User: user, AccionID: accion.ID, Metodo: accion.MetodoRPC})
	return a.exec(accion.MetodoRPC, params)
}

// resumirObservacion produce una frase legible del resultado.
func resumirObservacion(obs interface{}) string {
	if obs == nil {
		return "Sin datos en la respuesta."
	}
	if m, ok := obs.(map[string]interface{}); ok {
		if sem, ok := m["semaforo"].(string); ok {
			return "Semáforo del sistema: " + sem + "."
		}
		if sem, ok := m["semaforo_vdi"].(string); ok {
			return "Semáforo VDI: " + sem + "."
		}
		if causa, ok := m["diagnostico"].(map[string]interface{}); ok {
			if c, ok := causa["causa_probable"].(string); ok {
				return "Causa probable: " + c
			}
		}
	}
	return "Resultado recibido."
}

// listarHerramientas expone los metodos del catálogo (bos.ai.catalog).
func (a *Agente) listarHerramientas() []string {
	out := make([]string, 0, len(a.catalogo.Acciones))
	for _, ac := range a.catalogo.Acciones {
		marca := ""
		if ac.Confirmacion {
			marca = " [HITL]"
		}
		out = append(out, fmt.Sprintf("%s → %s (%s)%s", ac.ID, ac.MetodoRPC, ac.Riesgo, marca))
	}
	return out
}

// Herramientas expone el catálogo del agente (bos.ai.catalog).
func (a *Agente) Herramientas() []string { return a.listarHerramientas() }
