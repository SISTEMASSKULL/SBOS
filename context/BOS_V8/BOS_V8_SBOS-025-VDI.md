# SBOS-025-VDI
## SBOS VDI: Sovereign Desktop Infrastructure — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Identidad

| Campo | Valor |
|---|---|
| Nombre | SBOS VDI — Escritorio Soberano |
| Naturaleza | Sistema Operativo Empresarial Consciente |
| Base | Fedora 43 KDE Plasma |
| Control de privilegios | bAuth Host (daemon SKULL en host) + bAuth Client (daemon en Fedora) |
| Wrapper | sbos-vdi-run — punto único de ejecución de apps |
| Autenticación | Keycloak OIDC + PAM module |
| Red | iptables owner + Squid External ACL → bAuth |
| Almacenamiento | NFS4 homes + posiciones + compartidos |
| Recurso control | cgroups v2 via systemd scopes |

## 2. Función

Capa de presentación soberana para el usuario final. Escritorio Fedora KDE que se transforma dinámicamente al autenticarse según rol, posición y perfil personal — ejecutado en tiempo real por el bAuth.

No gestiona solo el escritorio — gestiona el ciclo de vida completo del usuario: activación, operación diaria, suspensión temporal, transferencia de posición, offboarding y archivo.

## 3. Por Qué No Kasm Workspaces

| Aspecto | Kasm | SBOS VDI |
|---|---|---|
| Modelo | Streaming contenedores (remoto) | Fedora local + control desde servidor |
| Privilegios | Interno Kasm, roles simples | Tryton (5 niveles) + bAuth BitMask |
| Personalización | Branding + apps predefinidas | Dinámica por BitMask por usuario |
| Apps locales | No aplica (todo remoto) | Control total via sbos-vdi-run |
| Red por usuario | Global o grupo | Granular: por app, horario, URL |
| Licencia | Comercial (BSL) | GPL + kernel Linux nativo |
| Offline | No soportado | Sí, con políticas contingencia |
| Soberanía | Dependencia proveedor | 100% SKULL |

## 4. 8 Principios Arquitectónicos

P1: Servidor gobierna, cliente ejecuta. P2: Usuario no instala nada. P3: Ficha = fuente de verdad. P4: Sesión continua (USB o web = mismo escritorio). P5: Políticas en cascada Empresa→Rol→Usuario. P6: Posición = unidad de continuidad (workspace pertenece a la posición). P7: Políticas son decisión de la empresa, bAuth solo ejecuta. P8: Soberanía total (0 licencias comerciales).

## 5. Arquitectura General

```
SERVIDOR UBUNTU
  ├── Tryton ERP — Motor de Privilegios (5 Niveles)
  ├── bAuth HOST — BitMask Engine, WebSocket, Redis cache, Audit PG
  ├── bKernel — WAL → invalida caché bAuth → notifica clientes
  ├── Squid Proxy — filtrado URL por usuario (External ACL → bAuth)
  ├── Keycloak — Auth, JWT, SSO
  └── NFS Server — homes, posiciones, compartidos

CLIENTES FEDORA (web contenedor o USB)
  ├── bAuth CLIENT — WebSocket a Host, responde sbos-vdi-run
  ├── sbos-vdi-run — wrapper universal de ejecución
  ├── iptables owner — control red por proceso/usuario
  └── Proxy → Squid para filtrado dinámico
```

## 6. bAuth — Daemon Soberano de Privilegios

### Host (systemd en servidor)
```
├── WebSocket Server       — 10,000+ conexiones concurrentes (asyncio)
├── BitMask Engine         — evaluación O(1) sobre enteros 64 bits
├── Rights Loader          — carga fichas rights (dlopen)
├── Tryton Client          — consulta API Tryton para BitMasks
├── Redis Cache Manager    — TTL 5 min por usuario
├── Invalidation Engine    — bKernel notifica → invalida caché
├── Notification Dispatcher — cambios en tiempo real a clientes
├── Squid ACL Helper       — autorización URL por request
├── Audit Logger           — cada acción en PostgreSQL (async)
└── Rights API             — endpoint para fichas rights
```

