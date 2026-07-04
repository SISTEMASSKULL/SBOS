package biaos

// safety.go — F10.7: guardrails del agente OS (ADR-006, BOS-REPAIR-10 §5.3).
//
// Tres barreras ANTES de que cualquier intención llegue al LLM o al ICAP:
//  1. Guardia de dominio: biaos es agente de INFRAESTRUCTURA — rechaza
//     consultas de datos de negocio (ventas, facturas, clientes…); esas
//     van a biedata/bcompass, no al plano de control.
//  2. RBAC: el usuario debe tener rol que permita operar la acción.
//  3. Auditoría: TODO intento (permitido o denegado) queda en el audit
//     JSONL ANTES de ejecutar — ISO 27001 A.8.15.

import (
	"errors"
	"strings"
)

// ErrFueraDeDominio: la intención pertenece al dominio de negocio.
var ErrFueraDeDominio = errors.New("biaos: fuera de dominio — biaos gobierna infraestructura; los datos de negocio van por biedata")

// ErrRBACDeniega: el usuario no tiene rol para la operación.
var ErrRBACDeniega = errors.New("biaos: RBAC deniega la operación")

// terminosDeNegocio dispara la guardia de dominio (BOS-REPAIR-10 §5.3:
// TestDomainGuard_RejectsBusinessData). Lista deliberadamente amplia —
// un falso positivo molesta; un falso negativo filtra datos de negocio
// al plano de control.
var terminosDeNegocio = []string{
	"venta", "factura", "cliente", "producto", "inventario", "precio",
	"cobro", "pago", "nomina", "nómina", "empleado", "proveedor",
	"contabilidad", "asiento", "impuesto", "siat",
}

// GuardiaDominio rechaza intenciones del dominio de negocio.
func GuardiaDominio(intencion string) error {
	lower := strings.ToLower(intencion)
	for _, t := range terminosDeNegocio {
		if strings.Contains(lower, t) {
			return ErrFueraDeDominio
		}
	}
	return nil
}

// RBACPort es el contrato mínimo hacia security.RBACProvider.
type RBACPort interface {
	CanExecute(user, cmd string) error
}

// VerificarRBAC: con proveedor presente, el usuario necesita permiso sobre
// el método RPC de la acción. Sin proveedor (tests, config parcial) se
// permite — el dispatcher del server ya aplicó su propia barrera F6.1.
func VerificarRBAC(rbac RBACPort, user, metodoRPC string) error {
	if rbac == nil {
		return nil
	}
	if err := rbac.CanExecute(user, metodoRPC); err != nil {
		return errors.Join(ErrRBACDeniega, err)
	}
	return nil
}
