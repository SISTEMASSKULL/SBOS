// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package security implementa los controles de seguridad del IAM Installer BOS:
// benchmarks CIS para Ubuntu y Kubernetes, RBAC de bosctl, y escaneo unificado.
//
// # Responsabilidades
//
//   - Ejecutar controles CIS Ubuntu Benchmark: permisos de archivos críticos,
//     servicios innecesarios activos, configuración SSH, umask, etc.
//   - Ejecutar controles CIS Kubernetes Benchmark: API server flags,
//     RBAC, Network Policies, Secrets encryption at rest.
//   - Gestionar RBAC de bosctl: roles admin/operator/readonly con BitMask 64-bit.
//   - Exponer RunFullScan() para bosctl security y el handler JSON-RPC.
//
// # Fuera de alcance
//
//   - Gestión de identidades — responsabilidad de bAuth (daemon soberano).
//   - Rotación de secretos en Vault — responsabilidad del installer de la ficha vault.
//   - Firewall/nftables — responsabilidad de internal/network.
//
// # Dependencias
//
//   - Comandos del host: stat, sshd -T, auditctl, kubectl.
//   - internal/state — STATE_MANAGER para obtener fichas instaladas.
//
// # Callers principales
//
//   - internal/server/api.go — handler "bos.security.scan".
//   - cmd/bosctl/app.go — subcomando "bosctl security".
//
// # Estándares y referencias
//
//   - SBOS-047 ISMS-ISO27001 — 20 controles ISO 27001:2022.
//   - CIS Ubuntu Benchmark 24.04 — controles de hardening del host.
//   - CIS Kubernetes Benchmark 1.28 — controles de hardening del cluster.
//   - NSA/CISA Kubernetes Hardening Guide.
//
// # Ejemplo de uso
//
//	report := security.RunFullScan(rbacProvider)
//	fmt.Printf("Ubuntu: %d/%d | K8s: %d/%d\n",
//	    report.Summary.UbuntuPass, report.Summary.UbuntuTotal,
//	    report.Summary.K8sPass, report.Summary.K8sTotal)
package security
