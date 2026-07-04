# INFORME — De qué partes se constituye bAuth
## Análisis de la documentación canónica · Decisiones · Investigaciones
### v3.0 · 2026-06-19 · SKULL · BitMask Dual Jun 2026

---

> ⚠️ **CORRECCIÓN BITMASK — JUNIO 2026:** Las referencias al modelo BitMask (SAM-128, "2 capas", "BitmaskBundle", "7×64 bits") en este documento corresponden al diseño anterior. El modelo actual es el **BitMask Dual**: BitMask Átomo 64-bit (label encoding) + Rol BitMask N-bit (one-hot encoding). Para desarrollo, usar: `SBOS-MANUAL-SISTEMA-PRIVILEGIOS-v1.0.md`, `SBOS-MANUAL-BAUTH-COMPONENT-ROLES.md` v1.7, `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` v2.1.

---

## 0. Resumen de la sesión

**24 documentos creados/actualizados · 189 átomos · 24 gates · ~620 horas estimadas.**

### Documentos del proyecto bauth

| # | Documento | Contenido |
|---|-----------|-----------|
| 1 | `REGISTRO-ESTADO.md` | 189 átomos atomizados (INVEST+XP), 24 gates, columna S |
| 2 | `BAUTH-ARQUITECTURA-FRAMEWORK.md` | Patrón Framework↔Engine validado contra Helidon, Doris, Duende |
| 3 | `BAUTH-JUSTIFICACION-RUST.md` | ADR-BAUTH-001: benchmarks 2025-2026, decisión Rust |
| 4 | `BAUTH-CONTRATO-SYMBIOSIS.md` | Principio Simbiótico bAuth↔KC↔Tryton |
| 5 | `INFORME-COMPONENTES-BAUTH.md` | ESTE DOCUMENTO — análisis completo |
| 6 | `BAUTH-PLAN-MAESTRO-v1.md` | 6 responsabilidades, 8 criterios certificación |
| 7 | `MAPA-NAVEGACION.md` | Árbol, reglas, jerarquía |
| 8 | `PROTOCOLO-SESION-AGENTE.md` | Apertura/ejecución/cierre |
| 9 | `LOG-DE-SESIONES.md` | S-001 |
| 10 | `INSTRUCCIONES-DE-USO.md` | Comandos Rust por gate |
| 11 | `GESTION-RIESGOS-OPERATIVOS.md` | 8 riesgos |

### Documentos BOS_V8 actualizados

- `BOS_V8_SBOS-021-DAEMON-BAUTH.md` → v1.3 con enmienda Rust + ADR-BAUTH-001
- `BOS_V8_SBOS-060-ESTANDAR-DOCUMENTACION.md` → Estándar DOC-SBOS-001 N3

---

## 1. Fuentes analizadas

| Documento | Líneas | Contenido |
|-----------|--------|-----------|
| `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md` | 1670 | Definición canónica completa |
| `SBOS-BAUTH-DECISIONES-ARQUITECTURA-v1_0.md` | 1257 | Decisiones de arquitectura |
| `SBOS-008-001-DOMAINS-BITMASK-REALM-v1_0.md` | 370 | Dominios BitMask + Realm |
| `SBOS-ROLTEMPLATE-v5_0.md` | 1115 | Contrato RolTemplate |
| `SBOS-USERTEMPLATE-v5_0.md` | 1070 | Contrato UserTemplate |
| `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` | 808 | SAM-128 corregido |
| `BAUTH-CONTRATO-SYMBIOSIS.md` | 250 | Principio simbiótico (creado hoy) |
| `BAUTH-JUSTIFICACION-RUST.md` | 280 | ADR-BAUTH-001 (creado hoy) |

---

## 2. Los 7 Componentes Constitutivos de bAuth

### C1 — PRIVILEGE ENGINE (el núcleo computacional)

**Qué es:** El motor H-RBAC que calcula permisos usando aritmética binaria sobre máscaras de 64 bits.