### Client (systemd --user en Fedora)
```
├── WebSocket persistente a Host
├── Responde consultas locales de sbos-vdi-run
├── Recibe notificaciones de cambio en tiempo real
├── Aplica reglas iptables locales según BitMask
├── Regenera .desktop entries según nueva política
└── Política offline: sin conexión = denegar todo
```

### Código Host (Python asyncio)
```python
async def check_permission(self, user_sub, action, context=None):
    bitmask = await self._get_bitmask(user_sub)  # Redis o Tryton
    action_bit = self._resolve_action_bit(action)
    allowed = bool(bitmask & action_bit)  # O(1)
    for rights_module in self.loaded_rights:
        allowed = await rights_module.evaluate(allowed, user_sub, action, context, bitmask)
    await self.audit_logger.log(user_sub, action, allowed, context)
    return PermissionResult(allowed=allowed, bitmask=bitmask)
```

### Métricas
| Métrica | Objetivo |
|---|---|
| Latencia consulta | < 5ms (Redis) |
| Conexiones | 10,000+ |
| Throughput | 50,000 consultas/s |
| Propagación cambios | < 3 segundos |

## 7. BitMask 64 bits — Escritorio

```
Bit  0: firefox            Bit  4: thunderbird        Bit 20: usb_mount
Bit  1: writer             Bit  5: element-desktop    Bit 21: print
Bit  2: calc               Bit  6: vscodium           Bit 22: screenshot
Bit  3: impress            Bit  7: okular             Bit 23: clipboard_out
...
Bit 40: bos_caja_apertura  Bit 41: bos_caja_cierre    Bit 42: bos_caja_arqueo
Bit 63: admin_local
```

### Composición de políticas
```python
empresa_mask = 0b...0000_1000_0000_0000  # okular + correo base
cajero_mask  = 0b...0111_1000_0000_0000  # + apertura, cierre, arqueo
maria_extra  = 0b...0000_0000_0000_0011  # + writer + firefox
maria_final  = empresa_mask | cajero_mask | maria_extra
```

### Tabla PostgreSQL
```sql
CREATE TABLE apibitmask_user_profile (
    user_sub TEXT PRIMARY KEY,
    empresa_id TEXT NOT NULL,
    rol_id TEXT NOT NULL,
    bitmask BIGINT NOT NULL DEFAULT 0,
    empresa_bitmask BIGINT NOT NULL DEFAULT 0,
    rol_bitmask BIGINT NOT NULL DEFAULT 0,
    user_extra_bitmask BIGINT NOT NULL DEFAULT 0,
    url_blocklist TEXT[] DEFAULT '{}',
    url_allowlist_add TEXT[] DEFAULT '{}',
    quota_soft_gb NUMERIC(10,2) DEFAULT 5.0,
    quota_hard_gb NUMERIC(10,2) DEFAULT 6.0,
    session_max_minutes INTEGER DEFAULT 480,
    cgroup_cpu_pct INTEGER DEFAULT 100,
    cgroup_mem_mb INTEGER DEFAULT 2048,
    bos_actions_extra JSONB DEFAULT '[]'
);
```

## 8. Fichas Rights — Extensión del bAuth

Mismo meta-patrón: motor + fichas declarativas. bAuth no sabe qué fichas existen.

```
/etc/apibitmask/rights/<nombre>/
├── manifest.yml       ← triggers, managed_bits, on_error
├── rights_engine.yml  ← pasos declarativos
├── rights_catalog.so  ← lógica compilada (Cython)
└── resources/
```

Catálogo: horario_laboral, limite_uso_tiempo, geolocalizacion, auditoria_reforzada, contingencia_offline, bloqueo_temporal, rendimiento_adaptativo, doble_factor_accion.

### Rights API
```python
class RightsModule(ABC):
    async def evaluate(self, current_result, user_sub, action, context, bitmask) -> bool: ...
    async def on_session_start(self, user_sub, session_context) -> None: ...
```

## 9. Wrapper sbos-vdi-run

Punto único de ejecución. Reemplaza todos los .desktop con versiones controladas.

