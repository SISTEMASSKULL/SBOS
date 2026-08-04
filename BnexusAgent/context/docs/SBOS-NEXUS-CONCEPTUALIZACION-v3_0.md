# SBOS — bNEXUS: Motor de Comunicación Física de bAuth
## Tres Capas · bAuth (principal) · bhnexus (ruteador) · banexus (frontera)
### SKULL · SBOS — Sovereign Business Operating System
### v3.0 · Abril 2026

---

| Campo | Valor |
|---|---|
| **Código** | SBOS-NEXUS-CONCEPTUALIZACION |
| **Versión** | 3.7 (bAuth como OIDC Provider universal + SBOS tenant interno + banexus-implicit primero) |
| **Estado** | ACTIVO |
| **Propietario** | `bAuth` — bhnexus y banexus son sus capas de comunicación física |
| **Capas** | `bAuth` (principal) · `bhnexus` (ruteador) · `banexus` (frontera) |
| **Lenguaje** | Rust 1.85+ MUSL (bhnexus y banexus) |
| **Documentos base** | SBOS-035-NEXUS-HOST-v1_0, SBOS-036-NEXUS-AGENT-v1_0 |

> **Principio rector:** bAuth, bhnexus y banexus son **tres daemons distintos** —
> tres binarios independientes, tres servicios systemd, cada uno vivo esperando señales.
> Su relación no es de fusión sino de **dependencia de ciclo de vida con independencia
> de propósito**: bhnexus no puede existir sin bAuth, pero tiene su propio binario,
> su propio proceso y su propia razón de ser. La documentación conceptual maestra vive
> en bAuth como autoridad de diseño; el código de cada uno vive en su propio directorio.

**Reemplaza:** SBOS-NEXUS-CONCEPTUALIZACION v1.0 y v2.0.
**Integra:** árbol físico de 11 niveles, HAL multi-protocolo, decisiones R-P4, R-Gap6, todas las decisiones de sesión Febrero–Abril 2026.
**v3.6 (2026-08-04):** correcciones de consistencia — eliminadas referencias KC/Tryton (ADR-010); modelo de identidad corregido a `idn_identity_entity` universal (Sección 11); banexus 5 formas canónicas con taxonomía completa (Sección 20.5); `nodes.yml`/`device_fichas` eliminados, sustituidos por SBOSDB.
**v3.7 (2026-08-04):** Sección 20 completamente reescrita — declaración arquitectónica fundamental (bAuth como OIDC Provider universal para cualquier lenguaje y framework); SBOS como primer tenant interno de su propio bAuth; modelo de tenants (interno vs externo, protocolo idéntico); banexus-implicit reposicionado como caso universal base (Forma 1, no 5); garantía universal de trazabilidad y auditoría como principio de primer orden; tres planos actualizados para reflejar la nueva jerarquía.

---

## TABLA DE CONTENIDOS

1. bNexus como Motor de Comunicación Física de bAuth
2. Definición Canónica de bhnexus
3. Definición Canónica de banexus
4. La Topología Invariable
5. El Flujo Soberano Completo
6. Arquitectura Interna de bhnexus
7. Arquitectura Interna de banexus
8. El Protocolo WebSocket bhnexus ↔ banexus
9. La HAL — Hardware Abstraction Layer
10. El Árbol Jerárquico de Ubicaciones Físicas
11. Identidades en el Árbol Universal
12. El Cache de bhnexus y el Cache Efímero de banexus
13. Comportamiento Offline y Fail-Secure
14. Flujos por Tipo de Credencial
15. Flujo de Política: Cuando el RolTemplate Cambia
16. Monitoreo, Alertas y Auto-Recuperación
17. Configuración (bhnexus.toml y banexus.toml)
18. Lo que NEXUS ES y NO ES
19. Posicionamiento en los 8 Daemons Soberanos

---

## 1. BNEXUS COMO MOTOR DE COMUNICACIÓN FÍSICA DE BAUTH

bNexus no es un solo daemon — es el **motor de comunicación física de bAuth**, compuesto por tres capas que operan como una sola entidad funcional: bAuth (identidad y política), bhnexus (ruteador físico, en el servidor central) y banexus (frontera, en cada nodo o cliente).

```
┌─────────────────────────────────────────────────────────────┐
│                  NEXUS como unidad                           │
│                                                             │
│  ┌──────────────────────┐   mTLS   ┌────────────────────┐  │
│  │       banexus        │◄────────►│      bhnexus       │  │
│  │   (Edge Sentinel)    │ WebSocket │ (Connectivity      │  │
│  │                      │          │  Broker)           │  │
│  │  • Intercepta USB    │          │  • Router central  │  │
│  │  • Shell sentinel    │          │  • Auth cache      │  │
│  │  • Activa actuadores │          │  • Hardware Bridge │  │
│  │  • Cache efímero     │          │  • Consulta bAuth  │  │
│  └──────────────────────┘          └────────┬───────────┘  │
│         (nodo Fedora)                        │ Unix socket  │
│                                             ▼              │
│                                    ┌────────────────────┐  │
│                                    │       bAuth        │  │
│                                    │  (fuente de verdad │  │
│                                    │   de identidad)    │  │
│                                    └────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**La misión conjunta:** interceptar TODO evento de credencial física antes de que el SO lo procese, resolverlo contra bAuth, y ejecutar las acciones autorizadas (liberar shell, activar actuadores) de forma atómica y en menos de 50ms.

---

## 2. DEFINICIÓN CANÓNICA DE BHNEXUS

**Nombre formal:** SBOS Nexus Host — Sovereign Connectivity Broker & Multiprotocol Gateway

**Daemon:** `bhnexus` — servicio de sistema en el host Ubuntu 24.04 LTS

**Lenguaje:** Rust 1.85+ MUSL (tokio async, 10.000+ conexiones WebSocket concurrentes con ~8–15 MB RAM)

### Lo que bhnexus PUEDE hacer

- **Router central:** todo tráfico de credenciales físicas del SBOS pasa por bhnexus. Es el único componente autorizado a consultar bAuth sobre eventos de acceso físico.
- **Auth Cache:** SAM-128 en memoria con TTL 30s. Cache hit = respuesta a banexus sin consultar bAuth. Cache miss = consulta Unix socket a bAuth.
- **Hardware Bridge:** traduce protocolos industriales (OSDP v2, MQTT, ONVIF, HTTP) a CredentialEvent normalizado. No modifica firmware de dispositivos.
- **Multi-destino:** envía el SAM-128 al shell de Fedora Y los comandos de actuación (OPEN_RELAY) a las controladoras de puertas simultáneamente, en el mismo frame de respuesta.
- **Distribuidor de políticas:** cuando bAuth actualiza un RolTemplate, bhnexus recibe el push y propaga la invalidación de cache a todos los banexus afectados.

### Lo que bhnexus NO PUEDE hacer

```
✗ Procesar lógica de negocio (impuestos, inventarios, contabilidad)
✗ Almacenar templates biométricos (es un negociador de tránsito)
✗ Autenticación primaria — bhnexus solo aplica la decisión de bAuth (PDP nativo), no toma decisiones propias
✗ Crear o modificar RolTemplates o UserTemplates
✗ Operar sin bAuth (si bAuth está caído, opera con cache hasta expiración TTL)
```

---

## 3. DEFINICIÓN CANÓNICA DE BANEXUS

**Nombre formal:** SBOS Nexus Agent — Edge Sentinel & Multi-Input Interceptor

**Daemon:** `banexus.service` — systemd --user en cada nodo Fedora

**Lenguaje:** Rust 1.85+ MUSL (binario estático, sin dependencias de runtime)

**Carácter:** monogámico — ignora todo tráfico que no provenga del bhnexus verificado por certificado mTLS.

### Lo que banexus PUEDE hacer

- **Input Hooking:** captura señales USB/serial (QR, NFC, código de barras) a nivel de bus vía udev rules + libusb, ANTES de que el dato llegue al sistema de input de Fedora.
- **Shell Sentinel:** intercepta comandos shell sensibles vía PAM module (`pam_banexus.so`), congela la ejecución, consulta a bhnexus, y libera o bloquea según la respuesta.
- **Control de Actuadores:** ejecuta apertura de relés (puertas, cajones) via serial/GPIO tras recibir orden firmada de bhnexus.
- **Cache Efímero:** almacena copia AES-256-GCM de la última política recibida para operar durante desconexiones temporales.
- **Auto-Verificación de Integridad:** calcula SHA-256 de su propio binario cada 5 minutos. Si hay discrepancia → alerta crítica a bhnexus + auto-shutdown.

### Lo que banexus NO PUEDE hacer

```
✗ Gestión de identidad — es responsabilidad exclusiva de bAuth (PDP nativo, ADR-010)
✗ Crear permisos nuevos — solo aplica los recibidos de bhnexus
✗ Comunicarse directamente con bAuth — siempre vía bhnexus
✗ Almacenar datos biométricos — solo captura y reenvía el hash
✗ Comunicarse con más de un bhnexus — monogámica por diseño
```

---

## 4. LA TOPOLOGÍA INVARIABLE

```
                    banexus
                       │
                 WebSocket mTLS
                       │
                    bhnexus
                       │
                  Unix socket
                       │
                     bAuth

NUNCA:
  banexus → bAuth          (saltar bhnexus = perder routing y cache)
  dispositivo → bhnexus    (saltar banexus = perder interceptación soberana)
  dispositivo → bAuth      (saltar ambos = perder todo el control)
  banexus → cualquier servicio externo de identidad (bAuth es el único PDP del ecosistema)
```

**Justificación de la topología:** Sin banexus no hay interceptación del evento USB/serial antes del SO. Sin bhnexus no hay cache, routing, ni distribución del SAM. Si cualquier dispositivo pudiera hablar directamente con bAuth, se rompe la cadena de custodia del evento de autenticación física.

---

## 5. EL FLUJO SOBERANO COMPLETO

El "Flujo Soberano" es el caso de uso estrella que demuestra la coordinación de los 3 daemons (banexus + bhnexus + bAuth) y la ejecución física atómica en menos de 50ms.

### Flujo 1 — QR en terminal Fedora (vendedor abre caja)

```
T+0.000s  Vendedor presenta QR al lector USB de la terminal Fedora

T+0.001s  banexus: udev intercepta datos del bus USB
          ANTES de que evdev los pase al sistema de input de Fedora
          banexus firma el payload: HMAC-SHA256(secret, payload+timestamp)

T+0.002s  banexus → bhnexus (WebSocket mTLS):
          {
            "type": "auth_request",
            "request_id": "uuid-req",
            "node_id": "Ventas-01",
            "input_type": "qr",
            "payload": "sbos://auth/user-uuid/1713000000/hmac...",
            "timestamp": "2026-04-15T10:30:00Z"
          }

T+0.005s  bhnexus: identifica nodo "Ventas-01"
          Verifica estructura del QR: sbos://auth/{user_id}/{ts}/{hmac}
          Verifica: timestamp < 30s ago AND HMAC válido

T+0.006s  bhnexus: ¿SAM-128 en cache para user-uuid @ Ventas-01?
          SÍ (TTL no expirado) → T+0.007s: SAM del cache
          NO → consulta bAuth via Unix socket

T+0.008s  bhnexus → bAuth (Unix socket):
          {
            "user_id": "user-uuid",
            "node_id": "Ventas-01",
            "query_type": "bitmask"
          }

T+0.010s  bAuth evalúa (RolTemplate del usuario):
          Dominio lógico:    red 10.0.1.45 ∈ 10.0.1.0/24 ✓
                             hora 10:30 ∈ 08:00-18:00 ✓
                             LoA 2 (pwd+OTP) suficiente ✓
          Dominio físico:    nodo "Ventas-01" ∈ zone_ventas ✓
                             security_level=2 OK ✓
          Dominio financiero: limit_tier=2 (10.000 BOB) ✓

T+0.012s  bAuth retorna SAM-128:
          {
            "granted": true,
            "sam128": "0x0000010900000300 0001001700010052",
            "ttl_seconds": 28800,
            "actuator_commands": [
              {"target": "RELAY_01", "action": "OPEN", "duration_ms": 5000}
            ]
          }

T+0.013s  bhnexus: almacena SAM en cache (TTL 30s)

T+0.014s  bhnexus → banexus (WebSocket):
          {
            "type": "auth_response",
            "request_id": "uuid-req",
            "status": "granted",
            "sam128": "0x0000010900000300 0001001700010052",
            "user_name": "Ivan Cajero",
            "ttl_seconds": 28800,
            "actuator_commands": [
              {"target": "RELAY_01", "action": "OPEN", "duration_ms": 5000}
            ]
          }

T+0.015s  banexus ejecuta en PARALELO (atómico):
          1. LOG_SHELL_UNLOCK (bit 17) = 1
             → PAM libera el login de Fedora
             → KDE Plasma aparece con perfil del usuario
          2. FIN_CAJA_OPEN via RELAY_01
             → Serial: envía comando OPEN al relé
             → Cajón de dinero se abre físicamente
          3. banexus almacena SAM en cache efímero (AES-256-GCM)

LATENCIA TOTAL: ~15ms
OBJETIVO: < 50ms
```

### Flujo 2 — Huella dactilar en puerta sala de servidores

```
T+0.000s  Técnico de TI presenta dedo en lector OSDP v2

T+0.001s  Lector OSDP (Biometric Profile):
          → Sensor captura imagen dactilar
          → Template extraído LOCALMENTE en el chip del lector
          → Template convertido a hash LOCALMENTE
          → Hash enviado por canal OSDP Secure (AES) al controlador

