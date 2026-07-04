// Package ficha — Governance Dual-Control (F11.F.5).
// BOS-REPAIR Plan Maestro v3 · SBOS-019 §13.
//
// ⛔ GATE DE APROBACIÓN — riesgo ALTO.
//
// Las operaciones sobre fichas se clasifican en 3 categorías de riesgo.
// Las operaciones destructivas (cat 3) requieren confirmación de DOS
// administradores distintos, una ventana de 60 minutos, y texto exacto
// de confirmación. Sin las 2 aprobaciones, la operación es rechazada.
//
// Categorías:
//   Cat 1 (lectura):   status, list, describe, plan, diff, logs, validate
//   Cat 2 (escritura): install, update, repair, pause, resume, scale
//   Cat 3 (destructiva): remove, scale a 0, reset_state
//                        → 2 admins + ventana 60min + texto exacto
//
// Flujo de aprobación dual:
//   1. Admin A inicia la operación → se genera ApprovalRequest con token único
//   2. Admin B confirma con el texto exacto dentro de 60min
//   3. Si ambas aprobaciones son válidas → operación ejecutada
//   4. Si expira la ventana → solicitud rechazada, audit_event registrado
//
// Estándares: ISO 27001 A.9.4.2 (segregation of duties), A.8.15 (audit),
// NIST SP 800-207 Tenet 2 (least privilege), SBOS-019 §13.
package ficha

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"strings"
	"sync"
	"time"
)

// ── Categorías de riesgo ──────────────────────────────────────────────

// RiskCategory clasifica una operación según su nivel de riesgo.
type RiskCategory int

const (
	RiskRead       RiskCategory = 1 // lectura — sin restricciones
	RiskWrite      RiskCategory = 2 // escritura — requiere auth
	RiskDestructive RiskCategory = 3 // destructiva — dual-control ⛔ GATE
)

// ClassifyOperation determina la categoría de riesgo de una operación.
func ClassifyOperation(op LifecycleOp) RiskCategory {
	switch op {
	case OpInstall, OpUpdate, OpRepair:
		return RiskWrite
	case OpRemove:
		return RiskDestructive // eliminar es irreversible
	default:
		return RiskRead
	}
}

// ClassifyCommand clasifica un comando de escala por riesgo.
// scale a N>0 = cat 2, scale a 0 = cat 3 (destructivo).
func ClassifyCommand(command string, replicas int) RiskCategory {
	switch command {
	case "scale":
		if replicas == 0 {
			return RiskDestructive // scale a 0 = eliminar todos los pods
		}
		return RiskWrite
	case "remove", "uninstall":
		return RiskDestructive
	case "reset_state":
		return RiskDestructive
	case "pause":
		return RiskWrite
	default:
		return RiskRead
	}
}

// RequiresDualControl retorna true si la operación requiere 2 administradores.
func RequiresDualControl(op LifecycleOp) bool {
	return ClassifyOperation(op) == RiskDestructive
}

// ── Solicitud de aprobación ───────────────────────────────────────────

// ApprovalRequest representa una solicitud de aprobación dual pendiente.
type ApprovalRequest struct {
	ID             string       // token único de la solicitud
	FichaID        string       // ficha sobre la que se opera
	Operation      LifecycleOp  // operación solicitada
	ConfirmText    string       // texto exacto que Admin B debe escribir
	RequesterID    string       // Admin A (quien inició)
	ApproverID     string       // Admin B (quien debe aprobar)
	Status         string       // "pending", "approved", "rejected", "expired"
	CreatedAt      time.Time
	ExpiresAt      time.Time    // ventana de 60 minutos
	ApprovedAt     time.Time    // timestamp de aprobación
	AuditEvents    []AuditEvent // registro de auditoría
}

// AuditEvent registra un evento de auditoría de governance.
type AuditEvent struct {
	Timestamp time.Time
	AdminID   string
	Action    string // "requested", "approved", "rejected", "expired"
	Detail    string
}

// ── Motor de governance ──────────────────────────────────────────────

// GovernanceEngine gestiona el ciclo de vida de aprobaciones dual-control.
// Thread-safe: usa sync.RWMutex para acceso concurrente desde gRPC/JSON-RPC.
type GovernanceEngine struct {
	mu              sync.RWMutex
	pending         map[string]*ApprovalRequest // ID → solicitud pendiente
	approvalWindow  time.Duration               // ventana de aprobación (default: 60min)
}

// NewGovernanceEngine crea un motor de governance.
func NewGovernanceEngine() *GovernanceEngine {
	return &GovernanceEngine{
		pending:        make(map[string]*ApprovalRequest),
		approvalWindow: 60 * time.Minute,
	}
}

