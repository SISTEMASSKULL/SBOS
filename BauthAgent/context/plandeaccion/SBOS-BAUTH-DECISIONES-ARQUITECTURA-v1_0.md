# SBOS bAuth — Decisiones de Arquitectura y Plan de Acción
## Complemento para SBOS-BAUTH-CONCEPTUALIZACION-v4_0.md
### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Abril 2026 (BitMask Dual Jun 2026)

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-BAUTH-DECISIONES-v1.0 |
| **Propósito** | Responder los bloques A–G del cuestionario de REQ-1 a REQ-5 |
| **Fuentes** | Authentication_Framework.json · Policies_Authentication_Framework.json · SBOS-bAuth-Evaluacion-Requerimientos-v1.0 · SBOS-BAUTH-CONCEPTUALIZACION-v4.0 · SBOS-008 · SBOS-008-001 · SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO |
| **Estado** | LISTO PARA REVISIÓN — sujeto a aprobación ARB |

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** El modelo BitMask descrito en este documento ha sido reemplazado por el **BitMask Dual** (`SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`): BitMask Átomo 64-bit (label encoding para identificación) + Rol BitMask N-bit (one-hot encoding para combinación). Las referencias a "2 capas", SAM-128, "7×64 bits", "BitmaskBundle" o "capa 1/capa 2" reflejan el modelo anterior. Para desarrollo, usar los manuales actualizados.

---

## Tabla de Contenidos