T+0.002s  bhnexus (OSDP driver): recibe paquete OSDP
          → Normaliza a CredentialEvent:
          {
            "type": "auth_request",
            "input_type": "fingerprint_hash",
            "payload": "<hash_cifrado>",
            "device_id": "PHY_DEV_FP_SALA_SERV",
            "location_id": "PHY_AP_SALA_SERV_PUERTA"
          }

T+0.006s  bhnexus → bAuth (Unix socket):
          {
            "query_type": "biometric",
            "payload_hash": "<hash>",
            "device_id": "PHY_DEV_FP_SALA_SERV"
          }

T+0.008s  bAuth:
          → Descifra payload con clave de Vault
          → Verifica hash contra bauth_biometric_templates
          → Match: user_id = "tech-uuid"
          → Evalúa RolTemplate:
            security_level requerido por PHY_SALA_SERV = 3 (restringido)
            GOV_LOA_LEVEL = 0100 (LoA 3, biométrico) ✓
            PHY_ZONE_D activo (sala servidores) ✓
            Horario 10:05 ∈ 08:00-18:00 ✓

T+0.010s  bAuth retorna SAM con GOV_LOA_LEVEL = LoA 3
          + actuator: LOCK_SALA_SERV: OPEN (5 segundos)

T+0.011s  bhnexus → OSDP driver:
          SendCommand(LOCK_SALA_SERV, OPEN, 5000ms)

T+0.012s  Puerta sala servidores se abre

LATENCIA TOTAL: ~12ms
NINGÚN DATO BIOMÉTRICO salió del chip del lector hacia ningún servidor.
Solo el HASH viajó. RGPD compliant.
```

### Flujo 3 — Shell Sentinel (comando sensible en terminal)

```
Técnico intenta ejecutar: sudo dnf install <paquete>

PAM module pam_banexus.so intercepta:
  → banexus recibe: {type: "shell_auth", command: "dnf install", user: "ivan"}
  → banexus → bhnexus → bAuth (consulta LOG_EXECUTE bit 4)
  → bAuth: LOG_EXECUTE = 0 para este usuario en este nodo

bhnexus → banexus: {status: "denied", reason: "insufficient_privileges"}

PAM module:
  → Bloquea el comando
  → Notifica al usuario: "Acción no autorizada. Contacte al administrador."
  → Log en bkernel_db.audit_events

Si LOG_EXECUTE = 1 (técnico de TI con permisos):
  → PAM libera el comando → ejecuta normalmente
```

---

## 6. ARQUITECTURA INTERNA DE BHNEXUS

```
┌──────────────────────────────────────────────────────────────┐
│                     bhnexus (Rust)                           │
│                                                              │
│  ┌─────────────────┐  ┌──────────────────────────────────┐  │
│  │  WebSocket       │  │      Hardware Bridge             │  │
│  │  Manager         │  │                                  │  │
│  │                  │  │  ┌──────────┐  ┌──────────────┐  │  │
│  │  Agents[]        │  │  │ OSDP v2  │  │ MQTT 5.0     │  │  │
│  │  (banexus nodes) │  │  │ Driver   │  │ Driver       │  │  │
│  │                  │  │  └──────────┘  └──────────────┘  │  │
│  │  10.000+         │  │  ┌──────────┐  ┌──────────────┐  │  │
│  │  conexiones WS   │  │  │ ONVIF    │  │ HTTP/REST    │  │  │
│  └────────┬─────────┘  │  │ Driver   │  │ Driver       │  │  │
│           │            │  └──────────┘  └──────────────┘  │  │
│           │            │  ┌──────────┐                     │  │
│           │            │  │ Wiegand  │  Identidades en     │  │
│           │            │  │ Adapter  │  SBOSDB (idn_iden.  │  │
│           │            │  └──────────┘  _entity + D93)     │  │
│           │            └──────────────────────────────────┘  │
│           │                           │                      │
│  ┌────────▼───────────────────────────▼────────────────────┐ │
│  │              Request Router                              │ │
│  │   Identifica nodo + tipo de solicitud + device_id        │ │
│  └──────────────────────────────┬───────────────────────────┘ │
│                                 │                             │
│  ┌──────────────────────────────▼───────────────────────────┐ │
│  │              Auth Cache (in-memory)                      │ │
│  │   SAM-128 por (user_id, node_id)                        │ │
│  │   TTL: 30s configurable │ Max entries: 10.000            │ │
│  └──────────────────────────────┬───────────────────────────┘ │
│                      cache miss │                             │
│  ┌──────────────────────────────▼───────────────────────────┐ │
│  │              bAuth Client                                │ │
│  │   Unix socket /run/bos/bauth.sock                       │ │
│  │   Latencia < 5ms │ Timeout: 1s │ Retry: 3 intentos       │ │
│  └──────────────────────────────┬───────────────────────────┘ │
│                                 │                             │
│  ┌──────────────────────────────▼───────────────────────────┐ │
│  │              Response Dispatcher                         │ │
│  │   → SAM-128 + user_name al agente banexus                │ │
│  │   → actuator_commands al driver de hardware              │ │
│  │   → Ambos enviados en el mismo frame (atomicidad)        │ │
│  └──────────────────────────────────────────────────────────┘ │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Policy Dispatcher                           │ │
│  │   Recibe policy_update de bAuth                         │ │
│  │   Invalida cache de SAM afectados                       │ │
│  │   Envía invalidación a banexus afectados                │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 7. ARQUITECTURA INTERNA DE BANEXUS

```
┌──────────────────────────────────────────────────────────────┐
│              banexus (Rust — systemd --user en Fedora)        │
│                                                              │
│  ┌────────────────────────┐  ┌─────────────────────────────┐ │
│  │  WebSocket Client       │  │  Input Interceptor           │ │
│  │  (mTLS a bhnexus)       │  │                             │ │
│  │                         │  │  udev rules → /dev/banexus/ │ │
│  │  Reconexión:            │  │  libusb → captura raw data  │ │
│  │  backoff exp.           │  │  ANTES de evdev             │ │
│  │  1→5→15→30→60s max      │  └─────────────┬───────────────┘ │
│  └────────────┬────────────┘                │               │
│               │                             │               │
│  ┌────────────▼─────────────────────────────▼─────────────┐ │
│  │              Event Normalizer                          │ │
│  │   Raw USB/serial → CredentialEvent{type, payload}      │ │
│  └──────────────────────────────┬──────────────────────────┘ │
│                                 │                            │
│  ┌──────────────────────────────▼──────────────────────────┐ │
│  │              Policy Cache (efímero)                     │ │
│  │   AES-256-GCM con clave derivada del certificado mTLS   │ │
│  │   TTL igual al SAM recibido de bhnexus                  │ │
│  │   Si TTL expirado → DENY todo (fail-secure)             │ │
│  └──────────────────────────────┬──────────────────────────┘ │
│                                 │                            │
│  ┌────────────────┬─────────────┘                            │
│  │                │                                          │
│  ▼                ▼                                          │
│  Shell Sentinel   Actuator Controller                        │
│  PAM module       serial/GPIO                                │
│  freeze→consult   RELAY_ON/OFF                               │
│  →release/deny    timer auto-close                           │
│                                                              │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │              Integrity Monitor                           │ │
│  │   SHA-256(/opt/banexus/banexus) cada 5 min              │ │
│  │   vs /etc/banexus/banexus.sha256                        │ │
│  │   Discrepancia → alerta crítica + auto-shutdown          │ │
│  └──────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
```

---

## 8. EL PROTOCOLO WEBSOCKET BHNEXUS ↔ BANEXUS

### Conexión (mTLS obligatorio)

```
banexus → bhnexus: WSS upgrade
  Headers:
    X-Node-ID: "Ventas-01"
    X-Agent-Version: "1.0.0"
    X-Agent-Cert-Fingerprint: "sha256:abc123..."

bhnexus verifica:
  1. Certificado mTLS válido (CA interna del SBOS)
  2. Node-ID registrado en SBOSDB (bauth.idn_identity_entity, entity_type='banexus_node')
  3. Versión del agente compatible (semver)
  4. Cert fingerprint contra registro de nodos

SI OK  → conexión establecida, agente en Agents[]
SI FAIL → 403 Forbidden + log de intento + alerta Wazuh
```

### Frames de Comunicación

```json
// banexus → bhnexus: solicitud de autorización
{
  "type": "auth_request",
  "request_id": "uuid-v4",
  "node_id": "Ventas-01",
  "input_type": "qr",
  "payload": "sbos://auth/user-uuid/1713000000/hmac...",
  "device_id": "PHY_DEV_QR_ZV_PUERTA_PRIN",
  "timestamp": "2026-04-15T10:30:00Z"
}

// bhnexus → banexus: respuesta autorizada
{
  "type": "auth_response",
  "request_id": "uuid-v4",
  "status": "granted",
  "sam128": "0x0000010900000300 0001001700010052",
  "user_id": "user-uuid",
  "user_name": "Ivan Cajero",
  "ttl_seconds": 28800,
  "actuator_commands": [
    { "target": "RELAY_01", "action": "OPEN", "duration_ms": 5000 }
  ],
  "timestamp": "2026-04-15T10:30:00.015Z"
}

// bhnexus → banexus: respuesta denegada
{
  "type": "auth_response",
  "request_id": "uuid-v4",
  "status": "denied",
  "reason": "outside_schedule",
  "message": "Acceso fuera de horario autorizado (08:00–18:00)",
  "timestamp": "2026-04-15T20:15:00Z"
}

// bhnexus → banexus: push de invalidación de política
{
  "type": "policy_update",
  "reason": "roltemplate_changed",
  "affected_users": ["user-uuid-1", "user-uuid-2"],
  "action": "invalidate_cache",
  "timestamp": "2026-04-15T11:00:00Z"
}

// banexus → bhnexus: heartbeat (cada 30s)
{
  "type": "heartbeat",
  "node_id": "Ventas-01",
  "uptime_seconds": 86400,
  "active_sessions": 2,
  "cache_entries": 3,
  "last_auth_ts": "2026-04-15T10:30:00Z",
  "integrity_ok": true
}

// banexus → bhnexus: solicitud shell sentinel
{
  "type": "shell_auth",
  "node_id": "Ventas-01",
  "user": "ivan.cajero",
  "command": "apt-get install vim",
  "timestamp": "2026-04-15T10:35:00Z"
}
```

### Reconexión con Backoff Exponencial

```
Si WebSocket pierde conexión:
  banexus intenta reconectar:
    1s → 5s → 15s → 30s → 60s (máximo, repite cada 60s)

Durante desconexión:
  banexus opera con cache efímero
  Si SAM en cache y TTL vigente → responde localmente
  Si TTL expirado → DENY todo (fail-secure)

Al reconectar:
  banexus envía heartbeat con actividad offline
  bhnexus envía policy_update si hubo cambios
  banexus invalida cache y recibe SAM fresco
```

---

## 9. LA HAL — HARDWARE ABSTRACTION LAYER

### El Principio

**Agregar un dispositivo al SBOS es declarativo — no requiere código.**

Si el protocolo del dispositivo ya está soportado → solo necesita registrar la identidad del dispositivo en SBOSDB (`bauth.auth_device`) y declarar los parámetros de conexión en `bhnexus.toml`.
Si el protocolo es nuevo → se agrega un driver Rust (crate) sin modificar el núcleo de bhnexus.

### La Interfaz DeviceDriver

```rust
/// Trait que todo driver implementa
#[async_trait]
pub trait DeviceDriver: Send + Sync {
    fn protocol(&self) -> &str;                          // "osdp_v2", "mqtt", etc.
    async fn connect(&mut self, params: ConnectionParams) -> Result<(), DriverError>;
    async fn listen(&self, tx: Sender<CredentialEvent>) -> Result<(), DriverError>;
    async fn send_command(&self, cmd: ActuatorCommand) -> Result<(), DriverError>;
    fn health_check(&self) -> DeviceHealth;
    async fn disconnect(&mut self) -> Result<(), DriverError>;
}

/// CredentialEvent — el lenguaje universal de la HAL
/// Todos los drivers producen este tipo, sin excepción
pub struct CredentialEvent {
    pub event_id:        Uuid,
    pub timestamp:       DateTime<Utc>,
    pub device_id:       DeviceId,       // "PHY_DEV_QR_ZV_PUERTA_PRIN"
    pub location_id:     LocationId,     // "PHY_AP_ZV_PUERTA_PRIN"
    pub node_id:         NodeId,         // "Ventas-01"
    pub credential_type: CredentialType, // QR_DYNAMIC|NFC_MIFARE_DESFIRE|FINGERPRINT_HASH|...
    pub payload:         Bytes,          // cifrado con clave de Vault
    pub direction:       Direction,      // Entry | Exit
    pub raw_protocol:    String,         // para audit: "osdp_v2", "wiegand", etc.
}
```

### Drivers Incluidos en bhnexus v1.0

| Driver | Protocolo | Dispositivos típicos | Seguridad |
|---|---|---|---|
| `osdp_driver.rs` | OSDP v2.2.2 (SIA/IEC 60839-11-5) | Lectores NFC, RFID, biométrico, teclados | ✅ AES cifrado, bidireccional |
| `wiegand_driver.rs` | Wiegand 26/34/37-bit | Lectores legacy (40+ años) | ⚠️ Sin cifrado — solo legacy |
| `mqtt_driver.rs` | MQTT 5.0 | IoT, sensores, actuadores industriales | ✅ TLS, QoS configurable |
| `onvif_driver.rs` | ONVIF Profile S/T | Cámaras IP de seguridad | ✅ HTTPS, auth digest |
| `usb_hid_driver.rs` | USB HID (en banexus) | Lectores QR USB, NFC USB (ACR122U) | ✅ Local a banexus |
| `http_driver.rs` | REST HTTPS | Terminales POS, interfonos IP, kioskos | ✅ TLS, flexible |