**Subcomponentes:**
- `BitmaskBundle` — 4×uint64: PhysicalDomainMask + LogicalDomainMask + FinancialDomainMask + GovernanceMask
- `ComputeBundle(templates) → BitmaskBundle` — herencia automática vía AND NOT
- `MergeRoles(a, b) → BitmaskBundle` — unión OR (PRE: Conflict Matrix verificada)
- `HasPermission(bundle, bit) → bool` — O(1), ~0.45 ns/op, zero allocations
- SAM-128 — Sovereign Authority Matrix de 128 bits (4 zonas de 32 bits)

**Tablas PostgreSQL:**
- `bos_rol_template` — fuente de verdad de cada rol
- `bos_rol_template_history` — WORM (Write Once Read Many), SHA-256 chain
- `bos_user_template` — asignación usuario→rol

**Documento SSOT:** `SBOS-ROLTEMPLATE-v5_0.md`, `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md`

### C2 — SYNC ENGINE (el sincronizador maestro)

**Qué es:** El puente que traduce RolTemplates a objetos nativos de Keycloak y Tryton.

**Subcomponentes:**
- KeycloakSync — Admin REST API: CRUD de realms, roles, users, groups, clients
- TrytonSync — XML-RPC: CRUD de grupos y usuarios
- ReconcileLoop — cada 60s: leer bauth_db → comparar KC + Tryton → corregir drift
- Bootstrap simbiótico — al arrancar: reconstruir TODO desde bauth_db

**Garantía:** < 5 segundos desde guardar RolTemplate hasta SYNCED en KC + Tryton

**Documento SSOT:** `BAUTH-CONTRATO-SYMBIOSIS.md`, `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md §3, §13`

### C3 — UNIX SOCKET API (el evaluador en tiempo real)

**Qué es:** La interfaz de consulta para que otros daemons validen identidad sin pasar por HTTP.

**Subcomponentes:**
- WebSocket RPC — para `bauthctl` CLI y Core UI (humanos)
- JSON-RPC 2.0 — para biedata, bkernel, bhnexus, kong (máquinas)
- AuthQuery — validar JWT + bitmask + LoA + expiry en < 5ms P99
- ContextAPI — `bauth.ctx.create` + `bauth.ctx.validate` (SBOS-049)
- Cache Redis — TTL 30s, lookup < 1ms P50

**Socket:** `/run/bos/bauth.sock` (0660, grupo `bosagent`)

**Documento SSOT:** `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md §11`, ADR-020

### C4 — PAP (Policy Administration Point — la interfaz de administración)

**Qué es:** La ÚNICA puerta de entrada para modificar la identidad del ecosistema.

**Subcomponentes:**
- CRUD de RolTemplates — crear, modificar, versionar, archivar roles
- CRUD de UserTemplates — asignar, revocar, reasignar roles a usuarios
- Conflict Matrix — evaluada ANTES de guardar (SoD enforcement)
- Validación de herencia circular — detección de ciclos en jerarquía de roles

**Acceso:** Solo via Core UI (WebSocket RPC por Unix socket)

**Documento SSOT:** `SBOS-ROLTEMPLATE-v5_0.md`, `SBOS-USERTEMPLATE-v5_0.md`

### C5 — PHYSICAL IDENTITY (el gestor de identidad física)

**Qué es:** El puente entre el mundo físico y el digital.

**Subcomponentes:**
- QR dinámicos — HMAC-SHA256, TTL 30s, un solo uso
- Hashes biométricos — PBKDF2-SHA256 (310K iteraciones), NUNCA datos crudos (RGPD Art.9)
- Validación NFC/RFID — via bhnexus
- Tabla `bauth_biometric_templates` — templates hasheados, no raw data

**Documento SSOT:** `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md §16`

### C6 — SoD GUARDIAN (el guardián de segregación de funciones)

**Qué es:** El sistema que previene conflictos de privilegios.

**Subcomponentes:**
- Conflict Matrix — 20+ reglas (ej: quien crea facturas NO puede aprobarlas)
- Audit Events — `bkernel_db.audit_events` con ctx_id obligatorio (ISO 27001 A.8.15)
- SuperUser break-glass — acceso de emergencia con auditoría completa
- Delegación temporal — vigencia configurable, revocación automática
- Alertas Wazuh SIEM — HIGH/CRITICAL en tiempo real

**Documento SSOT:** `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md §15, §17`

### C7 — SPIs (Service Provider Interfaces para Keycloak)