```
Usuario clic Writer → sbos-vdi-run libreoffice-writer
  → bAuth Client consulta Host (WebSocket < 5ms)
  → Evaluación BitMask O(1)
  → Fichas rights evalúan (horario, geo, etc.)
  → Permitido → systemd-run --scope con cgroup limits → app arranca
  → Denegado → zenity muestra mensaje con razón
```

PAM captura JWT Keycloak al login → almacena para bAuth Client.

## 10. Control de Red Soberano (Reemplazo HashiCorp Boundary GPL)

### Capa 1: iptables owner (kernel Linux)
```bash
# Por cada usuario: cadena con dominios bloqueados + redirect puerto 80/443 → Squid
iptables -A sbos-vdi-$UID -d <IP_bloqueada> -j REJECT
iptables -A sbos-vdi-$UID -p tcp --dport 443 -j REDIRECT --to-port 3128
```

### Capa 2: Squid External ACL → bAuth
```
squid.conf: external_acl_type apibitmask_check %LOGIN %DST /usr/local/bin/squid-apibitmask-helper
→ helper consulta bAuth Host via WebSocket
→ OK o ERR según effective_blocklist del usuario
```

### Flujo completo
```
Firefox → youtube.com:443 → iptables owner → ¿lista negra IP local? → REJECT (<1ms)
                                            → no → Squid → ACL Helper → bAuth Host
                                            → Redis caché → OK o ERR → Squid permite/deniega
                                            → Auditoría PostgreSQL
```

## 11. Políticas en Cascada (3 niveles)

```
NIVEL 1 — EMPRESA: BitMask base + URLs prohibidas + Config KDE corporativa
NIVEL 2 — ROL:     + bits adicionales + URLs + recursos (CPU, RAM, cuota)
NIVEL 3 — USUARIO: + bits personales + URLs extra permitidas + overrides recursos
  Final = empresa_mask | rol_mask | user_extra_mask (prioridad: usuario siempre gana)
```

Ejemplo: 5 cajeros ACME con mismo rol base, cada uno con overrides diferentes (María +writer +youtube, Juan +whatsapp +instagram, Carmen +calc +reporte_diario, Roberto sin overrides, Ana +writer +calc +turno extendido).

## 12. Modos de Operación

### Modo USB SKULL (Fedora en USB, arranca en cualquier PC)
SO completo SKULL en USB. bAuth Client conecta a Host vía WiFi/Ethernet. Home NFS. Sin rastro en PC host.

### Modo Web (contenedor Fedora KDE + noVNC/xRDP)
```
Containerfile (Fedora 43 KDE + noVNC + xRDP):
  Capa 1: Fedora base + KDE Plasma
  Capas 2-5: Apps corporativas + red + NFS + PAM
  Capa 6: Desactivar TODOS los .desktop (NoDisplay=true)
  Capa 7: Instalar sbos-vdi-run + bAuth Client
  Puertos: 3389 (RDP) + 6080 (noVNC)
  CMD: /usr/sbin/init (systemd gestiona todo)
```

Transparencia: misma sesión, mismo home NFS, mismos privilegios en ambos modos.

## 13. NFS + Cuotas

```
/export/
├── homes/<user>/          ← privado (Mi-Espacio, Documentos, .kde_profile)
├── positions/<posicion>/  ← workspace activo + archives/ (snapshots por usuario anterior)
├── shares/<rol>/          ← read-only por rol
└── empresa/<empresa>/     ← corporativo read-only
```

Cuotas: quotactl via API SBOS. soft_gb y hard_gb del UserPrivilegeProfile.

## 14. Recursos (cgroups v2 + polkit)

CPU/RAM: systemd-run --scope con CPUQuota y MemoryMax desde UserPrivilegeProfile.
Dispositivos: polkit rules consultan bAuth Client (USB mount, print, screenshot, clipboard).
Nice: prioridad de proceso por rol.

## 15. Stack Tecnológico