### Tipos de Credencial Soportadas

| Tipo | Protocolo habitual | Seguridad | LoA otorgado |
|---|---|---|---|
| `QR_DYNAMIC` | USB HID / OSDP Basic | Alto (HMAC-SHA256, TTL 30s) | 1–2 |
| `NFC_MIFARE_DESFIRE` | OSDP Smart Card | Alto (AES-128) | 2 |
| `NFC_MIFARE_CLASSIC` | RFID 13.56 MHz | Medio (clonable) | 1 |
| `RFID_125KHZ` | Wiegand / RS-485 | Bajo (muy clonable) | 1 |
| `FINGERPRINT_HASH` | OSDP Biometric | Muy alto (hash local en chip) | 3 |
| `FACE_HASH` | OSDP Biometric / ONVIF | Muy alto | 3 |
| `IRIS_HASH` | OSDP Biometric | Máximo | 3–4 |
| `SMARTCARD_X509` | OSDP Smart Card / CCID | Máximo (PKI) | 3–4 |
| `BLE_TOKEN` | BLE 5.x | Alto (emparejamiento seguro) | 2 |
| `PIN_HASH` | OSDP Basic | Bajo (sin posesión) | 1 |

---

## 10. EL ÁRBOL JERÁRQUICO DE UBICACIONES FÍSICAS

11 niveles. Administrado desde Core UI (interfaz de bAuth). Almacenado en PostgreSQL. Sincronizado con bhnexus como location fichas YAML en `/etc/bos/blibs/bhnexus/locations/`.

```
NIVEL 0  TENANT
  → El servidor SBOS de la empresa. Límite de soberanía. No es zona física.

NIVEL 1  REGIÓN / PAÍS
  → Bolivia | Argentina | México
  → Governa: timezone, normativa fiscal, retención de logs
  → Ejemplo ID: PHY_REGION_BO

NIVEL 2  CIUDAD / MUNICIPIO
  → La Paz | Cochabamba | Santa Cruz de la Sierra
  → Ejemplo ID: PHY_CITY_LPZ

NIVEL 3  SITIO / CAMPUS
  → Dirección física específica (puede haber múltiples por ciudad)
  → Ejemplo: "PHY_SITE_LPZ_001 — Av. Camacho 1234, La Paz"
  → Governa: schedule_default, horario base del sitio

NIVEL 4  EDIFICIO / ESTRUCTURA
  → Edificio dentro del sitio
  → Ejemplo: PHY_BLDG_A, PHY_BLDG_ALMACEN, PHY_BLDG_TORRE

NIVEL 5  PLANTA / PISO     ← primer nivel donde se ubican dispositivos (auth_device en SBOSDB)
  → Nivel vertical dentro del edificio
  → Ejemplo: PHY_FLOOR_PB (Planta Baja), PHY_FLOOR_1 (Piso 1)

NIVEL 6  ZONA / ÁREA
  → Área funcional dentro de la planta
  → Ejemplo: PHY_ZONE_VENTAS, PHY_ZONE_PROD, PHY_ZONE_ADMIN

NIVEL 7  ESPACIO / HABITACIÓN / SALA
  → Espacio delimitado dentro de una zona
  → Ejemplo: PHY_ROOM_JUNTAS, PHY_ROOM_SERVIDOR, PHY_ROOM_BOVEDA
  → security_level 3–4 para espacios críticos

NIVEL 8  PUNTO DE ACCESO
  → Apertura física entre espacios (puerta, ventana)
  → Ejemplo: PHY_AP_VENTAS_PUERTA_PRIN

NIVEL 9  CERRADURA / CONTROL
  → Mecanismo que controla el punto de acceso
  → mode: fail_secure (cierra sin poder) | fail_safe (abre sin poder)
  → REGLA: puertas de emergencia/escape SIEMPRE son fail_safe (ley)

NIVEL 10 DISPOSITIVO / LECTOR
  → El hardware que captura la credencial
  → Referencia al driver en la HAL (protocolo, connection params)
  → Ejemplo: PHY_DEV_QR_ZV_PUERTA_PRIN (lector QR OSDP v2)
```

### Herencia de Permisos en el Árbol

```
PHY_SITE_LPZ_001 (acceso al sitio completo)
  └── PHY_BLDG_A
        ├── PHY_FLOOR_P1
        │     ├── PHY_ZONE_VENTAS     ← ROL_CAJERO (security_level=2)
        │     └── PHY_ZONE_ADMIN      ← ROL_ADMIN  (security_level=2)
        └── PHY_FLOOR_P2
              └── PHY_ROOM_SERVIDORES ← ROL_IT     (security_level=3)
```

**Regla:** permiso en nivel superior cubre todos los sub-nodos. Una restricción explícita en un nivel inferior prevalece.

**SAM-128 Q2:** los bits representan `security_level` (1=público, 2=empleados, 3=restringido, 4=crítico). La location ficha resuelve `zone_id → security_level`. banexus evalúa O(1) sin conocer la semántica de la jerarquía.

---

## 11. IDENTIDADES EN EL ÁRBOL UNIVERSAL — `idn_identity_entity`

En bAuth **todo es una entidad**: un empleado, una empresa, un vehículo, un servidor,
una puerta con OSDP, un bot de integración, un nodo banexus. Todas comparten las mismas
tres tablas y el mismo motor de validación. Lo que distingue a cada entidad no es la tabla
— es el `entity_type` y los atributos que porta.

### 11.1 El árbol universal de 5 niveles

```
idn_identity_entity — árbol de adyacencia, 5 niveles fijos, entity_type variable

NIVEL 0  tenant        → raíz de aislamiento (interno / externo)
NIVEL 1  bdomain       → unidad principal: empresa, edificio, datacenter, flota, almacen, hogar…
NIVEL 2  bsubdomain    → división: sucursal, sala, deposito, zona, piso, habitacion…
NIVEL 3  pos           → punto de operación: puerta, caja, terminal, sensor, actuador, cámara, rack…
NIVEL 4  actor         → quien opera: HUMAN · SERVICE · DEVICE · BOT
                         o también:   vehiculo · servidor · producto · equipo · maquina
```

La jerarquía es **fija**; el `entity_type` es **variable**. Esto permite al sistema de
identidad operar como registro maestro de cualquier sector — RRHH, inventario, flota, TI,
control de acceso físico — sin tocar el DDL.

---

### 11.2 Cómo se registra cada tipo de entidad en bNexus

| Entidad | Nivel | `entity_type` | Función en bNexus |
|---------|-------|---------------|-------------------|
| Edificio / campus | `bdomain` | `edificio` | Contenedor geográfico |
| Planta / piso | `bsubdomain` | `piso` | División física del edificio |
| Zona de acceso | `bsubdomain` | `zona` | Área con security_level propio |
| Puerta con cerradura | `pos` | `puerta` | Punto de acceso controlado |
| Cámara de vigilancia | `pos` | `camara` | Punto de captura de video |
| Sensor / actuador | `pos` | `sensor` / `actuador` | Punto de captura o acción |
| Lector OSDP / NFC | `actor` | `DEVICE` | Hardware que captura credenciales |
| Servidor / rack | `actor` | `servidor` | Infraestructura de TI |
| banexus (daemon) | `actor` | `SERVICE` | Agente de frontera de bAuth |
| bhnexus (daemon) | `actor` | `SERVICE` | Ruteador de comunicación física |
| Bot / pipeline | `actor` | `BOT` | Integración automatizada |
| Empleado / usuario | `actor` | `HUMAN` | Identidad humana con credenciales |

> **Regla central:** `user_id` en todas las tablas de bauth es el `entity_id` de un nodo
> tipo `actor` en `idn_identity_entity`. Aplica para humanos, daemons y dispositivos por igual.

---

### 11.3 Las tres tablas del modelo de identidad (NIST SP 800-63-4)

```
T-156  idn_identity_entity     ← Capa 1: QUIÉN es (árbol organizacional)
T-320  idn_user                ← Capa 2: CÓMO accede (Subscriber Account, por tenant)
T-330  auth_credential         ← Capa 3: CON QUÉ se autentica (X.509, FIDO2, TOTP…)
```

Un mismo `entity_id` puede tener cuentas en distintos tenants. La entidad es única;
la cuenta es el objeto de login.

**Atributos:** `idn_identity_attribute` (EAV) almacena los datos de cada entidad —
namespaces: `core`, `professional`, `verification`, `security`, `contact`, `fiscal`.
Para un lector OSDP: serial, firmware, osdp_address, ubicación, fabricante.
Para un nodo banexus: node_id, SPIFFE ID, location_id, protocolo.

---

### 11.4 Ejemplo completo — registro de un lector OSDP como entidad

```
SKULL (tenant)
  └── Edificio-Central (bdomain, edificio)
        └── Planta-1 (bsubdomain, piso)
              └── Puerta-Principal (pos, puerta)
                    └── Lector-OSDP-001 (actor, DEVICE)   ← entidad en idn_identity_entity
                          ├── idn_identity_attribute:
                          │     security.serial      = "ZK-SB1000-4F2A"
                          │     security.osdp_address = "1"
                          │     security.firmware    = "v3.2.1"
                          │     core.fabricante      = "ZKTeco"
                          └── (sin idn_user — no se loguea como suscriptor)
                              (sin auth_credential — no autentica con contraseña)
```

El lector NO necesita `idn_user` ni `auth_credential` porque no inicia sesión por su
cuenta. **bhnexus HAL lo controla directamente** mediante su driver OSDP — el lector
es un endpoint, no un sujeto autenticable.

---

### 11.5 Ejemplo completo — registro de banexus como entidad con cuenta

```
SKULL (tenant)
  └── Datacenter (bdomain, datacenter)
        └── Sala-Servidores (bsubdomain, sala)
              └── Rack-01 (pos, rack)
                    └── banexus-ventas-01 (actor, SERVICE)   ← entidad en idn_identity_entity
                          ├── idn_identity_attribute:
                          │     security.node_id   = "Ventas-01"
                          │     security.spiffe_id = "spiffe://sbos.skull/agent/banexus/Ventas-01"
                          │     core.location      = "PHY_ZONE_VENTAS"
                          ├── idn_user:
                          │     username   = "banexus-ventas-01"
                          │     loa_min    = "AAL3"              ← mTLS obligatorio
                          │     ial_achieved = "IAL1"
                          └── auth_credential + auth_credential_x509:
                                method_code = "MTLS_X509"
                                vault_path  = "pki/bauth/banexus/ventas-01"
```

El daemon banexus SÍ necesita `idn_user` y `auth_credential_x509` porque se autentica
ante bhnexus con mTLS. Su **rol** tiene `type_id = 'SERVICE'` (del catálogo
`idn_roles_rol_type`) — lo que permite al PDP aplicar políticas específicas para agentes
de servicio.

---

### 11.6 Tablas complementarias — postura y gobernanza

Estas tablas son **complementarias** al árbol de identidad — añaden información de
hardware y gobernanza, pero no reemplazan a `idn_identity_entity`:

| Tabla | Propósito real | Para quién |
|-------|----------------|------------|
| `auth_device` | **Postura de hardware**: trust_level, MDM, OSDP config, AAGUID FIDO2, last_seen | Dispositivos físicos con WebAuthn o OSDP — tracking de seguridad del hardware |
| `auth_device_posture` | Evaluación de postura (antivirus, parches, cifrado de disco) | Laptops y móviles corporativos bajo MDM |
| `idn_roles_nhi_identity` | **Gobernanza NHI**: propietario, fecha de revisión, rotación de secretos | Daemons y service accounts — ciclo de vida de identidades máquina |
| `idn_nhi_svid` | SPIFFE SVID (X.509/JWT) para mTLS | bhnexus, banexus — autenticación workload |

> **Error a evitar:** `auth_device` NO es la identidad del dispositivo en el sistema —
> es información de postura de seguridad de su hardware. La identidad está en
> `idn_identity_entity`. Un dispositivo puede existir en `idn_identity_entity` sin
> tener fila en `auth_device` (si no requiere tracking MDM ni WebAuthn).

---

### 11.7 Ciclo de registro declarativo — agregar un dispositivo nuevo

```
CASO 1: Protocolo ya soportado (OSDP, Wiegand, MQTT, ONVIF, USB, HTTP)

  1. bos crea la entidad en el árbol
     INSERT INTO bauth.idn_identity_entity
       (level='actor', entity_type='DEVICE', slug='lector-osdp-001', ...)

  2. bos agrega atributos físicos
     INSERT INTO bauth.idn_identity_attribute
       (entity_id, attr_namespace='security', attr_key='osdp_address', attr_value='1')

  3. bos declara los parámetros de conexión en bhnexus.toml
     [[devices.osdp]]
     entity_slug  = "lector-osdp-001"     # referencia a idn_identity_entity
     port         = "/dev/ttyUSB0"
     osdp_address = 1

  4. bos recarga: bhnexus SIGHUP → instancia DeviceDriver → health check
  5. Dispositivo activo en < 30 segundos
  → SIN código, SIN compilación, SIN reinicio del daemon

CASO 2: Protocolo nuevo no soportado
  1. Implementar driver Rust que implemente el trait DeviceDriver
  2. Agregar como crate feature en Cargo.toml de bhnexus
  3. Compilar bhnexus con la feature activada
  4. Registrar entidad en árbol (Pasos 1-4 del Caso 1)
  → Código del driver, sin modificar el núcleo de bhnexus
```

---

### 11.8 Separación de responsabilidades

