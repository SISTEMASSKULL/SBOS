// Package server — traceparent.go: extracción y generación de W3C Trace Context.
// F5.6 — BOS-REPAIR Plan Maestro v3.
// Estándar: W3C Trace Context Level 1 (2019) — https://www.w3.org/TR/trace-context/
package server

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"regexp"
)

// w3cTPRegex valida el formato W3C traceparent: 00-{32hex}-{16hex}-{2hex}
var w3cTPRegex = regexp.MustCompile(
	`^00-[0-9a-f]{32}-[0-9a-f]{16}-[0-9a-f]{2}$`,
)

// IsValidTraceparent retorna true si tp cumple el formato W3C Trace Context spec.
func IsValidTraceparent(tp string) bool {
	return tp != "" && w3cTPRegex.MatchString(tp)
}

// NewTraceparent genera un traceparent W3C válido con trace_id y span_id aleatorios.
// Siempre retorna formato: "00-{32hex}-{16hex}-01"
func NewTraceparent() string {
	traceID := make([]byte, 16)
	spanID := make([]byte, 8)
	// A-01: entropía insuficiente es condición irrecuperable — W3C Trace Context §2.2.2
	// Un traceparent todo-cero (00-000...0-000...0-01) elimina la trazabilidad del sistema.
	if _, err := rand.Read(traceID); err != nil {
		panic("crypto/rand: entropía insuficiente para traceID: " + err.Error())
	}
	if _, err := rand.Read(spanID); err != nil {
		panic("crypto/rand: entropía insuficiente para spanID: " + err.Error())
	}
	return fmt.Sprintf("00-%s-%s-01", hex.EncodeToString(traceID), hex.EncodeToString(spanID))
}

// ExtractTraceparent extrae el traceparent de los params de una RPCRequest.
// Busca en el campo "traceparent" del objeto params.
// Si no existe o es inválido, retorna un traceparent nuevo generado localmente.
func ExtractTraceparent(req *RPCRequest) string {
	if req.Params == nil {
		return NewTraceparent()
	}
	var generic struct {
		Traceparent string `json:"traceparent"`
	}
	if err := json.Unmarshal(req.Params, &generic); err != nil {
		return NewTraceparent()
	}
	if IsValidTraceparent(generic.Traceparent) {
		return generic.Traceparent
	}
	return NewTraceparent()
}

// InjectTraceparent asegura que el campo "traceparent" esté presente en un mapa de respuesta.
// Si ya existe y es válido, lo preserva. Si no, genera uno nuevo.
func InjectTraceparent(result map[string]interface{}, tp string) map[string]interface{} {
	if existing, ok := result["traceparent"].(string); ok && IsValidTraceparent(existing) {
		return result // preservar el existente
	}
	if IsValidTraceparent(tp) {
		result["traceparent"] = tp
	} else {
		result["traceparent"] = NewTraceparent()
	}
	return result
}