// RequestApproval inicia una solicitud de aprobación dual.
// Retorna el ApprovalRequest generado con el token único.
func (g *GovernanceEngine) RequestApproval(fichaID string, op LifecycleOp, requesterID string) (*ApprovalRequest, error) {
	if !RequiresDualControl(op) {
		return nil, fmt.Errorf("la operación %s no requiere aprobación dual (cat %d)", op, ClassifyOperation(op))
	}

	g.mu.Lock()
	defer g.mu.Unlock()

	// Generar token único
	token, err := generateToken(16)
	if err != nil {
		return nil, fmt.Errorf("generar token: %w", err)
	}

	// Generar texto de confirmación
	confirmText := GenerateConfirmText(fichaID, op)

	req := &ApprovalRequest{
		ID:          token,
		FichaID:     fichaID,
		Operation:   op,
		ConfirmText: confirmText,
		RequesterID: requesterID,
		Status:      "pending",
		CreatedAt:   time.Now(),
		ExpiresAt:   time.Now().Add(g.approvalWindow),
		AuditEvents: []AuditEvent{{
			Timestamp: time.Now(),
			AdminID:   requesterID,
			Action:    "requested",
			Detail:    fmt.Sprintf("solicitó %s de %s", op, fichaID),
		}},
	}

	g.pending[token] = req
	return req, nil
}

// Approve procesa la aprobación de Admin B.
// Requiere el token de la solicitud y el texto exacto de confirmación.
func (g *GovernanceEngine) Approve(token, confirmText, approverID string) (*ApprovalRequest, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	req, ok := g.pending[token]
	if !ok {
		return nil, fmt.Errorf("solicitud no encontrada o ya procesada: %s", token)
	}

	// Validar ventana de tiempo
	if time.Now().After(req.ExpiresAt) {
		req.Status = "expired"
		req.AuditEvents = append(req.AuditEvents, AuditEvent{
			Timestamp: time.Now(),
			AdminID:   approverID,
			Action:    "expired",
			Detail:    "ventana de 60min expirada",
		})
		delete(g.pending, token)
		return nil, fmt.Errorf("solicitud expirada (ventana de %v excedida)", g.approvalWindow)
	}

	// Validar que no sea el mismo admin
	if approverID == req.RequesterID {
		return nil, fmt.Errorf("el mismo administrador no puede aprobar su propia solicitud (segregation of duties)")
	}

	// Validar texto exacto de confirmación
	if confirmText != req.ConfirmText {
		req.AuditEvents = append(req.AuditEvents, AuditEvent{
			Timestamp: time.Now(),
			AdminID:   approverID,
			Action:    "rejected",
			Detail:    fmt.Sprintf("texto de confirmación incorrecto (esperado: %q)", req.ConfirmText),
		})
		return nil, fmt.Errorf("texto de confirmación incorrecto — debe escribir exactamente: %s", req.ConfirmText)
	}

	// Aprobación exitosa
	req.Status = "approved"
	req.ApproverID = approverID
	req.ApprovedAt = time.Now()
	req.AuditEvents = append(req.AuditEvents, AuditEvent{
		Timestamp: time.Now(),
		AdminID:   approverID,
		Action:    "approved",
		Detail:    fmt.Sprintf("aprobó %s de %s", req.Operation, req.FichaID),
	})

	delete(g.pending, token)
	return req, nil
}

// Reject rechaza explícitamente una solicitud de aprobación.
func (g *GovernanceEngine) Reject(token, approverID, reason string) (*ApprovalRequest, error) {
	g.mu.Lock()
	defer g.mu.Unlock()

	req, ok := g.pending[token]
	if !ok {
		return nil, fmt.Errorf("solicitud no encontrada: %s", token)
	}

	req.Status = "rejected"
	req.AuditEvents = append(req.AuditEvents, AuditEvent{
		Timestamp: time.Now(),
		AdminID:   approverID,
		Action:    "rejected",
		Detail:    reason,
	})

	delete(g.pending, token)
	return req, nil
}

// GetPending retorna una solicitud pendiente por token.
func (g *GovernanceEngine) GetPending(token string) (*ApprovalRequest, bool) {
	g.mu.RLock()
	defer g.mu.RUnlock()
	req, ok := g.pending[token]
	return req, ok
}

// ListPending retorna todas las solicitudes pendientes.
func (g *GovernanceEngine) ListPending() []*ApprovalRequest {
	g.mu.RLock()
	defer g.mu.RUnlock()

	result := make([]*ApprovalRequest, 0, len(g.pending))
	for _, req := range g.pending {
		result = append(result, req)
	}
	return result
}

// CleanupExpired elimina solicitudes expiradas.
func (g *GovernanceEngine) CleanupExpired() int {
	g.mu.Lock()
	defer g.mu.Unlock()

	now := time.Now()
	removed := 0
	for token, req := range g.pending {
		if now.After(req.ExpiresAt) {
			req.Status = "expired"
			delete(g.pending, token)
			removed++
		}
	}
	return removed
}

// ── Helpers ────────────────────────────────────────────────────────────

// GenerateConfirmText genera el texto de confirmación exacto para una operación.
// Formato: <OPERACION>-<FICHA_ID> en mayúsculas.
func GenerateConfirmText(fichaID string, op LifecycleOp) string {
	return fmt.Sprintf("%s-%s", strings.ToUpper(string(op)), strings.ToUpper(strings.ReplaceAll(fichaID, "-", "")))
}

// generateToken genera un token aleatorio de N bytes en hex.
func generateToken(bytes int) (string, error) {
	b := make([]byte, bytes)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