| Pregunta | Respuesta | Dónde vive |
|----------|-----------|------------|
| **¿QUIÉN es?** | Entidad en el árbol organizacional | `idn_identity_entity` (nivel + entity_type) |
| **¿QUÉ atributos tiene?** | Serial, firmware, ubicación, protocolo… | `idn_identity_attribute` (EAV por namespace) |
| **¿CÓMO accede al sistema?** | Cuenta de suscriptor | `idn_user` (solo si se autentica) |
| **¿CON QUÉ se autentica?** | Certificado X.509, FIDO2, TOTP… | `auth_credential` + tablas especializadas |
| **¿Qué puede hacer?** | BitMask de permisos | `bAuth` PDP (roles + átomos) |
| **¿CÓMO conectarse al hardware?** | Puerto, baud_rate, topic MQTT… | `bhnexus.toml` (parámetros de conexión) |
| **¿Cuál es su postura de seguridad?** | Trust_level, MDM, firmware, parches | `auth_device` + `auth_device_posture` |
| **¿Quién es responsable del daemon?** | Propietario humano, fecha de revisión | `idn_roles_nhi_identity` |

---

## 12. EL CACHE DE BHNEXUS Y EL CACHE EFÍMERO DE BANEXUS

### bhnexus — Auth Cache (in-memory)

```
Estructura: map[(user_id, node_id)] → {SAM128, actuator_commands, expires_at}
TTL:        30 segundos (configurable por tipo de operación)
Max entries: 10.000 entradas
Eviction:   LRU al llegar al límite

Cache hit:  bhnexus responde a banexus en < 2ms (sin consultar bAuth)
Cache miss: bhnexus → bAuth (Unix socket) → respuesta en < 8ms total

Invalidación:
  - Cuando bAuth envía policy_update (RolTemplate cambiado)
  - Cuando TTL expira (automático)
  - Cuando banexus reporta evento de cierre de sesión
```

### banexus — Policy Cache Efímero

```rust
pub struct PolicyCache {
    pub user_id:     UserId,
    pub sam128:      Sam128,
    pub received_at: Instant,
    pub ttl:         Duration,
    pub encrypted:   Vec<u8>,  // AES-256-GCM con clave derivada del cert mTLS
}

impl PolicyCache {
    /// Decisión en modo offline — fail-secure: DENY si TTL expirado
    pub fn decide(&self, bit: u8) -> Result<bool, CacheError> {
        if self.received_at.elapsed() > self.ttl {
            return Err(CacheError::Expired);
        }
        let key = self.derive_key()?;  // derivada del certificado mTLS del agente
        let sam = self.decrypt(&key)?;
        Ok(sam.has_permission(bit))
    }
}
```

---

## 13. COMPORTAMIENTO OFFLINE Y FAIL-SECURE

```
ESCENARIO: banexus pierde conexión con bhnexus

DURANTE DESCONEXIÓN:
  banexus intenta reconectar (backoff exponencial)
  Para cada evento de credencial:
    → Consulta policy cache efímero
    → Si SAM en cache Y TTL vigente → responde localmente
    → Si TTL expirado → DENY (fail-secure)

  Shell Sentinel durante desconexión:
    → Permite solo apps en offline_allowed list (okular, etc.)
    → Bloquea apps sensibles (configuración, instalación, etc.)

  Actuadores durante desconexión:
    → Puertas permanecen en último estado
    → Si lock en fail_secure → cerrada
    → Si lock en fail_safe → abierta (emergencia)

AL RECONECTAR:
  1. banexus envía heartbeat con actividad offline
  2. bhnexus: envía policy_update si hubo cambios de RolTemplate
  3. banexus: invalida todo su cache efímero
  4. banexus: solicita SAM fresco para usuarios con sesión activa

ESCENARIO: bAuth caído (bhnexus opera sin bAuth)
  bhnexus: opera con su auth cache (TTL 30s)
  Cache hit: responde normalmente
  Cache miss: error "auth_service_unavailable"
  banexus: recibe error → consulta su cache efímero → fail-secure si vencido
```

---

## 14. FLUJOS POR TIPO DE CREDENCIAL

### QR Dinámico (bAuth como emisor)

```
bAuth genera: sbos://auth/{user_uuid}/{timestamp_unix}/{HMAC-SHA256}
              HMAC calculado con: hmac_key_de_vault + user_uuid + timestamp
              TTL: 30 segundos (configurable en RolTemplate)
              Renovación: Core UI puede generar uno nuevo en cualquier momento

Validación por bhnexus:
  1. Extraer user_uuid, timestamp, hmac del URI
  2. Verificar: now() - timestamp < 30s (dentro del TTL)
  3. Recalcular HMAC con clave de Vault
  4. Comparar HMAC calculado vs HMAC recibido
  5. Si OK → consultar bAuth con user_uuid → SAM-128
```

### NFC / RFID

```
Tag NFC DESFire:
  - user_uuid cifrado con AES-128 (clave rotada cada 90 días en Vault)
  - banexus lee tag → payload cifrado → bhnexus descifra → user_uuid
  - bhnexus → bAuth: SAM-128 para user_uuid

RFID 125kHz legacy:
  - Solo card_number sin cifrado (Wiegand)
  - bhnexus busca card_number en tabla de mapeo → user_uuid
  - bhnexus → bAuth: SAM-128 para user_uuid
  - Nivel de seguridad bajo — usar solo si no hay alternativa
```

### Biométrico (hash)

```
Lector OSDP Biometric:
  1. Sensor captura imagen biométrica localmente
  2. Template extraído en el chip (enclave seguro)
  3. Hash PBKDF2-SHA256 calculado localmente
  4. Hash transmitido por OSDP Secure Channel (AES) a bhnexus
  5. bhnexus → bAuth: {query_type: "biometric", hash: "<hash>"}
  6. bAuth: compara hash vs bauth_biometric_templates
  7. Match → user_uuid → SAM-128 con GOV_LOA_LEVEL = LoA 3

INVARIANTE: raw biometric NUNCA sale del chip del lector.
            Solo el hash viaja. RGPD compliant.
```

---

## 15. FLUJO DE POLÍTICA: CUANDO EL ROLTEMPLATE CAMBIA

```
Admin modifica RolTemplate en Core UI
  ↓
bAuth recalcula SAM-128 afectados (motor nativo — ADR-010)
  ↓
bAuth → bhnexus (Unix socket):
  { "type": "policy_update",
    "affected_roles": ["ROL_CAJERO"],
    "affected_users": ["user-uuid-1", "user-uuid-2"],
    "action": "invalidate_cache" }
  ↓
bhnexus:
  → Invalida SAM-128 en cache para los usuarios afectados
  → Para cada banexus que tenga usuarios afectados conectados:
      Envía: { "type": "policy_update", "affected_users": [...] }
  ↓
banexus:
  → Invalida su cache efímero para usuarios afectados
  → Próximo evento de credencial → consulta fresca a bhnexus → bAuth

TIEMPO TOTAL DESDE GUARDAR ROLTEMPLATE HASTA INVALIDACIÓN EN BANEXUS:
  < 5 segundos (objetivo)
  < 10 segundos (garantía con carga normal)
```

---

## 16. MONITOREO, ALERTAS Y AUTO-RECUPERACIÓN

### Métricas de bhnexus (Prometheus)

```
bhnexus_agents_connected         → agentes banexus conectados actualmente
bhnexus_auth_requests_total      → total de solicitudes de autorización
bhnexus_auth_cache_hits_ratio    → ratio cache hit/miss
bhnexus_bauth_latency_ms         → latencia de consultas a bAuth (p50, p95, p99)
bhnexus_hardware_devices_online  → dispositivos físicos online por protocolo
bhnexus_policy_updates_sent      → invalidaciones de cache enviadas a agentes
```

### Alertas Wazuh

| Evento | Severidad | Acción automática |
|---|---|---|
| Agente banexus desconectado > 5 min | MEDIUM | Notificar admin |
| Dispositivo físico offline > 2 min | HIGH | Notificar admin + log |
| Múltiples auth failures del mismo nodo | HIGH | Alertar + revisar |
| bAuth no responde > 3 intentos | CRITICAL | Operar con cache |
| Integridad de binario banexus comprometida | CRITICAL | Auto-shutdown + alerta |
| Auth negada a usuario con acceso previo | MEDIUM | Log para auditoría |
| Cache SAM-128 expirado en modo offline | HIGH | Notificar admin |

---

## 17. CONFIGURACIÓN

### bhnexus.toml

```toml
[server]
websocket_port = 9444
metrics_port   = 9445
tls_cert = "/etc/bos/tls/bhnexus.crt"
tls_key  = "/etc/bos/tls/bhnexus.key"
tls_ca   = "/etc/bos/tls/ca.crt"

[auth]
bauth_socket      = "/run/bos/bauth.sock"
bauth_timeout_ms  = 1000
bauth_retry_count = 3
cache_ttl_seconds = 30
cache_max_entries = 10000

[hardware]
# El catálogo de dispositivos físicos se consulta en SBOSDB (bauth.idn_identity_entity)
# No se usan fichas YAML — la identidad es soberana y vive en la base de datos
osdp_enabled  = true
mqtt_enabled  = true
mqtt_broker   = "localhost:1883"
onvif_enabled = false

[agents]
# El registro de nodos se consulta en SBOSDB (bauth.idn_identity_entity, entity_type='banexus_node')
# No se usan archivos nodes.yml — el alta de nodos se hace vía bAuth identity tree
heartbeat_interval_seconds = 30
max_idle_seconds          = 300

[metrics]
prometheus_enabled = true
```

### banexus.toml

```toml
[agent]
node_id  = "Ventas-01"
host_url = "wss://sbos-server:9444"
tls_cert = "/etc/banexus/tls/agent.crt"
tls_key  = "/etc/banexus/tls/agent.key"
tls_ca   = "/etc/banexus/tls/ca.crt"

[input]
intercept_usb     = true
reader_devices    = ["/dev/banexus/reader-*"]
input_timeout_seconds = 30

[shell_sentinel]
enabled           = true
sensitive_commands = ["apt-get", "dnf", "systemctl", "rm -rf", "dd"]
pam_module        = "/usr/lib64/security/pam_banexus.so"
deny_timeout_ms   = 5000

[actuators]
relay_port      = "/dev/ttyUSB0"
relay_baud_rate = 9600

[cache]
enabled                = true
max_entries            = 100
encryption_key_source  = "mtls_cert"

[offline]
default_action         = "deny_all"
offline_allowed_apps   = ["okular", "libreoffice-writer"]
reconnect_backoff_seconds = [1, 5, 15, 30, 60]

[integrity]
check_interval_seconds = 300
binary_hash_file       = "/etc/banexus/banexus.sha256"
```

---

## 18. LO QUE NEXUS ES Y NO ES

| NEXUS ES | NEXUS NO ES |
|---|---|
| El broker central de conectividad física | Un sistema de gestión de acceso físico (PACS) standalone |
| El interceptor soberano de eventos de credencial | Un sistema de vigilancia o CCTV |
| El distribuidor del SAM-128 a los nodos | El PDP — las decisiones de identidad son exclusivas de bAuth |
| El normalizador de protocolos heterogéneos (HAL) | Un almacén de templates biométricos |
| El ejecutor atómico de acciones físicas + digitales | Un sistema con lógica de negocio |
| El centinela de integridad del borde | Un daemon autónomo — depende de bAuth para existir |

---

## 19. POSICIONAMIENTO EN EL ECOSISTEMA SBOS

### bNexus es una extensión de bAuth, no un daemon par

En el catálogo de daemons SBOS, bAuth aparece como un daemon único. bhnexus y banexus
son sus **capas de despliegue físico** — binarios separados por necesidad operativa
(diferente hardware, diferente ubicación en la red), pero partes del mismo sistema.

```
ECOSISTEMA SBOS — daemons soberanos
─────────────────────────────────────────────────────────────────
bos      → Infrastructure Provisioning & Lifecycle Orchestrator
bkernel  → Reactive Data Orchestration Engine
biedata  → Federated Batch & Compliance Exchange
bcompass → Collaborative & Federated Intelligence
bsearch  → Sovereign Federated Intelligent Search (RAG)

bAuth    → Unified Identity & Permissions Orchestrator          ← SISTEMA PRINCIPAL
  ├── [Capa 1] bAuth core   → Identidad, política, JWT, BitMask
  ├── [Capa 2] bhnexus      → Motor de routing físico (daemon ruteador)
  └── [Capa 3] banexus      → Daemon de frontera (edge por nodo)
─────────────────────────────────────────────────────────────────
```

Las tres capas son **un solo sistema de identidad soberana** que opera en tres planos:

| Capa | Daemon | Rol | Alcance |
|------|--------|-----|---------|
| **1 — Principal** | `bAuth` | Decide, emite, evalúa, gestiona política | Servidor central SBOS |
| **2 — Ruteador** | `bhnexus` | Rutea eventos físicos a bAuth, gestiona HAL y cache SAM-128 | Servidor central SBOS (junto a bAuth) |
| **3 — Frontera** | `banexus` | Intercepta hardware local, ejecuta actuadores, aplica política en el borde | Cada nodo físico (workstation, gateway) |

```
Meta-patrón de las tres capas:

  bAuth   : recibir política del admin → calcular SAM-128 → distribuir a capas 2 y 3
  bhnexus : recibir evento de hardware → routear a bAuth → distribuir respuesta a banexus
  banexus : interceptar credencial física → enviar a bhnexus → ejecutar actuador local
```

### El Ciclo Completo de Vida de un Acceso Físico

