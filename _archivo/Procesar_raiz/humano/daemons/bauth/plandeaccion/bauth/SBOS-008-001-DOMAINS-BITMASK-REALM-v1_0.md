# SBOS-008-001
## Anexo: Dominios de Soberanía, BitMask, Plugin KC y Ciclo de Vida del Realm
### Especificación de Nivel de Código para el Auth Enforce

### SKULL · SBOS — Sovereign Business Operating System
### v1.0 · Marzo 2026 · BitMask Dual Jun 2026

---

**Código:** SBOS-008-001
**Complementa:** SBOS-008-ROLFRAMEWORK-v1_0.md, SBOS-009, SBOS-019, SBOS-020, SBOS-MP01
**Integra:** SBOS-MP01 PARTE A (Ciclo de Vida del Realm)
**Propósito:** Completar bauth al NIVEL 5 con los 3 dominios de soberanía, formato BitMask, plugin Keycloak, y flujos de sincronización.

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** El modelo BitMask de este documento ha sido reemplazado. El diseño correcto es el **BitMask Dual**: BitMask Átomo (64-bit label encoding para identificar) + Rol BitMask (N-bit one-hot encoding para combinar roles). Las referencias a SAM-128, "2 capas", "7×64 bits", "BitmaskBundle" o "capa 1/capa 2" son del modelo anterior. **Fuentes de verdad actuales:** `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md` (especificación + DDL), `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7 (arquitectura de motores), `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1 (D12 blockchain).

## 1. Los Tres Dominios de Soberanía

El Auth Enforce opera en tres dominios simultáneos. Un cambio en el RolTemplate actualiza los tres dominios en menos de 5 segundos de forma atómica.

### 1.1 Dominio Lógico

Controla acceso a recursos digitales: redes, dispositivos, aplicaciones, niveles de aseguramiento (LoA).

```yaml
# Dentro del RolTemplate
logical:
  allowed_networks: ["10.0.0.0/24", "192.168.1.0/24"]
  allowed_devices: ["registered"]     # registered | any | managed_only
  level_of_assurance: 2               # 1=password, 2=MFA, 3=MFA+biometric
  allowed_apps:
    - app: "tryton"
      permissions: ["sale.sale:read,write", "party.party:read"]
    - app: "orangehrm"
      permissions: ["portal:read"]
  session_max_minutes: 480            # 8 horas
  concurrent_sessions: 1             # 1 = no permite sesiones paralelas
```

### 1.2 Dominio Físico

Controla acceso a espacios y recursos físicos: zonas, horarios, hardware de proximidad.

```yaml
physical:
  allowed_zones:
    - zone_id: "ZONE-VENTAS"
      name: "Piso de Ventas"
      access_points: ["AP-PUERTA-01", "AP-PUERTA-02"]
    - zone_id: "ZONE-ALMACEN"
      name: "Almacén"
      access_points: ["AP-ALMACEN-01"]
  schedule:
    days: ["mon", "tue", "wed", "thu", "fri"]
    time_start: "08:00"
    time_end: "18:00"
    timezone: "America/La_Paz"
  proximity_required: false           # true = requiere proximidad NFC/BLE
  max_failed_physical_attempts: 3     # bloqueo tras 3 intentos fallidos
```

### 1.3 Dominio Financiero

Controla límites transaccionales y separación de deberes (SoD) para operaciones de valor.

```yaml
financial:
  daily_transaction_limit: 50000      # BOB
  monthly_transaction_limit: 500000   # BOB
  single_transaction_limit: 10000     # BOB — requiere aprobación si supera
  sod_rules:                          # Separation of Duties
    - action: "approve_purchase_order"
      cannot_also: "create_purchase_order"
    - action: "approve_payment"
      cannot_also: "create_payment"
  requires_dual_approval_above: 25000 # BOB — dos firmantes requeridos
  currency: "BOB"
```

### 1.4 Evaluación Combinada

Cuando un usuario solicita acceso, bauth evalúa los tres dominios en paralelo. TODOS deben aprobar:

