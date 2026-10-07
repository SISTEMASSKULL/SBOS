package domain

import (
	"testing"
)

func newTestWebSvc() *WebDomainService {
	return NewWebDomainService(NewMemWebDomain(), NoopNginx{})
}

func TestWebDomainAdd(t *testing.T) {
	svc := newTestWebSvc()
	rec, err := svc.Add("api.empresa.com", "10.0.0.5:8080", false, "ctx-1")
	if err != nil {
		t.Fatalf("Add: %v", err)
	}
	if rec.Domain != "api.empresa.com" {
		t.Errorf("domain esperado api.empresa.com, got %s", rec.Domain)
	}
	if rec.Target != "10.0.0.5:8080" {
		t.Errorf("target esperado 10.0.0.5:8080, got %s", rec.Target)
	}
}

func TestWebDomainAddDuplicate(t *testing.T) {
	svc := newTestWebSvc()
	_, err := svc.Add("api.empresa.com", "10.0.0.5:8080", false, "ctx-1")
	if err != nil {
		t.Fatalf("primer Add: %v", err)
	}
	_, err = svc.Add("api.empresa.com", "10.0.0.6:8080", false, "ctx-2")
	if err == nil {
		t.Fatal("esperaba error al registrar dominio duplicado")
	}
}

func TestWebDomainAddInvalidDomain(t *testing.T) {
	svc := newTestWebSvc()
	_, err := svc.Add("no es un dominio valido", "10.0.0.5:8080", false, "ctx-1")
	if err == nil {
		t.Fatal("esperaba error con dominio inválido")
	}
	_, err = svc.Add("", "10.0.0.5:8080", false, "ctx-1")
	if err == nil {
		t.Fatal("esperaba error con dominio vacío")
	}
}

func TestWebDomainList(t *testing.T) {
	svc := newTestWebSvc()
	domains := []string{"a.empresa.com", "b.empresa.com", "c.empresa.com"}
	for _, d := range domains {
		if _, err := svc.Add(d, "127.0.0.1", false, "ctx-1"); err != nil {
			t.Fatalf("Add %s: %v", d, err)
		}
	}
	list := svc.List()
	if len(list) != 3 {
		t.Errorf("esperaba 3 dominios, got %d", len(list))
	}
}

func TestWebDomainResolve(t *testing.T) {
	svc := newTestWebSvc()
	if _, err := svc.Add("portal.empresa.com", "10.1.2.3", false, "ctx-1"); err != nil {
		t.Fatalf("Add: %v", err)
	}
	rec, err := svc.Resolve("portal.empresa.com")
	if err != nil {
		t.Fatalf("Resolve: %v", err)
	}
	if rec.Target != "10.1.2.3" {
		t.Errorf("target esperado 10.1.2.3, got %s", rec.Target)
	}

	if _, err := svc.Resolve("noexiste.empresa.com"); err == nil {
		t.Fatal("esperaba error resolviendo dominio inexistente")
	}
}

func TestWebDomainRemove(t *testing.T) {
	svc := newTestWebSvc()
	if _, err := svc.Add("app.empresa.com", "10.0.0.1", false, "ctx-1"); err != nil {
		t.Fatalf("Add: %v", err)
	}
	if err := svc.Remove("app.empresa.com", "ctx-1"); err != nil {
		t.Fatalf("Remove: %v", err)
	}
	if err := svc.Remove("app.empresa.com", "ctx-1"); err == nil {
		t.Fatal("esperaba error al eliminar dominio inexistente")
	}
}

func TestWebDomainSSLNotProvisioned(t *testing.T) {
	svc := newTestWebSvc()
	if _, err := svc.Add("ssl.empresa.com", "10.0.0.1", false, "ctx-1"); err != nil {
		t.Fatalf("Add: %v", err)
	}
	status := svc.SSLStatus("ssl.empresa.com")
	if status.Provisioned {
		t.Error("NoopNginx no debe reportar SSL provisionado")
	}
}