**Qué es:** 5 plugins Java 17 que extienden Keycloak con lógica de negocio SBOS.

**SPIs:**
1. `BosRolTemplate` — inyecta BitmaskBundle en el JWT durante login
2. `FinancialDomain` — aplica políticas financieras (SoD, dual control)
3. `PhysicalDomain` — aplica restricciones de acceso físico
4. `LogicalDomain` — aplica restricciones de zona lógica (sucursal, país)
5. `TemporalContext` — aplica restricciones horarias (horario laboral, turnos)

**Lenguaje:** Java 17 (nativo de Keycloak — NO se migra a Rust)
**Directorio:** `spi/` dentro de BauthAgent

**Documento SSOT:** `SBOS-BAUTH-CONCEPTUALIZACION-v5_0.md §12`

---

## 3. Arquitectura de Dominios (corrección v3.0)

### El error del motor monolítico

El diseño original concebía un solo `PrivilegeEngine` que manejaba todos los dominios.
Esto **viola el principio Open/Closed** — agregar un nuevo dominio (ej. BiometricDomain)
requeriría modificar el motor central, volviéndolo código espagueti con el tiempo.

### La solución: `DomainEvaluator` trait + registro de dominios

```
trait DomainEvaluator {
    fn evaluate(&self, mask: u64, context: &EvalContext) -> bool;
    fn domain_name() -> &'static str;
}

DomainRegistry {
    evaluators: HashMap<DomainId, Box<dyn DomainEvaluator>>
}
```

**Cada dominio es un gate independiente.** Agregar un nuevo dominio = 1 llamada a `register()`.

### Los 7 Dominios

| # | Dominio | Evaluador | Bits | Fundamento |
|---|---------|-----------|------|-----------|
| 1 | **PhysicalDomain** | `PhysicalEvaluator` | 32 | SAM-128 §8.3 — puertas, zonas, hardware |
| 2 | **LogicalDomain** | `LogicalEvaluator` | 32 | SAM-128 §8.4 — verbos × zonas de negocio |
| 3 | **FinancialDomain** | `FinancialEvaluator` | 32 | SAM-128 §8.5 — límites, SoD financiero |
| 4 | **BiometricDomain** | `BiometricEvaluator` | 16 | NIST SP 800-63B-4 — fingerprint, face, iris |
| 5 | **TemporalDomain** | `TemporalEvaluator` | 32 | GTRBAC — turnos, horarios, expiración |
| 6 | **GeospatialDomain** | `GeospatialEvaluator` | 32 | NIST SP 800-207 — geo-fencing, jurisdicción |
| 7 | **NetworkDomain** | `NetworkEvaluator` | 32 | SBOS-054 — VPN, firewalls, segmentación |

### Estructura de Gates (v3.0)

| Gate | Componente | Átomos |
|------|-----------|--------|
| **B0** | Esqueleto Rust + CI | 8 |
| **B1** | Arquitectura de Dominios (Traits) | 4 |
| **B2** | PhysicalDomain | 3 |
| **B3** | LogicalDomain | 3 |
| **B4** | FinancialDomain | 3 |
| **B5** | BiometricDomain | 3 |
| **B6** | TemporalDomain | 3 |
| **B7** | GeospatialDomain | 3 |
| **B8** | NetworkDomain | 3 |
| **B9** | RolTemplate + UserTemplate | 6 |
| **B10** | Sincronizador Keycloak | 5 |
| **B11** | Sincronizador Tryton | 4 |
| **B12** | Context Plane + ctx_id | 4 |
| **B13** | Delegación + SuperUser + Auditoría | 5 |
| **B14** | gRPC + JSON-RPC (Interface Dual) | 5 |
| **B15** | Definición de Sagas | 4 |
| **B16** | Seguridad de Red (SBOS-054) | 6 |
| **FICHA** | Declaración BOS | 4 |

**Total: 17 gates · 76 átomos**

---

## 5. Matriz de Canales de Entrega de Documentos de Autenticación

**Investigación:** bAuth no solo genera documentos de autenticación — los ENTREGA al usuario
a través de canales específicos según el tipo de documento y el contexto del usuario.

### 5.1 Matriz Documento → Canal de Entrega

