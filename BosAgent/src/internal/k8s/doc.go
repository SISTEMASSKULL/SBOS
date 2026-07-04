// Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL
// Co-Autor (IA): Claude Sonnet 4.6 — Anthropic

// Package k8s implementa el punto único de despacho kubectl del SBOS (P1).
// Toda operación Kubernetes en el ecosistema DEBE pasar por este paquete.
//
// # Responsabilidades
//
//   - Ejecutar kubectl apply, delete, get, rollout, taint, drain, cordon.
//   - Validar manifiestos con --dry-run=client antes de todo apply (P10).
//   - Exponer WaitForReady() con polling configurable.
//   - Gestionar KUBECONFIG via parámetro (no variable de entorno hardcodeada).
//
// # Fuera de alcance
//
//   - Generar manifiestos YAML — responsabilidad del yaml_engine de cada ficha.
//   - Selección de qué ficha desplegar — responsabilidad del installer/observer.
//   - Comunicación con la API K8s directamente — solo via kubectl binario.
//
// # Dependencias
//
//   - kubectl binario en PATH (instalado por bootstrap Capa 1).
//
// # Callers principales
//
//   - internal/installer/saga.go — Apply() durante instalación de fichas.
//   - internal/repair/k8s_repair.go — taint/drain/uncordon durante reparación.
//   - internal/maintenance/ — cordon/drain/uncordon durante mantenimiento de nodos.
//
// # Estándares y referencias
//
//   - P1 (single dispatch point), P10 (dry-run antes de apply).
//   - SBOS-007 DEPLOY §3 — topología de nodos K8s del SBOS.
//   - CIS Kubernetes Benchmark — operaciones kubectl auditadas.
//
// # Ejemplo de uso
//
//	core := k8s.NewCore(paths.KubeconfigPath, 5*time.Minute)
//	if err := core.Apply("/etc/sbos/fichas/postgresql/manifest.yml", "sbos"); err != nil {
//	    log.Fatal(err)
//	}
package k8s