```
Admin modifica RolTemplate (Core UI de bAuth)
  │
  ▼  [Capa 1 — bAuth]
  bAuth calcula SAM-128 nuevo
  bAuth push → bhnexus: invalidate_cache
  │
  ▼  [Capa 2 — bhnexus]
  bhnexus invalida SAM en cache
  bhnexus push → banexus afectados: policy_update
  │
  ▼  [Capa 3 — banexus]
  banexus invalida cache efímero
  │
  ── (tiempo después) ──────────────────────────────────────────
  │
  Usuario presenta credencial (QR / NFC / huella)
  │
  ▼  [Capa 3 — banexus]
  banexus intercepta evento USB/serial antes de evdev
  banexus → bhnexus: auth_request (WebSocket mTLS)
  │
  ▼  [Capa 2 — bhnexus]
  bhnexus: ¿SAM en cache? → NO → consulta bAuth (Unix socket)
  │
  ▼  [Capa 1 — bAuth]
  bAuth evalúa RolTemplate: BitMask, zona, horario, LoA
  bAuth retorna: SAM-128 + actuator_commands
  │
  ▼  [Capa 2 — bhnexus]
  bhnexus almacena en cache (TTL 30s)
  bhnexus → banexus: auth_response (SAM-128 + actuator_commands)
  │
  ▼  [Capa 3 — banexus]
  banexus ejecuta en paralelo:
    → PAM: libera shell de Fedora
    → Serial: abre relé / cajón / puerta
    → Cache: almacena SAM efímero (AES-256-GCM)
  │
  ▼  [bkernel — daemon externo]
  bkernel registra audit_event con ctx_id completo

LATENCIA TOTAL: ~15ms  |  OBJETIVO: < 50ms
```

---

## 20. BAUTH COMO PROVEEDOR DE AUTENTICACIÓN UNIVERSAL

### 20.1 Declaración arquitectónica fundamental

**bAuth es el proveedor de autenticación de cualquier aplicación.**

No importa el lenguaje. No importa el framework. No importa si la aplicación es
parte de SBOS o es un sistema externo construido por un desarrollador independiente.
Cualquier aplicación que necesite autenticar usuarios puede usar bAuth como su
OIDC Provider soberano, exactamente igual que se usaría Auth0, Okta o Firebase Auth,
pero con una diferencia crítica: **los datos nunca salen del servidor del cliente.**

```
┌─────────────────────────────────────────────────────────────────┐
│                    bAuth — OIDC Provider Soberano                │
│                                                                 │
│  SBOS Core UI      Laravel      Vue / React    Django           │
│  (Flutter)         (PHP)        (Node.js)      (Python)         │
│       │                │              │              │          │
│       └────────────────┴──────────────┴──────────────┘          │
│                              │                                  │
│                   Protocolo idéntico para todos:                │
│                   mTLS X.509 + JWT/OIDC + W3C Trace Context     │
│                              │                                  │
│                              ▼                                  │
│                   bAuth (OIDC Provider nativo)                  │
│                   /run/bos/bauth.sock · Kong gateway            │
└─────────────────────────────────────────────────────────────────┘
```

**El protocolo es idéntico sin excepción.** La única diferencia entre una app de
SBOS y una app de un desarrollador externo es el **tenant** bajo el que se registra
la aplicación en bAuth — no el protocolo, no la librería, no la integración técnica.

### 20.2 SBOS como primer consumidor de su propio bAuth

SBOS no tiene un sistema de autenticación separado para sus propias aplicaciones.
**Las aplicaciones de SBOS son consumidores de bAuth exactamente igual que cualquier
app externa.**

| Aplicación SBOS | Tipo | Cómo usa bAuth |
|-----------------|------|----------------|
| Core UI (dashboard Flutter) | App desktop/web | OIDC + JWT — banexus-implicit |
| bOS CLI | Herramienta de línea de comandos | mTLS + JWT — banexus-implicit |
| bkernel dashboard | App web interna | OIDC + JWT — banexus-implicit |
| biedata | Daemon backend | mTLS (M2M, sin usuario) — banexus-implicit |
| bnotify | Daemon backend | mTLS (M2M, sin usuario) — banexus-implicit |
| bsearch | Servicio de búsqueda | mTLS (M2M, sin usuario) — banexus-implicit |

Estas aplicaciones son el **tenant interno canónico de SBOS** — están preregistradas
en bAuth desde la instalación del sistema y usan el mismo mecanismo que cualquier
app de un desarrollador externo.

### 20.3 El modelo de tenants — diferencia de registro, no de protocolo

Un **tenant** en bAuth es una organización registrada con su propio espacio de
identidades, roles y políticas. El tipo de tenant define quién administra la
configuración, no cómo se conecta la aplicación.

| Tipo de tenant | Quién lo es | Quién administra |
|----------------|-------------|-----------------|
| **Interno** | La organización que posee el servidor SBOS, y cualquier app que esa organización registre bajo su propio espacio | IT de la organización vía Core UI de bAuth |
| **Externo** | Un desarrollador o empresa tercera que usa bAuth como su proveedor de autenticación desde fuera | El developer desde el portal bAuth — autoservicio |

**Regla:** un desarrollador que despliega SBOS en su propia infraestructura y
registra sus apps bajo el espacio de su organización es un **tenant interno**.
Un desarrollador que conecta su app a un bAuth ajeno (el de otra empresa que tiene
SBOS) es un **tenant externo**. La definición es de control y propiedad, no técnica.

El protocolo de integración es **100% idéntico** en ambos casos:

```
Tenant interno (app SBOS)          Tenant externo (Laravel externo)
─────────────────────────          ────────────────────────────────
1. Registrar app en bAuth           1. Registrar app en portal bAuth
   (preregistrado en instalación)      (autoservicio)
2. Obtener client_id + secret       2. Obtener client_id + secret
3. Instalar cert mTLS               3. Instalar cert mTLS
   (bOS via SCEP/ACME)                 (descarga desde portal bAuth)
4. Configurar OIDC en la app        4. Configurar OIDC en Laravel
   (librería estándar)                 (laravel/socialite o passport)
5. Propagar ctx_id con OTEL         5. Propagar ctx_id con OTEL
   (SDK estándar)                      (SDK estándar)

        ═══ RESULTADO IDÉNTICO ═══
        Trazabilidad completa garantizada.
        Auditoría soberana en SBOSDB.
```

### 20.4 Garantía universal de trazabilidad y auditoría

**Todo cliente — sin excepción, sin importar tipo, lenguaje, framework o tenant —
tiene garantizada la trazabilidad completa y la auditoría soberana.**

Esta garantía se implementa con tres protocolos RFC estándar que cualquier lenguaje
y framework soporta nativamente:

**① mTLS — Identidad del servidor/dispositivo** (RFC 8446)

El certificado X.509 del cliente prueba QUIÉN está haciendo la llamada a nivel
de infraestructura. Funciona en toda librería HTTP: `curl`, `requests` (Python),
`Guzzle` (PHP/Laravel), `axios` (Node.js), `net/http` (Go), `HttpClient` (.NET).

**② JWT/OIDC — Identidad del usuario** (RFC 6749 + RFC 7519)

bAuth emite JWT firmados. Cualquier librería OAuth2/OIDC estándar los consume:
`laravel/passport`, `django-allauth`, `spring-security-oauth2`, `nuxt-auth`,
`next-auth`, `passport.js`, `jose` (JavaScript), y cientos más.

**③ W3C Trace Context — Trazabilidad de operaciones** (W3C + OpenTelemetry)

El SDK de OpenTelemetry existe en 15+ lenguajes e inyecta el header `traceparent`
automáticamente en cada llamada HTTP saliente. bAuth lo recibe y lo registra como
`ctx_id` (SBOS-049). Sin código adicional: solo configurar el SDK.

Con los tres protocolos activos, bAuth registra en `audit_events` para cada operación:

```
user_id    → JWT.sub              (quién es el usuario — identidad verificada)
device_id  → mTLS cert CN         (desde qué servidor/dispositivo — infraestructura)
ctx_id     → W3C traceparent      (qué operación, en qué sesión — trazabilidad)
tenant_id  → tenant del JWT       (bajo qué organización opera)
method     → método JSON-RPC      (qué acción ejecutó)
result     → granted / denied     (qué decidió bAuth)
ts         → server_now()         (cuándo — timestamp servidor, autoritativo)
```

**Esta auditoría es soberana:** vive en SBOSDB, en el servidor del cliente,
bajo control exclusivo de la organización. Ningún dato de auditoría sale del servidor.

### 20.5 Las formas de banexus — banexus-implicit como caso universal base

**banexus-implicit es la forma base. Las demás son extensiones para hardware.**

La forma **banexus-implicit** cubre el caso más amplio y frecuente: cualquier
aplicación de software que necesita autenticación — sin importar si es una app
de SBOS o una app externa, sin importar el lenguaje o el framework. No requiere
instalar ningún binario propietario.

```
┌─────────────────────────────────────────────────────────────────┐
│  banexus-implicit — El caso universal                            │
│                                                                 │
│  SBOS Core UI · bOS CLI · Laravel · Vue · React · Django        │
│  Spring Boot · .NET · FastAPI · NestJS · Rails · Phoenix        │
│  Cualquier app — cualquier lenguaje — cualquier framework        │
│                                                                 │
│  Protocolo: mTLS X.509 + JWT/OIDC + W3C Trace Context           │
│  Binario propietario requerido: NINGUNO                         │
│  Trazabilidad garantizada: SÍ — audit_events en SBOSDB          │
└─────────────────────────────────────────────────────────────────┘
         │
         ▼  cuando el cliente tiene hardware físico adjunto
┌─────────────────────────────────────────────────────────────────┐
│  Extensiones para hardware — las otras cuatro formas            │
│                                                                 │
│  banexus-daemon   → workstation / POS con hardware serial/GPIO  │
│  banexus-gateway  → sucursal remota con hardware cableado       │
│  banexus-sdk      → app móvil con BLE/UWB/NFC (Aliro CSA 2023) │
│  banexus-virtual  → dispositivo con HTTP/REST que se actúa solo │
└─────────────────────────────────────────────────────────────────┘
```

**Las cinco formas en detalle:**

| Forma | Cuándo aplica | Quién la usa | Binario |
|-------|--------------|--------------|---------|
| **banexus-implicit** | Cualquier app de software — base universal | SBOS apps, Laravel, Vue, React, Django, Spring, .NET, cualquier framework | Ninguno — protocolo estándar |
| **banexus-daemon** | PC o workstation con hardware físico adjunto (cajón serial, relé GPIO) | POS terminal Fedora, workstation de control | Rust MUSL, systemd --user |
| **banexus-gateway** | Hardware físico en sitio remoto sin conexión directa al servidor | Sucursal, edificio distante — Raspberry Pi / SBC | Mismo Rust MUSL, `mode = gateway` |
| **banexus-sdk** | App móvil con acceso físico (BLE + UWB + NFC) | iOS / Android corporativo | Librería nativa Aliro (CSA 2023) |
| **banexus-virtual** | Dispositivo con firmware HTTP/REST que puede auto-actuarse | Cerradura WiFi, terminal IP fijo | Ninguno — el dispositivo llama a bAuth |

**Forma aplicable por escenario:**

| Escenario | Forma | Tenant típico |
|-----------|-------|---------------|
| App Core UI de SBOS (Flutter) | **banexus-implicit** | Interno |
| App web en Laravel del cliente | **banexus-implicit** | Interno o Externo |
| SPA Vue / React | **banexus-implicit** | Interno o Externo |
| Backend Django / FastAPI | **banexus-implicit** | Interno o Externo |
| Servicio Spring Boot / .NET | **banexus-implicit** | Interno o Externo |
| Daemon biedata / bnotify (M2M) | **banexus-implicit** | Interno |
| App iOS / Android corporativa | **banexus-sdk** | Interno |
| Workstation Fedora + cajón serial | **banexus-daemon** | Interno |
| POS terminal Linux + relé | **banexus-daemon** | Interno |
| Sucursal remota con chapa OSDP | **banexus-gateway** | Interno |
| Cerradura WiFi con REST API | **banexus-virtual** | Interno |
| Chapa OSDP en mismo edificio | _(HAL Directo bhnexus)_ | — |
| Cámara ONVIF en LAN local | _(HAL Directo bhnexus)_ | — |

> El **HAL Directo** (sin ninguna forma de banexus) aplica solo a hardware mudo
> en el mismo edificio que bhnexus — la chapa no es un cliente de bAuth, es un
> periférico controlado por el driver del HAL.

### 20.6 La distinción fundamental: cliente de software vs. periférico de hardware

Un **cliente de software** corre en un OS de propósito general y hace llamadas
HTTP/WebSocket. Puede ser una app web, mobile, desktop, CLI, un servidor backend
o un daemon interno. **Todo cliente de software usa banexus-implicit.**

Un **periférico de hardware** no corre un OS de propósito general ni puede ejecutar
una librería arbitraria. Una chapa OSDP habla RS-485. Una cámara habla ONVIF/RTSP.
Un torniquete responde a pulsos de relé. **Estos dispositivos no son clientes de
bAuth — son periféricos controlados por bhnexus a través de su HAL.**

La caja registradora (POS terminal) está en el medio: es un computador de propósito
general (Windows Embedded, Android, Linux embebido) con periféricos físicos adjuntos.
La parte software del POS usa banexus-implicit; los periféricos físicos adjuntos
son controlados por banexus-daemon corriendo en el mismo equipo.

### 20.7 Los tres planos de control

