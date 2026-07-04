// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic
//
// SOLO REFERENCIA DE LÓGICA — NO IMPORTAR, NO COPIAR COMO ESTÁ.
//
// Origen: internal/server/bootstrap.go (archivado en F0.7)
// Destino: internal/bootstrap/ (F1.2)
// Razón: handlers de bootstrap en el paquete server violan la separación de capas.

package server

import (
	"fmt"
	"os"
	"strings"
	"time"

	"bos/internal/state"
)

// Bootstrap WS handlers — motor de instalación de 22 fichas (Iteración 1)
//
// Acciones expuestas:
//   bootstrap_start   — iniciar instalación (interactiva o --unattended)
//   bootstrap_status  — estado actual del proceso
//   bootstrap_verify  — verificar criterios C-01..C-08
//   bootstrap_resume  — reanudar instalación interrumpida
//   bootstrap_reset   — reiniciar estado bootstrap

// saveSeedEnv escribe los datos del tenant recibidos del TUI en /etc/bos/bos-bootstrap.env
// y los inyecta en el proceso actual para que el observer loop y el master script los lean.
func saveSeedEnv(params map[string]interface{}) error {
	str := func(key string) string { v, _ := params[key].(string); return v }

	vars := map[string]string{
		"BOS_TENANT_NAME":   str("razon_social"),
		"BOS_TENANT_NIT":    str("nit"),
		"BOS_TENANT_PAIS":   str("pais"),
		"BOS_TENANT_DOMAIN": str("dominio"),
		"BOS_ROOT_USER":     str("email"),
		"BOS_ADMIN_NOMBRE":  str("nombre"),
	}
	if pw := str("password"); pw != "" {
		vars["BOS_ROOT_PASSWORD"] = pw
	}
	if mfa, ok := params["mfa"].(bool); ok && mfa {
		vars["BOS_MFA_ENABLED"] = "true"
	}

	var lines []string
	for k, v := range vars {
		if v != "" {
			lines = append(lines, k+"="+v)
			os.Setenv(k, v) // disponible inmediatamente en el proceso actual
		}
	}
	return os.WriteFile("/etc/bos/bos-bootstrap.env", []byte(strings.Join(lines, "\n")+"\n"), 0600)
}

func (s *Server) wsHandleBootstrapStart(client *Client, req *Request) {
	mode, _ := stringParam(req.Params, "mode")
	if mode == "" {
		mode = "interactive"
	}

	// Persistir datos del tenant si el TUI los envió (seed data del formulario)
	if req.Params != nil {
		if razon, _ := req.Params["razon_social"].(string); razon != "" {
			if err := saveSeedEnv(req.Params); err != nil {
				s.logger.Warn("no se pudo persistir seed data en bos-bootstrap.env", "err", err)
			} else {
				s.logger.Info("seed data del tenant persistida en bos-bootstrap.env", "dominio", req.Params["dominio"])
			}
		}
	}

	s.logger.Info("bootstrap start solicitado", "mode", mode, "user", client.User)

	if s.installer == nil {
		s.wsHub.sendResponse(client, req.ID, false, nil,
			"installer no disponible — daemon en modo config-pending")
		return
	}

	st, err := s.stateMgr.Read()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil,
			fmt.Sprintf("estado no disponible: %v", err))
		return
	}

	// Resetear fichas bloqueadas para que el observer loop las reintente.
	// Casos:
	//   INSTALANDO       → huérfana (daemon reiniciado mid-install) → FALLA → LIMPIEZA → LISTA
	//   FALLA_INSTALACION → falló en sesión anterior               →         LIMPIEZA → LISTA
	reintentadas := 0
	for fichaID, ficha := range st.Fichas {
		var pasos []state.FichaState
		switch ficha.State {
		case state.StateInstalando:
			// Huérfana: el saga que la instalaba ya no corre — tratar como fallo
			pasos = []state.FichaState{state.StateFallaInstalacion, state.StateLimpieza, state.StateLista}
			s.logger.Warn("ficha huérfana en INSTALANDO — reseteando a LISTA", "ficha", fichaID)
		case state.StateFallaInstalacion:
			pasos = []state.FichaState{state.StateLimpieza, state.StateLista}
		default:
			continue
		}
		ok := true
		for _, paso := range pasos {
			if err := s.stateMgr.Transition(fichaID, paso); err != nil {
				s.logger.Warn("error reseteando ficha", "ficha", fichaID, "paso", paso, "err", err)
				ok = false
				break
			}
		}
		if ok {
			reintentadas++
		}
	}
	if reintentadas > 0 {
		s.logger.Info("fichas reseteadas para reintento", "cantidad", reintentadas)
	}

	// Re-leer estado después del reset
	st, err = s.stateMgr.Read()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil,
			fmt.Sprintf("estado no disponible tras reset: %v", err))
		return
	}

	total := len(st.Fichas)
	completados := fichaCountByState(st, state.StateInstalada)

	// El observer loop en main.go gestiona la instalación automática.
	// Este handler reporta el estado de activación del motor.
	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"message": fmt.Sprintf("Bootstrap %s activado — %d fichas registradas, %d completadas",
			mode, total, completados),
		"bootstrap_id":       fmt.Sprintf("bs-%d", time.Now().Unix()),
		"mode":               mode,
		"fichas_total":       total,
		"fichas_completadas": completados,
		"status":             "activo",
	}, "")
}

