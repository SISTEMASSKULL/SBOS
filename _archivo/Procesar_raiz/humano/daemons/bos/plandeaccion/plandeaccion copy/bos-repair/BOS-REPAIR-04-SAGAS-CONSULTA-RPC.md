# BOS-REPAIR-04 — Sagas de Consulta JSON-RPC
## Agregación de información multi-fuente para evaluación profesional del sistema
## Prefijo: BOS-REPAIR · SKULL · SBOS · v1.0 · Junio 2026

**Referencia:** PLAN_ACCION_BOSAGENT.md — Fase 6 (JSON-RPC robusto)  
**ADRs:** ADR-004 (Operator Soberano), ADR-005 (Abstracción bosctl)  
**Relacionado:** BOS-REPAIR-01, BOS-REPAIR-02, BOS-REPAIR-03

---

## El concepto central: JSON-RPC no es solo para acciones

El JSON-RPC del bos tiene dos clases de operaciones:

```
CLASE 1 — Acciones (ya implementadas):
  bos.ficha.install    → instala una ficha
  bos.ficha.repair     → repara una ficha
  bos.k8s.node.drain   → drena un nodo

CLASE 2 — Sagas de Consulta (lo que este documento define):
  bos.query.system     → agrega estado de Ubuntu + K8s + fichas en una llamada
  bos.query.vdi        → agrega estado del VDI Layer completo en una llamada
  bos.query.tenant     → snapshot completo de un tenant en una llamada
  bos.query.repair     → pre-diagnóstico antes de ejecutar una reparación
```

La diferencia fundamental: una **saga de consulta** ejecuta múltiples comandos internos en paralelo, agrega los resultados, y retorna una vista compuesta estructurada. El llamador obtiene todo lo que necesita en **una sola llamada RPC** en lugar de N llamadas secuenciales.

---

## Por qué las sagas de consulta son importantes

### El problema sin sagas de consulta

Para evaluar si el sistema está saludable antes de una reparación, hoy habría que hacer:

```bash
# 8 llamadas secuenciales — lento y difícil de correlacionar:
bosctl rpc bos.health.check
bosctl rpc bos.state.read
bosctl rpc bos.ficha.status '{"ficha_id":"postgresql"}'
bosctl rpc bos.ficha.status '{"ficha_id":"redis"}'
bosctl rpc bos.ficha.status '{"ficha_id":"nextcloud"}'
bosctl rpc bos.ctx.list '{"tenant_id":"skull"}'
bosctl vdi health --tenant=skull
bosctl node list
```

### Con una saga de consulta

```bash
# 1 llamada — todo en paralelo, resultado estructurado:
bosctl rpc bos.query.repair '{"tenant_id":"skull","target":"nextcloud"}'
```

Retorna en < 3 segundos todo lo necesario para decidir cómo reparar.

---

## Catálogo de Sagas de Consulta

### bos.query.system — Estado completo del servidor

**Propósito:** Vista unificada de Ubuntu + K8s + fichas + Context Plane. La consulta de referencia para diagnóstico general.

**Ejecuta internamente en paralelo:**
```
Thread 1: watchdog.CheckUbuntu()     → CPU, mem, disco, systemd services
Thread 2: watchdog.CheckK8s()        → nodos, pods críticos, CoreDNS
Thread 3: stateMgr.Read()            → estado de las 22 fichas
Thread 4: ctxSvc.ListByTenant()      → ctx_id activos
Thread 5: healthChecker.CheckAll()   → probes de fichas críticas
```

**Llamada:**
```bash
bosctl rpc bos.query.system
# o con filtros:
bosctl rpc bos.query.system '{"tenant_id":"skull","include":["ubuntu","k8s","fichas"]}'
```

