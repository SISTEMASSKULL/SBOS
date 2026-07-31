// Motor de asignación de puertos — Algoritmos A y B + resolución N1/N2/N3/HITL.
package portman

import (
	"crypto/sha256"
	"encoding/binary"
	"fmt"
)

// ── Bases de servidor (Algoritmo A — SBOS-050 §6) ────────────────────────
//
// Cada servidor lógico tiene una base de puerto ClusterIP.
// ClusterIP = BASE_SERVIDOR + (FICHA_INDEX × 10) + TIPO_T
//
// TIPO_T:
//   0 — servicio principal (ej: HTTP interno)
//   1 — admin / métricas
//   2 — gRPC
//   3 — debug / profiling
//   4-9 — auxiliares de la ficha

var serverBases = map[string]int{
	"S00": 20000, // dataserver — PostgreSQL, Redis, almacenamiento
	"S01": 20100, // idserver — Keycloak / bAuth
	"S02": 20200, // apiserver — Kong, biedata
	"S03": 20300, // appserver01 — ERP, RRHH
	"S04": 20400, // appserver02 — CRM, documentos
	"S05": 20500, // appserver03 — reserva
	"S06": 20600, // searchserver — bsearch
	"S07": 20700, // notifyserver — bnotify, bkernel
	"S08": 20800, // edgeserver — bnexus
	"S09": 20900, // vdiserver — escritorio corporativo
	"S10": 21000, // backupserver — respaldos
	"S11": 21100, // monitorserver — observabilidad
	"S12": 21200, // despliegueserver — CI/CD
	"S13": 21300, // emailserver — correo
	"S14": 21400, // aiserver — modelos IA locales
	"S15": 21500, // coreserver — bos daemon
	"S16": 21600, // devserver — desarrollo
	"S17": 21700, // testserver — pruebas
	"S18": 21800, // hostserver — host físico
}

// PortRequest es la solicitud para asignar uno o más puertos a una ficha.
type PortRequest struct {
	FichaID       string
	FichaIndex    int      // índice de la ficha dentro del servidor (0-based)
	LogicalServer string   // ej: "S00", "S01"
	PortTypes     []PortType
	Namespace     string
	ServiceName   string
	Transport     Transport
	AssignedBy    string
	CtxID         string
}

// Assignment es el resultado de la asignación de un puerto.
type Assignment struct {
	Port        int
	PortType    PortType
	Algorithm   string // "A" | "B"
	TipoT       int    // 0-9 según el índice del tipo en la solicitud
	ServiceName string
	Namespace   string
	FichaID     string
}

// resolveConflict implementa el ciclo N1 → N2 → N3 → HITL.
// Retorna el puerto asignado, el algoritmo usado, y si se necesita HITL.
func resolveConflict(
	req PortRequest,
	tipoT int,
	kardex KardexPort,
) (port int, algo string, needsHITL bool, err error) {
	base, ok := serverBases[req.LogicalServer]
	if !ok {
		return 0, "", false, fmt.Errorf("servidor lógico desconocido: %s", req.LogicalServer)
	}

	// N1: Algoritmo A — fórmula determinista
	candidate := base + (req.FichaIndex * 10) + tipoT
	if ok, reason := conflictCheck(candidate, req.PortTypes[tipoT], req.Namespace, kardex); !ok {
		port = candidate
		algo = "A"
		_ = reason
		return port, algo, false, nil
	}

	// N2: Incrementar ficha_index hasta 5 intentos
	for attempt := 1; attempt <= 5; attempt++ {
		candidate = base + ((req.FichaIndex + attempt) * 10) + tipoT
		if ok, _ := conflictCheck(candidate, req.PortTypes[tipoT], req.Namespace, kardex); !ok {
			port = candidate
			algo = "A+N2"
			return port, algo, false, nil
		}
	}

	// N3: Algoritmo B — hash SHA-256 fallback (32000-49151)
	for clashCounter := 0; clashCounter < 10; clashCounter++ {
		candidate = algorithmB(req.FichaID, string(req.PortTypes[tipoT]), clashCounter)
		if ok, _ := conflictCheck(candidate, req.PortTypes[tipoT], req.Namespace, kardex); !ok {
			port = candidate
			algo = "B"
			return port, algo, false, nil
		}
	}

	// HITL: todos los algoritmos fallaron
	return 0, "", true, fmt.Errorf(
		"conflicto irresolvible para ficha %s tipo %s en %s — requiere intervención manual",
		req.FichaID, req.PortTypes[tipoT], req.LogicalServer,
	)
}

// algorithmB implementa el hash SHA-256 fallback.
// Resultado garantizado en rango 32000-49151 (NodePort dinámico SBOS).
func algorithmB(fichaID, tipoDesc string, clashCounter int) int {
	seed := fmt.Sprintf("%s:%s:%d", fichaID, tipoDesc, clashCounter)
	h := sha256.Sum256([]byte(seed))
	val := binary.BigEndian.Uint32(h[:4])
	// Rango 32000-49151 = 17152 valores
	return 32000 + int(val%17152)
}

// conflictCheck verifica un puerto contra las 3 capas.
// Retorna (conflicto bool, reason string).
// conflicto=true significa que el puerto NO está disponible.
func conflictCheck(port int, pt PortType, namespace string, kardex KardexPort) (bool, string) {
	// Capa 1: lista negra local
	if reserved, reason := IsReserved(port); reserved {
		return true, "capa1:" + reason
	}

	// Capa 2: catálogo SBOS-050
	if inSBOS, reason := IsInSBOS050(port); inSBOS {
		return true, "capa2:" + reason
	}

	// Capa 3: Kardex DB
	if kardex != nil {
		if exists, err := kardex.ExistsActive(port, string(pt), namespace); err == nil && exists {
			return true, "capa3:kardex"
		}
	}

	return false, ""
}