func (s *Server) wsHandleBootstrapStatus(client *Client, req *Request) {
	st, err := s.stateMgr.Read()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil,
			fmt.Sprintf("error leyendo estado: %v", err))
		return
	}

	total := len(st.Fichas)
	completados := fichaCountByState(st, state.StateInstalada)
	instalando := fichaCountByState(st, state.StateInstalando)
	alertas := fichaCountByState(st, state.StateDegradada)
	bloqueadas := fichaCountByState(st, state.StatePendiente)
	pendientes := fichaCountByState(st, state.StateLista)

	var progress float64
	if total > 0 {
		progress = float64(completados) / float64(total)
	}

	phase := "pendiente"
	switch {
	case completados == total && total > 0:
		phase = "completado"
	case instalando > 0:
		phase = "instalando"
	case completados > 0:
		phase = "en_progreso"
	}

	type fichaEntry struct {
		ID      string `json:"id"`
		State   string `json:"state"`
		Server  string `json:"server"`
		Version string `json:"version"`
		Health  string `json:"health,omitempty"`
	}

	fichas := make([]fichaEntry, 0, len(st.Fichas))
	currentFicha := ""
	for id, f := range st.Fichas {
		fichas = append(fichas, fichaEntry{
			ID:      id,
			State:   string(f.State),
			Server:  f.Server,
			Version: f.Version,
			Health:  f.HealthStatus,
		})
		if f.State == state.StateInstalando && currentFicha == "" {
			currentFicha = id
		}
	}

	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"phase":             phase,
		"progress":          progress,
		"total_fichas":      total,
		"completed_fichas":  completados,
		"installing_fichas": instalando,
		"alert_fichas":      alertas,
		"blocked_fichas":    bloqueadas,
		"pending_fichas":    pendientes,
		"current_ficha":     currentFicha,
		"fichas":            fichas,
		"updated_at":        st.UpdatedAt,
	}, "")
}