**Respuesta estructurada:**
```json
{
  "timestamp": "2026-06-07T14:32:00Z",
  "duration_ms": 1847,
  "semaforo": "VERDE",

  "ubuntu": {
    "healthy": true,
    "cpu_pct": 45,
    "mem_pct": 62,
    "disk_pct": 28,
    "services": {
      "containerd": "active",
      "kubelet": "active"
    },
    "uptime_hours": 132
  },

  "kubernetes": {
    "healthy": true,
    "nodes": [
      {"name": "node-01", "status": "Ready", "cpu_pct": 45, "mem_pct": 62}
    ],
    "nodes_ready": 1,
    "nodes_total": 1,
    "pods_anomalies": []
  },

  "fichas": {
    "total": 22,
    "instalada": 22,
    "degradada": 0,
    "pendiente": 0,
    "detalles": [
      {"id": "postgresql", "state": "INSTALADA", "health": "OK", "version": "18.4"},
      {"id": "redis",      "state": "INSTALADA", "health": "OK", "version": "8.6.2"},
      {"id": "nextcloud",  "state": "INSTALADA", "health": "OK", "version": "30.x"},
      {"id": "keycloak",   "state": "INSTALADA", "health": "OK", "version": "26.6.2"}
    ]
  },

  "context_plane": {
    "healthy": true,
    "ctx_activos": 12,
    "dctx_activos": 5,
    "promote_p99_ms": 1240
  },

  "certificacion": {
    "c01": true, "c02": true, "c03": true, "c04": true,
    "c05": true, "c06": true, "c07": true, "c08": true,
    "c09": true, "c10": true, "c11": true, "c12": true,
    "c13": true, "c14": true,
    "total": "14/14",
    "aprobada": true
  }
}
```

**Casos de uso:**
- Dashboard de Grafana (polling cada 30s)
- Pre-check antes de cualquier operación de mantenimiento
- Post-check después de cualquier reparación
- Certificación operacional por el Operador

---

### bos.query.repair — Pre-diagnóstico de reparación

**Propósito:** Antes de ejecutar una reparación, recopilar todo lo necesario para tomar la decisión correcta. Responde: ¿qué está fallando? ¿por qué? ¿qué impacto tiene repararlo ahora?

**Ejecuta internamente en paralelo:**
```
Thread 1: stateMgr.Get(fichaID)          → estado actual de la ficha
Thread 2: healthChecker.Probe(fichaID)   → probe real del servicio
Thread 3: reconciler.GetHashes(fichaID)  → drift SHA-256 detectado
Thread 4: stateMgr.GetDependencies()     → fichas que dependen de esta
Thread 5: audit.GetLastRepairs(fichaID)  → historial de reparaciones
Thread 6: k8sCore.GetPodLogs(fichaID)   → últimas 50 líneas de logs del pod
Thread 7: ctxSvc.CountByFicha(fichaID)  → ctx_id activos que usan esta ficha
Thread 8: scaler.GetPolicy(fichaID)      → política de escalado actual
```

**Llamada:**
```bash
bosctl rpc bos.query.repair '{"ficha_id":"nextcloud","tenant_id":"skull"}'
```

**Respuesta estructurada:**
```json
{
  "timestamp": "2026-06-07T14:32:00Z",
  "duration_ms": 2103,
  "ficha_id": "nextcloud",
  "tenant_id": "skull",

  "estado_actual": {
    "state": "DEGRADADA",
    "health": "FAIL",
    "replicas_ready": 0,
    "replicas_desired": 2,
    "tiempo_degradada": "8m32s"
  },

  "diagnostico": {
    "causa_probable": "OOMKilled — memoria insuficiente",
    "drift_detectado": false,
    "probe_resultado": {
      "healthy": false,
      "error": "connection refused on port 28300",
      "latency_ms": 5001
    },
    "logs_recientes": [
      "2026-06-07T14:23:12Z ERROR OOMKilled — container nextcloud",
      "2026-06-07T14:23:11Z WARN  Memory usage 3.9/4.0 GB (97%)",
      "2026-06-07T14:23:10Z INFO  Processing large file upload..."
    ]
  },

  "impacto": {
    "usuarios_afectados": 12,
    "ctx_id_activos_usando_ficha": 12,
    "home_desmontado_en_pods": 3,
    "dependientes_afectados": []
  },

  "historial_reparaciones": [
    {"fecha": "2026-06-05T14:32:00Z", "outcome": "OK", "duracion": "8m02s"},
    {"fecha": "2026-06-03T09:15:00Z", "outcome": "OK", "duracion": "6m44s"}
  ],

  "recomendacion": {
    "accion": "bos.ficha.repair",
    "ajuste_sugerido": "aumentar memory_limit de 4Gi a 6Gi en manifest",
    "impacto_reparacion": "downtime estimado 5-8 minutos",
    "usuarios_notificados": true,
    "rpc_ejecutar": "bosctl rpc bos.ficha.repair '{\"ficha_id\":\"nextcloud\"}'"
  }
}
```

