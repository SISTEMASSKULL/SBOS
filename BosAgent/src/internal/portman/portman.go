// Package portman — Motor de Asignación de Puertos del IAM Installer (SBOS-050).
//
// Implementa el Kardex canónico de puertos: registro, asignación, validación
// y liberación de puertos por ficha, con dos algoritmos de resolución:
//
//   - Algoritmo A (fórmula determinista): ClusterIP = BASE_SERVIDOR + (FICHA_INDEX×10) + TIPO_T
//   - Algoritmo B (hash fallback):        32000 + SHA256(ficha:tipo:clash)[0:4] % 17151
//
// Resolución de conflictos (N1 → N2 → N3 → HITL):
//
//	N1 Fórmula A  (<1ms)  — resultado único y reproducible por servidor/ficha/tipo
//	N2 Incremento (<5ms)  — ficha_index+1 hasta 5 intentos
//	N3 Hash B     (<10ms) — espacio dinámico 32000-49151
//	HITL          (∞)     — intervención humana requerida
//
// Verificación en 3 capas:
//
//	Capa 1 — blacklist local (IANA 0-1023, puertos K8s core, Linkerd)
//	Capa 2 — catálogo SBOS-050 (conflictos con otros daemons SBOS)
//	Capa 3 — Kardex DB (bos.prt_port_assignment T-408)
//
// Inmutabilidad lógica: las filas del Kardex nunca se borran; los puertos
// transicionan assigned → released → revoked.
//
// Integración:
//
//	bos.ficha.install → portman.Assign()
//	bos.ficha.remove  → portman.Release()
//	reconcile/scheduler.go → portman.Validate() cada 300s (comparar Kardex vs kubectl)
package portman
