package bootstrap

import (
	"os"
	"testing"
)

func TestResolveKubeconfig_UsaEnvVar(t *testing.T) {
	t.Setenv("KUBECONFIG", "/custom/path/config")
	got := ResolveKubeconfig()
	if got != "/custom/path/config" {
		t.Fatalf("esperado /custom/path/config, got %q", got)
	}
}

func TestResolveKubeconfig_UsaDefault(t *testing.T) {
	t.Setenv("KUBECONFIG", "")
	got := ResolveKubeconfig()
	if got != DefaultKubeconfig {
		t.Fatalf("esperado %q, got %q", DefaultKubeconfig, got)
	}
}

func TestResolveKubeconfig_IgnoraVacioYUsaSiguiente(t *testing.T) {
	os.Unsetenv("KUBECONFIG")
	got := ResolveKubeconfig()
	if got != DefaultKubeconfig {
		t.Fatalf("KUBECONFIG ausente debe usar default, got %q", got)
	}
}

func TestResolveKubeconfigWithOverride_UsaOverride(t *testing.T) {
	t.Setenv("KUBECONFIG", "/env/path")
	got := ResolveKubeconfigWithOverride("/override/config")
	if got != "/override/config" {
		t.Fatalf("override explícito debe tener prioridad, got %q", got)
	}
}

func TestResolveKubeconfigWithOverride_OverrideVacioUsaEnv(t *testing.T) {
	t.Setenv("KUBECONFIG", "/env/path")
	got := ResolveKubeconfigWithOverride("")
	if got != "/env/path" {
		t.Fatalf("override vacío debe usar env, got %q", got)
	}
}
