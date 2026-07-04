package domain

import (
	"strings"
	"testing"
	"time"
)

func TestCtxService_Create(t *testing.T) {
	svc := NewCtxService()

	t.Run("ok — campos mínimos", func(t *testing.T) {
		ctx, err := svc.Create(CreateParams{TenantID: "acme"})
		if err != nil {
			t.Fatalf("Create inesperado error: %v", err)
		}
		if ctx.TenantID != "acme" {
			t.Errorf("TenantID=%q, quería %q", ctx.TenantID, "acme")
		}
		if ctx.Source != "bos" {
			t.Errorf("Source=%q, quería 'bos'", ctx.Source)
		}
		if ctx.TraceParent == "" {
			t.Error("TraceParent vacío")
		}
		if ctx.SpanID == "" {
			t.Error("SpanID vacío")
		}
		if ctx.CreatedAt.IsZero() {
			t.Error("CreatedAt es zero")
		}
		if ctx.ExpiresAt.IsZero() {
			t.Error("ExpiresAt es zero")
		}
	})

	t.Run("campos opcionales se preservan", func(t *testing.T) {
		ctx, err := svc.Create(CreateParams{
			TenantID:   "skull",
			EmpresaID:  "emp-01",
			SucursalID: "suc-02",
			PosLogico:  "pos-03",
			UserID:     "usr-99",
		})
		if err != nil {
			t.Fatalf("error inesperado: %v", err)
		}
		if ctx.EmpresaID != "emp-01" {
			t.Errorf("EmpresaID=%q", ctx.EmpresaID)
		}
		if ctx.SucursalID != "suc-02" {
			t.Errorf("SucursalID=%q", ctx.SucursalID)
		}
		if ctx.PosLogico != "pos-03" {
			t.Errorf("PosLogico=%q", ctx.PosLogico)
		}
		if ctx.UserID != "usr-99" {
			t.Errorf("UserID=%q", ctx.UserID)
		}
	})

	t.Run("TTL 0 defaults a 30 minutos", func(t *testing.T) {
		ctx, err := svc.Create(CreateParams{TenantID: "t1", TTL: 0})
		if err != nil {
			t.Fatal(err)
		}
		ttl := ctx.ExpiresAt.Sub(ctx.CreatedAt)
		// 29min < ttl < 31min
		if ttl < 29*time.Minute || ttl > 31*time.Minute {
			t.Errorf("TTL esperado ~30min, got %v", ttl)
		}
	})

	t.Run("TTL personalizado se aplica", func(t *testing.T) {
		ctx, err := svc.Create(CreateParams{TenantID: "t2", TTL: 5 * time.Minute})
		if err != nil {
			t.Fatal(err)
		}
		ttl := ctx.ExpiresAt.Sub(ctx.CreatedAt)
		if ttl < 4*time.Minute || ttl > 6*time.Minute {
			t.Errorf("TTL esperado ~5min, got %v", ttl)
		}
	})

	t.Run("tenant_id vacío → ErrTenantIDRequired", func(t *testing.T) {
		_, err := svc.Create(CreateParams{TenantID: ""})
		if err == nil {
			t.Fatal("esperaba error, got nil")
		}
		if err != ErrTenantIDRequired {
			t.Errorf("error=%v, quería ErrTenantIDRequired", err)
		}
	})

	t.Run("traceparent tiene formato W3C 00-32hex-16hex-01", func(t *testing.T) {
		ctx, _ := svc.Create(CreateParams{TenantID: "t"})
		tp := ctx.TraceParent
		parts := strings.Split(tp, "-")
		if len(parts) != 4 {
			t.Fatalf("TraceParent %q: esperaba 4 partes separadas por '-', got %d", tp, len(parts))
		}
		if parts[0] != "00" {
			t.Errorf("versión=%q, quería '00'", parts[0])
		}
		if len(parts[1]) != 32 {
			t.Errorf("traceId longitud=%d, quería 32", len(parts[1]))
		}
		if len(parts[2]) != 16 {
			t.Errorf("spanId longitud=%d, quería 16", len(parts[2]))
		}
		if parts[3] != "01" {
			t.Errorf("flags=%q, quería '01'", parts[3])
		}
	})

	t.Run("traceparents de dos llamadas son distintos", func(t *testing.T) {
		a, _ := svc.Create(CreateParams{TenantID: "t"})
		time.Sleep(time.Microsecond) // garantizar diferente nanosegundo
		b, _ := svc.Create(CreateParams{TenantID: "t"})
		if a.TraceParent == b.TraceParent {
			t.Error("dos traceparents consecutivos son idénticos")
		}
	})

	t.Run("el traceparent generado es válido según Validate", func(t *testing.T) {
		ctx, _ := svc.Create(CreateParams{TenantID: "t"})
		result, err := svc.Validate(ctx.TraceParent, "t")
		if err != nil {
			t.Fatalf("Validate error: %v", err)
		}
		if !result.Valid {
			t.Errorf("traceparent generado no válida según Validate: %q", ctx.TraceParent)
		}
	})
}

