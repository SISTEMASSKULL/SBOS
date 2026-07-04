package util_test

import (
	"strings"
	"testing"

	"bos/internal/tui/util"
)

func TestFichaVersions_Completo(t *testing.T) {
	expected := []string{
		"postgresql", "redis", "minio", "vault", "keycloak",
		"kong", "nginx", "certbot", "linkerd", "kyverno",
		"prometheus", "grafana", "alertmanager", "alloy",
	}
	for _, id := range expected {
		v, ok := util.FichaVersions[id]
		if !ok {
			t.Errorf("FichaVersions no contiene %q", id)
		}
		if v == "" {
			t.Errorf("FichaVersions[%q] está vacío", id)
		}
	}
}

func TestVersionSuffix_Conocida(t *testing.T) {
	got := util.VersionSuffix("postgresql")
	if !strings.HasPrefix(got, " ") {
		t.Errorf("VersionSuffix debe comenzar con espacio, got %q", got)
	}
	if !strings.Contains(got, "18.4") {
		t.Errorf("esperado '18.4' en VersionSuffix('postgresql'), got %q", got)
	}
}

func TestVersionSuffix_Desconocida(t *testing.T) {
	if got := util.VersionSuffix("no-existe"); got != "" {
		t.Errorf("ficha desconocida debe retornar '', got %q", got)
	}
}

func TestVersionSuffix_Bootstrap(t *testing.T) {
	// Las fichas de bootstrap no tienen versión canónica aún
	got := util.VersionSuffix("sbos-bootstrap-os")
	if got != "" {
		t.Logf("sbos-bootstrap-os retornó %q (si se agrega versión, actualizar test)", got)
	}
}
