// Package bootstrap — kubeconfig.go: resolución centralizada de kubeconfig (F4.1).
// Corrige P5 — duplicación ×7 en cmd/bosctl/bootstrap.go.
package bootstrap

import "os"

// DefaultKubeconfig es la ruta canónica del kubeconfig generado por bos durante el bootstrap.
const DefaultKubeconfig = "/etc/bos/.kube/config"

// ResolveKubeconfig retorna la ruta al kubeconfig siguiendo el orden de prioridad:
//  1. KUBECONFIG env var (si no está vacía)
//  2. DefaultKubeconfig ("/etc/bos/.kube/config")
//
// La integración con bos.toml / cfg.Install.KubeconfigPath se añade en F5
// una vez que el Config centralizado esté disponible.
func ResolveKubeconfig() string {
	if k := os.Getenv("KUBECONFIG"); k != "" {
		return k
	}
	return DefaultKubeconfig
}

// ResolveKubeconfigWithOverride permite especificar un override explícito.
// Si override no está vacío, se usa directamente (útil en tests y en el servidor bos).
// Si está vacío, delega a ResolveKubeconfig().
func ResolveKubeconfigWithOverride(override string) string {
	if override != "" {
		return override
	}
	return ResolveKubeconfig()
}
