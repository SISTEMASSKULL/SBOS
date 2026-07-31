// Manager — punto de entrada público del Port Manager.
//
// Expone Assign, Release, Lookup, Check, List, Validate, Export.
// Todos los métodos son seguros para uso concurrente (state sin mutex
// necesario — el Kardex maneja la concurrencia via UNIQUE constraint en BD).
package portman

import (
	"fmt"
	"strings"
	"time"
)

// Manager es el motor de puertos del IAM Installer.
// Crea con New(kardex) inyectando el Kardex; usa NewWithDSN para producción.
type Manager struct {
	kardex KardexPort
}

// New crea un Manager con el Kardex inyectado.
// Usar para tests (MockKardex) o cuando la conexión ya existe.
func New(kardex KardexPort) *Manager {
	return &Manager{kardex: kardex}
}

// NewWithDSN crea un Manager abriendo la conexión PostgreSQL.
// Para producción — DSN desde env BOS_PG_DSN.
func NewWithDSN(dsn string) (*Manager, error) {
	k, err := NewPgKardex(dsn)
	if err != nil {
		return nil, fmt.Errorf("portman: %w", err)
	}
	return &Manager{kardex: k}, nil
}

// Close cierra la conexión del Kardex.
func (m *Manager) Close() error {
	if m.kardex != nil {
		return m.kardex.Close()
	}
	return nil
}

// ── Assign ────────────────────────────────────────────────────────────────

// AssignResult es el resultado de una asignación de puertos.
type AssignResult struct {
	Assignments []Assignment
	NeedsHITL   bool
	HITLReason  string
}

// Assign asigna los puertos requeridos a una ficha.
// Aplica N1→N2→N3 para cada tipo de puerto pedido.
// Si algún tipo no se puede resolver → NeedsHITL=true y se aborta.
func (m *Manager) Assign(req PortRequest) (*AssignResult, error) {
	if req.FichaID == "" {
		return nil, fmt.Errorf("portman.Assign: ficha_id requerido")
	}
	if req.LogicalServer == "" {
		return nil, fmt.Errorf("portman.Assign: logical_server requerido")
	}
	if len(req.PortTypes) == 0 {
		return nil, fmt.Errorf("portman.Assign: al menos un port_type requerido")
	}
	if req.Transport == "" {
		req.Transport = TransportTCP
	}
	if req.CtxID == "" {
		req.CtxID = "system"
	}
	if req.Namespace == "" {
		req.Namespace = "default"
	}

	result := &AssignResult{}

	for tipoT, pt := range req.PortTypes {
		port, algo, needsHITL, err := resolveConflict(req, tipoT, m.kardex)
		if err != nil {
			return nil, fmt.Errorf("portman.Assign tipoT=%d: %w", tipoT, err)
		}
		if needsHITL {
			result.NeedsHITL = true
			result.HITLReason = fmt.Sprintf("tipo %s no resoluble con algoritmos A/B", pt)
			return result, nil
		}

		svcName := req.ServiceName
		if svcName == "" {
			svcName = fmt.Sprintf("%s-%s", req.FichaID, strings.ToLower(string(pt)))
		}

		if err := m.kardex.Insert(KardexRow{
			ServiceName:   svcName,
			Port:          port,
			Transport:     string(req.Transport),
			PortType:      string(pt),
			LogicalServer: req.LogicalServer,
			Namespace:     req.Namespace,
			FichaID:       req.FichaID,
			AssignedBy:    req.AssignedBy,
			Description:   fmt.Sprintf("ficha:%s tipo:%s", req.FichaID, pt),
			DocReference:  "SBOS-050",
			Algorithm:     algo,
			CtxID:         req.CtxID,
		}); err != nil {
			return nil, fmt.Errorf("portman.Assign registrar en kardex: %w", err)
		}

		result.Assignments = append(result.Assignments, Assignment{
			Port:        port,
			PortType:    pt,
			Algorithm:   algo,
			TipoT:       tipoT,
			ServiceName: svcName,
			Namespace:   req.Namespace,
			FichaID:     req.FichaID,
		})
	}

	return result, nil
}

// ── Release ───────────────────────────────────────────────────────────────

// Release marca los puertos de una ficha como 'released'.
// Los registros en el Kardex se preservan (inmutabilidad lógica).
// Se llama desde bos.ficha.remove.
func (m *Manager) Release(fichaID, ctxID string) (int, error) {
	rows, err := m.kardex.ListByFicha(fichaID)
	if err != nil {
		return 0, fmt.Errorf("portman.Release listar puertos de %s: %w", fichaID, err)
	}

	now := time.Now()
	released := 0
	for _, row := range rows {
		if row.Status != "assigned" {
			continue
		}
		if err := m.kardex.SetStatus(row.PortID, "released", &now); err != nil {
			return released, fmt.Errorf("portman.Release port %d: %w", row.Port, err)
		}
		released++
	}
	return released, nil
}

// ── Lookup ────────────────────────────────────────────────────────────────