```
┌──────────────────────────────────────────────────────────────┐
│  PLANO C — La mayoría de las integraciones                    │
│  banexus-implicit: cualquier app, cualquier lenguaje          │
│  mTLS + JWT/OIDC + W3C Trace Context → bAuth via Kong        │
│                                                              │
│  SBOS Core UI · Laravel · Vue · React · Django · Spring      │
│  .NET · FastAPI · NestJS · Rails · biedata · bnotify         │
└──────────────────────────────────┬───────────────────────────┘
                                   │
                                   ▼ bAuth decide
┌───────────────────────────────────────────────────────────────┐
│  PLANO B — Hardware local adjunto al cliente                   │
│  banexus-daemon / banexus-gateway / banexus-sdk               │
│  Cuando la respuesta de bAuth debe actuar hardware físico      │
│                                                               │
│  Cajón serial · Relé GPIO · Chapa OSDP remota · BLE móvil    │
└──────────────────────────────────┬────────────────────────────┘
                                   │
                                   ▼ bhnexus HAL ejecuta
┌──────────────────────────────────────────────────────────────┐
│  PLANO A — Hardware mudo en el edificio del servidor          │
│  HAL Directo de bhnexus — sin banexus de ningún tipo          │
│                                                              │
│  Chapa OSDP local · Cámara ONVIF · Torniquete MQTT local     │
└──────────────────────────────────────────────────────────────┘
```

### 20.8 Dispositivos Mudos — La Inversión de Conexión

La confusión conceptual más frecuente: *"¿cómo se conecta una chapa OSDP a bhnexus?"*

**La respuesta: no se conecta. Es bhnexus quien va al dispositivo.**

Los dispositivos mudos (chapas OSDP, lectores Wiegand, sensores MQTT, cámaras ONVIF)
son el **extremo pasivo** del circuito. No tienen stack TCP/IP completo ni pueden
iniciar conexiones de red arbitrarias. Los drivers del HAL de bhnexus son los que:

- Abren el canal de comunicación hacia el dispositivo (serial, GPIO, MQTT, HTTP)
- Sondeando/escuchando los eventos que el dispositivo produce
- Envían comandos al dispositivo (OPEN, LOCK, TRIGGER)

```
Dispositivo mudo                     bhnexus — servidor
────────────────                     ─────────────────────
[Chapa OSDP]  ◄──── cable RS-485 ───► osdp_driver.rs
                                        • abre el puerto serial al arrancar
                                        • mantiene poll loop cada 100ms
                                        • recibe evento → CredentialEvent
                                        • envía OSDP SendCommand(OPEN, 5s)

[Sensor MQTT] ◄──── TCP/1883 ────────► mqtt_driver.rs
                                        • se suscribe al topic del sensor
                                        • recibe publicación → CredentialEvent
                                        • publica comando de respuesta

[Cámara ONVIF]◄──── HTTP/RTSP ───────► onvif_driver.rs
                                        • PullMessages cada 5s (ONVIF polling)
                                        • dispara grabación o PTZ si autorizado
```

El driver **no espera que el dispositivo lo llame** — él va al dispositivo a través
del protocolo nativo. La chapa no sabe que existe bhnexus; solo ve un maestro OSDP
que le habla por RS-485.

#### Requisito de conectividad física del HAL directo

Para que el HAL de bhnexus alcance al dispositivo mudo, el **host del servidor bhnexus
debe tener conectividad física o de red con ese hardware**:

| Protocolo | Conectividad requerida en el host bhnexus |
|-----------|-------------------------------------------|
| OSDP v2 (RS-485) | Adaptador USB→RS-485 o tarjeta serial en el servidor |
| Wiegand (GPIO) | Pin GPIO — típico en SBC; impracticable en servidor rack |
| MQTT IoT | Acceso de red al broker MQTT (localhost o LAN del edificio) |
| ONVIF (cámaras IP) | Cámara con IP accesible en la red local del servidor |
| HTTP/REST | Dispositivo con IP y endpoint REST en la LAN |

**Consecuencia directa:** el HAL directo funciona cuando el hardware está en el
**mismo local físico que el servidor bhnexus** — el edificio o campus donde vive
el servidor, con cables o red LAN alcanzando los lectores.

#### El problema del sitio remoto

Si la chapa OSDP está en una **sucursal a 100 km del servidor bhnexus**, no es
posible tender un cable RS-485 ni hacer LAN local. Se necesita un intermediario
en la sucursal: el **gateway banexus**.

### 20.9 El Gateway banexus — banexus para Hardware en Sitios Remotos

Para hardware mudo en sitios remotos, banexus no corre en un computador de escritorio
— corre en un **dispositivo gateway embebido** (Raspberry Pi, ARM SBC, PC industrial)
instalado físicamente en el local remoto, con los lectores y actuadores cableados
a él directamente.

```
SUCURSAL (sitio remoto)                     SERVIDOR SBOS (central)
───────────────────────                     ───────────────────────
[Chapa OSDP]  ──RS-485──►  banexus-gateway
[Lector NFC]  ──RS-485──►  (Raspberry Pi    ──── WebSocket mTLS ────►  bhnexus
[Relé puerta] ◄─serial──   ARM SBC          ◄─── WebSocket mTLS ────   bAuth
                            PC industrial)                              SBOSDB

                 banexus-gateway:
                 • lee OSDP/Wiegand localmente
                 • controla relés y cerrojos localmente
                 • tuneliza auth_request → bhnexus por internet
                 • recibe auth_response + actuator_commands
                 • ejecuta el comando en el hardware local
```

**El banexus-gateway es el mismo binario Rust MUSL que el banexus de workstation.**
No hay un "banexus especial para gateway" — el mismo daemon arranca en modo gateway
activando los drivers de hardware correspondientes en `banexus.toml`:

```toml
[agent]
node_id  = "Sucursal-Norte-Puerta-Entrada"
host_url = "wss://sbos-central.empresa.com:9444"
mode     = "gateway"   # workstation | gateway

[gateway]
osdp_enabled = true
osdp_port    = "/dev/ttyUSB0"
osdp_baud    = 9600
osdp_devices = [
  { address = 1, id = "PHY_DEV_CHAPA_ENTRADA_NORTE" },
  { address = 2, id = "PHY_DEV_NFC_RECEPCION_NORTE" }
]

[actuators]
relay_port      = "/dev/ttyUSB1"
relay_baud_rate = 9600
# banexus controla el relé de puerta localmente

[cache]
# Modo offline: si cae internet, opera con cache hasta 4h
max_entries           = 100
encryption_key_source = "mtls_cert"
```

El flujo completo es idéntico al flujo soberano (sección 5): el evento de credencial
viaja de la sucursal al servidor central por WebSocket mTLS cifrado, bhnexus lo
procesa en el servidor, y los `actuator_commands` regresan al banexus-gateway que
los ejecuta **en el hardware local** (< 50ms en red normal, < 200ms en conexión
de sucursal con latencia alta).

**Modo offline del gateway:** si cae la conexión con bhnexus, banexus opera con
su policy cache cifrado (AES-256-GCM, TTL hasta 4h) exactamente igual que en
workstation — fail-secure si el cache vence.

### 20.10 Árbol de Decisión — Qué Modalidad para Qué Dispositivo

```
¿El hardware mudo está físicamente en el mismo local que el servidor bhnexus?
│
├── SÍ (mismo edificio, cables directos o LAN local)
│     └── HAL Directo: bhnexus se conecta al hardware
│           ├── OSDP/Wiegand  →  osdp_driver.rs / wiegand_driver.rs
│           │   (cable RS-485 o GPIO al servidor)
│           ├── MQTT IoT       →  mqtt_driver.rs
│           │   (broker MQTT en localhost o LAN)
│           └── ONVIF / HTTP   →  onvif_driver.rs / http_driver.rs
│               (cámara o dispositivo con IP en LAN del servidor)
│
└── NO (sucursal remota, otro edificio, ciudad distinta)
      └── banexus-gateway en el local remoto
            ├── Hardware cableado directamente al gateway (RS-485, GPIO, serial)
            ├── banexus lee/controla el hardware localmente
            └── banexus tuneliza eventos a bhnexus por WebSocket mTLS

¿El dispositivo tiene HTTP/REST pero no puede instalar un binario?
(cerrojo WiFi, terminal IP con firmware fijo)
      └── banexus-virtual: el dispositivo llama a un endpoint HTTP
            en bhnexus/bAuth, recibe { actuator_commands } en la respuesta,
            y ejecuta los comandos él mismo (abre su propio cerrojo)
            — Identificación: mTLS device certificate
```

**Resumen de modalidades:**

| Dispositivo | Protocolo | Dónde corre el control | Modalidad |
|-------------|-----------|------------------------|-----------|
| Chapa OSDP en mismo edificio | RS-485 | bhnexus HAL, directo | HAL Directo |
| Lector Wiegand en mismo edificio | GPIO | bhnexus HAL, directo | HAL Directo |
| Sensor MQTT en LAN local | MQTT | bhnexus HAL, directo | HAL Directo |
| Chapa OSDP en sucursal remota | RS-485 local + WSS | banexus-gateway (Pi/SBC) | Gateway |
| Torniquete en ciudad remota | Wiegand local + WSS | banexus-gateway (Pi/SBC) | Gateway |
| Cerradura WiFi con REST API | HTTPS | bhnexus endpoint HTTP | banexus-virtual |
| Workstation Fedora + cajón serial | USB + serial local | banexus-daemon | Daemon |
| App web / mobile / backend | HTTPS / OIDC | bAuth via Kong | banexus-implicit (Forma 5) |

---

## 21. PREGUNTAS ABIERTAS — PENDIENTES DE DECISIÓN

> Estas preguntas bloquean la documentación formal y deben resolverse antes del Sprint 1.

| ID | Pregunta | Opciones |
|----|----------|----------|
| **C-01** | ¿El POS/workstation Windows usa banexus Windows Service o `libbauth_core.dll` embebida en la app? | daemon / library embedded |
| **C-02** | Cuando un usuario se autentica desde browser (Plano C) y debe gatillar una acción física (abrir puerta), ¿cómo notifica bAuth a bhnexus? | Unix socket directo bAuth→bhnexus / WAL evento / bkernel CDC |
| **C-03** | ¿El JWT puede llevar `actuator_hints` que el cliente ejecuta localmente (para POS sin banexus)? | sí (mezcla responsabilidades) / no (solo bhnexus actúa) |
| **C-04** | ¿banexus se expande a Windows/Android o se reemplaza por `libbauth_core` multiplataforma? | expandir daemon a más OS / crear librería core |
| **C-05** | ¿Los tenants externos pueden tener bits de acceso físico en su SAM-128 o solo acceso lógico por definición? | pueden tenerlo / nunca lo tienen |

---

## 22. RELACIÓN BAUTH ↔ BHNEXUS — EL AGENTE DE EJECUCIÓN FÍSICA (PEA)

### 22.1 El error conceptual que debe evitarse

bhnexus **no es un daemon hermano o peer de bAuth**. Tratarlos como dos daemons
independientes coordinados por un contrato bilateral sería el peor error arquitectónico
posible: generaría una descoordinación entre el órgano de decisión (bAuth) y el brazo
ejecutor (bhnexus) que abre ventanas de seguridad directamente en la capa física.

Un usuario con acceso revocado podría seguir abriendo puertas. Una política de
emergencia podría tardar 30 segundos en llegar al hardware. Un cambio de rol podría
no propagarse a un nodo con cache desactualizado. Ninguno de estos es un escenario
teórico — todos son consecuencias directas de aislamiento mal gestionado entre PDP y PEP.

### 22.2 El modelo PAP/PDP/PEP aplicado a NEXUS

La industria (Lenel, Software House, Genetec, Honeywell) lleva 30 años resolviendo
este problema con el patrón XACML/NIST SP 800-207:

```
bAuth   = PDP — Policy Decision Point  — el único que DECIDE identidad y permisos
bhnexus = PEP — Policy Enforcement Point primario — el único que EJECUTA físicamente
banexus = PEP de borde (Edge PEP) — brazo del PEP en cada nodo físico
```

```
                    DECIDE
                    ┌─────┐
    Admin ─────────►│bAuth│◄──────── RolTemplates / UserTemplates
                    │(PDP)│
                    └──┬──┘
                       │ canal privilegiado
                       │ bidireccional
                       │ Unix socket persistente
                    ┌──▼──┐
                    │bhnex│ EJECUTA en nombre del PDP
                    │ (PEA│ sin autoridad propia
                    │ /PEP│
                    └──┬──┘
                       │ WebSocket mTLS
              ┌────────┴────────┐
           ┌──▼──┐           ┌──▼──┐
           │ban-1│           │ban-2│  Edge PEP (banexus por nodo)
           └─────┘           └─────┘
```

**bhnexus tiene CERO autoridad de decisión propia.** No evalúa BitMask, no interpreta
RolTemplates, no conoce la semántica de los bits del SAM-128. El cache de SAM-128
en bhnexus no es una "decisión local" — es una extensión de la memoria de bAuth,
con TTL y validez dictados por bAuth, revocable por bAuth en tiempo real.

### 22.3 Por qué deben permanecer como daemons separados

La separación no responde a independencia operativa — responde a **resiliencia y
responsabilidad única** (Unix philosophy, principio de mínimo privilegio):

| Riesgo de fusionarlos | Consecuencia |
|-----------------------|-------------|
| Un crash del driver OSDP (RS-485) | Derribaría el sistema de autenticación completo |
| Hardware polling cada 100ms por dispositivo | Compite por CPU/RAM con la evaluación de identidad |
| Código de drivers de bajo nivel en bAuth | Contamina el codebase de identidad con serialport-rs, libusb, GPIO |
| bAuth no puede deployarse independiente | Queda atado a la topología de red del hardware físico |
| Otros daemons no pueden usar bhnexus | bkernel, bos no pueden pedir acciones físicas sin pasar por bAuth |

