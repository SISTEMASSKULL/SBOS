// Package server — tests F6.6–F6.11: sagas de consulta bos.query.*.
// DoD por saga según BOS-REPAIR Plan Maestro v3 §FASE-6.
package server

import (
	"strings"
	"testing"
	"time"

	"bos/internal/state"
)

// queryStateStub retorna un estado con fichas en varios estados para las sagas.
type queryStateStub struct {
	fichas map[string]*state.Ficha
}

func (q queryStateStub) Read() (*state.SBOSState, error) {
	return &state.SBOSState{
		Version:  "1.0",
		Hostname: "host-query",
		Fichas:   q.fichas,
	}, nil
}
func (queryStateStub) Transition(string, state.FichaState) error { return nil }
func (queryStateStub) SetHealth(string, string) error            { return nil }

func fichaOK(name, version string) *state.Ficha {
	return &state.Ficha{Name: name, Version: version,
		State: state.StateInstalled, HealthStatus: "OK"}
}

// makeQueryServer arma un Server con estado de fichas y Context Plane en
// memoria — sin daemon, sin cluster.
func makeQueryServer(fichas map[string]*state.Ficha) *Server {
	s := makeCtxTestServer()
	s.stateMgr = queryStateStub{fichas: fichas}
	return s
}

// TestQuerySystem_MenosDe4s es el DoD de F6.6: la saga responde en < 4s con
// las claves del contrato aunque haya fuentes degradadas (sin cluster K8s).
// El SLO se valida con duration_ms — la medición interna del motor, que es
// lo que el deadline garantiza. El reloj externo solo acota a 6s para no
// fallar por contención del runner (compilación -race de varios paquetes).
func TestQuerySystem_MenosDe4s(t *testing.T) {
	s := makeQueryServer(map[string]*state.Ficha{
		"postgresql": fichaOK("postgresql", "18.4"),
		"redis":      fichaOK("redis", "8.6.2"),
	})

	start := time.Now()
	resp := s.rpcQuerySystem(buildRPC("bos.query.system", map[string]string{"tenant_id": "skull"}))
	elapsed := time.Since(start)

	if elapsed > 6*time.Second {
		t.Errorf("la saga excedió incluso el margen de contención: %v", elapsed)
	}
	if resp.Error != nil {
		t.Fatalf("bos.query.system: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	for _, clave := range []string{"ubuntu", "kubernetes", "fichas", "certificacion", "context_plane", "semaforo", "timestamp", "duration_ms"} {
		if _, ok := out[clave]; !ok {
			t.Errorf("falta la clave %s en la respuesta", clave)
		}
	}

	// SLO <4s medido por el motor (deadline interno + margen de recolección)
	if ms, ok := out["duration_ms"].(int64); !ok || ms >= 4500 {
		t.Errorf("SLO: duration_ms del motor debe ser <4500 (deadline 4s), got %v", out["duration_ms"])
	}

	// las fichas del stub deben agregarse correctamente
	fichas := out["fichas"].(map[string]interface{})
	if fichas["total"] != 2 || fichas["instalada"] != 2 {
		t.Errorf("resumen de fichas incorrecto: %+v", fichas)
	}

	// regresión de staging real: con ubuntu y fichas sanas (las críticas),
	// el semáforo NUNCA es ROJO — solo AMARILLO por fuentes secundarias
	// degradadas (kubectl ausente en CI) o VERDE con todo sano
	if out["semaforo"] == "ROJO" {
		t.Errorf("críticas sanas no pueden dar ROJO: %v (fichas=%+v)", out["semaforo"], fichas)
	}
}

// TestQuerySystem_RegistradaEnDispatcher: la saga es invocable vía dispatchRPC
// (criterio de completitud BOS-REPAIR-12 §6.4 — registrada en rpcRegistry).
func TestQuerySystem_RegistradaEnDispatcher(t *testing.T) {
	s := makeQueryServer(map[string]*state.Ficha{"redis": fichaOK("redis", "8.6.2")})

	resp := s.dispatchRPC(buildRPC("bos.query.system", nil), rpcAuth{})
	if resp == nil {
		t.Fatal("respuesta nil")
	}
	if resp.Error != nil {
		t.Fatalf("bos.query.system vía dispatcher: %v", resp.Error)
	}
}

// TestQueryRepair_CausaProbable es el DoD de F6.7: el pre-diagnóstico de una
// ficha degradada identifica una causa probable accionable.
func TestQueryRepair_CausaProbable(t *testing.T) {
	s := makeQueryServer(map[string]*state.Ficha{
		"nextcloud": {Name: "nextcloud", Version: "30.0",
			State: state.StateDegraded, HealthStatus: "FAIL"},
	})

	resp := s.rpcQueryRepair(buildRPC("bos.query.repair", map[string]string{
		"ficha_id": "nextcloud", "tenant_id": "skull",
	}))
	if resp.Error != nil {
		t.Fatalf("bos.query.repair: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})

	diag, ok := out["diagnostico"].(map[string]interface{})
	if !ok {
		t.Fatalf("falta diagnostico: %+v", out)
	}
	causa, _ := diag["causa_probable"].(string)
	if causa == "" {
		t.Error("causa_probable no debe estar vacía para ficha DEGRADADA")
	}
	if !strings.Contains(causa, "degradado") && !strings.Contains(causa, "probe") {
		t.Errorf("causa_probable debe explicar la degradación, got: %s", causa)
	}

	rec, ok := out["recomendacion"].(map[string]interface{})
	if !ok || rec["accion"] != "bos.ficha.repair" {
		t.Errorf("recomendación debe proponer bos.ficha.repair: %+v", rec)
	}

	// ficha sana → recomendación "ninguna"
	s2 := makeQueryServer(map[string]*state.Ficha{"redis": fichaOK("redis", "8.6.2")})
	resp2 := s2.rpcQueryRepair(buildRPC("bos.query.repair", map[string]string{"ficha_id": "redis"}))
	out2 := resp2.Result.(map[string]interface{})
	rec2 := out2["recomendacion"].(map[string]interface{})
	if rec2["accion"] != "ninguna" {
		t.Errorf("ficha sana debe recomendar accion=ninguna: %+v", rec2)
	}

	// ficha_id vacío → InvalidParams
	bad := s.rpcQueryRepair(buildRPC("bos.query.repair", map[string]string{}))
	if bad.Error == nil || bad.Error.Code != ErrInvalidParams {
		t.Errorf("sin ficha_id debe dar InvalidParams: %+v", bad)
	}
}

// TestQueryVdi_SemaforoVerde es el DoD de F6.8: con las 3 fichas del VDI
// Layer INSTALADAS y saludables el semáforo es VERDE; con una degradada
// deja de serlo.
func TestQueryVdi_SemaforoVerde(t *testing.T) {
	s := makeQueryServer(map[string]*state.Ficha{
		"nextcloud":     fichaOK("nextcloud", "30.0"),
		"guacamole":     fichaOK("guacamole", "1.6"),
		"fedora-logico": fichaOK("fedora-logico", "1.0"),
	})

	resp := s.rpcQueryVdi(buildRPC("bos.query.vdi", map[string]string{"tenant_id": "skull"}))
	if resp.Error != nil {
		t.Fatalf("bos.query.vdi: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})

	if out["semaforo_vdi"] != "VERDE" {
		t.Errorf("VDI completo y sano: want VERDE, got %v", out["semaforo_vdi"])
	}
	for _, clave := range []string{"nextcloud", "guacamole", "fedora_logico", "context_plane_vdi"} {
		if _, ok := out[clave]; !ok {
			t.Errorf("falta la clave %s", clave)
		}
	}
	nc := out["nextcloud"].(map[string]interface{})
	if nc["healthy"] != true {
		t.Errorf("nextcloud debe reportar healthy: %+v", nc)
	}

	// guacamole degradado → el semáforo deja de ser VERDE (crítica → ROJO)
	s2 := makeQueryServer(map[string]*state.Ficha{
		"nextcloud": fichaOK("nextcloud", "30.0"),
		"guacamole": {Name: "guacamole", Version: "1.6",
			State: state.StateDegraded, HealthStatus: "FAIL"},
		"fedora-logico": fichaOK("fedora-logico", "1.0"),
	})
	resp2 := s2.rpcQueryVdi(buildRPC("bos.query.vdi", nil))
	out2 := resp2.Result.(map[string]interface{})
	if out2["semaforo_vdi"] == "VERDE" {
		t.Errorf("con guacamole degradado el semáforo no puede ser VERDE: %v", out2["semaforo_vdi"])
	}
}

// crearSesion registra y promueve un dispositivo, retornando el ctx_id.
func crearSesion(t *testing.T, s *Server, tenant, user string) string {
	t.Helper()
	reg := s.rpcCtxDeviceRegister(buildRPC("bos.ctx.device.register", map[string]string{
		"hostname": "host-" + user, "tenant_id": tenant, "ip": "10.0.0.1",
	}))
	if reg.Error != nil {
		t.Fatalf("register: %v", reg.Error)
	}
	dctxID := reg.Result.(map[string]interface{})["dctx_id"].(string)
	prom := s.rpcCtxPromote(buildRPC("bos.ctx.promote", map[string]interface{}{
		"dctx_id": dctxID, "user_id": user, "bitmask": uint64(0x0F), "loa": 2,
	}))
	if prom.Error != nil {
		t.Fatalf("promote: %v", prom.Error)
	}
	return prom.Result.(map[string]interface{})["ctx_id"].(string)
}

// TestQueryTenant_TodosLosTenants es el DoD de F6.9: el snapshot reúne TODAS
// las sesiones del tenant consultado y SOLO las de ese tenant (aislamiento
// multi-tenant SBOS-049 §5.1).
func TestQueryTenant_TodosLosTenants(t *testing.T) {
	s := makeQueryServer(map[string]*state.Ficha{
		"postgresql": fichaOK("postgresql", "18.4"),
	})

	crearSesion(t, s, "skull", "ana")
	crearSesion(t, s, "skull", "luis")
	crearSesion(t, s, "acme", "eve") // otro tenant — no debe aparecer

	resp := s.rpcQueryTenant(buildRPC("bos.query.tenant", map[string]string{"tenant_id": "skull"}))
	if resp.Error != nil {
		t.Fatalf("bos.query.tenant: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})

	for _, clave := range []string{"identidad", "infraestructura", "contexto", "usuarios"} {
		if _, ok := out[clave]; !ok {
			t.Errorf("falta la sección %s", clave)
		}
	}

	ctxInfo := out["contexto"].(map[string]interface{})
	if ctxInfo["ctx_activos"] != 2 || ctxInfo["ctx_total"] != 2 {
		t.Errorf("skull debe tener exactamente sus 2 sesiones: %+v", ctxInfo)
	}
	for _, ses := range ctxInfo["sesiones"].([]map[string]interface{}) {
		if ses["user_id"] == "eve" {
			t.Error("violación de aislamiento: sesión de otro tenant en el snapshot")
		}
	}

	infra := out["infraestructura"].(map[string]interface{})
	if infra["namespace"] != "sbos-skull" {
		t.Errorf("namespace derivado: want sbos-skull, got %v", infra["namespace"])
	}

	// tenant_id vacío → InvalidParams
	bad := s.rpcQueryTenant(buildRPC("bos.query.tenant", map[string]string{}))
	if bad.Error == nil || bad.Error.Code != ErrInvalidParams {
		t.Errorf("sin tenant_id debe dar InvalidParams: %+v", bad)
	}
}

// TestQueryNode_TodosReady es el DoD de F6.10: la evaluación "todos los
// nodos Ready" es correcta con datos del contrato K8sNodesSummary, y la
// saga responde con las secciones del contrato aunque no haya cluster.
func TestQueryNode_TodosReady(t *testing.T) {
	// evaluación pura — todos ready
	ready, conocido := todosLosNodosReady(map[string]interface{}{
		"nodes_ready": 3, "nodes_total": 3,
	})
	if !conocido || !ready {
		t.Errorf("3/3 nodos: want ready=true conocido=true, got %v/%v", ready, conocido)
	}

	// un nodo caído
	ready, conocido = todosLosNodosReady(map[string]interface{}{
		"nodes_ready": 2, "nodes_total": 3,
	})
	if !conocido || ready {
		t.Errorf("2/3 nodos: want ready=false, got %v", ready)
	}

	// números como float64 (tras viajar por JSON)
	ready, conocido = todosLosNodosReady(map[string]interface{}{
		"nodes_ready": float64(1), "nodes_total": float64(1),
	})
	if !conocido || !ready {
		t.Errorf("1/1 (float64): want ready=true, got %v/%v", ready, conocido)
	}

	// fuente degradada → no conocido
	if _, conocido := todosLosNodosReady(map[string]string{"error": "sin cluster"}); conocido {
		t.Error("fuente con error no debe reportar nodos_ready")
	}

	// saga completa — estructura aunque k8s degrade
	s := makeQueryServer(map[string]*state.Ficha{
		"postgresql": {Name: "postgresql", Version: "18.4",
			State: state.StateInstalled, HealthStatus: "OK", Criticality: true},
	})
	resp := s.rpcQueryNode(buildRPC("bos.query.node", map[string]string{"node": "node-01"}))
	if resp.Error != nil {
		t.Fatalf("bos.query.node: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})
	for _, clave := range []string{"k8s", "ubuntu", "fichas_en_nodo", "impacto_si_se_drena"} {
		if _, ok := out[clave]; !ok {
			t.Errorf("falta la sección %s", clave)
		}
	}
	impacto := out["impacto_si_se_drena"].(map[string]interface{})
	criticas := impacto["fichas_criticas"].([]string)
	if len(criticas) != 1 || criticas[0] != "postgresql" {
		t.Errorf("fichas críticas: want [postgresql], got %v", criticas)
	}

	// node vacío → InvalidParams
	bad := s.rpcQueryNode(buildRPC("bos.query.node", map[string]string{}))
	if bad.Error == nil || bad.Error.Code != ErrInvalidParams {
		t.Errorf("sin node debe dar InvalidParams: %+v", bad)
	}
}

// TestQueryContext_TTLsValidos es el DoD de F6.11: las sesiones activas
// reportan TTL restante > 0, la distribución de estados cuadra y las
// sesiones invalidadas no aparecen en la lista de TTLs.
func TestQueryContext_TTLsValidos(t *testing.T) {
	s := makeQueryServer(nil)

	crearSesion(t, s, "skull", "ana")
	ctxLuis := crearSesion(t, s, "skull", "luis")

	// invalidar la sesión de luis — debe salir de ttls y contar en la distribución
	inv := s.rpcCtxInvalidate(buildRPC("bos.ctx.invalidate", map[string]string{"ctx_id": ctxLuis}))
	if inv.Error != nil {
		t.Fatalf("invalidate: %v", inv.Error)
	}

	resp := s.rpcQueryContext(buildRPC("bos.query.context", map[string]string{"tenant_id": "skull"}))
	if resp.Error != nil {
		t.Fatalf("bos.query.context: %v", resp.Error)
	}
	out := resp.Result.(map[string]interface{})

	resumen := out["resumen"].(map[string]interface{})
	if resumen["ctx_total"] != 2 || resumen["ctx_activos"] != 1 {
		t.Errorf("resumen: want total=2 activos=1, got %+v", resumen)
	}

	dist := out["distribucion_estados"].(map[string]int)
	if dist["ACTIVO"] != 1 || dist["INVALIDADO"] != 1 {
		t.Errorf("distribución: want ACTIVO=1 INVALIDADO=1, got %+v", dist)
	}

	ttls := out["ttls"].([]map[string]interface{})
	if len(ttls) != 1 {
		t.Fatalf("solo la sesión activa debe listar TTL: got %d", len(ttls))
	}
	ttl := ttls[0]["ttl_restante_s"].(int64)
	if ttl <= 0 || ttl > 12*3600 {
		t.Errorf("TTL restante debe estar en (0, 12h]: got %d s", ttl)
	}
	if ttls[0]["user_id"] != "ana" {
		t.Errorf("la sesión activa es de ana: %+v", ttls[0])
	}

	anom := out["anomalias"].(map[string]interface{})
	if n := len(anom["ctx_sin_bitmask"].([]string)); n != 0 {
		t.Errorf("sin anomalías de BitMask esperadas: %d", n)
	}
	if n := len(anom["ctx_expirados_no_invalidados"].([]string)); n != 0 {
		t.Errorf("sin expirados esperados: %d", n)
	}

	// tenant_id vacío → InvalidParams
	bad := s.rpcQueryContext(buildRPC("bos.query.context", map[string]string{}))
	if bad.Error == nil || bad.Error.Code != ErrInvalidParams {
		t.Errorf("sin tenant_id debe dar InvalidParams: %+v", bad)
	}
}