1. [Contexto y Prioridad de los REQ](#1-contexto-y-prioridad-de-los-req)
2. [Bloque A — REQ-2: JSON Schema del RolTemplate](#2-bloque-a--req-2-json-schema-del-roltemplate)
3. [Bloque B — REQ-1: bauth.toml Completo](#3-bloque-b--req-1-bauthtomL-completo)
4. [Bloque C — REQ-3: Protocolo Unix Socket](#4-bloque-c--req-3-protocolo-unix-socket)
5. [Bloque D — REQ-4: Contrato KC Admin API y Maven SPIs](#5-bloque-d--req-4-contrato-kc-admin-api-y-maven-spis)
6. [Bloque E — REQ-5: Schema SQL bauth_db](#6-bloque-e--req-5-schema-sql-bauth_db)
7. [Bloque F — Decisiones que Afectan v4.0](#7-bloque-f--decisiones-que-afectan-v40)
8. [Bloque G — Gaps Menores de Coherencia](#8-bloque-g--gaps-menores-de-coherencia)
9. [Plan de Acción y Orden de Ejecución](#9-plan-de-acción-y-orden-de-ejecución)
10. [Decision Log Consolidado](#10-decision-log-consolidado)
11. [Glosario](#11-glosario)

---

## 1. Contexto y Prioridad de los REQ

Antes de responder los bloques A–G, se establece la dependencia real entre artefactos según el análisis del corpus:

```
FASE 1 — Paralelos (sin dependencia entre sí):
  REQ-1: bauth.toml  ────┐
  REQ-2: JSON Schema ────┼──► REQ-4: KC sync_role() + Maven SPIs
  REQ-3: Unix socket ────┘
                              │
                              ▼
                    REQ-5: Schema SQL bauth_db
```

**Fundamento desde el corpus:**
- `Authentication_Framework.json §metadata` define `version: "2.0.0"`, `environment: "production"`, `encryptionLevel: "high"` — estos valores deben reflejarse en `bauth.toml`.
- `Policies_Authentication_Framework.json §modern_authentication_policies` define los flujos WebAuthn/FIDO2 que los SPIs de KC deben implementar.
- `SBOS-BAUTH-CONCEPTUALIZACION-v4.0 §5` tiene las tablas parciales que forman la base del REQ-5.

---

## 2. Bloque A — REQ-2: JSON Schema del RolTemplate

### A1. Validity_period — end_date nulo en tipo FIXED

**Decisión:** `end_date` acepta `null` o ausencia cuando `type = "FIXED"` o `type = "INDEFINITE"`. Si `end_date` está presente, debe ser un timestamp ISO-8601 válido y posterior a `start_date`. El schema **no rechaza** un RolTemplate FIXED sin `end_date`.

**Razonamiento:** El corpus (`EsrtructuraRolFinal.txt §validity_period`) define `type: "FIXED"` con `end_date` para el caso de 30 días, pero el mismo documento define `type: "INDEFINITE"` como opción válida. Forzar `end_date` en FIXED rompería la semántica de roles permanentes que existen en todos los sectores del sistema (ej.: `ROL_CAJERO` base sin caducidad).

**Fragmento JSON Schema:**

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "properties": {
    "validity_period": {
      "type": "object",
      "properties": {
        "type": {
          "type": "string",
          "enum": ["FIXED", "INDEFINITE", "PROJECT_BASED"]
        },
        "start_date": {
          "type": "string",
          "format": "date-time"
        },
        "end_date": {
          "oneOf": [
            { "type": "string", "format": "date-time" },
            { "type": "null" }
          ]
        }
      },
      "required": ["type", "start_date"],
      "if": {
        "properties": { "type": { "const": "FIXED" } }
      },
      "then": {
        "properties": {
          "end_date": { "type": "string", "format": "date-time" }
        },
        "required": ["end_date"]
      }
    }
  }
}
```

**Nota de migración:** Roles existentes con `type: "FIXED"` y `end_date: null` deben ser migrados a `type: "INDEFINITE"` en el script de migración `migrations/002_fix_validity_types.sql`.

---

### A2. Zones — Rango de limit_tier

**Decisión:** El JSON Schema valida `limit_tier` estrictamente en el rango `0–5` conforme al mapa de bits SAM-128 Q3 (`FIN_LIMIT_TIER` bits 80–83). Valores custom de tenant (ej.: `limit_tier: 10`) **no están permitidos en el schema**. Si un tenant requiere límites especiales, estos se modelan como metadata contextual en `zone_financial.custom_limits` (campo nuevo, fuera del bitmask).

**Razonamiento:** El documento `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO §3.1` establece que el SAM-128 tiene exactamente 4 bits para `FIN_LIMIT_TIER` (bits 80–83), lo que permite un máximo de 16 valores (0–15). El rango operacional definido es 0–5. Permitir valores > 5 en el schema sin control produciría bitmasks silenciosamente incorrectos en PrivilegeEngine.

**Fragmento JSON Schema:**

```json
{
  "properties": {
    "zones": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "properties": {
          "limit_tier": {
            "type": "integer",
            "minimum": 0,
            "maximum": 5,
            "description": "Nivel de límite financiero. 0=sin operaciones, 5=sin límite (solo C-Level)."
          }
        }
      }
    }
  }
}
```

---

### A3. button_rules — Formato sod_cannot_also

**Decisión:** El campo `sod_cannot_also` en `tryton_privileges.button_rules` soporta **dos formatos**:

- Formato Tryton nativo: `"model.button"` → ej.: `"account.payment:create"`
- Formato zona lógica (v1.0+): `"zone:VERB"` → ej.: `"zone_financial/pagos:APPROVE"`

**Razonamiento:** El corpus (`SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION §3.3`) define la Conflict Matrix en términos de bits de dominio, no de roles. La decisión aprobada en `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO §2.4` establece que SoD debe operar en la capa de gobernanza con vocabulario de zonas. Soportar ambos formatos permite migración gradual sin romper Button Rules existentes.

**Fragmento JSON Schema:**

```json
{
  "properties": {
    "button_rules": {
      "type": "array",
      "items": {
        "type": "object",
        "properties": {
          "sod_cannot_also": {
            "oneOf": [
              {
                "type": "string",
                "pattern": "^[a-zA-Z_]+\\.[a-zA-Z_]+:[a-zA-Z_]+$",
                "description": "Formato Tryton: model.button:action"
              },
              {
                "type": "string",
                "pattern": "^zone_[a-zA-Z_/]+:[A-Z_]+$",
                "description": "Formato zona lógica: zone_domain/sub:VERB"
              },
              { "type": "null" }
            ]
          }
        }
      }
    }
  }
}
```

---

### A4. approval_workflow — Consistencia de approvers

**Decisión:** La validación de que `required_approvers <= len(approver_roles)` se realiza en **runtime de bAuth** (no en el JSON Schema), pero con rechazo 422 inmediato en el endpoint `PUT /api/v1/roltemplate/{id}` antes de persistir. El JSON Schema valida solo tipos y rangos.

**Razonamiento:** JSON Schema 2020-12 no permite comparar el valor de un campo con la longitud de un array en la misma instancia sin `$data` (que no es estándar). La validación cruzada es responsabilidad de la capa de aplicación (PrivilegeEngine.validate()). Esta decisión alinea con el patrón del corpus donde `Authentication_Framework.json §webSocketAccessControl.dynamicAccessControl.decisionEngine` usa `combiningAlgorithm: "denyOverrides"` — la denegación es determinista y temprana.

**Implementación:**

```go
// En bAuth PrivilegeEngine.validate()
func validateApprovalWorkflow(rt RolTemplate) error {
    aw := rt.ApprovalWorkflow
    if aw.RequiredApprovers > len(aw.ApproverRoles) {
        return fmt.Errorf("required_approvers (%d) excede la cantidad de approver_roles (%d)",
            aw.RequiredApprovers, len(aw.ApproverRoles))
    }
    return nil
}
```

---

### A5. metadata.region — RolTemplate vs UserTemplate

**Decisión:** `metadata.region` pertenece **exclusivamente al RolTemplate**. El UserTemplate **no tiene este campo** y no debe replicarlo. La región se hereda del RolTemplate asignado al usuario.

**Razonamiento:** El corpus (`EsrtructuraRolFinal.txt §metadata`) define `region: "NORTH"` y `territory_code: "VEN-NORTH-001"` en el RolTemplate. La estructura `EstructuraUserFinal.txt` no incluye estos campos en el usuario, sino que los hereda del rol activo. El documento `SBOS-BAUTH-CONCEPTUALIZACION-v4.0 §4` establece que el RolTemplate define "lo que PUEDE HACER un tipo de rol" incluyendo el alcance territorial.

**Regla en JSON Schema del RolTemplate:**

```json
{
  "properties": {
    "metadata": {
      "type": "object",
      "properties": {
        "region": {
          "type": "string",
          "description": "Código de región operativa. Herencia exclusiva del RolTemplate."
        },
        "territory_code": {
          "type": "string",
          "pattern": "^[A-Z]+-[A-Z]+-[0-9]+$"
        }
      }
    }
  }
}
```

---

## 3. Bloque B — REQ-1: bauth.toml Completo

### B1. Mecanismo de client_secret (Vault)

**Decisión:** Jerarquía de resolución de secretos:

1. **Primero:** `vault://secret/bauth/keycloak#client_secret` (Vault Agent Sidecar)
2. **Fallback:** Variable de entorno `BAUTH_KC_CLIENT_SECRET` inyectada por `bos` al arrancar el servicio
3. **Último recurso:** Archivo en `/run/secrets/bauth_kc_client_secret` montado por systemd credentials

**Razonamiento:** El corpus (`Authentication_Framework.json §authenticationCore.sanctumEnhanced.tokenManagement.security.keyRotation`) define rotación proactiva de claves cada 4 horas con `strategy: "proactive"`. Un mecanismo de resolución jerárquico permite rotación sin redeploy (Vault) manteniendo compatibilidad con entornos sin Vault (env vars).

**Fragmento bauth.toml de referencia:**

```toml
# ============================================================
# BAUTH CONFIGURATION — SKULL · SBOS
# Versión: 1.0.0
# NUNCA almacenar secretos en texto plano en este archivo.
# ============================================================

[metadata]
version             = "1.0.0"
environment         = "production"       # production|staging|development
log_level           = "info"             # debug|info|warn|error
log_format          = "json"

# ── KEYCLOAK ────────────────────────────────────────────────
[keycloak]
url                        = "https://auth.sbos.internal"
realm                      = "master"                         # realm de administración
client_id                  = "bauth-admin"
# Resolución jerárquica: Vault → env → /run/secrets
# client_secret = "vault://secret/bauth/keycloak#client_secret"
# Fallback automático a: $BAUTH_KC_CLIENT_SECRET
# Fallback final a:      /run/secrets/bauth_kc_client_secret
client_secret_source       = "vault"                          # vault|env|file
vault_path                 = "secret/bauth/keycloak"
vault_field                = "client_secret"
token_refresh_interval_s   = 240                              # 4 minutos (< 5 min KC default)
admin_api_timeout_ms        = 5000
admin_api_retry_count       = 3
admin_api_retry_backoff_ms  = [100, 500, 1000]

# ── TRYTON ──────────────────────────────────────────────────
[tryton]
url          = "http://tryton.sbos.internal:8000"
db           = "tryton_db"
user         = "admin"
# password_source = "vault"
# vault_path = "secret/bauth/tryton"
pool_size    = 10
timeout_ms   = 3000

# ── POSTGRESQL ──────────────────────────────────────────────
[postgres]
# dsn_source = "vault"
# vault_path = "secret/bauth/postgres"
dsn          = "postgres://bauth:${BAUTH_PG_PASSWORD}@localhost:5432/bauth_db?sslmode=require"
max_conns    = 20
min_conns    = 5
conn_timeout_s = 10

# ── REDIS ───────────────────────────────────────────────────
[redis]
enabled          = true                   # false = modo in-memory (solo desarrollo)
addr             = "localhost:6379"
password_source  = "vault"
vault_path       = "secret/bauth/redis"
db               = 0
cache_ttl_seconds = 30
max_entries      = 10000
tls_enabled      = true

# ── UNIX SOCKET (bhnexus) ────────────────────────────────────
[socket]
path             = "/run/bos/bauth.sock"
permissions      = "0660"
owner_group      = "bos"
request_timeout_ms = 1000
max_connections  = 100

# ── RECONCILE LOOP ───────────────────────────────────────────
[reconcile]
global_interval_seconds = 60             # override por realm en realm_config
min_interval_seconds    = 30             # no permitir reconcile más frecuente
drift_auto_correct      = true
drift_alert_severity    = "HIGH"         # LOW|MEDIUM|HIGH|CRITICAL

# ── VAULT ────────────────────────────────────────────────────
[vault]
enabled      = true
addr         = "https://vault.sbos.internal:8200"
# auth_method: kubernetes|approle|token
auth_method  = "kubernetes"
role         = "bauth"
mount_path   = "secret"
timeout_ms   = 2000

# ── WAZUH / ALERTAS ──────────────────────────────────────────
[alerts]
# Mecanismo: syslog (recomendado) | log_file | redis
mechanism    = "syslog"
syslog_addr  = "wazuh-manager.sbos.internal:514"
syslog_proto = "tcp"
log_file     = "/var/log/bos/bauth-alerts.log"  # fallback si syslog no disponible

# ── ASSUME TENANT CONTEXT ─────────────────────────────────────
[superuser]
admin_uuid          = ""                  # UUID del sbos-admin; vacío = sin superusuario
context_ttl_min     = 15                  # TTL mínimo (minutos)
context_ttl_max     = 120                 # TTL máximo (minutos); default 60
context_ttl_default = 60
break_glass_uuid    = ""                  # UUID del segundo sbos-admin (break-glass)
```

---

### B2. Múltiples realms — Arquitectura de instancias

**Decisión:** Una instancia de `bauth.service` por **host SBOS**. Un host puede gestionar múltiples realms (uno por empresa cliente). La separación de datos entre realms se garantiza mediante namespacing en PostgreSQL (`tenant_id` en todas las tablas) y prefijos de namespace en Redis (`realm:{realm_name}:user:{uuid}`).

**Razonamiento:** El corpus (`SBOS-008 §12 Provisioning de un realm nuevo`) describe que múltiples realms coexisten en el mismo servidor KC. Una instancia de bAuth por realm elevaría el costo operativo innecesariamente. El patrón de namespacing en Redis y PostgreSQL es suficiente para el aislamiento.

**Fragmento de configuración multi-realm:**

```toml
# Configuración por realm (overrides del global)
[[realm_config]]
realm_id              = "empresa-acme"
kc_realm              = "empresa-acme"
sync_interval_seconds = 45             # override del global de 60s
drift_auto_correct    = true

[[realm_config]]
realm_id              = "empresa-beta"
kc_realm              = "empresa-beta"
sync_interval_seconds = 120            # tenants de bajo tráfico → menos frecuente
drift_auto_correct    = false          # requiere aprobación manual
```

---

### B3. Reconcile loop — Configurabilidad

**Decisión:** El reconcile loop es **configurable por realm** con un mínimo global (`min_interval_seconds = 30`). El intervalo por defecto es 60s. El mínimo global previene sobrecarga en deployments multi-tenant densos.

---

### B4. Redis — Obligatoriedad

**Decisión:** Redis es **recomendado en producción**; modo in-memory (`redis.enabled = false`) está disponible para desarrollo y deployments de un solo nodo. En modo in-memory, el cache es volátil — los SAM-128 se pierden en restart.

**Trade-offs documentados:**

| Modo | Durabilidad | Escalabilidad | Consistencia multi-instancia |
|---|---|---|---|
| Redis | Alta | Alta | Sí |
| In-memory | Ninguna | Solo single-node | No |

---

## 4. Bloque C — REQ-3: Protocolo Unix Socket

### C1. Clientes autorizados

**Decisión:** El socket `/run/bos/bauth.sock` es consultado **exclusivamente por `bhnexus`**. Otros daemons (`bkernel`, `bcompass`) **no tienen acceso directo**. Si bkernel necesita información de identidad, consulta vía REST API de bAuth en el puerto interno (no por socket).

**Razonamiento:** El corpus (`SBOS-NEXUS-CONCEPTUALIZACION §4 Topología Invariable`) establece explícitamente: `banexus → bhnexus → bAuth` — nunca saltar bhnexus. Extender el socket a otros daemons rompe esta invariante y crea vectores de ataque lateral.

**Implementación — ACL del socket:**

```bash
# En bauth.service (systemd unit)
[Service]
RuntimeDirectory=bos
RuntimeDirectoryMode=0750
User=bauth
Group=bos
# Solo procesos del grupo 'bos' pueden acceder al socket
```

---

### C2. Framing de transporte

**Decisión:** **Length-prefix JSON** (4 bytes big-endian + payload JSON UTF-8). Formato Go estándar, sin dependencias externas, legible en debugging.

**Razonamiento:** El corpus define los tipos Go en `SBOS-BAUTH-CONCEPTUALIZACION-v4.0 §11` como structs JSON-serializable. El patrón `uint32 big-endian + JSON` es idiomático en Go y compatible con el parsing que bhnexus ya realiza para el protocolo WebSocket.

**Especificación de transporte:**

```
Frame format:
  [4 bytes: uint32 big-endian = longitud del payload en bytes]
  [N bytes: JSON payload UTF-8]

Timeout por request: 1000ms (configurable en socket.request_timeout_ms)
Timeout de conexión: 5000ms
Max payload size: 65536 bytes (64KB)
Max conexiones simultáneas: 100

Error codes (campo "error_code" en respuesta):
  AUTH_001 — user_id no encontrado
  AUTH_002 — RolTemplate no activo o vencido
  AUTH_003 — Dominio físico denegado (zona/horario)
  AUTH_004 — Dominio financiero denegado (límite/SoD)
  AUTH_005 — Biométrico no coincide
  AUTH_006 — Cache expirado (modo offline)
  SRV_001  — bAuth interno error
  SRV_002  — bAuth sobrecargado (circuit breaker abierto)
```

**Mensajes completos:**

```json
// Request (bhnexus → bAuth)
{
  "request_id": "uuid-v4",
  "user_id":    "550e8400-e29b-41d4-a716-446655440000",
  "node_id":    "Ventas-01",
  "query_type": "bitmask",
  "timestamp":  "2026-04-15T10:30:00.000Z"
}

// Response (bAuth → bhnexus) — granted
{
  "request_id": "uuid-v4",
  "granted":    true,
  "sam128":     "0x00000209000100520001001700010052",
  "bos_context": { "...": "..." },
  "ttl_seconds": 28800,
  "actuator_commands": [],
  "timestamp":  "2026-04-15T10:30:00.008Z"
}

// Response — denied
{
  "request_id":  "uuid-v4",
  "granted":     false,
  "error_code":  "AUTH_003",
  "reason":      "outside_schedule",
  "message":     "Acceso fuera de horario autorizado (08:00–18:00 LPZ)",
  "timestamp":   "2026-04-15T20:15:00.003Z"
}
```

---

### C3. Concurrencia en user_id

**Decisión:** **Deduplicación con singleflight**. Si dos solicitudes con el mismo `user_id` y `node_id` llegan simultáneamente, la segunda espera el resultado de la primera y recibe la misma respuesta. Si las solicitudes difieren en `node_id` o `query_type`, se procesan en paralelo.

**Razonamiento:** La operación de consulta a bAuth es **idempotente** para el mismo `(user_id, node_id)` en una ventana de tiempo corta. El patrón `singleflight` del stdlib de Go es la implementación correcta: elimina llamadas redundantes a bAuth sin introducir locks que degraden el rendimiento.

**Implementación:**

```go
import "golang.org/x/sync/singleflight"

type BAuthServer struct {
    sfGroup singleflight.Group
    // ...
}

func (s *BAuthServer) handleQuery(q AuthQuery) (*AuthResponse, error) {
    key := fmt.Sprintf("%s:%s:%s", q.UserID, q.NodeID, q.QueryType)
    result, err, _ := s.sfGroup.Do(key, func() (interface{}, error) {
        return s.resolveFromCacheOrDB(q)
    })
    if err != nil { return nil, err }
    return result.(*AuthResponse), nil
}
```

---

## 5. Bloque D — REQ-4: Contrato KC Admin API y Maven SPIs

### D1. Estrategia de compensación en sync_role()

**Decisión:** **Opción B** — Marcar `sync_status = 'ERROR'` con retry automático de Tryton. No se realiza rollback de KC.

**Razonamiento:** El corpus (`SBOS-008 §5 Cómo SBOS Auth Enforce programa Keycloak`) describe sincronización idempotente. Revertir KC produce una ventana de inconsistencia garantizada (usuarios en KC con rol viejo mientras bAuth intenta revertir). Marcar ERROR y reintentar Tryton es más seguro: KC queda en estado nuevo (correcto), Tryton eventualmente converge.

**Pseudocódigo de sync_role() con manejo de errores:**

```go
func (s *BAuthSyncer) SyncRole(roleID string) error {
    rt, err := s.db.GetRolTemplate(roleID)
    if err != nil { return err }

    // PASO 1: Validar (falla rápido antes de tocar KC o Tryton)
    if err := s.engine.Validate(rt); err != nil {
        return fmt.Errorf("validation failed: %w", err)
    }

    // PASO 2: Calcular SAM-128
    sam, err := s.engine.Calculate(rt)
    if err != nil { return err }

    // PASO 3: Sincronizar KC (si falla aquí, nada cambia)
    if err := s.kcSync.SyncCompositeRole(rt, sam); err != nil {
        s.db.SetSyncStatus(roleID, "ERROR", err.Error())
        return fmt.Errorf("KC sync failed: %w", err)
    }

    // PASO 4: Sincronizar Tryton (si falla, KC ya está actualizado)
    // NO hacemos rollback de KC — marcamos ERROR y reintentamos Tryton
    if err := s.trytonSync.SyncGroup(rt, sam); err != nil {
        s.db.SetSyncStatus(roleID, "ERROR_TRYTON_PENDING", err.Error())
        s.scheduler.ScheduleRetry(roleID, RetryTryton, backoffPolicy)
        // Alerta Wazuh MEDIUM — KC OK, Tryton pendiente
        s.alerts.Emit("tryton_sync_failed", roleID, wazuh.MEDIUM)
        return fmt.Errorf("Tryton sync failed (KC OK, retry scheduled): %w", err)
    }

    // PASO 5: Todo OK
    s.db.SetSyncStatus(roleID, "SYNCED", "")
    s.cache.Invalidate(roleID)
    s.nexus.PushPolicyUpdate(roleID)

    return nil
}
```

**Política de reintentos para Tryton:**

```
Intento 1: inmediato tras fallo
Intento 2: +30 segundos
Intento 3: +2 minutos
Intento 4: +10 minutos
Intento 5: +1 hora
> 5 intentos fallidos: alerta CRITICAL a Wazuh + notificación admin
```

---

### D2. Versión target de Keycloak

**Decisión:** **KC 26.x** como versión objetivo. Los SPIs se compilan contra KC 26.x (Email OTP nativo, Step-Up RFC 9470 mejorado, Passkeys). Se documenta el límite de compatibilidad mínimo como KC 21.x (step-up básico disponible desde esa versión).

**Razonamiento:** El corpus (`Policies_Authentication_Framework.json §modern_authentication_policies.webauthn_fido2`) define soporte para `biometric_passwordless` y `push_notification` que requieren las APIs de KC 26+. Además, `Authentication_Framework.json §federatedAuthentication.identityFederation.federationProtocols.openidConnect.version: "2.0"` requiere KC 26+ para OIDC 2.0 completo.

**Fragmento pom.xml base:**

```xml
<project>
  <groupId>bo.skull.sbos</groupId>
  <artifactId>bauth-spi</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>

  <properties>
    <keycloak.version>26.0.0</keycloak.version>
    <java.version>17</java.version>
  </properties>

  <dependencies>
    <dependency>
      <groupId>org.keycloak</groupId>
      <artifactId>keycloak-core</artifactId>
      <version>${keycloak.version}</version>
      <scope>provided</scope>
    </dependency>
    <dependency>
      <groupId>org.keycloak</groupId>
      <artifactId>keycloak-server-spi</artifactId>
      <version>${keycloak.version}</version>
      <scope>provided</scope>
    </dependency>
    <dependency>
      <groupId>org.keycloak</groupId>
      <artifactId>keycloak-server-spi-private</artifactId>
      <version>${keycloak.version}</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>

  <build>
    <plugins>
      <plugin>
        <groupId>org.apache.maven.plugins</groupId>
        <artifactId>maven-compiler-plugin</artifactId>
        <version>3.11.0</version>
        <configuration>
          <source>${java.version}</source>
          <target>${java.version}</target>
        </configuration>
      </plugin>
    </plugins>
  </build>
</project>
```

**Archivos de servicio META-INF requeridos:**

```
META-INF/services/org.keycloak.authentication.AuthenticatorFactory
  → bo.skull.sbos.keycloak.spi.SkbosGuardAuthenticatorFactory
  → bo.skull.sbos.keycloak.spi.SkbosGeoContextAuthenticatorFactory
  → bo.skull.sbos.keycloak.spi.SkbosFinancialPeriodAuthenticatorFactory
  → bo.skull.sbos.keycloak.spi.SkbosRoleValidityAuthenticatorFactory
  → bo.skull.sbos.keycloak.spi.SkbosStepUpConditionFactory
```

---

### D3. Despliegue de SPIs

**Decisión:** Despliegue **automatizado** como parte del flujo de provisioning del realm. El script `provision_realm.sh` (invocado por bAuth durante `onboard-tenant`) copia los JARs y ejecuta `kc.sh build`. No requiere `AssumeTenantContext` — es parte del setup inicial del servidor.

**Script de deployment:**

```bash
#!/bin/bash
# provision_spi.sh — despliega los SPIs de bAuth en Keycloak
# Ejecutado por bAuth durante realm provisioning

KC_HOME="/opt/keycloak"
BAUTH_SPI_JAR="/opt/bos/lib/bauth-spi-1.0.0.jar"
PROVIDERS_DIR="${KC_HOME}/providers"

set -euo pipefail

echo "[bAuth] Desplegando SPIs de bAuth en Keycloak..."

# 1. Verificar firma del JAR
sha256sum --check /opt/bos/lib/bauth-spi-1.0.0.jar.sha256 || {
    echo "[ERROR] Verificación de firma del JAR fallida"
    exit 1
}

# 2. Copiar JAR
cp "${BAUTH_SPI_JAR}" "${PROVIDERS_DIR}/"

# 3. Rebuild de KC (carga nuevos providers)
${KC_HOME}/bin/kc.sh build --optimized

# 4. Verificar que los providers fueron registrados
${KC_HOME}/bin/kc.sh show-config 2>/dev/null | grep -q "SkbosGuard" || {
    echo "[ERROR] SPIs no registrados tras build"
    exit 1
}

echo "[bAuth] SPIs desplegados exitosamente"
```

---

### D4. Authentication Flow por rol

**Decisión:** Cada rol usa una **copia local del flow base** con overrides específicos. No se usan referencias (links) al flow base.

**Razonamiento:** Las referencias en KC son frágiles — un cambio en el flow base afecta silenciosamente todos los roles que lo referencian. Las copias son más costosas en almacenamiento pero garantizan que un cambio en el flow de un rol no afecte otros. El corpus (`SBOS-008 §3`) confirma este patrón al describir `FLOW: RGV_001_browser_flow` como un flow con nombre canónico propio.

**Pseudocódigo sync_role() — creación de Authentication Flow:**

```go
func (s *KCSync) SyncAuthenticationFlow(rt RolTemplate, realm string) error {
    flowName := fmt.Sprintf("%s_browser_flow", rt.ID)
    
    // ¿Ya existe este flow?
    existing, err := s.api.GetFlowByAlias(realm, flowName)
    if err == nil && existing != nil {
        // Actualizar executions del flow existente
        return s.updateFlowExecutions(realm, existing.ID, rt)
    }
    
    // Crear copia del flow base "browser"
    baseFlow, err := s.api.GetFlowByAlias(realm, "browser")
    if err != nil { return err }
    
    newFlow, err := s.api.CopyFlow(realm, baseFlow.ID, flowName)
    if err != nil { return err }
    
    // Configurar executions según requiredMethods del RolTemplate
    return s.configureFlowExecutions(realm, newFlow.ID, rt)
}
```

---

## 6. Bloque E — REQ-5: Schema SQL bauth_db

### E1. Ubicación de templates biométricos

**Decisión:** Los templates biométricos (hashes) viven en **`bauth_db`**, base de datos dedicada de bAuth, **nunca en la base de datos del tenant**. El acceso está restringido al proceso `bauth` con credenciales propias.

**Razonamiento:** El corpus (`SBOS-BAUTH-CONCEPTUALIZACION-v4.0 §5`) ya ubica `bauth_biometric_templates` en el esquema de bAuth. La separación física es un requisito de cumplimiento RGPD (datos biométricos son categoría especial bajo Art. 9) y de la política `Authentication_Framework.json §dataProtection.dataClassification.sensitivityLevels.critical`.

---

### E2. bos_rol_template_history — WORM enforcement

**Decisión:** La tabla usa **BIGSERIAL con Row Security Policy** que prohíbe `UPDATE` y `DELETE`. Se usa PostgreSQL RLS (Row Level Security) en lugar de triggers para performance.

**Implementación:**

```sql
-- Tabla de historial inmutable
CREATE TABLE bos_rol_template_history (
    history_id    BIGSERIAL PRIMARY KEY,
    rol_id        TEXT        NOT NULL,
    version       TEXT        NOT NULL,
    template_snap JSONB       NOT NULL,
    changed_by    TEXT        NOT NULL,
    changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_reason TEXT,
    -- Hash de la entrada anterior para cadena de integridad
    prev_hash     TEXT,
    entry_hash    TEXT GENERATED ALWAYS AS (
        encode(sha256(
            (rol_id || version || changed_at::text || template_snap::text)::bytea
        ), 'hex')
    ) STORED
);

-- WORM: prohibir UPDATE y DELETE
CREATE OR REPLACE RULE no_update_history AS
    ON UPDATE TO bos_rol_template_history DO INSTEAD NOTHING;

CREATE OR REPLACE RULE no_delete_history AS
    ON DELETE TO bos_rol_template_history DO INSTEAD NOTHING;

-- Solo bauth puede INSERT
REVOKE ALL ON bos_rol_template_history FROM PUBLIC;
GRANT INSERT, SELECT ON bos_rol_template_history TO bauth;
```

---

### E3. bauth_sync_log — Ubicación

**Decisión:** `bauth_sync_log` vive en **`bauth_db`**. La tabla `bkernel_db.audit_events` recibe el evento de auditoría de alto nivel (quién cambió qué, cuándo), pero el log de sincronización técnico (intentos, errores, timestamps de cada paso) vive en bAuth para correlación interna.

**Schema:**

```sql
CREATE TABLE bauth_sync_log (
    id              BIGSERIAL PRIMARY KEY,
    rol_id          TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    sync_type       TEXT        NOT NULL,  -- FULL|KC_ONLY|TRYTON_ONLY|RETRY
    triggered_by    TEXT        NOT NULL,  -- ROLTEMPLATE_CHANGE|RECONCILE|MANUAL|STARTUP
    status          TEXT        NOT NULL,  -- PENDING|KC_SYNCED|SYNCED|ERROR|ERROR_TRYTON_PENDING
    kc_status       TEXT,                  -- OK|ERROR|SKIPPED
    tryton_status   TEXT,                  -- OK|ERROR|SKIPPED
    error_message   TEXT,
    retry_count     INTEGER     DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ,
    duration_ms     INTEGER GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (completed_at - started_at)) * 1000
    ) STORED
);

CREATE INDEX idx_bsl_rol_id    ON bauth_sync_log(rol_id, started_at DESC);
CREATE INDEX idx_bsl_status    ON bauth_sync_log(status) WHERE status IN ('ERROR', 'PENDING');
CREATE INDEX idx_bsl_next_retry ON bauth_sync_log(next_retry_at) WHERE next_retry_at IS NOT NULL;
```

---

### E4. empresa_id vs tenant_id en bos_user_template

**Decisión:** Mantener **ambas columnas** (`tenant_id` y `empresa_id`) con significados distintos.

- `tenant_id`: identifica el servidor SBOS (nivel de infraestructura, Capa 1 del SAM-128)
- `empresa_id`: identifica la empresa dentro del tenant, mapeado al realm KC (Capa 2, NIT de la empresa)

**Razonamiento:** El corpus (`SBOS-BAUTH-CONCEPTUALIZACION-v4.0 §9 Las 6 Capas`) distingue explícitamente TENANT (Capa 1) de EMPRESA (Capa 2). En el SBOS actual, un servidor puede hospedar múltiples empresas (multi-tenant). Si en el futuro cada empresa tiene su propio servidor, `empresa_id = tenant_id` y la columna se vuelve redundante — pero no es el caso hoy.

**Schema completo migrations/001_bauth_init.sql:**

```sql
-- ============================================================
-- bauth_db — Schema inicial
-- SKULL · SBOS · bAuth v1.0
-- Ejecutar como usuario: bauth
-- ============================================================

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- RolTemplates
CREATE TABLE bos_rol_template (
    id              TEXT        PRIMARY KEY,
    tenant_id       TEXT        NOT NULL,
    empresa_id      TEXT        NOT NULL,
    parent_id       TEXT        REFERENCES bos_rol_template(id),
    status          TEXT        NOT NULL DEFAULT 'DRAFT',
    version         TEXT        NOT NULL DEFAULT '1.0.0',
    sam128_lo       BIGINT,
    sam128_hi       BIGINT,
    sync_status     TEXT        NOT NULL DEFAULT 'PENDING',
    sync_error      TEXT,
    last_sync_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_by      TEXT        NOT NULL,
    template        JSONB       NOT NULL,
    CONSTRAINT chk_status CHECK (status IN ('DRAFT','REVIEW','ACTIVE','DEPRECATED','ARCHIVED')),
    CONSTRAINT chk_sync   CHECK (sync_status IN ('PENDING','SYNCING','SYNCED','ERROR','ERROR_TRYTON_PENDING','DRIFT'))
);

CREATE INDEX idx_brt_tenant_empresa ON bos_rol_template(tenant_id, empresa_id);
CREATE INDEX idx_brt_status         ON bos_rol_template(status);
CREATE INDEX idx_brt_parent         ON bos_rol_template(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_brt_template_gin   ON bos_rol_template USING GIN(template);

-- Historial inmutable
CREATE TABLE bos_rol_template_history (
    history_id    BIGSERIAL   PRIMARY KEY,
    rol_id        TEXT        NOT NULL,
    version       TEXT        NOT NULL,
    template_snap JSONB       NOT NULL,
    changed_by    TEXT        NOT NULL,
    changed_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    change_reason TEXT,
    prev_hash     TEXT,
    entry_hash    TEXT
);

CREATE OR REPLACE RULE no_update_history AS
    ON UPDATE TO bos_rol_template_history DO INSTEAD NOTHING;
CREATE OR REPLACE RULE no_delete_history AS
    ON DELETE TO bos_rol_template_history DO INSTEAD NOTHING;

-- UserTemplates
CREATE TABLE bos_user_template (
    uuid        TEXT        PRIMARY KEY,
    username    TEXT        NOT NULL,
    email       TEXT        NOT NULL,
    tenant_id   TEXT        NOT NULL,
    empresa_id  TEXT        NOT NULL,
    rol_id      TEXT        REFERENCES bos_rol_template(id),
    status      TEXT        NOT NULL DEFAULT 'ACTIVE',
    sync_status TEXT        NOT NULL DEFAULT 'PENDING',
    kc_user_id  TEXT,
    tryton_user_id INTEGER,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    template    JSONB       NOT NULL,
    CONSTRAINT chk_user_status CHECK (status IN ('ACTIVE','INACTIVE','SUSPENDED','TERMINATED')),
    UNIQUE (tenant_id, username)
);

CREATE INDEX idx_but_tenant   ON bos_user_template(tenant_id, empresa_id);
CREATE INDEX idx_but_rol      ON bos_user_template(rol_id);
CREATE INDEX idx_but_kc       ON bos_user_template(kc_user_id);

-- Templates biométricos (solo hashes — NUNCA raw biometric)
CREATE TABLE bauth_biometric_templates (
    id                BIGSERIAL   PRIMARY KEY,
    user_uuid         TEXT        NOT NULL REFERENCES bos_user_template(uuid),
    tenant_id         TEXT        NOT NULL,
    biometric_type    TEXT        NOT NULL,
    finger            SMALLINT,
    template_hash     BYTEA       NOT NULL,
    salt              BYTEA       NOT NULL,
    enrollment_policy TEXT        NOT NULL DEFAULT 'admin_only',
    liveness_verified BOOLEAN     NOT NULL DEFAULT false,
    admin_verified    BOOLEAN     NOT NULL DEFAULT false,
    enrolled_at       TIMESTAMPTZ,
    enrolled_by       TEXT,
    revoked_at        TIMESTAMPTZ,
    revoked_by        TEXT,
    CONSTRAINT chk_biometric_type CHECK (biometric_type IN ('fingerprint','face','iris','palm_vein')),
    CONSTRAINT chk_enrollment     CHECK (enrollment_policy IN ('admin_only','self_service','hybrid')),
    UNIQUE (user_uuid, biometric_type, COALESCE(finger, 0))
);

-- Log de sincronización
CREATE TABLE bauth_sync_log (
    id              BIGSERIAL   PRIMARY KEY,
    rol_id          TEXT        NOT NULL,
    tenant_id       TEXT        NOT NULL,
    sync_type       TEXT        NOT NULL,
    triggered_by    TEXT        NOT NULL,
    status          TEXT        NOT NULL,
    kc_status       TEXT,
    tryton_status   TEXT,
    error_message   TEXT,
    retry_count     INTEGER     DEFAULT 0,
    next_retry_at   TIMESTAMPTZ,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at    TIMESTAMPTZ
);

CREATE INDEX idx_bsl_rol_id     ON bauth_sync_log(rol_id, started_at DESC);
CREATE INDEX idx_bsl_pending    ON bauth_sync_log(next_retry_at) WHERE next_retry_at IS NOT NULL;

-- Contextos de superusuario (AsumeTenantContext)
CREATE TABLE bauth_superuser_contexts (
    context_id      TEXT        PRIMARY KEY DEFAULT gen_random_uuid()::text,
    admin_uuid      TEXT        NOT NULL,
    realm_id        TEXT        NOT NULL,
    reason          TEXT        NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at      TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    revoked_by      TEXT
);

CREATE INDEX idx_bsc_active ON bauth_superuser_contexts(expires_at) WHERE revoked_at IS NULL;
```

---

## 7. Bloque F — Decisiones que Afectan v4.0

### F1. Renombramientos VDIMask → PhysicalDomainMask

**Decisión:** **APROBADO para v4.0**. Los nombres `VDIMask` y `ERPMask` se reemplazan por `PhysicalDomainMask` y `LogicalDomainMask` respectivamente en todo el documento. Los claims JWT cambian de `bos_vdi_mask` / `bos_erp_mask` a `bos_physical_mask` / `bos_logical_mask`.

**Plan de migración JWT (sin breaking change):**

```
v0.9 Beta (periodo de transición):
  JWT incluye AMBOS claims:
    "bos_vdi_mask":      "0x..." (deprecado)
    "bos_physical_mask": "0x..." (nuevo canónico)

v1.0 GA:
  JWT incluye solo:
    "bos_physical_mask": "0x..."
    "bos_logical_mask":  "0x..."
    "bos_financial_mask": "0x..."
```

---

### F2. LogicalDomainEvaluator

**Decisión:** Incluir en v4.0 como **sección completa con interfaz Go y `zone_application_map.yaml` de referencia**. Marcado como `STATUS: PENDIENTE IMPLEMENTACIÓN v1.0` para indicar que el diseño está cerrado pero el código no existe aún.

**Sección a agregar en v4.0 §12bis:**

```go
// LogicalDomainEvaluator — Policy Decision Point para el dominio lógico
// STATUS: PENDIENTE IMPLEMENTACIÓN v1.0
// Custodio: equipo bAuth
type LogicalDomainEvaluator interface {
    // CanAccessZone — ¿puede este usuario operar en esta zona con este verbo?
    CanAccessZone(userID, nodeID string, zone BusinessZone, verb UniversalVerb) (bool, string, error)

    // GetActiveZones — zonas activas para el usuario (para construcción de menús)
    GetActiveZones(userID, nodeID string) ([]BusinessZone, error)

    // GetZoneApplications — apps que implementan esta zona
    GetZoneApplications(zone BusinessZone) ([]ApplicationEndpoint, error)
}

type BusinessZone string
const (
    ZoneContabilidad BusinessZone = "zone_contabilidad"
    ZoneRRHH         BusinessZone = "zone_rrhh"
    ZoneVentas       BusinessZone = "zone_ventas"
    ZoneSoporte      BusinessZone = "zone_soporte"
    ZoneAdminSistema BusinessZone = "zone_admin_sistema"
)

type UniversalVerb string
const (
    VerbRead      UniversalVerb = "READ"
    VerbWrite     UniversalVerb = "WRITE"
    VerbDelete    UniversalVerb = "DELETE"
    VerbApprove   UniversalVerb = "APPROVE"
    VerbExecute   UniversalVerb = "EXECUTE"
    VerbConfigure UniversalVerb = "CONFIGURE"
    VerbAudit     UniversalVerb = "AUDIT"
)
```

---

### F3. FinancialDomainMask

**Decisión:** **Incluir en v4.0** con el mapa de bits del documento `SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION §3.4`. Marcado como `STATUS: DISEÑO CERRADO — Evaluador pendiente v1.0`.

El `BitmaskBundle` en v4.0 queda como:

```go
type BitmaskBundle struct {
    PhysicalDomainMask  uint64 `json:"bos_physical_mask"`
    LogicalDomainMask   uint64 `json:"bos_logical_mask"`
    FinancialDomainMask uint64 `json:"bos_financial_mask,omitempty"`
}
```

---

### F4. TTL de AssumeTenantContext

**Decisión:**

| Parámetro | Valor | Razón |
|---|---|---|
| TTL mínimo | 15 minutos | Evitar contextos inútiles que saturan el audit log |
| TTL máximo | 4 horas | Operaciones de emergencia pueden durar hasta 4h; exceder requiere una nueva justificación |
| TTL por defecto | 60 minutos | Suficiente para la mayoría de operaciones administrativas |

**Referencia:** `Authentication_Framework.json §incidentResponse.incidentManagement.detectionEngine.classification.severityLevels.critical.responseTime: "immediate"` — las operaciones críticas no deben estar abiertas indefinidamente.

---

### F5. Integración con Wazuh

**Decisión:** **Syslog hacia Wazuh Manager** como mecanismo principal. Log file local como fallback. Redis como canal de eventos para bkernel (no para Wazuh directamente).

```
Ruta primaria:  bAuth → syslog TCP → Wazuh Manager (puerto 514)
Ruta fallback:  bAuth → /var/log/bos/bauth-alerts.log → Wazuh Agent (file monitor)
Canal bkernel:  bAuth → Redis pub/sub → bkernel → audit_events (no es canal Wazuh)
```

**Formato de mensaje syslog (CEF):**

```
CEF:0|SKULL|bAuth|1.0|AUTH_DRIFT|RolTemplate drift detectado|7|
  tenant=empresa-acme rol=RGV_001 domain=KC msg=composite_role_mismatch
```

---

## 8. Bloque G — Gaps Menores de Coherencia

### G1. GOV_NORMATIVE_AR y GOV_NORMATIVE_MX

**Decisión:** Agregar bits separados para cada jurisdicción soportada en v1.0. El bit `GOV_NORMATIVE_BO` (bit 110) ya existe. Se agregan:

```
Bit 110: GOV_NORMATIVE_BO  — cumplimiento Bolivia (SIAT)
Bit 111: GOV_NORMATIVE_PCI — cumplimiento PCI-DSS
Bit 112: GOV_NORMATIVE_AR  — cumplimiento Argentina (AFIP)  ← NUEVO
Bit 113: GOV_NORMATIVE_MX  — cumplimiento México (SAT)       ← NUEVO
Bits 114–127: GOV_CUSTOM    — reservados / definibles por tenant
```

**Nota:** Esto desplaza `GOV_IS_SUPERUSER` al bit 128, que excede los 128 bits del SAM-128 actual. La solución es reorganizar Q4 en la próxima versión del mapa de bits, o usar `GOV_CUSTOM` para las nuevas jurisdicciones hasta entonces.

**Solución inmediata para v1.0:** Usar un campo contextual `bos_governance.jurisdiction_codes: ["BO", "SIAT"]` en el JWT en lugar de bits adicionales. Los bits de jurisdicción se añaden en v1.5 con la reorganización de Q4.

---

### G2. Jurisdiction en JWT — Por tenant o por usuario

**Decisión:** `jurisdiction` proviene del **seed file del tenant** y es el mismo para todos los usuarios de ese tenant. No se permite override por usuario individual en v1.0. Si un empleado extranjero requiere jurisdicción diferente, se modela como un campo informativo en `UserTemplate.professional_info`, no como un control de seguridad.

**Razonamiento:** La jurisdicción determina qué normativa fiscal y de retención de logs aplica. Esta es una propiedad de la **empresa**, no del empleado. Permitir override por usuario introduciría inconsistencias regulatorias.

---

### G3. Clave HMAC para QR Dinámico

**Decisión:** **Una clave HMAC por tenant** almacenada en Vault. Todos los usuarios del tenant comparten la clave del tenant. La rotación es cada 90 días (alineado con `Authentication_Framework.json §cryptographyServices.keyManagement.keyStorage.rotationPolicies.symmetric.aes.interval: "90d"`).

**Justificación de no usar clave por usuario:** Una clave por usuario requeriría N accesos a Vault por generación de QR (uno por usuario), degradando el rendimiento y creando complejidad operativa sin beneficio de seguridad proporcional. La unicidad del QR está garantizada por el `user_uuid` en el payload, no por la clave.

---

### G4. Break-glass para AssumeTenantContext

**Decisión:** Siempre debe existir un **segundo `sbos-admin` registrado** (`break_glass_uuid` en `bauth.toml`). Si el admin principal no está disponible, el break-glass puede asumir el contexto sin aprobación del primero, pero con notificación automática al primero (email/SMS) y alerta CRITICAL en Wazuh.

**Política:**

```
Situación normal:    admin_uuid asume contexto → alerta HIGH
Situación break-glass: break_glass_uuid asume contexto → alerta CRITICAL + notificación a admin_uuid
Situación sin break-glass: operación bloqueada hasta que admin_uuid esté disponible
```

**No existe override automático sin human approval** — el SBOS no tiene un bypass de emergencia no supervisado.

---

### G5. SMTP para onboarding — Dónde se configura

**Decisión:** El servidor SMTP es configurado en **Keycloak** (sección "Email" del realm), no en bAuth. bAuth no tiene responsabilidad de envío de emails. Cuando bAuth crea un usuario en KC durante el onboarding, KC envía el email de activación usando su propia configuración SMTP del realm.

**Flujo:**

```
bAuth → KC Admin API: POST /admin/realms/{realm}/users
  { "enabled": true, "email": "...", ... }

bAuth → KC Admin API: PUT /admin/realms/{realm}/users/{id}/execute-actions-email
  { "requiredActions": ["CONFIGURE_TOTP", "UPDATE_PASSWORD"] }

KC → SMTP (configurado en el realm) → email al usuario
```

**Configuración SMTP por realm** se realiza durante el provisioning en `provision_realm.sh`:

```bash
# Configurar SMTP del realm
curl -X PUT "${KC_URL}/admin/realms/${REALM}/smtp" \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "host": "smtp.sbos.internal",
    "port": "587",
    "auth": true,
    "user": "bos-noreply@sbos.internal",
    "password": "${SMTP_PASSWORD}",
    "ssl": false,
    "starttls": true,
    "from": "noreply@sbos.internal",
    "fromDisplayName": "SBOS Identity"
  }'
```

---

## 9. Plan de Acción y Orden de Ejecución

### Sesión A — Artefactos de configuración y protocolo (REQ-1, REQ-2, REQ-3)

**Duración estimada: 1–2 días**

| Tarea | Archivo a crear/modificar | Dependencias |
|---|---|---|
| `bauth.toml` de referencia completo | `/etc/bos/bauth.toml.reference` | Ninguna |
| JSON Schema `roltemplate_schema.json` | `/opt/bos/schema/roltemplate_schema.json` | A1–A5 aprobadas (✅ en este doc) |
| Especificación del socket `/run/bos/bauth.sock` | `SBOS-008 §11 bis` | C1–C3 aprobadas (✅ en este doc) |
| Implementar `bitmask_constants.go` con `BitmaskBundle v3` | `pkg/bitmask/constants.go` | F1, F3 aprobadas |

### Sesión B — Contrato KC y Maven SPIs (REQ-4)

**Duración estimada: 3–5 días**

| Tarea | Archivo a crear/modificar | Dependencias |
|---|---|---|
| `pom.xml` del proyecto Maven `bauth-spi/` | `bauth-spi/pom.xml` | D2 aprobada (KC 26.x) |
| Implementar `SkbosGuardAuthenticator.java` | `bauth-spi/src/...` | REQ-2 (schema para validar) |
| Implementar los otros 4 SPIs | `bauth-spi/src/...` | Código base en SBOS-008 §4 |
| `provision_spi.sh` | `scripts/provision_spi.sh` | D3 aprobada |
| Pseudocódigo `sync_role()` exhaustivo | `SBOS-008 §5 actualizado` | D1, D4 aprobadas |

### Sesión C — Schema SQL (REQ-5)

**Duración estimada: 1 día**

| Tarea | Archivo a crear/modificar | Dependencias |
|---|---|---|
| `migrations/001_bauth_init.sql` | `db/migrations/001_bauth_init.sql` | E1–E4 aprobadas (✅ en este doc) |
| `migrations/002_fix_validity_types.sql` | `db/migrations/002_fix_validity_types.sql` | A1 aprobada |

### Actualización de SBOS-BAUTH-CONCEPTUALIZACION-v4_0.md

**Tras las 3 sesiones**, actualizar el documento principal:

| Sección | Cambio |
|---|---|
| §4 BitmaskBundle | Agregar `FinancialDomainMask`, renombrar VDI→Physical, ERP→Logical |
| §5 Schema PostgreSQL | Reemplazar tablas parciales con el schema completo de REQ-5 |
| §8 SAM-128 §8.1 | Agregar bits GOV_NORMATIVE_AR/MX, documentar solución temporal con JWT claim |
| §11 Interface bAuth | Agregar spec del socket (framing, error codes) |
| §12 bis (nuevo) | LogicalDomainEvaluator — interfaz Go + zone_application_map.yaml |
| §16 AssumeTenantContext | Agregar TTL min/max/default + política break-glass |
| §19 Pendientes | Cerrar todos los pendientes con referencias a este documento |

---

## 10. Decision Log Consolidado

| # | Pregunta | Decisión | Razonamiento clave | Impacto | Estado |
|---|---|---|---|---|---|
| A1 | end_date null en FIXED | Permitido; schema exige end_date solo en FIXED explícito | Roles permanentes son caso de uso válido | Migración de tipos en DB | ✅ Cerrado |
| A2 | limit_tier rango | Estricto 0–5 en schema | SAM-128 tiene 4 bits para LIMIT_TIER | Ninguno | ✅ Cerrado |
| A3 | sod_cannot_also formato | Soportar ambos formatos (model.button y zone:VERB) | Migración gradual sin breaking change | Regex de validación doble | ✅ Cerrado |
| A4 | approval_workflow coherencia | Validar en runtime (422 temprano), no en schema | JSON Schema no soporta cross-field length | Implementar en PrivilegeEngine | ✅ Cerrado |
| A5 | metadata.region ubicación | Solo en RolTemplate | UserTemplate hereda del rol asignado | Documentar en schema | ✅ Cerrado |
| B1 | client_secret Vault | Vault → env → /run/secrets (jerarquía) | Rotación sin redeploy | Vault Agent requerido en prod | ✅ Cerrado |
| B2 | Multi-realm | Una instancia bAuth, namespacing por tenant_id | Costo operativo vs aislamiento | Redis namespace, PG tenant_id | ✅ Cerrado |
| B3 | Reconcile configurable | Por realm, mínimo global 30s | Flexibilidad sin sobrecarga | realm_config en toml | ✅ Cerrado |
| B4 | Redis obligatorio | Recomendado en prod, in-memory en dev | Trade-off durabilidad/complejidad | Flag enable_redis | ✅ Cerrado |
| C1 | Socket clientes | Solo bhnexus | Topología invariable del SBOS | ACL systemd | ✅ Cerrado |
| C2 | Framing socket | Length-prefix 4B BE + JSON | Idiomático Go, sin deps | Spec documentada | ✅ Cerrado |
| C3 | Concurrencia user_id | Singleflight (deduplicación) | Idempotente, O(0) overhead | golang.org/x/sync | ✅ Cerrado |
| D1 | Compensación sync fallo | Opción B: marcar ERROR, retry Tryton | Evitar ventana KC inconsistente | Retry scheduler | ✅ Cerrado |
| D2 | KC versión target | KC 26.x | Email OTP nativo, OIDC 2.0 | pom.xml deps | ✅ Cerrado |
| D3 | SPIs despliegue | Automatizado en provisioning | Sin intervención manual | provision_spi.sh | ✅ Cerrado |
| D4 | Auth Flow por rol | Copia local con overrides | Aislamiento de cambios entre roles | Mayor almacenamiento KC | ✅ Cerrado |
| E1 | Biometría ubicación | bauth_db exclusivamente | RGPD Art. 9, cumplimiento | Acceso restringido a bauth | ✅ Cerrado |
| E2 | WORM historial | BIGSERIAL + RLS Rules NO UPDATE/DELETE | Performance sobre triggers | Reglas PG explícitas | ✅ Cerrado |
| E3 | sync_log ubicación | bauth_db | Correlación interna de bAuth | Schema separado de bkernel | ✅ Cerrado |
| E4 | empresa_id vs tenant_id | Mantener ambas columnas | Capa 1 vs Capa 2 SAM-128 son distintas | Normalización futura si 1:1 | ✅ Cerrado |
| F1 | Renombrar VDI/ERP masks | APROBADO — Physical/Logical | Abstracción correcta del dominio | Migración JWT v0.9→v1.0 | ✅ Cerrado |
| F2 | LogicalDomainEvaluator | Sección completa en v4.0, pendiente impl | Diseño cerrado, código abierto | Nueva sección §12bis | ✅ Cerrado |
| F3 | FinancialDomainMask | Incluir en v4.0 | Dominio sin máscara es un gap crítico | BitmaskBundle v3 | ✅ Cerrado |
| F4 | TTL AssumeTenantContext | Min 15min, Max 4h, Default 60min | Operaciones criticas < 4h | Configurable en toml | ✅ Cerrado |
| F5 | Wazuh integración | Syslog TCP primario, log file fallback | Estándar SIEM, sin deps adicionales | Configurar syslog_addr | ✅ Cerrado |
| G1 | GOV_NORMATIVE AR/MX bits | JWT claim temporal, bits en v1.5 | SAM-128 Q4 necesita reorganización | zone_compliance.jurisdiction_codes | ✅ Cerrado |
| G2 | Jurisdiction por usuario | Solo por tenant, no override por usuario | Jurisdicción = propiedad de la empresa | Documentar en UserTemplate | ✅ Cerrado |
| G3 | HMAC clave por tenant | Una clave por tenant en Vault | Performance + seguridad suficiente | Vault rotation 90d | ✅ Cerrado |
| G4 | Break-glass | Segundo sbos-admin obligatorio | No existe bypass no supervisado | break_glass_uuid en toml | ✅ Cerrado |
| G5 | SMTP configuración | KC realm SMTP, no bAuth | Separación de responsabilidades | provision_realm.sh | ✅ Cerrado |

---

## 11. Glosario

| Término | Definición |
|---|---|
| **ACR** | Authentication Context Reference. Nivel de seguridad de la autenticación. |
| **AND NOT** | Operación bitwise `A &^ B` en Go. Implementa herencia H-RBAC y revocación. **Nunca NAND.** |
| **BitmaskBundle** | Struct Go `{PhysicalDomainMask, LogicalDomainMask, FinancialDomainMask uint64}`. Reemplaza bos_bitmask único. |
| **Break-glass** | Mecanismo de acceso de emergencia ante ausencia del administrador principal. |
| **Button Rule** | Regla en Tryton (`ir.model.button`) con condición PYSON. Generada automáticamente por bAuth. |
| **PrivilegeEngine** | Motor algebraico de bAuth que calcula el SAM-128 desde el RolTemplate con operaciones bitwise. |
| **RolTemplate** | Contrato técnico y organizacional de un tipo de rol. Fuente de verdad única de identidad en el SBOS. |
| **SAM-128** | Sovereign Authority Matrix. Registro de 128 bits (2×uint64) evaluable en O(1) por banexus. |
| **Singleflight** | Patrón Go para deduplicar solicitudes concurrentes idénticas. Librería `golang.org/x/sync/singleflight`. |
| **SoD** | Separation of Duties. Nadie puede ejecutar de punta a punta una operación financiera crítica. |
| **WORM** | Write Once Read Many. Política de inmutabilidad para tablas de historial y auditoría. |
| **zone_application_map** | Archivo YAML que mapea zonas de negocio (ej: `zone_contabilidad`) a las apps que las implementan (Tryton, Superset, etc.). |

---

*SKULL · SBOS · SBOS-BAUTH-DECISIONES-ARQUITECTURA · v1.0 · Abril 2026*
*Complemento para: SBOS-BAUTH-CONCEPTUALIZACION-v4_0.md*
*Todas las decisiones A1–G5 cerradas. Listas para incorporar en v4.0.*
*Estándares: NIST SP 800-63B/C · ISO/IEC 27001:2022 · PCI-DSS v4.0 · RGPD Art. 9 · ANSI/INCITS 359-2004 H-RBAC · RFC 9470 Step-Up*