| Documento | Canal 1 (Principal) | Canal 2 | Canal 3 | Canal 4 |
|-----------|---------------------|---------|---------|---------|
| **QR físico** | 🖨️ PDF → impresión en boleta | 📱 WhatsApp Business API (PNG) | 📬 Telegram Bot API (PNG) | 📧 Email adjunto (PNG) |
| **NFC tag** | 🏢 Entrega en persona (admin escribe tag NXP NTAG424DNA) | 🛒 Usuario compra llave NFC programable | 📱 HCE (Host Card Emulation) — app SBOS emula NFC | 🪪 Tarjeta física pre-grabada |
| **TOTP** | 📱 QR en pantalla → usuario escanea con Google Authenticator/Authy | 📱 QR vía WhatsApp | 📧 QR vía Email | 🖥️ QR en Core UI (dashboard) |
| **Push** | 📲 FCM (Android) / APNs (iOS) → app SBOS | 🌐 Web Push API (navegador) | — | — |
| **SMS** | 📩 Twilio / AWS SNS → número móvil registrado | — | — | — |
| **Email** | 📧 SMTP + DKIM → correo registrado | — | — | — |
| **Backup codes** | 🖨️ PDF → impresión | 📱 Mostrar en pantalla (1 sola vez) | 📧 Email cifrado | — |
| **Magic link** | 📧 Email (enlace único JWT + nonce) | 📱 WhatsApp (enlace) | 📩 SMS (enlace corto) | — |

### 5.2 NFC — Host Card Emulation (HCE)

Cuando no hay tag físico disponible, el teléfono Android del usuario EMULA una tarjeta NFC:

```
Teléfono Android
  ├── App SBOS instalada
  ├── HCE Service registrado en AndroidManifest.xml
  ├── bAuth envía token NFC al teléfono vía Push (FCM)
  ├── Token se almacena en Android Keystore (cifrado AES-256-GCM)
  ├── Usuario acerca el teléfono al lector NFC
  ├── Lector lee el token emulado por HCE (ISO 14443-4, NDEF)
  └── bhnexus → bAuth: validar token HCE → autorizar acceso
```

### 5.3 Ciclo de Vida del Aprovisionamiento

```
1. SOLICITUD → Admin o sistema solicita documento para usuario
2. GENERACIÓN → bAuth genera documento con HMAC/TOTP/criptografía
3. APROVISIONAMIENTO → Documento escrito/transmitido al medio (tag, app, papel)
4. ENTREGA → Documento llega al usuario vía canal (WhatsApp, email, impresión, HCE)
5. ALMACENAMIENTO → Documento reside en dispositivo/usuario (tag, app, papel)
6. USO → Usuario presenta documento → bAuth valida → acceso concedido
7. INVALIDACIÓN → Post-uso o expiración → documento marcado como consumido
```

---

## 6. Decisiones de Arquitectura (ADR)

| ADR | Decisión | Fundamento |
|-----|----------|-----------|
| **ADR-BAUTH-001** | Rust 1.85+ (no Go) | P99 determinista, 64% menos memoria, sin GC spikes. Benchmarks 2025-2026 |
| **ADR-BAUTH-002** | Framework↔Engine (no monolito) | Patrón validado: Helidon, Apache Doris, Duende. Open/Closed |
| **ADR-BAUTH-003** | 7 dominios independientes (no 1 solo BitMask) | Escalable: nuevo dominio = nuevo evaluador, sin tocar existentes |
| **ADR-BAUTH-004** | Templates YAML→JSONB encriptados (no SQL directo) | Fuente de verdad declarativa. AES-256-GCM. Vault |
| **ADR-BAUTH-005** | Motores vía API nativa (no SQL directo) | KC→REST, Tryton→JSON-RPC, OAuth2→config+SIGHUP |
| **ADR-BAUTH-006** | Canales de entrega de documentos | WhatsApp, Telegram, HCE, FCM, SMTP. Multi-canal por documento |
| **ADR-BAUTH-007** | Context Plane = Policy Engine NIST 800-207 | bAuth = PE, bos = PA, Kong = PEP. W3C Trace Context |

---
*INFORME-COMPONENTES-BAUTH v3.0 · 2026-06-19 · SKULL*