```
Solicitud de acceso
  │
  ├── Dominio Lógico: ¿red autorizada? ¿dispositivo registrado? ¿LoA suficiente? ¿app permitida?
  │     └── FAIL → deny: "network_not_allowed" | "device_not_registered" | "loa_insufficient"
  │
  ├── Dominio Físico: ¿zona autorizada? ¿dentro de horario? ¿proximidad OK?
  │     └── FAIL → deny: "zone_denied" | "outside_schedule" | "proximity_required"
  │
  ├── Dominio Financiero: ¿dentro de límite? ¿SoD cumplido?
  │     └── FAIL → deny: "limit_exceeded" | "sod_violation"
  │
  └── TODOS OK → GRANT (generar BitMask)
```

---

## 2. Formato BitMask (64 bits)

La BitMask es un entero de 64 bits donde cada bit representa un privilegio específico. El bhnexus la empaqueta y envía a los banexus para decisiones de baja latencia sin consultar al servidor.

### 2.1 Mapa de Bits

```
Bit  0: SESSION_VALID          — sesión activa y autenticada
Bit  1: SHELL_UNLOCK           — desbloquear shell de Fedora
Bit  2: APP_TRYTON             — acceso a Tryton
Bit  3: APP_ORANGEHRM          — acceso a OrangeHRM
Bit  4: APP_SALEOR             — acceso a Saleor
Bit  5: DRAWER_OPEN            — activar relé cajón de dinero
Bit  6: DOOR_ZONE_A            — abrir puertas Zona A
Bit  7: DOOR_ZONE_B            — abrir puertas Zona B
Bit  8: DOOR_ZONE_C            — abrir puertas Zona C (restringida)
Bit  9: PRINT_ALLOWED          — imprimir documentos
Bit 10: USB_STORAGE            — acceso a dispositivos USB de almacenamiento
Bit 11: NETWORK_EXTERNAL       — acceso a internet externo
Bit 12: VPN_ACCESS             — acceso a VPN corporativa
Bit 13: ADMIN_PANEL            — acceso a panel de administración
Bit 14: FINANCIAL_APPROVE      — aprobar transacciones financieras
Bit 15: FINANCIAL_CREATE       — crear transacciones financieras
Bit 16: INVENTORY_WRITE        — modificar inventario
Bit 17: INVENTORY_READ         — consultar inventario
Bit 18: HR_WRITE               — modificar datos de RRHH
Bit 19: HR_READ                — consultar datos de RRHH
Bit 20: REPORT_GENERATE        — generar reportes
Bit 21: REPORT_EXPORT          — exportar reportes
Bit 22: BACKUP_TRIGGER         — disparar backup manual
Bit 23: SYSTEM_CONFIG          — modificar configuración del sistema
Bits 24-31: RESERVED           — reservados para extensión del dominio lógico
Bits 32-47: RESERVED           — reservados para extensión del dominio físico
Bits 48-63: CUSTOM             — definibles por cliente en RolTemplate
```

### 2.2 Ejemplo de BitMask para un Vendedor

```
Rol: Vendedor de Tienda
BitMask: 0x000000000003E627

Bit  0: 1  SESSION_VALID
Bit  1: 1  SHELL_UNLOCK
Bit  2: 1  APP_TRYTON (solo lectura — granularidad en KC)
Bit  5: 1  DRAWER_OPEN
Bit  6: 1  DOOR_ZONE_A
Bit  9: 1  PRINT_ALLOWED
Bit 13: 0  ADMIN_PANEL (no)
Bit 17: 1  INVENTORY_READ
```

### 2.3 Operaciones sobre BitMask

```go
// En bhnexus (Go)
func HasPermission(mask uint64, bit int) bool {
    return (mask & (1 << bit)) != 0
}

func GrantBit(mask uint64, bit int) uint64 {
    return mask | (1 << bit)
}

func RevokeBit(mask uint64, bit int) uint64 {
    return mask &^ (1 << bit)
}

// Ejemplo: verificar si puede abrir cajón
if HasPermission(userMask, 5) { // DRAWER_OPEN
    sendActuatorCommand("OPEN_RELAY", nodeId)
}
```

---

## 3. Plugin Keycloak: rolframework_sync

### 3.1 Tipo de SPI

El plugin es un **Authentication SPI** de Keycloak que se ejecuta durante el flujo de autenticación, DESPUÉS de que el usuario se autentica pero ANTES de que el token se emita.

### 3.2 Flujo de ejecución