**Casos de uso:**
- Evaluación profesional antes de reparar en producción
- El watchdog lo ejecuta internamente antes de disparar auto-repair
- El biedata lo usa para presentar diagnóstico en la UI del operador
- Registro en audit log antes de cualquier intervención

---

### bos.query.vdi — Estado completo del VDI Layer

**Propósito:** Vista unificada de todo lo necesario para que el usuario pueda trabajar. Una sola llamada reemplaza 6 verificaciones individuales.

**Ejecuta internamente en paralelo:**
```
Thread 1: k8sCore.GetPodsReady("nextcloud")        → réplicas nextcloud
Thread 2: k8sCore.GetPodsReady("guacamole")        → réplicas guacamole
Thread 3: k8sCore.GetPodsReady("fedora-logico")    → pool VDI disponible
Thread 4: ctxSvc.CountByType("logical_pod")        → sesiones activas
Thread 5: nextcloudClient.Health()                 → Nextcloud accesible
Thread 6: guacamoleClient.Health()                 → Guacamole API OK
Thread 7: k8sCore.GetHPA("fedora-logico")          → política de escalado
Thread 8: ctxSvc.CountHomeMounted()                → homes montados
```

**Llamada:**
```bash
bosctl rpc bos.query.vdi '{"tenant_id":"skull"}'
# o para todos los tenants:
bosctl rpc bos.query.vdi
```

**Respuesta estructurada:**
```json
{
  "timestamp": "2026-06-07T14:32:00Z",
  "duration_ms": 1203,
  "tenant_id": "skull",
  "semaforo_vdi": "VERDE",

  "nextcloud": {
    "healthy": true,
    "replicas": "2/2",
    "url": "https://files.skull.sksistemas.com",
    "storage_used_gb": 128,
    "storage_total_gb": 500,
    "storage_pct": 26
  },

  "guacamole": {
    "healthy": true,
    "replicas": "1/1",
    "url": "https://vdi.skull.sksistemas.com",
    "conexiones_activas": 8
  },

  "fedora_logico": {
    "healthy": true,
    "pods_running": 3,
    "pods_min": 2,
    "pods_max": 20,
    "sesiones_activas": 8,
    "home_montado_pct": 100,
    "escalado_auto": true
  },

  "context_plane_vdi": {
    "dctx_ids_activos": 3,
    "ctx_ids_activos": 8,
    "promote_p99_ms": 1240,
    "bitmask_cero_count": 0
  },

  "iso_fedora": {
    "version": "1.0.0",
    "disponible": true,
    "url": "https://releases.skull.io/sbos-fedora-1.0.0.iso",
    "sha256": "a3f9..."
  },

  "verificacion_e2e": {
    "ok": true,
    "login_latency_ms": 7800,
    "home_mount_ok": true,
    "archivo_persistido": true
  }
}
```

---

### bos.query.tenant — Snapshot completo de un tenant

**Propósito:** Todo lo que el bos sabe sobre un tenant en una sola llamada. Para administración, auditoría, y onboarding.

**Llamada:**
```bash
bosctl rpc bos.query.tenant '{"tenant_id":"skull"}'
```

**Ejecuta internamente en paralelo:**
```
Thread 1: stateMgr.GetTenantFichas()    → fichas del tenant
Thread 2: ctxSvc.ListByTenant()         → contextos activos
Thread 3: k8sCore.GetNamespaceUsage()  → recursos K8s consumidos
Thread 4: nextcloudClient.GetQuotas()  → uso de almacenamiento
Thread 5: keycloakClient.GetUsers()    → usuarios activos
Thread 6: audit.GetRecentEvents()      → eventos de auditoría recientes
Thread 7: deviceSvc.ListActive()        → dispositivos físicos registrados
```

