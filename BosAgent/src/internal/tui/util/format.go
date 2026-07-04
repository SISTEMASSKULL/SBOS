// Package util — format.go: helpers de formato puro sin dependencias del proyecto.
// Fuente canónica para FormatDur, TruncA, WordWrap, MaxInt, BootMessage.
// Migrado desde screens/helpers.go y model/update.go (elimina duplicación).
package util

import (
	"fmt"
	"strings"
	"time"
)

// FormatDur formatea una duración como "m:ss" o "Xs". Retorna "" si < 1s.
func FormatDur(d time.Duration) string {
	if d < time.Second {
		return ""
	}
	d = d.Round(time.Second)
	m := int(d.Minutes())
	s := int(d.Seconds()) % 60
	if m > 0 {
		return fmt.Sprintf("%d:%02d", m, s)
	}
	return fmt.Sprintf("%ds", s)
}

// TruncA trunca s a max runas, añadiendo "…" si se trunca.
func TruncA(s string, max int) string {
	if max <= 1 {
		return s
	}
	r := []rune(s)
	if len(r) <= max {
		return s
	}
	return string(r[:max-1]) + "…"
}

// WordWrap inserta saltos de línea para que cada línea tenga ≤ maxW bytes.
func WordWrap(text string, maxW int) string {
	if maxW <= 0 {
		return text
	}
	words := strings.Fields(text)
	var lines []string
	var cur strings.Builder
	for _, w := range words {
		if cur.Len()+len(w)+1 > maxW {
			lines = append(lines, cur.String())
			cur.Reset()
		}
		if cur.Len() > 0 {
			cur.WriteByte(' ')
		}
		cur.WriteString(w)
	}
	if cur.Len() > 0 {
		lines = append(lines, cur.String())
	}
	return strings.Join(lines, "\n")
}

// MaxInt retorna el mayor de dos enteros.
func MaxInt(a, b int) int {
	if a > b {
		return a
	}
	return b
}

// BootMessage retorna el mensaje de progreso de arranque para un pct dado (0–1).
func BootMessage(pct float64) string {
	msgs := []struct {
		threshold float64
		msg       string
	}{
		{0.12, "Verificando integridad de componentes..."},
		{0.25, "Cargando configuración del tenant..."},
		{0.38, "Verificando Ubuntu — kernel OK"},
		{0.52, "Verificando Kubernetes — cluster OK"},
		{0.65, "Iniciando daemons SBOS..."},
		{0.78, "Activando Context Plane..."},
		{0.90, "Registrando ctx_id de sesión..."},
		{1.01, "Sistema listo ✓"},
	}
	for _, m := range msgs {
		if pct < m.threshold {
			return m.msg
		}
	}
	return "Sistema listo ✓"
}

// StepMsgSuffix retorna ": msg" si msg no está vacío.
func StepMsgSuffix(msg string) string {
	if msg != "" {
		return ": " + msg
	}
	return ""
}