| Componente | Licencia | Función |
|---|---|---|
| bAuth Host | SKULL | BitMask Engine + WebSocket + Redis + Audit PG |
| bAuth Client | SKULL | Daemon Fedora + iptables + .desktop |
| sbos-vdi-run | SKULL | Wrapper universal ejecución |
| Tryton + módulo sbos-vdi_privileges | LGPL + SKULL | 5 niveles acceso + políticas escritorio |
| Keycloak | Apache 2.0 | Auth JWT SSO |
| Redis 7.x | BSD | Caché BitMasks TTL 5min |
| PostgreSQL | PG License | Auditoría + BD bAuth |
| Squid | GPL | Filtrado URL External ACL |
| iptables/nftables | GPL | Control red por proceso |
| NFS4 | GPL | Homes + posiciones + compartidos |
| cgroups v2 / systemd | GPL | CPU/RAM por app |
| Fedora 43 KDE | GPL | Escritorio |
| PAM sbos-vdi | SKULL | Captura JWT al login |

---

## §16 — ENRIQUECIMIENTO V5: Integración con RolFramework y Modelo BitMask Extendido

### V5-1: RolFramework como Coordinador Keycloak ↔ Tryton (desde SBOS-012 v5.0)

El RolFramework traduce grupos de Keycloak en BitMasks de Tryton y las sincroniza en la tabla `apibitmask_user_profile`:

```
Usuario se autentica en Keycloak
    ↓
JWT contiene: realm_roles = ['CAJERO', 'ACME-EMPLEADOS']
    ↓
RolFramework::on_login(user_sub, realm_roles):
    1. Obtiene RolTemplate de CAJERO desde Tryton
    2. Calcula empresa_bitmask (base de todos los empleados ACME)
    3. Calcula rol_bitmask (bits adicionales del rol CAJERO)
    4. Lee SkVDIUserOverride para este user_sub desde Tryton
    5. Calcula user_extra_bitmask (bits adicionales del usuario)
    6. bitmask_efectiva = empresa_bitmask | rol_bitmask | user_extra_bitmask
    7. Compone UserPrivilegeProfile completo (URLs, cuotas, cgroups)
    8. INSERT/UPDATE en apibitmask_user_profile
    9. Invalida caché Redis del usuario
    ↓
bAuth Host ya tiene la BitMask actualizada
```

### V5-2: Propagación de Cambios en Tiempo Real

```
Admin modifica override de Juan en Core UI
    ↓ (< 1 segundo)
Tryton escribe en sbos-vdi.user.override
    ↓ (WAL event, < 100ms)
bKernel detecta cambio en tabla sbos-vdi.user.override
    ↓ (< 500ms)
bKernel llama RolFramework.recalculate_user(user_sub='uuid-juan')
    ↓ (< 500ms)
RolFramework recalcula BitMask y actualiza apibitmask_user_profile
    ↓ (< 200ms)
RolFramework llama bAuth.invalidate_user_cache(user_sub)
    ↓ (< 100ms)
bAuth invalida Redis + notifica WebSocket al cliente de Juan
    ↓ (< 2 segundos total desde click del admin)
Fedora de Juan recibe PRIVILEGE_UPDATE
    ↓
bAuth Client actualiza iptables + regenera .desktop entries
    ↓
Juan ve el cambio en su escritorio sin reiniciar sesión
```

### V5-3: Modelo de Seguridad en 6 Capas (desde SBOS-012 v5.0)

```
CAPA 1 — AUTENTICACIÓN: Keycloak OIDC + JWT + MFA opcional
CAPA 2 — AUTORIZACIÓN: Tryton (5 niveles) + bAuth (BitMask Engine)
CAPA 3 — CONTROL DE EJECUCIÓN: sbos-vdi-run wrapper
CAPA 4 — CONTROL DE RED: iptables owner + Squid External ACL Helper
CAPA 5 — CONTROL DE ARCHIVOS: NFSv4 con permisos granulares + quotactl
CAPA 6 — AUDITORÍA COMPLETA: PostgreSQL, cada acción registrada
```

### V5-4: Ciclo de Vida del Usuario (desde SBOS-012 v5.0)

**Activación (Onboarding):**
```
Admin → Core UI → Nuevo Usuario
1. Keycloak: crear cuenta + asignar realm_roles
2. Tryton: crear sbos-vdi.user.override
3. bKernel detecta → RolFramework calcula BitMask inicial
4. bAuth: INSERT apibitmask_user_profile
5. NFS: mkdir /export/homes/{username} + aplicar cuota
6. Usuario puede hacer login en < 60 segundos
```