**Respuesta estructurada:**
```json
{
  "tenant_id": "skull",
  "timestamp": "2026-06-07T14:32:00Z",

  "identidad": {
    "razon_social": "SKULL S.A.",
    "nit": "1025463029",
    "pais": "BO",
    "dominio": "skull.sksistemas.com",
    "instalado_en": "2026-06-01T10:00:00Z",
    "version_sbos": "1.0.0"
  },

  "infraestructura": {
    "namespace": "sbos-skull",
    "fichas_instaladas": 22,
    "fichas_degradadas": 0,
    "cpu_usado_cores": 4.5,
    "mem_usado_gb": 18.3,
    "storage_usado_gb": 128
  },

  "usuarios": {
    "total_keycloak": 45,
    "activos_ahora": 8,
    "dispositivos_fisicos": 12,
    "dispositivos_logicos": 3
  },

  "contexto": {
    "ctx_activos": 8,
    "dctx_activos": 15,
    "sesiones_hoy": 47
  },

  "almacenamiento": {
    "nextcloud_usado_gb": 128,
    "nextcloud_total_gb": 500,
    "usuarios_con_home": 45,
    "archivos_totales": 12847
  },

  "auditoria_reciente": [
    {"ts": "14:28:00", "evento": "REPAIR_OK", "ficha": "nextcloud"},
    {"ts": "14:15:00", "evento": "SCALE_UP",  "ficha": "fedora-logico"},
    {"ts": "13:50:00", "evento": "CTX_PROMOTE","user": "juan.garcia"}
  ],

  "slo_status": {
    "postgresql_uptime_30d": 99.97,
    "vdi_uptime_30d": 99.12,
    "ctx_promote_p99_ms": 1240,
    "mttr_avg_min": 7.3
  }
}
```

---

### bos.query.node — Diagnóstico completo de un nodo

**Propósito:** Todo lo que se necesita saber sobre un nodo antes de hacer mantenimiento.

**Llamada:**
```bash
bosctl rpc bos.query.node '{"node":"node-01"}'
```

**Ejecuta internamente en paralelo:**
```
Thread 1: k8sCore.GetNodeStatus()       → estado K8s del nodo
Thread 2: watchdog.CheckNodeUbuntu()    → métricas Ubuntu del nodo
Thread 3: k8sCore.GetPodsOnNode()       → fichas corriendo en este nodo
Thread 4: k8sCore.GetNodeEvents()       → eventos K8s del nodo
Thread 5: audit.GetNodeOps()            → operaciones recientes en este nodo
Thread 6: maintenanceSvc.GetHistory()   → historial de mantenimientos
```

**Respuesta:**
```json
{
  "node": "node-01",
  "timestamp": "2026-06-07T14:32:00Z",

  "k8s": {
    "status": "Ready",
    "schedulable": true,
    "version": "v1.32.0+k3s1",
    "joined_at": "2026-06-01T10:00:00Z"
  },

  "ubuntu": {
    "hostname": "sbos-server-01",
    "os": "Ubuntu 24.04 LTS",
    "kernel": "6.8.0-51-generic",
    "cpu_pct": 45,
    "mem_pct": 62,
    "disk_pct": 28,
    "uptime_hours": 132
  },

  "fichas_en_nodo": [
    {"ficha": "postgresql", "pod": "postgresql-0", "cpu_pct": 12, "mem_pct": 35},
    {"ficha": "redis",      "pod": "redis-0",      "cpu_pct": 3,  "mem_pct": 8},
    {"ficha": "nextcloud",  "pod": "nextcloud-0",  "cpu_pct": 8,  "mem_pct": 22},
    {"ficha": "nextcloud",  "pod": "nextcloud-1",  "cpu_pct": 7,  "mem_pct": 21}
  ],

  "fichas_criticas_en_nodo": ["postgresql", "redis", "vault"],

  "impacto_si_se_drena": {
    "fichas_a_migrar": 8,
    "fichas_criticas": 3,
    "ctx_afectados": 12,
    "capacidad_restante_cluster_pct": 0,
    "advertencia": "Cluster de 1 nodo — drain dejará sin capacidad"
  },

  "historial_mantenimientos": [
    {"fecha": "2026-05-15", "op": "k8s-patch", "duracion": "12m", "outcome": "OK"}
  ],

  "recomendacion_mantenimiento": {
    "momento_optimo": "Fuera de horario laboral (después de 20:00)",
    "pre_requisito": "Escalar fedora-logico a 0 replicas antes del drain",
    "rpc_ejecutar": "bosctl node maintain node-01 --op=k8s-patch --schedule=20:00"
  }
}
```