```
Usuario ingresa credenciales
  │
  ▼
Keycloak: Autenticación estándar (username/password + MFA si aplica)
  │
  ▼
KC Authentication Flow → rolframework_sync execution
  │
  ├── 1. Leer RolTemplate del usuario desde atributos del grupo KC
  ├── 2. Evaluar requiredMethods del rol:
  │       ¿El nivel de autenticación actual cumple el LoA requerido?
  │       ¿El dispositivo está en la lista de allowed_devices?
  │       ¿La IP está en allowed_networks?
  │
  ├── 3. SI NO CUMPLE → AuthenticationFlowException
  │       → Token NO se emite
  │       → Usuario recibe error contextual: "Se requiere MFA para este rol"
  │
  ├── 4. SI CUMPLE → Enriquecer token con claims bos_*:
  │       bos_bitmask: "0x000000000003E627"
  │       bos_domains: ["logical", "physical", "financial"]
  │       bos_zone_allowed: ["ZONE-VENTAS"]
  │       bos_financial_limit: 50000
  │       bos_schedule: {"days":["mon-fri"],"start":"08:00","end":"18:00"}
  │
  └── 5. Token emitido con claims SBOS en el JWT
```

### 3.3 Claims SBOS en el JWT

```json
{
  "sub": "uuid-user",
  "realm_access": { "roles": ["vendedor"] },
  "bos_bitmask": "0x000000000003E627",
  "bos_domains": {
    "logical": { "loa": 2, "apps": ["tryton", "saleor"] },
    "physical": { "zones": ["ZONE-VENTAS"], "schedule": "08:00-18:00" },
    "financial": { "daily_limit": 50000, "sod": ["create_sale"] }
  },
  "bos_node_id": "Ventas-01",
  "bos_template_version": "1.3.2"
}
```

---

## 4. Sincronización Atómica KC ↔ Tryton

### 4.1 Flujo de sincronización cuando se modifica un RolTemplate

```
Admin modifica RolTemplate en Core UI
  │
  ▼
bauth recibe evento via API REST
  │
  ▼
PASO 1: Validar RolTemplate (schema, SoD, herencia)
  │
  ▼
PASO 2: Sincronizar a Keycloak
  │  ├── Actualizar grupo KC con atributos del template
  │  ├── Actualizar Authentication Flow si requiredMethods cambió
  │  └── Verificar: GET /admin/realms/{realm}/groups/{group_id}
  │
  ▼
PASO 3: Sincronizar a Tryton
  │  ├── Actualizar reglas de acceso a campos (ir.rule)
  │  ├── Actualizar permisos de modelo (ir.model.access)
  │  └── Verificar: SQL query en ir_model_access
  │
  ▼
PASO 4: Registrar sync en bauth_sync_log
  │
  ▼
PASO 5: Emitir evento via Redis
  │  └── bkernel:events → {"type":"roltemplate_synced","id":"RGV_001"}
  │
  ▼
Tiempo total objetivo: < 5 segundos
```

### 4.2 Drift Detection

bauth ejecuta un check de drift cada 60 segundos:

```
RECONCILE LOOP (cada 60s):
  │
  Para cada RolTemplate activo:
  │
  ├── Leer estado declarado (RolTemplate YAML)
  ├── Leer estado real en KC (Admin API)
  ├── Leer estado real en Tryton (SQL)
  │
  ├── Comparar:
  │   ├── KC group attributes == template.logical?
  │   ├── KC auth flow == template.requiredMethods?
  │   ├── Tryton ir.rule == template.logical.apps.permissions?
  │   └── Tryton ir_model_access == template permisos por modelo?
  │
  ├── SI HAY DRIFT:
  │   ├── Log: "DRIFT detected: RolTemplate RGV_001, KC group missing attribute X"
  │   ├── Auto-corrección: re-sincronizar el template
  │   ├── Emitir evento: roltemplate_drift_corrected
  │   └── Si auto-corrección falla → alerta crítica al admin
  │
  └── SI NO HAY DRIFT: next template
```

---

## 5. Ciclo de Vida del Realm (integración SBOS-MP01 PARTE A)

### 5.1 Alta de tenant