**Suspensión Temporal:**
```
Admin → Core UI → Usuario → Suspender
1. Keycloak: desactivar cuenta
2. bAuth: bitmask = 0
3. Sesión activa: recibe PRIVILEGE_UPDATE → bitmask = 0
4. sbos-vdi-run deniega toda acción
```

**Offboarding:**
```
Admin → Core UI → Usuario → Offboarding
1. Keycloak: desactivar cuenta permanentemente
2. bAuth: DELETE apibitmask_user_profile
3. NFS Snapshot en /export/positions/{posicion}/archives/{username}_{timestamp}/
4. Auditoría: logs conservados (inmutables)
```

### V5-5: Herencia de Políticas por Posición (desde SBOS-012 v5.0)

Las políticas personales se archivan junto con el workspace. Al hacer onboarding del nuevo usuario, el admin puede heredar lo que corresponde:

```
Onboarding: Pedro Pérez → Cajero Sucursal Norte Caja 3
Posición previamente ocupada por: María García

Políticas archivadas de María García:
  App: LibreOffice Writer    [✓ Heredar] [✗ No heredar]
  Razón original: "Premio Q4 + hace informes mensuales del puesto"
  URL: youtube.com           [✓ Heredar] [✗ No heredar]
```

---

## §17 — ENRIQUECIMIENTO V7: BitmaskBundle v3 y Reconceptualización de Dominios

### V7-1: BitmaskBundle v3 — Tres Registros Independientes (desde V7 Dominios)

El modelo de BitMask único de 64 bits para escritorio se reconceptualiza como parte del **BitmaskBundle v3**, que define tres registros independientes de 64 bits:

```go
type BitmaskBundle struct {
    PhysicalDomainMask uint64  // bits 0-63: acceso físico (escritorio, apps locales, USB, print)
    LogicalDomainMask  uint64  // bits 0-63: acceso lógico (apps web, datos, módulos)
    FinancialDomainMask uint64 // bits 0-63: transacciones financieras (pagos, nómina, compras)
}
```

La VDI BitMask del V6 original (bits 0-63 para escritorio) pasa a ser el **PhysicalDomainMask**:
- Bits 0-19: aplicaciones de escritorio nativas (firefox, writer, calc, impress, thunderbird, element, vscodium, okular)
- Bits 20-31: periféricos y acciones del sistema (usb_mount, print, screenshot, clipboard_out, download_files, upload_files)
- Bits 32-39: acciones administrativas del escritorio
- Bits 40-47: acciones BOS (caja apertura, cierre, arqueo)
- Bits 48-62: reservado para expansión del perfil físico
- Bit 63: admin_local (privilegio de administración local)

### V7-2: Mapa de Zonas Físicas del PhysicalDomainMask (desde V7 Dominios)

```go
// PhysicalDomainMask — zonas de acceso físico al escritorio
const (
    // Zona OFIMATICA (bits 0-7)
    PhysicalZoneOfimatica  uint64 = 0xFF
    BitFirefox             uint64 = 1 << 0
    BitWriter              uint64 = 1 << 1
    BitCalc                uint64 = 1 << 2
    BitImpress             uint64 = 1 << 3
    BitThunderbird         uint64 = 1 << 4
    BitElementDesktop      uint64 = 1 << 5
    BitVscodium            uint64 = 1 << 6
    BitOkular              uint64 = 1 << 7

    // Zona PERIFERICOS (bits 20-23)
    PhysicalZonePerifericos uint64 = 0xF << 20
    BitUsbMount            uint64 = 1 << 20
    BitPrint               uint64 = 1 << 21
    BitScreenshot          uint64 = 1 << 22
    BitClipboardOut        uint64 = 1 << 23

    // Zona BOS (bits 40-47)
    PhysicalZoneBos        uint64 = 0xFF << 40
    BitCajaApertura        uint64 = 1 << 40
    BitCajaCierre          uint64 = 1 << 41
    BitCajaArqueo          uint64 = 1 << 42

    // Admin local
    BitAdminLocal          uint64 = 1 << 63
)
```

### V7-3: Operaciones del PhysicalDomainMask (desde V7 SAM-128)