func TestCtxService_Validate(t *testing.T) {
	svc := NewCtxService()
	validTP := "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"

	t.Run("traceparent W3C válido", func(t *testing.T) {
		result, err := svc.Validate(validTP, "acme")
		if err != nil {
			t.Fatalf("error inesperado: %v", err)
		}
		if !result.Valid {
			t.Error("esperaba Valid=true")
		}
		if result.TraceParent != validTP {
			t.Errorf("TraceParent=%q", result.TraceParent)
		}
		if result.TenantID != "acme" {
			t.Errorf("TenantID=%q", result.TenantID)
		}
	})

	t.Run("traceparent vacío → ErrTraceparentRequired", func(t *testing.T) {
		_, err := svc.Validate("", "t")
		if err != ErrTraceparentRequired {
			t.Errorf("error=%v, quería ErrTraceparentRequired", err)
		}
	})

	cases := []struct {
		name string
		tp   string
	}{
		{"demasiado corto", "00-abc-def-01"},
		{"versión incorrecta", "ff-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01"},
		{"traceId todo ceros", "00-00000000000000000000000000000000-00f067aa0ba902b7-01"},
		{"spanId todo ceros", "00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01"},
		{"separadores faltantes", "004bf92f3577b34da6a3ce929d0e0e473600f067aa0ba902b701"},
		{"caracteres no hex en traceId", "00-GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG-00f067aa0ba902b7-01"},
	}

	for _, tc := range cases {
		tc := tc
		t.Run("inválido: "+tc.name, func(t *testing.T) {
			result, err := svc.Validate(tc.tp, "t")
			if err != nil {
				t.Fatalf("error inesperado: %v", err)
			}
			if result.Valid {
				t.Errorf("esperaba Valid=false para %q", tc.tp)
			}
		})
	}
}

// ── isValidTraceParent (función interna) ──────────────────────────

func TestIsValidTraceParent(t *testing.T) {
	valid := []string{
		"00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
		"00-aabbccddeeff00112233445566778899-0102030405060708-00",
	}
	for _, tp := range valid {
		if !isValidTraceParent(tp) {
			t.Errorf("esperaba válido: %q", tp)
		}
	}

	invalid := []string{
		"",
		"00-abc",
		"01-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01",
		"00-00000000000000000000000000000000-00f067aa0ba902b7-01",
		"00-4bf92f3577b34da6a3ce929d0e0e4736-0000000000000000-01",
		"00-4bf92f3577b34da6a3ce929d0e0e4736-XXXXXXXXXXXXXXXX-01",
	}
	for _, tp := range invalid {
		if isValidTraceParent(tp) {
			t.Errorf("esperaba inválido: %q", tp)
		}
	}
}

// ── isHex y allZero (funciones internas) ──────────────────────────

func TestIsHex(t *testing.T) {
	valid := []string{"0123456789abcdefABCDEF", "00", "ff", "AABB"}
	for _, s := range valid {
		if !isHex(s) {
			t.Errorf("esperaba hex: %q", s)
		}
	}
	invalid := []string{"", "gg", "0x1A", " ff", "1.0"}
	for _, s := range invalid {
		if isHex(s) {
			t.Errorf("esperaba no-hex: %q", s)
		}
	}
}

func TestAllZero(t *testing.T) {
	if !allZero("0000") {
		t.Error("esperaba true para '0000'")
	}
	if !allZero("00000000000000000000000000000000") {
		t.Error("esperaba true para 32 ceros")
	}
	if allZero("0001") {
		t.Error("esperaba false para '0001'")
	}
	if allZero("") {
		t.Error("esperaba false para vacío")
	}
}