---

### bos.query.context — Estado del Context Plane para diagnóstico

**Propósito:** Vista completa del Context Plane para un tenant. Detecta ctx_id sin BitMask, sesiones huérfanas, dispositivos sin dctx_id.

**Llamada:**
```bash
bosctl rpc bos.query.context '{"tenant_id":"skull"}'
```

**Respuesta:**
```json
{
  "tenant_id": "skull",
  "timestamp": "2026-06-07T14:32:00Z",

  "resumen": {
    "ctx_activos": 8,
    "ctx_suspendidos": 2,
    "ctx_bloqueados": 0,
    "dctx_activos": 15,
    "sesiones_hoy": 47
  },

  "anomalias": {
    "ctx_sin_bitmask": [],
    "ctx_expirados_no_invalidados": [],
    "dctx_sin_promote_mas_de_1h": [
      {"dctx_id": "dctx-device-991", "hostname": "caja-01", "tiempo": "2h15m"}
    ],
    "dispositivos_sin_dctx": []
  },

  "distribucion_estados": {
    "PRE_AUTH": 7,
    "ACTIVO": 8,
    "SUSPENDIDO": 2,
    "BLOQUEADO": 0,
    "INVALIDADO_HOY": 30
  },

  "metricas": {
    "promote_p50_ms": 890,
    "promote_p95_ms": 1580,
    "promote_p99_ms": 2240,
    "bitmask_cero_post_auth": 0
  }
}
```

---

## Implementación: cómo se construyen las sagas de consulta

### Patrón de implementación en Go

```go
// internal/server/jsonrpc.go — handler de saga de consulta
// Cada query saga ejecuta en paralelo con context y timeout

func (s *Server) rpcQuerySystem(req *RPCRequest) RPCResponse {
    var p struct {
        TenantID string   `json:"tenant_id"`
        Include  []string `json:"include"` // opcional: filtrar componentes
    }
    _ = parseParams(req.Params, &p)

    // Timeout específico para sagas de consulta (rápidas por naturaleza)
    ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
    defer cancel()

    // Ejecutar todas las consultas en paralelo
    type result struct {
        key  string
        data interface{}
        err  error
    }
    ch := make(chan result, 8)

    go func() { u, e := s.watchdog.CheckUbuntu(ctx);    ch <- result{"ubuntu", u, e} }()
    go func() { k, e := s.watchdog.CheckK8s(ctx);       ch <- result{"kubernetes", k, e} }()
    go func() { f, e := s.stateMgr.Read();              ch <- result{"fichas", f, e} }()
    go func() { c, e := s.ctxSvc.Summary(ctx, p.TenantID); ch <- result{"context_plane", c, e} }()
    go func() { h, e := s.healthChecker.CheckCritical(ctx); ch <- result{"health", h, e} }()
    go func() { cert, e := s.bootstrapSvc.Verify(ctx);  ch <- result{"certificacion", cert, e} }()

    // Recopilar resultados con timeout
    collected := make(map[string]interface{})
    for i := 0; i < 6; i++ {
        select {
        case r := <-ch:
            if r.err == nil {
                collected[r.key] = r.data
            } else {
                collected[r.key] = map[string]string{"error": r.err.Error()}
            }
        case <-ctx.Done():
            collected["timeout"] = "query exceeded 10s deadline"
            goto done
        }
    }
done:

    // Calcular semáforo general
    semaforo := calcSemaforo(collected)
    collected["semaforo"] = semaforo
    collected["timestamp"] = time.Now()
    collected["duration_ms"] = time.Since(startTime).Milliseconds()

    return rpcOK(req.ID, collected)
}
```

### Registro en rpcRegistry

```go
// En internal/server/jsonrpc.go, agregar en init():

// bos.query.* — Sagas de consulta (agregación multi-fuente en paralelo)
"bos.query.system":  (*Server).rpcQuerySystem,   // Ubuntu+K8s+fichas+ctx
"bos.query.repair":  (*Server).rpcQueryRepair,   // pre-diagnóstico de reparación
"bos.query.vdi":     (*Server).rpcQueryVdi,      // VDI Layer completo
"bos.query.tenant":  (*Server).rpcQueryTenant,   // snapshot de tenant
"bos.query.node":    (*Server).rpcQueryNode,     // diagnóstico de nodo
"bos.query.context": (*Server).rpcQueryContext,  // Context Plane diagnóstico
```

