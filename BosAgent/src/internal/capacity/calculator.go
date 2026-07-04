package capacity

import (
	"fmt"
	"math"
)

// Calculate deriva los requisitos de hardware a partir del estimado de capacidad.
//
// Todas las fórmulas están documentadas en INVESTIGACION-LOG.md INV-001 y
// se basan en los componentes reales del stack SBOS:
// kubeadm/K8s + PostgreSQL 18.4 + Redis 8.6.2 + Keycloak 26.6.2 + Vault + Kong + daemons.
//
// Modificar solo si cambia el stack — no ajustar para que "pase" en hardware débil.
func Calculate(e Estimate) Requirements {
	concurrent := e.ConcurrentUsers()
	total := e.TotalUsers()

	// ── Redis ──────────────────────────────────────────────────────────────────
	// DB1 (ctx_id cache): 700 bytes por sesión concurrente (referencia SBOS-PERF-002)
	redisDB1MB := ceilMB(float64(concurrent) * 700)
	// Total Redis: DB1 + 50% overhead para Streams, pub/sub, DB0 general
	redisTotalMB := max(int(float64(redisDB1MB)*1.5), 256)

	// ── PostgreSQL ─────────────────────────────────────────────────────────────
	// Datos: 500MB/tenant + 50MB/empresa + 20MB/sucursal + 5MB/usuario
	pgDataMB := e.Tenants*500 +
		e.Tenants*e.CompaniesPerTenant*50 +
		e.Tenants*e.CompaniesPerTenant*e.BranchesPerCompany*20 +
		total*5
	pgDataGB := max(ceilGB(float64(pgDataMB)), 20)
	// RAM PG: shared_buffers ≈ 25% del tamaño de datos (regla práctica)
	pgRAMMB := max(int(math.Ceil(float64(pgDataGB)*1024*0.25)), 1024)

	// ── Keycloak ───────────────────────────────────────────────────────────────
	// Base 2048MB JVM + 512MB por cada 10K usuarios totales
	kcMB := 2048 + (total/10000)*512
	if kcMB < 2048 {
		kcMB = 2048
	}

	// ── Kong ───────────────────────────────────────────────────────────────────
	// Base 1024MB + 256MB por tenant (namespace upstream pool)
	kongMB := max(1024+e.Tenants*256, 1024)

	// ── Infraestructura fija (independiente del número de tenants) ─────────────
	const (
		k8sMB    = 2048 // control plane: API server + etcd + scheduler + controller-manager
		daemonsMB = 2560 // bKernel + biedata + bAuth + bSearch + bnotify
		bosMB     = 256  // daemon BOS
		vaultMB   = 512
		osMB      = 2048 // Ubuntu 26.04 headless + systemd overhead
	)

	ramMinMB := redisTotalMB + pgRAMMB + kcMB + kongMB + k8sMB + daemonsMB + bosMB + vaultMB + osMB
	ramRecMB := ramMinMB * 2 // 2× para absorber picos y WAL burst

	// ── Disco ──────────────────────────────────────────────────────────────────
	// Base (OS + K8s + imágenes + overlays): 60 GB
	// PostgreSQL WAL: 1 GB por defecto + crecimiento proporcional
	pgWALGB := max(1+pgDataGB/10, 5)
	redisDiskGB := max(ceilGB(float64(redisTotalMB)/512), 2)
	logDiskGB := 20 + int(float64(concurrent)*0.001) // 1 GB por cada 1000 concurrentes
	diskMinGB := 60 + pgDataGB + pgWALGB + redisDiskGB + logDiskGB + 30 // +30 buffer crecimiento
	diskRecGB := diskMinGB * 2

	// ── CPU ────────────────────────────────────────────────────────────────────
	// Base: 8 cores (K8s 2 + PG 2 + KC 2 + Kong 2)
	// Adicional: +2 cores por cada 100K usuarios concurrentes
	cpuMin := max(8, 8+(concurrent/100000)*2)
	cpuRec := cpuMin * 2

	return Requirements{
		RAMMinMB:      ramMinMB,
		RAMRecMB:      ramRecMB,
		DiskMinGB:     diskMinGB,
		DiskRecGB:     diskRecGB,
		CPUMin:        cpuMin,
		CPURec:        cpuRec,
		ConcurrentCtx: concurrent,
		RedisDB1MB:    redisDB1MB,
		PGDataGB:      pgDataGB,
	}
}

// FormatRAM formatea MB a GB con un decimal para mostrar en la UI.
func FormatRAM(mb int) string {
	gb := float64(mb) / 1024
	if gb < 1 {
		return fmt.Sprintf("%dMB", mb)
	}
	return fmt.Sprintf("%.1f GB", gb)
}

// ─── helpers ────────────────────────────────────────────────────────────────

func ceilMB(bytes float64) int { return int(math.Ceil(bytes / 1024 / 1024)) }
func ceilGB(mb float64) int    { return int(math.Ceil(mb / 1024)) }
func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