```go
// HasVDIPermission — verifica si el PhysicalDomainMask contiene un permiso
func (b *BitmaskBundle) HasVDIPermission(bit uint64) bool {
    return b.PhysicalDomainMask&bit != 0
}

// GetVDIZone — obtiene subconjunto de PhysicalDomainMask por zona
func (b *BitmaskBundle) GetVDIZone(mask uint64) uint64 {
    return b.PhysicalDomainMask & mask
}

// SetVDIPermission — activa un permiso VDI
func (b *BitmaskBundle) SetVDIPermission(bit uint64) {
    b.PhysicalDomainMask |= bit
}

// RevokeVDIPermission — revoca un permiso VDI usando AND NOT
func (b *BitmaskBundle) RevokeVDIPermission(bit uint64) {
    b.PhysicalDomainMask &^= bit
}

// MergeVDIProfiles — combina perfiles VDI (empresa | rol | usuario)
func (b *BitmaskBundle) MergeVDIProfiles(empresa, rol, usuario uint64) {
    b.PhysicalDomainMask = empresa | rol | usuario
}
```

### V7-4: AssumeTenantContext — Superusuario Zero Standing Privileges (desde V7 SAM-128)

Para operaciones administrativas que requieren acceso total al escritorio (soporte técnico, auditoría), se implementa el patrón **AssumeTenantContext** con máscara maestra temporal:

```go
type AssumeTenantContext struct {
    AdminUserSub    string    `json:"admin_user_sub"`
    TargetTenant    string    `json:"target_tenant"`
    ExpiresAt       time.Time `json:"expires_at"`
    GrantedMasks    BitmaskBundle `json:"granted_masks"`
    Reason          string    `json:"reason"`
    AuditID         string    `json:"audit_id"`
}

func NewAssumeTenantContext(admin, tenant string, duration time.Duration, reason string) *AssumeTenantContext {
    return &AssumeTenantContext{
        AdminUserSub: admin,
        TargetTenant: tenant,
        ExpiresAt:    time.Now().Add(duration),
        GrantedMasks: BitmaskBundle{
            PhysicalDomainMask:  ^uint64(0), // Todos los bits encendidos
            LogicalDomainMask:   ^uint64(0),
            FinancialDomainMask: ^uint64(0),
        },
        Reason:   reason,
        AuditID:  uuid.New().String(),
    }
}

func (a *AssumeTenantContext) IsExpired() bool {
    return time.Now().After(a.ExpiresAt)
}
```

### V7-5: Conflict Matrix para SoD en VDI (desde V7 SAM-128)

El operador XOR del V6 original se reemplaza por una **Conflict Matrix** explícita para detección de Separation of Duties:

```go
type SoDConflict struct {
    BitA     uint64
    BitB     uint64
    Severity string // "critical" | "warning"
    Reason   string
}

var VdiSoDMatrix = []SoDConflict{
    // Un cajero no puede tener apertura y arqueo simultáneamente
    {BitA: BitCajaApertura, BitB: BitCajaArqueo, Severity: "critical", Reason: "Separation of duties: cajero"},
    // Admin local + clipboard_out puede ser fuga de datos
    {BitAdminLocal, BitClipboardOut, "warning", "Admin local with clipboard out"},
}

func CheckVdiSoDViolation(mask uint64) []SoDConflict {
    var violations []SoDConflict
    for _, conflict := range VdiSoDMatrix {
        if mask&conflict.BitA != 0 && mask&conflict.BitB != 0 {
            violations = append(violations, conflict)
        }
    }
    return violations
}
```

### V7-6: Integración con LogicalDomainMask (desde V7 Dominios)

El PhysicalDomainMask (VDI) se evalúa en conjunto con el LogicalDomainMask para determinar el acceso completo del usuario. Una aplicación puede requerir permiso tanto en el dominio físico (poder ejecutar la app en el escritorio) como en el lógico (tener acceso al módulo correspondiente):

```
Usuario intenta abrir Firefox en el escritorio
  → bAuth evalúa PhysicalDomainMask: BitFirefox activo? SÍ
  → bAuth evalúa LogicalDomainMask: ZONE_WEB_NAVIGATION tiene permiso READ? SÍ
  → Ambas condiciones cumplidas → PERMITIDO
```