```
Saga "onboard-tenant":
  Paso 1: Crear realm en Keycloak via Admin API
          Compensación: DELETE realm
  Paso 2: Configurar 5 SPIs custom en el realm nuevo
          Compensación: (incluido en DELETE realm)
  Paso 3: Crear usuarios iniciales (admin + service accounts)
          Compensación: DELETE usuarios
  Paso 4: Desplegar fichas contratadas en namespace K8s
          Compensación: DELETE namespace
  Paso 5: Crear BD del tenant en PostgreSQL
          Compensación: DROP DATABASE
  Paso 6: Actualizar .sbos_state.json
          Compensación: Revertir estado
  Paso 7: Emitir evento WAL "tenant.onboarded"
```

### 5.2 Suspensión temporal

```bash
# Deshabilitar realm (login bloqueado, datos conservados)
bauth tenant suspend <realm_name>
# Internamente: PUT /admin/realms/{realm} {"enabled": false}
# JWTs activos expiran en 5 minutos
```

### 5.3 Baja definitiva

```
SEMANA -2: Notificación + export de datos al cliente
DÍA 0:    Deshabilitar realm
DÍA 1:    Eliminar namespace K8s + realm KC + BD PostgreSQL
RETENCIÓN: Logs de auditoría según jurisdicción (BO:10 años, AR:10 años, MX:5 años)
```

---

## 6. Delegación Temporal con Vigencia

```yaml
# En UserTemplate
delegations:
  - delegated_to: "user-uuid-maria"
    delegated_from: "user-uuid-gerente"
    role_template: "RGV_001"
    reason: "Vacaciones del gerente"
    valid_from: "2026-03-15T00:00:00Z"
    valid_until: "2026-03-30T23:59:59Z"
    auto_revoke: true                  # bauth revoca automáticamente al expirar
    requires_approval: true            # segundo admin debe aprobar la delegación
    approved_by: "admin-uuid"
    approved_at: "2026-03-14T15:00:00Z"
```

bauth verifica vigencia en cada evaluación de acceso. Si `valid_until` ha pasado y `auto_revoke: true`, la delegación se revoca automáticamente y se emite evento `delegation_expired`.

---

## 7. Presentación de Identidad Física

### 7.1 QR Dinámico

```
Generación:
  bauth genera QR con: user_id + timestamp + HMAC-SHA256(secret)
  QR válido por 30 segundos (configurable)
  El QR codifica: "sbos://auth/{user_id}/{timestamp}/{hmac}"

Validación:
  banexus captura QR del lector USB
  banexus envía a bhnexus: {"type":"qr","data":"sbos://auth/..."}
  bhnexus extrae user_id + timestamp
  bhnexus verifica: timestamp < 30s ago AND HMAC válido
  bhnexus consulta bauth para BitMask
```

### 7.2 NFC/RFID

```
El tag NFC contiene: user_id cifrado con AES-256-GCM
Clave de cifrado almacenada en Vault, rotada cada 90 días
banexus lee tag → envía payload cifrado a bhnexus
bhnexus descifra con clave de Vault → obtiene user_id
bhnexus consulta bauth para BitMask
```

### 7.3 Biométrico (huella)

```
El lector biométrico genera template hash local
banexus envía hash a bhnexus (NUNCA el raw biometric)
bhnexus consulta bauth: match template contra UserTemplate.biometric_hash
Si match → generar BitMask
bhnexus NUNCA almacena templates biométricos — son transitorios
```

---

## 8. Registro de Cambios

### v1.0 — Marzo 2026

Documento nuevo. Integra los 3 dominios de soberanía (lógico/físico/financiero) del compendio del arquitecto, formato completo de BitMask de 64 bits con mapa de bits, plugin rolframework_sync para Keycloak con flujo de claims JWT, sincronización atómica KC↔Tryton con drift detection, ciclo de vida del realm (integra SBOS-MP01 PARTE A), delegación temporal con vigencia, y presentación de identidad física (QR/NFC/biométrico).

---

*SKULL · SBOS · SBOS-008-001 · Anexo 001 · v1.0 · Marzo 2026*

> **Referencias:** NIST SP 800-207 Zero Trust Architecture · NIST SP 800-63B Digital Identity Guidelines · Keycloak SPI Documentation · Bitmask RBAC patterns · FIDO2/WebAuthn for biometric authentication · OSDP v2 for physical access control