### Comandos bosctl para sagas de consulta

```bash
# Sistema completo
bosctl query system
bosctl query system --output=json
bosctl query system --tenant=skull

# Pre-diagnóstico de reparación
bosctl query repair nextcloud --tenant=skull
bosctl query repair nextcloud --tenant=skull --output=json

# VDI Layer
bosctl query vdi --tenant=skull
bosctl query vdi --all-tenants

# Tenant completo
bosctl query tenant skull

# Nodo
bosctl query node node-01

# Context Plane
bosctl query context --tenant=skull
```

---

## Coexistencia: kubectl + bosctl + JSON-RPC

El ADR-005 establece que kubectl sigue vigente. La tabla completa de acceso:

```
HERRAMIENTA       QUIÉN LA USA              PARA QUÉ
──────────────────────────────────────────────────────────────────────
kubectl           Administrador avanzado     Diagnóstico de emergencia,
                  (en modo fallback)         operaciones fuera del bos

bosctl get/node   Operador SBOS              Operación diaria del sistema
bosctl query      Operador / scripts         Evaluación y diagnóstico

bosctl rpc        Scripts / automatización  Integración programática
                  biedata / bkernel          Sagas de consulta complejas

JSON-RPC directo  Daemons internos          biedata, bkernel, bsearch,
                                             banexus, bhnexus

kubectl get fichas Administrador avanzado   Vista K8s-nativa de fichas SBOS
                   (CRDs registrados)        Compatible con herramientas K8s
```

### El modelo de equivalencia

```
kubectl get pods -n sbos-skull              ═══╗
                                               ║ retornan la
bosctl get pods --tenant=skull              ═══╣ misma información
                                               ║ con diferente
bosctl rpc bos.ficha.list                   ═══╝ vocabulario
  '{"tenant_id":"skull"}'

kubectl get pods -n sbos-skull              → vista K8s (Pods)
bosctl get pods --tenant=skull              → vista SBOS (Fichas)
bosctl rpc bos.ficha.list                   → JSON estructurado (API)
bosctl rpc bos.query.system                 → vista agregada multi-fuente
```

---

## Casos de uso de sagas de consulta en el flujo de reparación

### Caso 1 — Reparación manual por operador

```bash
# Paso 1: diagnóstico
bosctl query repair nextcloud --tenant=skull
# → retorna causa_probable, usuarios_afectados, recomendacion

# Paso 2 (si decide proceder): ejecutar reparación
bosctl rpc bos.ficha.repair '{"ficha_id":"nextcloud"}'

# Paso 3: verificar resultado
bosctl query vdi --tenant=skull
# → retorna semaforo_vdi: VERDE cuando está resuelto
```

### Caso 2 — Auto-reparación del watchdog

```go
// internal/watchdog/unified_watchdog.go
// El watchdog usa bos.query.repair ANTES de disparar auto-repair

func (w *UnifiedWatchdog) handleDegradada(fichaID string) {
    // Primero: obtener diagnóstico completo
    diagnosis, err := w.querySvc.Repair(fichaID, w.tenantID)
    if err != nil {
        w.logger.Error("diagnóstico fallido", "ficha", fichaID)
        return
    }

    // Registrar diagnóstico en audit log ANTES de reparar
    audit.Log(audit.DefaultPath, "WATCHDOG_DIAGNOSIS",
        "ficha="+fichaID,
        "causa="+diagnosis.Diagnostico.CausaProbable,
        "usuarios_afectados="+strconv.Itoa(diagnosis.Impacto.UsuariosAfectados),
    )

    // Solo reparar si el diagnóstico indica que es seguro
    if diagnosis.Impacto.UsuariosAfectados > 50 {
        w.logger.Warn("demasiados usuarios afectados — notificar admin antes de reparar",
            "ficha", fichaID, "usuarios", diagnosis.Impacto.UsuariosAfectados)
        // Emitir alerta pero NO reparar automáticamente
        return
    }

    // Proceder con reparación
    w.repairMgr.Repair(fichaID)
}
```

### Caso 3 — Dashboard de biedata (Core UI)