---

## §18 — ENRIQUECIMIENTO Smart* (V8)

### V8-1: SmartORC — Criptografía y Ciclo Documental (desde BOSORC-012-CRIPTOGRAFIA.md v2.0, BOSORC-BVAULT-TRATAMIENTO-DOCUMENTOS.md)

El SmartORC define el ciclo de vida completo del documento desde su ingreso hasta el despacho, con integración directa con bvault. Este ciclo complementa el modelo de acceso físico del VDI al añadir trazabilidad documental:

**7-step signing flow (RSA-2048 + SHA-256 + Vault KV v2):**
1. Init — recepción del documento en ORC
2. Re-auth — re-autenticación forzada vía WebAuthn/TOTP
3. DataPack — construcción del JSON canónico del evento
4. SHA-256 — hash del DataPack
5. RSA — firma PKCS1v15 con clave privada del usuario desde Vault
6. Atomic persist — escritura en correspondencia_custody con el signature_hash
7. Notify — Centrifugo push a los involucrados

**Key rotation policy:** activa (365 días) → retirada → movida a SmartVaultFlow (.bvault-keys/) → revocada (destrucción).

**VerificationService.Go:** DataPack con struct canónico, SignPKCS1v15, VerifyCustodySignature para validación cruzada de firmas.

**8 failure cases documentados:** key not found, signature mismatch, expired key, revoked key, DataPack tampering, user not authenticated, duplicate event, timeout en firma.

**Document Treatment (IRM):** El archivo nunca sale del servidor. Visor seguro con marca de agua dinámica presenta el contenido sin permitir descarga directa. Permisos según estado del documento. 4-layer fraud prevention: Prevención → Detección → Respuesta → Evidencia (RN-026 a RN-033). Documentos soporte obligatorios por paso. Redirección por incompetencia con retorno al custodio anterior. Custodia grupal (múltiples revisores simultáneos).

### V8-2: SmartVaultFlow — Custodia Permanente y Entrega (desde BVAULT-006-ARQUITECTURA.md, BVAULT-002-CICLO-DOCUMENTAL.md, BVAULT-001-ACOPLAMIENTO.md)

El bvault (SmartVaultFlow) provee la capa de custodia permanente que complementa el VDI:

**Stack tecnológico:** Go + PostgreSQL 17 + pg_cron + HashiCorp Vault + Nextcloud + Centrifugo + Rocket.Chat + Servidor Email (SES/Brevo).

**12 restricciones de diseño:** AD-01 a AD-13 que rigen integridad, aislamiento, y no-repudio. Las 12 restricciones cubren: NO modificar archivos originales, NO permitir borrado lógico sin auditoría, NO exponer datos fuera del tenant, SIEMPRE verificar SHA-256 antes de entrega, etc.

**Jobs automáticos (pg_cron):**
- `integrity-check`: verificación periódica SHA-256 de activos en custodia
- `expiry-alert`: notifica antes del vencimiento del período de custodia
- `escalation-check`: escalado automático si no hay respuesta del destinatario
- `orphan-cleaner`: limpia activos huérfanos
- `account-expiry`: deshabilita cuentas expiradas

**Crypto key custody:** Las claves RSA retiradas de ORC se almacenan en path `.bvault-keys/` dentro de Vault Transit (AES-256-GCM). Las claves activas permanecen en Vault KV v2 para uso de ORC.

**Delivery windows para entrega al destinatario:**
| Modalidad | Descripción | Autenticación |
|---|---|---|
| `virtual_self` | Entrega digital en Ventanilla | Autenticación SBOS (JWT) |
| `virtual_link` | Enlace externo con token one-time | Token + email |
| `virtual_confirmed` | Entrega digital con acuse de recibo | JWT + WebAuthn |
| `physical_counter` | Retiro físico en mostrador | Identificación + cédula |
| `physical_print` | Impresión certificada | Firma del empleado |

**Mapping ORC → bvault por tipo de activo:**
| Tipo ORC | Período custodia | Destino final |
|---|---|---|
| legal_notice | 10 años | Archivado frío |
| fiscal | 10 años | Archivado frío |
| contract | 5 años | Archivado frío |
| invoice | 5 años | Archivado frío |
| internal | 2 años | Eliminación segura |

