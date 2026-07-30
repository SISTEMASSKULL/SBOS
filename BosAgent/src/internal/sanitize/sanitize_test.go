package sanitize

import (
	"strings"
	"testing"
)

func TestUUID_Validos(t *testing.T) {
	validos := []string{
		"4bf92f35-77b3-4da6-a3ce-929d0e0e4736",
		"00000000-0000-4000-8000-000000000000",
		"ffffffff-ffff-4fff-9fff-ffffffffffff",
		"4BF92F35-77B3-4DA6-A3CE-929D0E0E4736", // mayúsculas
	}
	for _, s := range validos {
		if !UUID(s) {
			t.Errorf("UUID(%q) debe ser válido", s)
		}
	}
}

func TestUUID_Invalidos(t *testing.T) {
	invalidos := []string{
		"",
		"no-es-uuid",
		"4bf92f35-77b3-4da6-a3ce-929d0e0e473",   // corto
		"4bf92f35-77b3-4da6-a3ce-929d0e0e47360",  // largo
		"4bf92f35-77b3-3da6-a3ce-929d0e0e4736",   // versión 3, no v4
		"4bf92f35-77b3-4da6-03ce-929d0e0e4736",   // variante inválida (03)
		"4bf92f35-77b3-4da6-z3ce-929d0e0e4736",   // caracter inválido
	}
	for _, s := range invalidos {
		if UUID(s) {
			t.Errorf("UUID(%q) debe ser inválido", s)
		}
	}
}

func TestSlug_Validos(t *testing.T) {
	validos := []string{"skull", "bos-dev", "tenant_01", "a1b2c3", "x"}
	for _, s := range validos {
		if !Slug(s) {
			t.Errorf("Slug(%q) debe ser válido", s)
		}
	}
}

func TestSlug_Invalidos(t *testing.T) {
	invalidos := []string{
		"",
		"-empieza-con-guion",
		"MAYUSCULAS",
		"con espacios",
		"con/barra",
		strings.Repeat("a", 65), // demasiado largo
	}
	for _, s := range invalidos {
		if Slug(s) {
			t.Errorf("Slug(%q) debe ser inválido", s)
		}
	}
}

func TestIPAddr_Validos(t *testing.T) {
	validos := []string{"127.0.0.1", "10.0.0.1", "::1", "2001:db8::1"}
	for _, s := range validos {
		if !IPAddr(s) {
			t.Errorf("IPAddr(%q) debe ser válida", s)
		}
	}
}

func TestIPAddr_Invalidos(t *testing.T) {
	invalidos := []string{"", "no-es-ip", "999.0.0.1", "localhost"}
	for _, s := range invalidos {
		if IPAddr(s) {
			t.Errorf("IPAddr(%q) debe ser inválida", s)
		}
	}
}

func TestFilePath_Limpia(t *testing.T) {
	cases := []struct {
		input    string
		wantClean bool
	}{
		{"/etc/bos/bos.toml", true},
		{"/var/log/bos/audit.log", true},
		{"/etc/bos/../bos.toml", false}, // path traversal
		{"/etc/bos/../../etc/passwd", false},
		{"/etc/bos/\x00null", false},   // byte nulo
	}
	for _, tc := range cases {
		_, err := FilePath(tc.input)
		if tc.wantClean && err != nil {
			t.Errorf("FilePath(%q) no debe fallar: %v", tc.input, err)
		}
		if !tc.wantClean && err == nil {
			t.Errorf("FilePath(%q) debe fallar (path traversal)", tc.input)
		}
	}
}

func TestLogCtxID_Trunca(t *testing.T) {
	full := "4bf92f35-77b3-4da6-a3ce-929d0e0e4736"
	safe := LogCtxID(full)
	if !strings.HasPrefix(safe, "4bf92f35") {
		t.Errorf("LogCtxID debe mostrar los primeros 8 chars: %q", safe)
	}
	if strings.Contains(safe, "929d0e0e4736") {
		t.Error("LogCtxID no debe exponer el final del ctx_id")
	}
	if len(safe) == len(full) {
		t.Error("LogCtxID debe ser más corto que el ID completo")
	}
}

func TestLogCtxID_Vacio(t *testing.T) {
	if LogCtxID("") != "(vacío)" {
		t.Error("LogCtxID('') debe retornar '(vacío)'")
	}
}

func TestLogCtxID_Corto(t *testing.T) {
	short := "abc"
	if LogCtxID(short) != short {
		t.Errorf("LogCtxID de string corto debe retornar el original: %q", LogCtxID(short))
	}
}

func TestTruncateField(t *testing.T) {
	s := "abcdefgh"
	if TruncateField(s, 4) != "abcd" {
		t.Error("TruncateField debe truncar a 4 chars")
	}
	if TruncateField(s, 100) != s {
		t.Error("TruncateField no debe modificar strings cortos")
	}
	if TruncateField(s, 0) != "" {
		t.Error("TruncateField con maxLen=0 debe retornar vacío")
	}
}

func TestCtxIDParam(t *testing.T) {
	if !CtxIDParam("4bf92f35-77b3-4da6-a3ce-929d0e0e4736") {
		t.Error("CtxIDParam debe aceptar UUIDv4 válido")
	}
	if CtxIDParam("") {
		t.Error("CtxIDParam no debe aceptar vacío")
	}
	if CtxIDParam("no-es-uuid") {
		t.Error("CtxIDParam no debe aceptar no-UUID")
	}
}

func TestTenantIDParam(t *testing.T) {
	if !TenantIDParam("skull") {
		t.Error("TenantIDParam debe aceptar slug válido")
	}
	if TenantIDParam("") {
		t.Error("TenantIDParam no debe aceptar vacío")
	}
	if TenantIDParam("Skull") {
		t.Error("TenantIDParam no debe aceptar mayúsculas")
	}
}