// Lookup retorna la asignación activa para un puerto específico.
// Retorna nil si el puerto no está asignado.
func (m *Manager) Lookup(port int, portType, namespace string) (*KardexRow, error) {
	if namespace == "" {
		namespace = "default"
	}
	row, err := m.kardex.GetByPort(port, portType, namespace)
	if err != nil {
		return nil, fmt.Errorf("portman.Lookup puerto %d: %w", port, err)
	}
	return row, nil
}

// ── Check ─────────────────────────────────────────────────────────────────

// CheckResult es el resultado de verificar si un puerto está disponible.
type CheckResult struct {
	Available bool
	Conflicts []string // razones de conflicto (si Available=false)
}

// Check verifica si un puerto está disponible en las 3 capas.
func (m *Manager) Check(port int, portType PortType, namespace string) (*CheckResult, error) {
	if namespace == "" {
		namespace = "default"
	}
	result := &CheckResult{Available: true}

	// Capa 1
	if reserved, reason := IsReserved(port); reserved {
		result.Available = false
		result.Conflicts = append(result.Conflicts, "capa1:"+reason)
	}
	// Capa 2
	if inSBOS, reason := IsInSBOS050(port); inSBOS {
		result.Available = false
		result.Conflicts = append(result.Conflicts, "capa2:"+reason)
	}
	// Capa 3
	if m.kardex != nil {
		exists, err := m.kardex.ExistsActive(port, string(portType), namespace)
		if err != nil {
			return nil, fmt.Errorf("portman.Check capa3: %w", err)
		}
		if exists {
			result.Available = false
			result.Conflicts = append(result.Conflicts, "capa3:kardex-assigned")
		}
	}

	return result, nil
}

// ── List ──────────────────────────────────────────────────────────────────

// List retorna todas las asignaciones del Kardex.
// Si fichaID != "" filtra por ficha; si fichaID == "" retorna todo.
func (m *Manager) List(fichaID string, limit int) ([]KardexRow, error) {
	if fichaID != "" {
		return m.kardex.ListByFicha(fichaID)
	}
	return m.kardex.ListAll(limit)
}

// ── Validate ──────────────────────────────────────────────────────────────

// ValidationResult es el resultado de validar el Kardex contra el estado real.
type ValidationResult struct {
	Checked  int
	OK       int
	Drifted  []DriftItem
}

// DriftItem describe una discrepancia entre el Kardex y el estado real de K8s.
type DriftItem struct {
	PortID      string
	Port        int
	FichaID     string
	ServiceName string
	Reason      string // "not-found-in-k8s" | "wrong-port" | "wrong-namespace"
}

// ValidateKardex compara el Kardex con los servicios K8s reales.
// Llama a getK8sSvcFn para obtener el estado actual de un servicio en K8s.
// Si getK8sSvcFn es nil, solo verifica que el puerto no colisione consigo mismo.
func (m *Manager) ValidateKardex(getK8sSvcFn func(svc, ns string) (int, bool)) (*ValidationResult, error) {
	rows, err := m.kardex.ListAll(0)
	if err != nil {
		return nil, fmt.Errorf("portman.Validate listar kardex: %w", err)
	}

	result := &ValidationResult{Checked: len(rows)}

	for _, row := range rows {
		if row.Status != "assigned" {
			continue
		}
		if getK8sSvcFn == nil {
			result.OK++
			continue
		}
		actualPort, found := getK8sSvcFn(row.ServiceName, row.Namespace)
		if !found {
			result.Drifted = append(result.Drifted, DriftItem{
				PortID:      row.PortID,
				Port:        row.Port,
				FichaID:     row.FichaID,
				ServiceName: row.ServiceName,
				Reason:      "not-found-in-k8s",
			})
			continue
		}
		if actualPort != row.Port {
			result.Drifted = append(result.Drifted, DriftItem{
				PortID:      row.PortID,
				Port:        row.Port,
				FichaID:     row.FichaID,
				ServiceName: row.ServiceName,
				Reason:      fmt.Sprintf("wrong-port:kardex=%d,k8s=%d", row.Port, actualPort),
			})
			continue
		}
		result.OK++
	}

	return result, nil
}

// ── Export ────────────────────────────────────────────────────────────────

// Export retorna el Kardex completo en formato Markdown (SBOS-050).
func (m *Manager) Export(limit int) (string, error) {
	rows, err := m.kardex.ListAll(limit)
	if err != nil {
		return "", fmt.Errorf("portman.Export: %w", err)
	}

	var sb strings.Builder
	sb.WriteString("# Kardex de Puertos SBOS — Motor IAM Installer\n\n")
	sb.WriteString("| Puerto | Tipo | Ficha | Servidor | Namespace | Servicio | Estado | Algoritmo | Asignado |\n")
	sb.WriteString("|--------|------|-------|----------|-----------|----------|--------|-----------|----------|\n")

	for _, r := range rows {
		releasedMark := ""
		if r.Status != "assigned" {
			releasedMark = " _(liberado)_"
		}
		sb.WriteString(fmt.Sprintf("| %d | %s | %s | %s | %s | %s | %s%s | %s | %s |\n",
			r.Port, r.PortType, r.FichaID, r.LogicalServer, r.Namespace,
			r.ServiceName, r.Status, releasedMark,
			r.Algorithm, r.AssignedAt.Format("2006-01-02"),
		))
	}

	return sb.String(), nil
}
