package screens_test

import (
	"strings"
	"testing"
	"time"

	tuimodel "bos/internal/tui/model"
	"bos/internal/tui/screens"
)

// newPostInstallModel crea un modelo base para tests de S06/S07/S08.
func newPostInstallModel() tuimodel.Model {
	cfg := tuimodel.Config{DemoMode: true}
	m := tuimodel.New(cfg, tuimodel.SeedData{})
	m.Width = 120
	m.Height = 40
	m.TermW = 120
	m.StartTime = time.Now().Add(-48 * time.Minute)
	m.FichasOK = 112
	m.FichasTotal = 112
	m.Fichas = map[string]*tuimodel.FichaDetail{
		"postgresql": {ID: "postgresql", Status: tuimodel.FichaDone},
		"redis":      {ID: "redis", Status: tuimodel.FichaDone},
		"keycloak":   {ID: "keycloak", Status: tuimodel.FichaDone},
	}
	m.TenantName = "Empresa Demo"
	m.TenantDomain = "demo.sbos.local"
	m.AdminEmail = "admin@demo.sbos.local"
	return *m
}

// ── S06 — RenderInstallDone ───────────────────────────────────────────────────

func TestScreen06_SinPanic_80x24(t *testing.T) {
	m := newPostInstallModel()
	m.Width = 80
	m.Height = 24
	if out := screens.RenderInstallDone(m); out == "" {
		t.Fatal("RenderInstallDone 80×24: retornó vacío")
	}
}

func TestScreen06_SinPanic_120x40(t *testing.T) {
	m := newPostInstallModel()
	if out := screens.RenderInstallDone(m); out == "" {
		t.Fatal("RenderInstallDone 120×40: retornó vacío")
	}
}

func TestScreen06_SinPanic_xs(t *testing.T) {
	m := newPostInstallModel()
	m.Width = 50
	m.Height = 20
	if out := screens.RenderInstallDone(m); out == "" {
		t.Fatal("RenderInstallDone XS: retornó vacío")
	}
}

func TestScreen06_Paridad_tabs(t *testing.T) {
	m := newPostInstallModel()
	out := screens.RenderInstallDone(m)
	for _, tab := range []string{"Tenant", "Ubuntu", "Kubernetes", "SBOS"} {
		if !strings.Contains(out, tab) {
			t.Errorf("RenderInstallDone: falta tab %q", tab)
		}
	}
}

func TestScreen06_Tab0_Tenant(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 0
	out := screens.RenderInstallDone(m)
	for _, kw := range []string{"demo.sbos.local", "admin@demo.sbos.local", "https://"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstallDone tab0 Tenant: falta %q", kw)
		}
	}
}

func TestScreen06_Tab0_TieneFichasContadas(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 0
	m.FichasOK = 3
	m.FichasTotal = 5
	out := screens.RenderInstallDone(m)
	if !strings.Contains(out, "3/5") {
		t.Error("RenderInstallDone tab0: falta '3/5' de fichas")
	}
}

func TestScreen06_Tab1_Ubuntu(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 1
	out := screens.RenderInstallDone(m)
	for _, kw := range []string{"Ubuntu", "containerd", "ufw", "fail2ban"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstallDone tab1 Ubuntu: falta %q", kw)
		}
	}
}

func TestScreen06_Tab2_Kubernetes(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 2
	out := screens.RenderInstallDone(m)
	for _, kw := range []string{"Kubernetes", "kubeadm", "Calico", "Linkerd", "Kong", "Vault", "Keycloak"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstallDone tab2 K8s: falta %q", kw)
		}
	}
}

func TestScreen06_Tab2_TieneDominio(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 2
	out := screens.RenderInstallDone(m)
	if !strings.Contains(out, "demo.sbos.local") {
		t.Error("RenderInstallDone tab2 K8s: falta dominio del tenant")
	}
}

func TestScreen06_Tab3_SBOS(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 3
	out := screens.RenderInstallDone(m)
	for _, kw := range []string{"bKernel", "bAuth", "bSearch", "biedata", "bhnexus", "bnotify"} {
		if !strings.Contains(out, kw) {
			t.Errorf("RenderInstallDone tab3 SBOS: falta %q", kw)
		}
	}
}

func TestScreen06_Tab3_ContextPlane(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 3
	out := screens.RenderInstallDone(m)
	if !strings.Contains(out, "Context Plane") {
		t.Error("RenderInstallDone tab3 SBOS: falta 'Context Plane'")
	}
}

func TestScreen06_FocusActivo_Resaltado(t *testing.T) {
	m := newPostInstallModel()
	m.CompleteFocus = 2
	out := screens.RenderInstallDone(m)
	if !strings.Contains(out, "›") {
		t.Error("RenderInstallDone: falta '›' en tab activo")
	}
}

func TestScreen06_SinSidePanel_xs(t *testing.T) {
	m := newPostInstallModel()
	m.Width = 50
	m.Height = 20
	m.CompleteFocus = 0
	out := screens.RenderInstallDone(m)
	if !strings.Contains(out, "demo.sbos.local") {
		t.Error("RenderInstallDone XS tab0: falta dominio sin side panel")
	}
}
