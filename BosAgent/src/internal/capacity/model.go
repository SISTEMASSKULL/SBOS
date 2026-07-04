// Package capacity — modelo y calculadora de capacidad del SBOS.
//
// El operador declara estimados en el wizard de instalación (tenants, empresas,
// sucursales, usuarios). A partir de esos estimados se calculan los requisitos
// reales de hardware, los umbrales del observer y los límites de admisión en
// tiempo de ejecución.
//
// Formulas: INVESTIGACION-LOG.md INV-001.
package capacity

import "fmt"

// Estimate contiene los parámetros de capacidad declarados por el operador
// durante la instalación. Se persiste en /etc/bos/capacity.yaml.
type Estimate struct {
	Tenants            int `yaml:"tenants"`             // número de tenants
	CompaniesPerTenant int `yaml:"companies_per_tenant"` // empresas por tenant
	BranchesPerCompany int `yaml:"branches_per_company"` // sucursales por empresa
	UsersPerBranch     int `yaml:"users_per_branch"`     // usuarios por sucursal
}

// TotalUsers retorna el total de usuarios del sistema.
func (e Estimate) TotalUsers() int {
	return e.Tenants * e.CompaniesPerTenant * e.BranchesPerCompany * e.UsersPerBranch
}

// ConcurrentUsers estima las sesiones concurrentes pico (10% del total).
func (e Estimate) ConcurrentUsers() int {
	c := e.TotalUsers() / 10
	if c < 1 {
		c = 1
	}
	return c
}

// Requirements contiene los requisitos de hardware calculados a partir de Estimate.
// Son el resultado de Calculate(e) — no se modifican manualmente.
type Requirements struct {
	RAMMinMB      int // RAM mínima absoluta en MB
	RAMRecMB      int // RAM recomendada en MB
	DiskMinGB     int // Disco libre mínimo en GB
	DiskRecGB     int // Disco libre recomendado en GB
	CPUMin        int // Cores mínimos
	CPURec        int // Cores recomendados
	ConcurrentCtx int // ctx_id concurrentes estimados (sesiones pico)
	RedisDB1MB    int // Redis DB1 (ctx_id cache) en MB
	PGDataGB      int // PostgreSQL datos estimados en GB
}

// AdmissionResult es el resultado de una comprobación de admisión en ejecución.
// Si Allowed=false, Reason explica el motivo al operador y Detail va al log.
type AdmissionResult struct {
	Allowed bool
	Reason  string // mensaje para el operador (vía JSON-RPC / bosctl)
	Detail  string // detalle técnico para el log
}

// CheckAdmission evalúa si una operación puede ejecutarse dados los recursos actuales.
// Se llama antes de crear un tenant, empresa, sucursal o usuario.
//
//	opType:    nombre legible de la operación ("nuevo tenant", "nueva empresa")
//	current:   unidades actuales del recurso limitante
//	limit:     límite máximo calculado de esas unidades
//	usedMB:    RAM o disco actual en uso (MB)
//	requiredMB: incremento de RAM o disco que necesitaría la operación
func CheckAdmission(opType string, current, limit, usedMB, requiredMB int) AdmissionResult {
	if usedMB+requiredMB > limit {
		return AdmissionResult{
			Allowed: false,
			Reason: fmt.Sprintf(
				"recursos insuficientes para %s: se necesitan %dMB adicionales pero solo hay %dMB disponibles",
				opType, requiredMB, limit-usedMB,
			),
			Detail: fmt.Sprintf("used=%dMB required_extra=%dMB limit=%dMB", usedMB, requiredMB, limit),
		}
	}
	if current >= limit {
		return AdmissionResult{
			Allowed: false,
			Reason: fmt.Sprintf(
				"límite de capacidad alcanzado para %s: %d/%d unidades (declaradas en instalación)",
				opType, current, limit,
			),
			Detail: fmt.Sprintf("current=%d limit=%d", current, limit),
		}
	}
	return AdmissionResult{Allowed: true}
}