**Recipient protocols:** client (persona natural), state_org (organismo estatal), private_org (organización privada), internal_user (usuario interno SBOS). Cada uno con su propio flujo de notificación y verificación de identidad.

**Exception flows:** expired token (re-generar enlace), dispute (congelar activo + notificar Admin bos), integrity violation (bloquear acceso + alertar).

### V8-3: Context Plane — Ciclo POS y ctx_id (desde SBOS-049-CONTEXT-PLANE.md v3.0)

El Context Plane (bos IAM Installer como propietario) define el ciclo de sesión POS que conecta la identidad del VDI con las operaciones de caja:

**POS Lifecycle completo:**
| Estado | ctx_id | BitMask | Acción |
|---|---|---|---|
| pre-auth | dctx_id | bitmask=0 | Usuario se identifica sin capacidades |
| authentication | ctx_id transicional | verificación multi-capa | banexus → bhnexus → Keycloak → bAuth → bos |
| active | ctx_id operativo | bitmask unlocks real capabilities | Apertura de puertas, cajón de dinero, apps |
| logout | ctx_id invalidado | bitmask=0 | Cierre de sesión con invalidación |

El event `context.promoted` marca la transición entre estados. La tabla `context_sessions` está particionada por RANGE (created_at) para manejo eficiente de sesiones históricas. OTel Baggage propagation asegura que el ctx_id viaje en toda la cadena de microservicios.

### V8-4: Propuesta de Bits VDI para Operaciones Documentales (desde BVAULT-001-ACOPLAMIENTO.md)

El BitMask del VDI se extiende para incluir operaciones documentales:

```
Bits 25-29 propuestos para documentos:
  Bit 25: DOC_READ        — leer documentos en custodia
  Bit 26: DOC_SIGN        — firmar documentos (RSA-2048)
  Bit 27: DOC_DELIVER     — entregar documentos al destinatario
  Bit 28: DOC_AUDIT       — auditar cadena de custodia
  Bit 29: DOC_ADMIN       — administrar políticas documentales
```

Estos bits se evalúan en conjunto con el Context Plane: el ctx_id del POS debe tener el bit correspondiente activo para ejecutar la acción documental. La firma RSA-2048 del documento (Bit 26) es idéntica al proceso de 7 pasos del SmartORC, compartiendo el mismo VerificationService.

**Implementation phases (5 fases, 12 semanas):**
| Fase | Semanas | Alcance |
|---|---|---|
| F1 | 1-3 | DDL, Vault provisioner, Keycloak client ORC |
| F2 | 4-7 | Go API core, SigningService 7-step, priority job, Tryton module |
| F3 | 8-11 | UI, chat, 3-quadrant mailbox, biometric flow, Rocket.Chat bot |
| F4 | 12 | KPIs, bSearch pattern, PDF audit export, 6 crypto security tests |
| F5 | Go-Live | Certificación, documentación, despliegue |

---

## Trazabilidad V8

| Sección | Fuente |
|---|---|
| §1-15 (V6 completo) | BOS_V6_SBOS-025-VDI.md |
| §16 V5-1 a V5-5 | BOS_V5_SBOS-012-SBOS-VDI-v4_0.md (secciones 12, 14-21) |
| §17 V7-1 a V7-6 | BOS_V7_SBOS-DOMINIOS-AUTENTICACION-Y-RECONCEPTUALIZACION.md, BOS_V7_SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md |
| §18 V8-1 a V8-4 | SBOS Smart ORC (BOSORC-012-CRIPTOGRAFIA.md v2.0, BOSORC-BVAULT-TRATAMIENTO-DOCUMENTOS.md), SBOS Smart Vault Flow (BVAULT-006-ARQUITECTURA.md, BVAULT-002-CICLO-DOCUMENTAL.md, BVAULT-001-ACOPLAMIENTO.md), SBOS-049-CONTEXT-PLANE.md v3.0 |

---

_SKULL · SBOS · SBOS-025-VDI · HUMAN-DOC V8 ENRIQUECIDO · Mayo 2026_
