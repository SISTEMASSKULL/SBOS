package util_test

import (
	"testing"
	"time"

	"bos/internal/tui/util"
)

// Alias para brevedad en tests.
var (
	FormatDur    = util.FormatDur
	TruncA       = util.TruncA
	WordWrap     = util.WordWrap
	MaxInt       = util.MaxInt
	BootMessage  = util.BootMessage
	StepMsgSuffix = util.StepMsgSuffix
)

func TestFormatDur_MenosDeUnSegundo(t *testing.T) {
	if got := FormatDur(500 * time.Millisecond); got != "" {
		t.Errorf("esperado '', got %q", got)
	}
}

func TestFormatDur_Segundos(t *testing.T) {
	if got := FormatDur(42 * time.Second); got != "42s" {
		t.Errorf("esperado '42s', got %q", got)
	}
}

func TestFormatDur_MinutosYSegundos(t *testing.T) {
	if got := FormatDur(2*time.Minute + 5*time.Second); got != "2:05" {
		t.Errorf("esperado '2:05', got %q", got)
	}
}

func TestTruncA_SinTruncar(t *testing.T) {
	if got := TruncA("hola", 10); got != "hola" {
		t.Errorf("esperado 'hola', got %q", got)
	}
}

func TestTruncA_Trunca(t *testing.T) {
	got := TruncA("abcde", 4)
	if got != "abc…" {
		t.Errorf("esperado 'abc…', got %q", got)
	}
}

func TestTruncA_MaxUno(t *testing.T) {
	if got := TruncA("abc", 1); got != "abc" {
		t.Errorf("max<=1 debe retornar s sin truncar, got %q", got)
	}
}

func TestWordWrap_SinExceder(t *testing.T) {
	if got := WordWrap("hola mundo", 20); got != "hola mundo" {
		t.Errorf("sin exceder no debe cambiar, got %q", got)
	}
}

func TestWordWrap_Corta(t *testing.T) {
	got := WordWrap("uno dos tres cuatro", 10)
	for _, line := range splitLines(got) {
		if len(line) > 10 {
			t.Errorf("línea %q excede 10 bytes", line)
		}
	}
}

func TestWordWrap_MaxCero(t *testing.T) {
	if got := WordWrap("hola", 0); got != "hola" {
		t.Errorf("maxW=0 debe retornar texto sin cambio, got %q", got)
	}
}

func TestMaxInt_Mayor(t *testing.T) {
	if got := MaxInt(3, 7); got != 7 {
		t.Errorf("esperado 7, got %d", got)
	}
}

func TestMaxInt_Iguales(t *testing.T) {
	if got := MaxInt(5, 5); got != 5 {
		t.Errorf("esperado 5, got %d", got)
	}
}

func TestBootMessage_Inicio(t *testing.T) {
	msg := BootMessage(0.05)
	if msg == "" {
		t.Error("BootMessage(0.05) no debe retornar vacío")
	}
}

func TestBootMessage_Completo(t *testing.T) {
	msg := BootMessage(1.0)
	if msg != "Sistema listo ✓" {
		t.Errorf("esperado 'Sistema listo ✓', got %q", msg)
	}
}

func TestBootMessage_Progresion(t *testing.T) {
	prev := ""
	for _, pct := range []float64{0.05, 0.15, 0.30, 0.45, 0.60, 0.70, 0.85, 1.0} {
		msg := BootMessage(pct)
		if msg == "" {
			t.Errorf("BootMessage(%v) retornó vacío", pct)
		}
		_ = prev
		prev = msg
	}
}

func TestStepMsgSuffix_ConMsg(t *testing.T) {
	if got := StepMsgSuffix("fallo"); got != ": fallo" {
		t.Errorf("esperado ': fallo', got %q", got)
	}
}

func TestStepMsgSuffix_Vacio(t *testing.T) {
	if got := StepMsgSuffix(""); got != "" {
		t.Errorf("msg vacío debe retornar '', got %q", got)
	}
}

func splitLines(s string) []string {
	var out []string
	start := 0
	for i, c := range s {
		if c == '\n' {
			out = append(out, s[start:i])
			start = i + 1
		}
	}
	if start < len(s) {
		out = append(out, s[start:])
	}
	return out
}