La separación es **arquitectónica**. La co-dependencia es **operativa e irrenunciable**.

### 22.4 El canal privilegiado bidireccional

A diferencia de cómo otros daemons interactúan con bAuth (JSON-RPC stateless),
bhnexus tiene un **canal Unix socket bidireccional persistente** con capacidad
de push en ambas direcciones — el único daemon con este privilegio:

```
bAuth ──── /run/bos/bauth-nexus.sock ────► bhnexus
           (canal dedicado, siempre abierto, full-duplex)

bAuth → bhnexus  (PUSH de autoridad, tiempo real):
  invalidate_cache   — RolTemplate cambió, cache inválido (ya existe)
  emergency_revoke   — usuario comprometido, DENY inmediato en todos los nodos < 1s
  security_level_up  — incidente activo, elevar nivel de seguridad global
  blacklist_node     — nodo físico comprometido, bloquear toda credencial
  policy_sync        — sincronización completa de políticas al reconectar

bhnexus → bAuth  (PUSH de estado físico, tiempo real):
  device_tamper      — lector OSDP reportó manipulación física
  node_offline       — banexus perdió conexión, nodo sin custodia
  auth_spike         — pico de intentos fallidos en un nodo (posible ataque)
  hardware_failure   — actuador no responde al comando de apertura
  integrity_breach   — banexus detectó discrepancia en hash de binario
```

La TTL de 30s del cache es suficiente para eficiencia operativa normal. No es
suficiente para una revocación de emergencia. El mecanismo de `emergency_revoke`
resuelve eso: bAuth lo dispara y bhnexus invalida el cache de ese usuario en todos
los nodos banexus conectados en menos de 1 segundo, sin esperar el TTL.

### 22.5 Co-dependencia de ciclo de vida

```ini
# /etc/systemd/system/bhnexus.service
[Unit]
Description=SBOS Nexus Host — Physical Enforcement Agent
Requires=bauth.service
After=bauth.service
PartOf=bauth.service
# PartOf: si bAuth se detiene, bhnexus se detiene con él.
# Si bAuth se reinicia, bhnexus se reinicia con él.

[Service]
ExecStartPre=/usr/bin/bos-wait-socket /run/bos/bauth.sock 30s
# bhnexus no acepta conexiones de banexus hasta que bAuth responde.
```

**Comportamiento si bAuth cae:**

```
bAuth caído
  └─► bhnexus: entra en modo "cache only"
        ├── Requests con cache vigente (TTL) → responde normalmente
        ├── Requests sin cache → responde auth_service_unavailable
        ├── Alerta a Wazuh: CRITICAL — PDP no disponible
        └── Si bAuth no regresa en 60s:
              → bhnexus comienza a denegar todo request sin cache
              → Notifica a todos los banexus: degraded_mode
```

### 22.6 Cómo otros daemons usan bhnexus sin saltarse a bAuth

bhnexus es el único punto de entrada al mundo físico en SBOS. Otros daemons
(bkernel, bos) pueden solicitar acciones físicas, pero **siempre con un JWT
firmado por bAuth que autoriza esa acción específica**:

```json
// bkernel detecta intrusión → solicita lockdown del nodo físico
{
  "type":        "physical_action",
  "requester":   "bkernel",
  "bauth_token": "<JWT firmado por bAuth, claim: physical_action=node_lockdown>",
  "action":      "node_lockdown",
  "target_node": "Ventas-01",
  "reason":      "intrusion_event_detected",
  "ctx_id":      "00-abc123-def456-01"
}
```

bhnexus valida el JWT de bAuth antes de ejecutar cualquier acción. Ningún daemon
puede ordenar una acción física sin autorización firmada de bAuth — bhnexus es
el portero del mundo físico, no un ejecutor ciego de cualquier daemon que lo invoque.

### 22.7 Tabla de co-dependencia bAuth ↔ bhnexus

| Propiedad | Definición |
|-----------|-----------|
| **Relación** | bAuth es PDP/autoridad · bhnexus es PEA/brazo ejecutor — no peers |
| **Autoridad de decisión propia de bhnexus** | CERO — solo ejecuta decisiones de bAuth |
| **Canal de comunicación** | Unix socket bidireccional persistente `/run/bos/bauth-nexus.sock` |
| **Inicio** | bhnexus arranca después de bAuth (`After=bauth.service`) |
| **Detención** | bhnexus se detiene con bAuth (`PartOf=bauth.service`) |
| **bAuth caído** | bhnexus opera con cache (TTL vigente) → alerta crítica → DENY si TTL expira |
| **Revocación de emergencia** | bAuth push → bhnexus invalida < 1s → banexus propaga < 2s |
| **Uso por otros daemons** | Permitido con JWT de bAuth — nunca sin autorización firmada |
| **Observabilidad** | Audit events de bhnexus se consolidan en el trail de bAuth — misma cadena forense |
| **Acoplamiento** | Arquitectónicamente separados · operativamente inseparables |

---

## 23. EL MODELO DE TRES CAPAS — bNEXUS COMO MOTOR DE COMUNICACIÓN DE bAUTH

### 23.1 La afirmación central

bAuth, bhnexus y banexus son **tres daemons distintos**:

```
bauth.service    → binario /usr/bin/bauth    → espera JSON-RPC en Unix socket
bhnexus.service  → binario /usr/bin/bhnexus  → espera WebSocket de banexus + eventos HAL
banexus.service  → binario /usr/bin/banexus  → espera eventos USB/hardware + frames de bhnexus
```

Cada uno es un proceso propio, gestionado por systemd, que arranca, vive y muere
de forma independiente. No comparten proceso ni espacio de memoria.

Su relación se define con dos principios que deben coexistir:

**Independencia de propósito** — cada daemon tiene su propia razón de ser:
- bAuth: decide identidad y política
- bhnexus: rutea eventos físicos y distribuye decisiones de bAuth al hardware
- banexus: intercepta hardware local y ejecuta actuadores en el borde

**Dependencia de ciclo de vida** — la existencia de uno requiere al otro:
- bhnexus no puede operar sin bAuth: sin PDP no hay decisiones que routear
- banexus no puede operar sin bhnexus: sin router no hay canal a la autoridad de identidad
- El orden de arranque es: `bauth` → `bhnexus` → `banexus`

> bNexus es el **motor de comunicación física de bAuth**: el sistema de dos daemons
> especializados (bhnexus + banexus) que permiten a bAuth gobernar el mundo físico
> sin que bAuth tenga dependencias directas de hardware.

### 23.2 Por qué tres capas y no uno o dos

**¿Por qué no una sola capa (todo en bAuth)?**
Porque bAuth no puede tener dependencias de hardware de bajo nivel (RS-485, GPIO,
libusb). Un crash en un driver OSDP no puede derribar el sistema de identidad.
La separación protege al núcleo.

**¿Por qué no dos capas (bAuth + un agente)?**
Porque el agente de borde (banexus) opera en múltiples nodos físicos simultáneamente,
con hardware heterogéneo, en ubicaciones remotas, con capacidad offline. Necesita
ser un proceso propio en cada nodo — no puede ser un hilo dentro de bhnexus.
bhnexus es el concentrador central; banexus es el borde distribuido.

**Las tres capas resuelven tres problemas distintos:**

```
Capa 1 — bAuth (daemon principal)
  Problema que resuelve: ¿QUIÉN eres? ¿Qué puedes hacer?
  Responsabilidad: identidad, política, JWT, BitMask, RolTemplate, UserTemplate
  Dónde vive: servidor central SBOS
  Acceso a hardware: NINGUNO (por diseño)

Capa 2 — bhnexus (daemon ruteador)
  Problema que resuelve: ¿Cómo llegan los eventos físicos a bAuth?
                         ¿Cómo bAuth controla el hardware sin tocarlo?
  Responsabilidad: routing, HAL, cache SAM-128, distribución de política
  Dónde vive: servidor central SBOS (mismo host que bAuth o cercano)
  Acceso a hardware: HAL (OSDP, MQTT, ONVIF, HTTP) solo para hardware local al servidor

Capa 3 — banexus (daemon frontera)
  Problema que resuelve: ¿Cómo controla bAuth hardware en nodos remotos?
  Responsabilidad: intercepción, actuadores locales, cache offline, PAM sentinel
  Dónde vive: cada nodo físico (workstation, gateway, SBC remoto)
  Acceso a hardware: USB HID, serial, GPIO, OSDP local (en modo gateway)
```

### 23.3 La analogía del sistema nervioso

```
bAuth    = cerebro          → decide, recuerda, aprende, ordena
bhnexus  = médula espinal   → conduce señales, reflexos intermedios, cache de respuestas
banexus  = nervios y músculos → percibe el entorno físico (sensores) y actúa (actuadores)
```

El cerebro no toca el mundo directamente. Lo toca a través de su sistema nervioso.
bAuth no toca el hardware. Lo toca a través de bhnexus (Capa 2) y banexus (Capa 3).

### 23.4 Dónde vive el código y la documentación

**El código de los tres daemons vive dentro de BauthAgent**, en carpetas separadas
bajo `src/` — exactamente igual que el dashboard desktop Flutter tiene su carpeta
propia dentro de `BauthAgent/src/desktop/` pero compila como una app independiente.

```
BauthAgent/
  src/                      ← código de bAuth (Capa 1) — binario: bauth
  src/bnexus/               ← motor de comunicación física (Capas 2 y 3)
    bhnexus/                    ← daemon ruteador — binario: bhnexus
    banexus/                    ← daemon frontera — binario: banexus
  src/desktop/              ← dashboard Flutter — app independiente (ya existe)
  context/Documentacion/    ← documentación de las tres capas + corpus bAuth
  context/docs/             ← especificaciones y conceptualizaciones (este doc)
  context/contracts/        ← contratos bAuth↔bhnexus y bAuth↔banexus
```

`src/bnexus/` agrupa los dos daemons del motor de comunicación — bhnexus y banexus
son hermanos dentro de ese subdirectorio, cada uno con su propio `Cargo.toml`,
su propio binario compilado y su propio `systemd.service`. Son daemons independientes
que corren por separado, pero su código vive agrupado bajo `bnexus/` igual que
el desktop vive bajo `desktop/`.

### 23.5 Tabla de identidad de las tres capas

| | Capa 1 · bAuth | Capa 2 · bhnexus | Capa 3 · banexus |
|--|----------------|------------------|------------------|
| **Nombre** | Identity Core | Physical Router | Edge Sentinel |
| **Rol** | Daemon principal | Daemon ruteador | Daemon frontera |
| **Decide** | Sí — única fuente | No | No |
| **Rutea** | No | Sí | No |
| **Actúa en hardware** | No | HAL (local al servidor) | Sí (local al nodo) |
| **Ubicación** | Servidor central | Servidor central | Cada nodo físico |
| **Cantidad** | 1 por SBOS | 1 por SBOS | N (uno por nodo) |
| **Offline** | No aplica | Cache TTL 30s | Cache TTL 4h |
| **Binario** | `bauth` | `bhnexus` | `banexus` |
| **Puerto/socket** | `/run/bos/bauth.sock` | `:9444` (WSS) | sin puerto externo |
| **Propietario** | bAuth | bAuth | bAuth |

---

---

## 24. LAS FORMAS DE BANEXUS SEGÚN EL TIPO DE CLIENTE

banexus siempre existe — pero no siempre como el mismo artefacto. Su forma concreta
depende de quién es el cliente y qué capacidades tiene su entorno de ejecución.

### 24.1 Taxonomía de formas de banexus

| Forma | Artefacto | Para quién | Mecanismo de control de hardware |
|-------|-----------|-----------|----------------------------------|
| **banexus-daemon** | Binario Rust MUSL, systemd | Workstation Linux, POS, embedded Linux | `serialport-rs` (serial/RS-485) · `rusb`+`udev` (USB HID) · `tokio-gpiod` (GPIO `/dev/gpiochip*`) |
| **banexus-gateway** | Binario Rust MUSL, systemd en SBC/Pi | OSDP/Wiegand en sitio remoto | OSDP v2 sobre RS-485 · Wiegand via GPIO · relay via serial — todo local al SBC |
| **banexus-sdk** | Librería nativa `.so`/`.dll`/`.a`/framework | App móvil iOS/Android, app desktop de terceros | **Aliro** (BLE+UWB+NFC, CSA std) · CoreBluetooth/Android BLE · CoreNFC/Android NFC · USB OTG HID |
| **banexus-virtual** | Endpoint HTTP+MQTT en bhnexus | Dispositivo con REST o MQTT propio (cerradura WiFi, panel IP) | HTTP device-initiated + `actuator_commands` en respuesta · MQTT pub/sub (device sub, bhnexus pub) · WebSocket push |
| **banexus-implicit** | Sin binario — Web APIs + protocolo puro | Browser (Chrome/Edge), backend de terceros, CLI | Web Bluetooth API · WebHID API · Web Serial API (Chrome/Edge) · para backend: REST/WS a bhnexus con JWT bAuth |

### 24.2 Forma 1 — banexus-daemon (tenant interno, SBOS propio)

**Quién lo usa:** workstations Fedora del tenant, POS terminals Linux, embedded Linux
con periféricos físicos directamente cableados.

**Qué es:** el daemon Rust MUSL completo instalado como `banexus.service` en systemd --user.
Es la forma canónica y más completa de banexus.

**Mecanismos de control de hardware:**