```javascript
// biedata puede usar la saga de consulta para el dashboard del operador
// Una sola llamada RPC cada 30 segundos en lugar de 8 llamadas

async function refreshDashboard() {
    const estado = await bosRPC.call('bos.query.system', {
        tenant_id: currentTenant
    });

    updateSemaforo(estado.semaforo);
    updateFichasGrid(estado.fichas);
    updateContextPlane(estado.context_plane);
    updateCertificacion(estado.certificacion);
    // Todo actualizado en una sola llamada
}
```

### Caso 4 — Script de mantenimiento nocturno

```bash
#!/bin/bash
# BOS-REPAIR mantenimiento nocturno automatizado

TENANT="skull"
NODE="node-01"

echo "=== Diagnóstico pre-mantenimiento $(date) ==="

# 1. Saga de consulta del nodo — decide si es seguro hacer mantenimiento
NODO_STATUS=$(bosctl rpc bos.query.node "{\"node\":\"$NODE\"}" --output=json)

USUARIOS=$(echo $NODO_STATUS | jq '.impacto_si_se_drena.ctx_afectados')
if [ "$USUARIOS" -gt 0 ]; then
    echo "ERROR: $USUARIOS usuarios activos en el nodo — posponer mantenimiento"
    exit 1
fi

# 2. Saga de consulta VDI — confirmar que no hay sesiones activas
VDI_STATUS=$(bosctl rpc bos.query.vdi "{\"tenant_id\":\"$TENANT\"}" --output=json)
SESIONES=$(echo $VDI_STATUS | jq '.fedora_logico.sesiones_activas')
if [ "$SESIONES" -gt 0 ]; then
    echo "ERROR: $SESIONES sesiones VDI activas — posponer mantenimiento"
    exit 1
fi

echo "=== Sin usuarios activos — iniciando mantenimiento ==="
bosctl node maintain $NODE --op=k8s-patch

# 3. Saga de consulta post-mantenimiento
echo "=== Verificación post-mantenimiento ==="
bosctl query system --tenant=$TENANT

echo "=== Mantenimiento completado $(date) ==="
```

---

## Métricas de las sagas de consulta

```
# Prometheus — performance de sagas de consulta
bos_query_duration_seconds{query}     Histogram (p50, p95, p99)
bos_query_calls_total{query,outcome}  Counter
bos_query_timeout_total{query}        Counter

# SLO de sagas de consulta:
bos.query.system:   p99 < 5s   (agrega 6 fuentes en paralelo)
bos.query.repair:   p99 < 5s   (agrega 8 fuentes en paralelo)
bos.query.vdi:      p99 < 3s   (agrega 8 fuentes en paralelo)
bos.query.tenant:   p99 < 8s   (agrega 7 fuentes en paralelo)
bos.query.node:     p99 < 3s   (agrega 6 fuentes en paralelo)
bos.query.context:  p99 < 2s   (agrega 3 fuentes)
```

---

## Tareas en el Plan de Acción

Agregar a **Fase 6 — JSON-RPC robusto**:

```
F6.6  internal/query/: nuevo paquete — sagas de consulta paralelas
F6.7  jsonrpc: registrar bos.query.system
F6.8  jsonrpc: registrar bos.query.repair
F6.9  jsonrpc: registrar bos.query.vdi
F6.10 jsonrpc: registrar bos.query.tenant
F6.11 jsonrpc: registrar bos.query.node
F6.12 jsonrpc: registrar bos.query.context
F6.13 cmd/bosctl/query.go: bosctl query <tipo> [--tenant=X] [--output=json|table]
F6.14 watchdog: usar bos.query.repair antes de auto-repair
F6.15 Tests: TestQuerySystem_AllSourcesParallel
              TestQueryRepair_DiagnosisBefore_Repair
              TestQueryVdi_SemaforoCalculation
```

---

*BOS-REPAIR-04 — SKULL · SBOS · Junio 2026*  
*Prefijo BOS-REPAIR: todos los archivos de este proyecto llevan este prefijo*  
*Referencia: PLAN_ACCION_BOSAGENT.md — Fase 6 F6.6-F6.15*  
*Referencia: ADR-004, ADR-005*
---
*Autor: Ivan Jorge Villanueva Mollinedo — Sistemas SKULL*  
*Co-Autor (IA): Claude Sonnet 4.6 — Anthropic*