func (s *Server) wsHandleBootstrapVerify(client *Client, req *Request) {
	s.logger.Info("bootstrap verify solicitado", "user", client.User)

	st, err := s.stateMgr.Read()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil,
			fmt.Sprintf("error leyendo estado: %v", err))
		return
	}

	type criterio struct {
		ID      string `json:"id"`
		Nombre  string `json:"nombre"`
		OK      bool   `json:"ok"`
		Detalle string `json:"detalle"`
	}

	// C-01..C-08: criterios de certificación del Operador (SBOS-BOOTSTRAP-MANUAL §Verificación)
	checks := []struct {
		id      string
		nombre  string
		fichaID string
	}{
		{"C-01", "sbos-bootstrap-os HEALTHY (kernel, /data/)", "sbos-bootstrap-os"},
		{"C-02", "sbos-bootstrap-k8s HEALTHY (kubeadm, Calico)", "sbos-bootstrap-k8s"},
		{"C-03", "Calico CNI operativo (NetworkPolicy activa)", "sbos-bootstrap-cni"},
		{"C-04", "PostgreSQL HEALTHY + WAL lógico + bkernel_slot", "postgresql"},
		{"C-05", "Redis HEALTHY (PONG DB0/1/2)", "redis"},
		{"C-06", "Vault unsealed + AppRole sbos-pods creado", "vault"},
		{"C-07", "Keycloak HEALTHY (realm master, health/ready 200)", "keycloak"},
		{"C-08", "Kong HEALTHY (migrations OK, admin API restringida)", "kong"},
	}

	criterios := make([]criterio, len(checks))
	passed := 0

	for i, c := range checks {
		criterios[i].ID = c.id
		criterios[i].Nombre = c.nombre

		if ficha, ok := st.Fichas[c.fichaID]; ok {
			criterios[i].OK = ficha.State == state.StateInstalada
			health := ficha.HealthStatus
			if health == "" {
				health = "sin datos"
			}
			criterios[i].Detalle = fmt.Sprintf("estado=%s health=%s ver=%s",
				ficha.State, health, ficha.Version)
		} else {
			criterios[i].Detalle = "ficha no registrada — pendiente bootstrap"
		}

		if criterios[i].OK {
			passed++
		}
	}

	certified := passed == len(criterios)

	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"criterios": criterios,
		"passed":    passed,
		"total":     len(criterios),
		"certified": certified,
		"timestamp": time.Now(),
	}, "")
}

func (s *Server) wsHandleBootstrapResume(client *Client, req *Request) {
	st, err := s.stateMgr.Read()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil,
			fmt.Sprintf("error leyendo estado: %v", err))
		return
	}

	completados := fichaCountByState(st, state.StateInstalada)
	total := len(st.Fichas)

	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"message": fmt.Sprintf(
			"Reanudando bootstrap desde %d/%d fichas — el observer loop continuará automáticamente",
			completados, total),
		"fichas_completadas": completados,
		"fichas_total":       total,
	}, "")
}

func (s *Server) wsHandleBootstrapReset(client *Client, req *Request) {
	confirmed, _ := req.Params["confirmed"].(bool)
	if !confirmed {
		s.wsHub.sendResponse(client, req.ID, false, nil,
			"operación destructiva — enviar confirmed:true para confirmar")
		return
	}

	s.logger.Warn("bootstrap reset solicitado", "user", client.User)

	st, err := s.stateMgr.Read()
	if err != nil {
		s.wsHub.sendResponse(client, req.ID, false, nil, fmt.Sprintf("error: %v", err))
		return
	}

	resetCount := 0
	for id, f := range st.Fichas {
		// Solo reiniciar fichas en estado de error o transitorio, nunca INSTALADA -- OK
		switch f.State {
		case state.StateDegradada, state.StateInstalando,
			state.StateErrorLogico, state.StateReparando:
			if err := s.stateMgr.Transition(id, state.StateLista); err != nil {
				s.logger.Warn("reset: transición fallida", "ficha", id, "err", err)
			} else {
				resetCount++
			}
		}
	}

	s.wsHub.sendResponse(client, req.ID, true, map[string]interface{}{
		"message":     fmt.Sprintf("Bootstrap reset — %d fichas reiniciadas a NO_INSTALADA", resetCount),
		"reset_count": resetCount,
	}, "")
}

// ── Helpers internos ─────────────────────────────────────────────

// stringParam extrae un string de un mapa de parámetros WS.
func stringParam(params map[string]interface{}, key string) (string, bool) {
	if params == nil {
		return "", false
	}
	v, ok := params[key]
	if !ok {
		return "", false
	}
	s, ok := v.(string)
	return s, ok
}

// fichaCountByState cuenta fichas en un estado dado.
func fichaCountByState(st *state.SBOSState, target state.FichaState) int {
	count := 0
	for _, f := range st.Fichas {
		if f.State == target {
			count++
		}
	}
	return count
}
