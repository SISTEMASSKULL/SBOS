package query

// semaforo.go — cálculo del semáforo agregado de una saga de consulta.
// Contrato BOS-REPAIR-04: "semaforo": "VERDE" | "AMARILLO" | "ROJO".

// Niveles canónicos del semáforo.
const (
	SemVerde    = "VERDE"
	SemAmarillo = "AMARILLO"
	SemRojo     = "ROJO"
)

// CalcSemaforo agrega el estado de las fuentes recolectadas por Run.
//
// Reglas (de más grave a menos):
//   - ROJO: alguna fuente de la lista críticas falló (clave con "error")
//     o reporta healthy == false.
//   - AMARILLO: cualquier otra fuente falló o reporta healthy == false,
//     o hay degradadas > 0 en el resumen de fichas.
//   - VERDE: todo lo demás.
//
// Las claves no presentes en out se ignoran — permite reutilizar el cálculo
// en sagas con distintos conjuntos de fuentes.
func CalcSemaforo(out map[string]interface{}, criticas []string) string {
	esCritica := make(map[string]bool, len(criticas))
	for _, k := range criticas {
		esCritica[k] = true
	}

	sem := SemVerde
	for key, val := range out {
		if key == "timestamp" || key == "duration_ms" || key == "semaforo" || key == "semaforo_vdi" {
			continue
		}
		if fuenteConProblema(val) {
			if esCritica[key] {
				return SemRojo
			}
			sem = SemAmarillo
			continue
		}
		if fuenteAmarilla(val) {
			sem = SemAmarillo
		}
	}
	return sem
}

// fuenteConProblema detecta si el valor de una fuente indica fallo crítico
// (digno de ROJO): {"error": "<mensaje>"} o healthy == false.
// La saturación de recursos (saturado:true) es AMARILLO — ver fuenteSaturada.
func fuenteConProblema(val interface{}) bool {
	switch m := val.(type) {
	case map[string]string:
		_, hasErr := m["error"]
		return hasErr
	case map[string]interface{}:
		if v, hasErr := m["error"]; hasErr {
			if _, esTexto := v.(string); esTexto {
				return true
			}
		}
		if h, ok := m["healthy"].(bool); ok && !h {
			return true
		}
		// degradada > 0 en el resumen de fichas → AMARILLO (manejado en CalcSemaforo).
	}
	return false
}

// fuenteAmarilla detecta condiciones de degradación no crítica:
// degradada > 0 en fichas, saturado:true en ubuntu.
func fuenteAmarilla(val interface{}) bool {
	m, ok := val.(map[string]interface{})
	if !ok {
		return false
	}
	if d, ok := m["degradada"].(int); ok && d > 0 {
		return true
	}
	if d, ok := m["degradada"].(float64); ok && d > 0 {
		return true
	}
	if s, ok := m["saturado"].(bool); ok && s {
		return true
	}
	return false
}