| Protocolo | Crate Rust | Dispositivos típicos |
|-----------|-----------|---------------------|
| USB HID | `rusb` + `udev` | Lectores QR, NFC ACR122U, teclados de acceso |
| GPIO | `tokio-gpiod` (`/dev/gpiochip*`) | Relés, sensores, indicadores luminosos |
| Serial RS-232/RS-485 | `serialport-rs` | Cajones de dinero, cerrojos serie, displays |
| I2C | `linux-embedded-hal` | Sensores de temperatura, RTC, expansores GPIO |
| SPI | `spidev` | Lectores de tarjeta integrados, displays |

`tokio-gpiod` usa la API moderna de character device de Linux (`/dev/gpiochip*`) — no el deprecated sysfs — y es nativa de tokio async, sin bloquear el event loop.

```
Fedora workstation (tenant interno)
  banexus.service  ←  instalado por bos durante onboarding
  │
  ├── Input Hooking    (udev + rusb → /dev/banexus/reader-*)
  ├── Shell Sentinel   (pam_banexus.so en auth phase)
  ├── GPIO Actuator    (tokio-gpiod → /dev/gpiochip0 → relé puerta)
  ├── Serial Actuator  (serialport-rs → /dev/ttyUSB0 → cajón dinero)
  └── WebSocket mTLS → bhnexus:9444
```

### 24.3 Forma 2 — banexus-gateway (hardware mudo en sitio remoto)

**Quién lo usa:** una Raspberry Pi, ARM SBC o PC industrial instalado en una sucursal
o sitio remoto donde hay lectores OSDP, Wiegand u otros dispositivos sin conectividad IP.

**Qué es:** el mismo binario Rust MUSL que banexus-daemon, pero arrancado en
`mode = "gateway"` en `banexus.toml`. El hardware mudo se cablea directamente
al SBC (RS-485, GPIO); banexus lo lee localmente y tuneliza los eventos a bhnexus
en el servidor central por WebSocket mTLS.

```
Sucursal remota                          Servidor SBOS
──────────────────                       ──────────────
[Chapa OSDP] ──RS-485──►                 [bhnexus]
[Relé puerta] ◄─serial─   banexus        [bAuth]
                           gateway   ──── WebSocket mTLS ────►
                           (Pi/SBC)
```

### 24.4 Forma 3 — banexus-sdk (apps de terceros con hardware o apps móviles)

**Quién lo usa:**
- Desarrolladores externos que integran bAuth como plataforma de autenticación
  y cuya aplicación necesita control de hardware local
- Apps móviles iOS/Android de SBOS o de terceros que usan bAuth

**Qué es:** una librería nativa compilada que la app embebe vía FFI/JNI/Swift Package.
No es un proceso separado — vive dentro del proceso de la aplicación.

**Mecanismos de control de hardware por plataforma:**

**iOS / Android — Aliro (CSA estándar 2023):**
Aliro es el protocolo abierto de la Connectivity Standards Alliance adoptado por
Apple, Google, Samsung, HID Global y ASSA ABLOY para credenciales digitales de
acceso físico. Unifica tres radios en un solo protocolo:

| Radio | Uso | Estándar |
|-------|-----|---------|
| **BLE** (Bluetooth Low Energy) | Tap-to-open, presencia, notificaciones | CoreBluetooth (iOS) / Android BLE API |
| **UWB** (Ultra-Wideband) | Hands-free por proximidad (< 1m preciso) | U1 chip (iPhone/Apple Watch) / Android UWB API |
| **NFC** | Tap preciso, modo tarjeta emulada | CoreNFC (iOS) / Android NFC HCE |

libbauth_nexus implementa Aliro como capa de credencial digital:
```
App iOS / Android
  └── libbauth_nexus (Swift Package / Android AAR)
        ├── Aliro stack (BLE + UWB + NFC)
        │     ├── CoreBluetooth / Android BLE → smart locks
        │     ├── UWB (U1) / Android UWB → hands-free (distancia < 1m)
        │     └── CoreNFC / Android HCE → tap-to-open (emula tarjeta)
        ├── mTLS client cert (cert del tenant distribuido por portal bAuth)
        ├── WebSocket mTLS → bhnexus (eventos de credencial)
        └── JWT OIDC → bAuth (autenticación de usuario)
```

**Desktop no-SBOS (.NET, Python, Go, etc.):**
```
App desktop (Windows/Linux/macOS)
  └── libbauth_nexus.so / .dll / .a (FFI nativa)
        ├── Serial (RS-232/RS-485) → lectores, cerrojos
        ├── USB HID (libusb) → lectores de tarjeta, biométricos
        └── WebSocket mTLS → bhnexus
```

**Cómo lo obtiene un desarrollador externo:**
El portal de bAuth distribuye:
1. `libbauth_nexus` en todos los formatos (Swift Package, Android AAR, `.so`, `.dll`, `.a`)
2. El client certificate mTLS del tenant
3. Documentación del SDK con ejemplos Aliro / BLE / NFC

### 24.5 Forma 4 — banexus-virtual (dispositivos con HTTP o MQTT propio)

**Quién lo usa:** dispositivos físicos con conectividad de red propia pero sin
capacidad de instalar un binario arbitrario: cerraduras WiFi, paneles IP, terminales
de acceso con firmware fijo, interfonos IP, cámaras con API de control.

**Qué es:** bhnexus expone dos mecanismos de banexus-virtual que el dispositivo
elige según su protocolo nativo:

#### Mecanismo A — HTTP device-initiated (REST)

El dispositivo hace una petición HTTP al servidor. Recibe `actuator_commands` en la
respuesta y los ejecuta él mismo localmente. Patrón industria: Axis VAPIX Physical
Access Control API, HID OSDP-IP.

```
Cerradura WiFi / Panel IP (firmware fijo)
  │
  │  POST https://sbos.empresa.com/bnexus/v1/event
  │  mTLS device cert + { device_id, credential, ctx_id }
  ▼
bhnexus → bAuth → SAM-128 + actuator_commands
  │
  ▼
HTTP 200 { "status": "granted", "actuator_commands": [{"action":"OPEN","ms":5000}] }
  │
  ▼
Dispositivo ejecuta OPEN localmente (su propio cerrojo)
```

#### Mecanismo B — MQTT pub/sub (push asíncrono)

El dispositivo se suscribe a su topic de comandos en el broker MQTT de bhnexus.
Cuando un usuario se autentica (por cualquier canal), bhnexus publica el comando
en el topic. El dispositivo lo recibe y actúa. Patrón industria: AWS IoT Core,
Azure IoT Hub, OpenRemote, EMQ.

```
Sensor IoT / Actuador MQTT
  │                                   bhnexus broker MQTT (localhost:1883)
  ├─ SUBSCRIBE bhnexus/cmd/{device_id}  ◄──── bhnexus publica OPEN tras bAuth GRANTED
  └─ PUBLISH bhnexus/event/{device_id}  ────► bhnexus recibe credencial → bAuth

Flujo:
  Dispositivo publica evento (credencial presentada)
    → bhnexus mqtt_driver lo recibe → bAuth evalúa
    → bhnexus publica en topic de comandos del dispositivo
    → Dispositivo recibe OPEN y actúa localmente
```

#### Mecanismo C — WebSocket push (conexión persistente)

Para dispositivos con capacidad WebSocket: mantienen conexión persistente con
bhnexus y reciben comandos en tiempo real sin polling.

**Identidad del dispositivo:** mTLS client certificate distribuido por bOS durante
el registro de la identidad del dispositivo en `bauth.auth_device` (SBOSDB). El
certificado queda vinculado al `device_id` y es validado por bhnexus en cada conexión.

### 24.6 Forma 5 — banexus-implicit (browser o backend, con o sin hardware local)

**Quién lo usa:**
- Aplicaciones web en browser (Chrome/Edge con Web APIs, o cualquier browser sin hardware)
- Backends de terceros que usan bAuth como OIDC provider
- CLIs remotos, scripts, microservicios externos

**Qué es:** no hay un artefacto banexus instalado. La trazabilidad e identidad se
logran con tres protocolos RFC estándar. El control de hardware local del usuario
se logra con las Web APIs nativas del browser (Chrome/Edge).

#### Sub-forma 5A — Browser con hardware local (Chrome/Edge)

Los browsers modernos exponen APIs que permiten controlar hardware físico conectado
al computador del usuario **sin instalar ningún plugin ni extensión**:

| Web API | Hardware que controla | Soporte |
|---------|----------------------|---------|
| **Web Bluetooth API** | Cerraduras BLE, lectores BLE, dispositivos BLE | Chrome/Edge (no Firefox, no Safari) |
| **WebHID API** | Lectores USB HID, teclados de acceso, gamepads especiales | Chrome 89+ / Edge 89+ |
| **Web Serial API** | Dispositivos serie RS-232, microcontroladores, paneles | Chrome/Edge |
| **Web USB API** | Dispositivos USB sin driver OS estándar | Chrome/Edge |

```javascript
// Ejemplo: abrir cerradura BLE desde el browser (Web Bluetooth API)
const device = await navigator.bluetooth.requestDevice({
  filters: [{ services: ['access_control_service'] }]
});
const server = await device.gatt.connect();
// bAuth ya validó → JWT tiene actuator_hint → app ejecuta localmente
await server.getPrimaryService('access_control_service')
            .then(s => s.getCharacteristic('lock_control'))
            .then(c => c.writeValue(new Uint8Array([0x01]))); // OPEN
```

**Limitaciones:** requiere HTTPS, requiere gesto explícito del usuario (permission prompt),
solo Chrome/Edge (no Firefox, no Safari). El hardware debe estar físicamente
conectado al computador del usuario.

#### Sub-forma 5B — Browser sin hardware / Backend de terceros

Trazabilidad pura vía protocolos RFC estándar. Sin artefacto banexus:

```
① mTLS X.509        → identidad del dispositivo/servidor (RFC 8446)
② JWT/OIDC          → identidad del usuario (RFC 6749 + RFC 7519)
③ W3C Trace Context → trazabilidad de operación (W3C + OpenTelemetry)
```

Un desarrollador externo que usa bAuth como Auth0/Keycloak usa esta sub-forma:
configura bAuth como OIDC provider en su framework (Laravel Passport, Django OAuth,
Spring Security), instala su cert mTLS, y propaga ctx_id con OTEL SDK.
bAuth registra auditoría completa sin ningún binario propietario en el cliente.

### 24.7 Árbol de decisión — ¿Qué forma de banexus corresponde?

```
¿El cliente necesita controlar hardware físico?
│
├── SÍ ─── ¿El hardware está en el mismo PC/dispositivo que corre la app?
│              │
│              ├── SÍ ── ¿El OS permite instalar daemons (Linux/Windows)?
│              │              SÍ → banexus-daemon  (Forma 1)
│              │              NO → banexus-sdk embebido en la app (Forma 3)
│              │
│              └── NO ── ¿El hardware tiene IP y REST API propia?
│                             SÍ → banexus-virtual (Forma 4)
│                             NO → banexus-gateway en SBC local (Forma 2)
│
└── NO ─── banexus-implicit / Plano C (Forma 5)
           mTLS + JWT + W3C Trace Context
           Sin artefacto banexus

```

### 24.8 Tabla resumen por tipo de cliente

| Tipo de cliente | Forma de banexus | Artefacto |
|-----------------|-----------------|-----------|
| Workstation Fedora SBOS | banexus-daemon | `banexus.service` systemd |
| POS terminal Linux con relé | banexus-daemon | `banexus.service` systemd |
| Embedded Linux + hardware adjunto | banexus-daemon | `banexus.service` systemd |
| SBC/Pi con OSDP/Wiegand remoto | banexus-gateway | `banexus.service` mode=gateway |
| App Flutter desktop SBOS | banexus-sdk | `libbauth_nexus.so` embebida |
| App Android/iOS SBOS | banexus-sdk | `libbauth_nexus.a` JNI/Swift |
| App de terceros con hardware local | banexus-sdk | `libbauth_nexus` en su lenguaje |
| Cerradura WiFi / terminal IP REST | banexus-virtual | Endpoint HTTP en bhnexus |
| App web browser | banexus-implicit | Ninguno — Plano C puro |
| Backend de terceros (Laravel, Django…) | banexus-implicit | Ninguno — Plano C puro |
| Microservicio externo / CLI remoto | banexus-implicit | Ninguno — Plano C puro |

---

*SKULL · SBOS · SBOS-NEXUS-CONCEPTUALIZACION · v3.7 · Agosto 2026*
*v3.0: Abril 2026 — caso interno gestionado (secciones 1-19)*
*v3.1: Agosto 2026 — modelo de tenants, tres planos físicos, trazabilidad agnóstica (secciones 20-21)*
*v3.2: Agosto 2026 — dispositivos mudos: HAL directo, gateway banexus, árbol de decisión (secciones 20.7-20.9)*
*v3.3: Agosto 2026 — relación bAuth↔bhnexus como PEA, canal privilegiado bidireccional, co-dependencia de ciclo de vida (sección 22)*
*v3.4: Agosto 2026 — modelo de tres capas: bNexus como motor de comunicación de bAuth, docs viven en bAuth (sección 23)*
*v3.5: Agosto 2026 — cinco formas de banexus por tipo de cliente con mecanismos de hardware: tokio-gpiod/serialport-rs/rusb (daemon), Aliro+BLE+UWB+NFC (sdk), HTTP+MQTT+WebSocket (virtual), Web Bluetooth+WebHID+Web Serial (implicit) (sección 24)*
*Estándares: SIA OSDP v2.2.2 (IEC 60839-11-5), MQTT 5.0 (OASIS),*
*ONVIF Profile S/T, WebSocket RFC 6455, mTLS RFC 8446,*
*NIST SP 800-207 Device Agent/Gateway model, ISO/IEC 27001:2022 A.7*
