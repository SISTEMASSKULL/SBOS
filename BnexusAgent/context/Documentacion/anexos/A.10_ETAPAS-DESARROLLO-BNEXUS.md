# A.10 — Etapas de Desarrollo de bNexus
## Estrategia bootstrap para romper el ciclo huevo-gallina

**Versión:** 1.3.0
**Fecha:** 2026-08-05
**Manual padre:** `INDICE.md`
**Carta rectora:** `0.00_MANUAL-DIRECTRICES-NEXUS.md`

---

## 1. El problema: ciclo de dependencia circular

bNexus, el desktop y el módulo de identidad forman un ciclo de dependencias que bloquea el
inicio de desarrollo si se intenta resolver todo a la vez:

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                  │
│   Desktop necesita autenticarse   →   necesita bAuth activo     │
│         ↑                                     │                  │
│         │                                     ↓                  │
│   bNexus necesita identidades    ←   identidades necesitan      │
│   para auth real (SPIFFE/Vault)       módulo identity desktop   │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Solución:** desarrollo por etapas. En la Etapa 1 se abre el canal Puerta 1 (banexus ↔ bhnexus)
con una **CA de desarrollo autofirmada** en lugar de SPIFFE/SVID de Vault/SPIRE — eso es lo
único que se simula. Los **JWT los emite bAuth real** desde el primer día: bAuth ya tiene
`JwtSigner` (EdDSA Ed25519) + `bauth.token.issue` + `bauth.token.jwks` implementados y
funcionando. bhnexus valida tokens obteniendo la clave pública de bAuth vía `bauth.token.jwks`
(RFC 7517) — sin ningún secreto local ni firma simulada.

---

## 2. Las tres etapas

### Etapa 1 — Canal vivo (Bootstrap)

**Objetivo:** bhnexus y banexus compilados, conectados, canal Puerta 1 activo con auth simulada.

**Qué se implementa:**

| Componente | Qué hace | Auth |
|-----------|----------|------|
| `bhnexus` | Unix socket `/run/bos/bhnexus.sock` (Interface Dual ADR-020) + TCP 9444 escuchando | **Puerta 1:** dev CA autofirmada (no SPIFFE/SVID) |
| `banexus` | Se conecta a bhnexus por TCP 9444, envía heartbeat cada 30s, JSON-RPC básico funciona | **Puerta 1:** cert generado por dev CA al arrancar |
| JWT de sesión | Emitido por **bAuth real** (`bauth.token.issue` — EdDSA Ed25519) | ✅ Real desde Etapa 1 — sin simulación |
| Validación JWT | bhnexus obtiene clave pública via `bauth.token.jwks` (RFC 7517) | ✅ Real desde Etapa 1 — sin simulación |
| Interface Dual | `bhnexus.health`, `bhnexus.node.list`, `bhnexus.status` — métodos mínimos | JWT real de bAuth |
| Auth requests (Puerta 1) | Retornan `GRANTED` hardcodeado en modo dev (sin consultar bAuth aún) | Flag `dev_mode = true` en `bhnexus.toml` |

**Lo único simulado en Etapa 1:**
- Certificados Puerta 1 (banexus ↔ bhnexus): dev CA autofirmada en lugar de SPIFFE/SVID de Vault/SPIRE

**Lo que NO se implementa en Etapa 1 (se agrega en Etapa 3):**
- SPIFFE/SVID real (necesita SPIRE + Vault)
- Puerta 2 (bhnexus ↔ bAuth via Unix socket TLV)
- HAL (OSDP, MQTT, ONVIF, Wiegand)
- Auth Cache con invalidación real desde bAuth
- Policy Cache cifrado en banexus

**Las 5 formas de banexus y su representación en código:**

| Forma | Artefacto | Dónde vive en el árbol |
|-------|-----------|------------------------|
| `banexus-daemon` | Binario Rust MUSL (systemd --user en workstation/POS) | `banexus/daemon/` |
| `banexus-gateway` | **Mismo binario** que daemon — `mode = "gateway"` en config | `banexus/daemon/` (mismo crate) |
| `banexus-sdk` | Librería nativa `libbauth_nexus` (iOS Swift Package / Android AAR) | `banexus/sdk/` |
| `banexus-virtual` | Sin binario propio — endpoints HTTP/MQTT/WS **dentro de bhnexus** | `bhnexus/virtual/` |
| `banexus-implicit` | Sin binario — protocolo puro (Motor 2.18 en bAuth) | — (no genera código aquí) |

**Estructura Rust completa (Etapa 1 activa en 🟢; resto estructura preparada para E2/E3):**

El código vive en `BauthAgent/src/bnexus/` — igual que `desktop/` vive en
`BauthAgent/src/desktop/`. La documentación vive en `BnexusAgent/context/Documentacion/`
pero el código en `BauthAgent/src/`. (Ver `SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md` §23.4.)

```
BauthAgent/src/bnexus/
├── bhnexus/                          🟢 ETAPA 1
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs                   # Entry point, señales systemd, tokio runtime
│       ├── config/mod.rs             # bhnexus.toml — dev_mode, puertos, certs
│       ├── server/
│       │   ├── mod.rs
│       │   ├── unix_socket.rs        # /run/bos/bhnexus.sock — Interface Dual
│       │   ├── jsonrpc.rs            # Dispatcher JSON-RPC 2.0
│       │   ├── websocket.rs          # WebSocket RPC (operadores humanos)
│       │   └── puerta1.rs            # TCP 9444 — acepta banexus-daemon y banexus-gateway
│       ├── virtual/                  ○ Etapa 2/3 — banexus-virtual (endpoints en bhnexus)
│       │   ├── mod.rs
│       │   ├── http.rs               # Device-initiated REST (IoT HTTP-only)
│       │   ├── mqtt.rs               # MQTT pub/sub (sensores, actuadores)
│       │   └── ws_push.rs            # WebSocket push persistente (pantallas)
│       ├── auth/
│       │   ├── mod.rs
│       │   └── dev_auth.rs           # Etapa 1: dev CA autofirmada (→ SPIFFE/SVID en E3)
│       └── node/
│           ├── mod.rs
│           └── registry.rs           # Registro en memoria de nodos conectados
└── banexus/
    ├── Cargo.toml                    # Workspace: miembros [daemon, sdk]
    ├── daemon/                       🟢 ETAPA 1 — banexus-daemon + banexus-gateway
    │   ├── Cargo.toml                # [[bin]] name = "banexus"
    │   └── src/
    │       ├── main.rs               # Entry point; mode = "daemon"|"gateway" vía config
    │       ├── config/mod.rs         # banexus.toml: mode, host_url, node_id, dev_mode
    │       └── transport/
    │           ├── mod.rs
    │           ├── conexion.rs       # WebSocket mTLS → bhnexus TCP 9444
    │           └── heartbeat.rs      # Ping 30s, reconexión con backoff exponencial
    └── sdk/                          ○ Etapa 3 — banexus-sdk: libbauth_nexus
        ├── Cargo.toml                # [lib] name = "bauth_nexus" → .so/.a + Swift Package / Android AAR
        └── src/
            ├── lib.rs                # API pública: init, authenticate, disconnect
            ├── aliro/                # Aliro CSA 2023: BLE + UWB + NFC
            │   └── mod.rs
            └── ffi/                  # FFI C ABI → JNI (Android) + Swift Package (iOS)
                └── mod.rs
```

**En Etapa 1 solo se compila lo marcado 🟢:** `bhnexus` + `banexus/daemon`. Los directorios
`virtual/` y `sdk/` se crean vacíos como estructura (solo `mod.rs` stub) para que el workspace
esté correctamente organizado desde el inicio.

**Criterio de salida de Etapa 1:**
- `cargo build --release` sin errores en ambos binarios
- `banexus` se conecta a `bhnexus` y aparece en `bhnexus.node.list`
- Heartbeat funciona: banexus envía PING, bhnexus responde PONG
- `bnexusctl status` muestra el nodo activo
- Un `curl` / `wscat` al socket confirma `bhnexus.health` → `operativo`

---

### Etapa 2 — Desktop + Módulo de Identidad

**Objetivo:** con el canal bNexus vivo (aunque sea en modo dev), desarrollar el desktop y el
módulo de identidad + roles template. bAuth ya tiene su socket activo — el desktop usa
banexus-implicit (Motor 2.18) y se conecta directamente a bAuth.

**Por qué desbloquea el desktop:**
- El desktop conecta a bAuth vía `banexus-implicit` — directo al socket de bAuth, no pasa por
  bhnexus. Pero necesita que el ecosistema esté "vivo": un bhnexus corriendo (aunque sea en
  modo dev) confirma que la infraestructura base funciona.
- Los certificados de desarrollo generados en Etapa 1 sirven también para el desktop en fase dev.

**Qué se desarrolla en Etapa 2:**

| Módulo | Dónde | Qué hace |
|--------|-------|----------|
| Identity module (desktop) | `BauthAgent/src/desktop/` | Vista D00-D01 — identidades organizacionales |
| Roles template (desktop) | `BauthAgent/src/desktop/` | Vista de árbol de roles (134 bloques) |
| Auth flow (desktop) | `BauthAgent/src/desktop/` | Login user+password → JWT → Dashboard |
| bNexus: node detail (desktop) | `BauthAgent/src/desktop/` | Vista de nodos bNexus activos (consume `bhnexus.node.list`) |

**bNexus en Etapa 2:** sin cambios de código — sigue en modo dev. Solo se usa como infraestructura
de prueba para que el desktop pueda mostrar el panel de nodos.

---

### Etapa 3 — Expansión bNexus (Auth Real + Hardware)

**Objetivo:** reemplazar la auth simulada con SPIFFE/SVID real e implementar el HAL completo.
Esta etapa se inicia cuando el módulo de identidad y roles template del desktop estén
operativos — porque para provisionar SPIFFE/SVID se necesita identidades reales en SBOSDB.

**Submódulos en orden de implementación:**

```
3.1  Auth real          SPIFFE/SVID + Vault PKI — reemplaza dev_auth.rs
3.2  Puerta 2           Unix socket TLV bhnexus ↔ bAuth (sub-canal A)
                        Canal privilegiado /run/bos/bauth-nexus.sock (sub-canal B)
3.3  Auth Cache         In-memory TTL 30s + invalidación por push de bAuth
3.4  HAL — OSDP         Driver RS-485, protocolo SIA IEC 60839-11-5
3.5  HAL — Wiegand      Driver GPIO 26-bit / 34-bit
3.6  HAL — MQTT         Broker local, protocolo OASIS 5.0
3.7  HAL — ONVIF        Profile C/A — cámaras y control de acceso
3.8  HAL — USB HID      udev rule 99-banexus + libusb bulk transfer
3.9  Policy Cache       AES-256-GCM disco efímero en banexus
3.10 Actuator Ctrl      RS-232/GPIO/HTTP — frame 3 bytes + auto-close timer
3.11 Shell Sentinel     PAM pam_banexus.so + LD_PRELOAD + eBPF
3.12 Políticas físicas  APB, 2PR, Mantrap (manual 3.04)
3.13 Input Hooking      udev + libusb antes de evdev
3.14 Integrity Monitor  SHA-256 del binario al arrancar
```

---

## 3. Mapa de dependencias entre etapas

```
ETAPA 1 (Canal vivo)
  └── Prerrequisito de todo lo demás

      ├── ETAPA 2 (Desktop + Identity)
      │     ├── bAuth socket activo (ya existe)
      │     ├── SBOSDB con datos (seeds existentes)
      │     └── bNexus en modo dev (Etapa 1)
      │
      └── ETAPA 3 (Expansión)
            ├── Módulo de identidad DONE (Etapa 2)
            │   → para provisionar SPIFFE/SVID reales
            ├── bAuth Puerta 2 implementada
            └── Etapas 3.1 → 3.14 en orden
```

---

## 4. Configuración de modo dev (Etapa 1)

`bhnexus.toml` — sección de desarrollo:
```toml
[dev]
# Activo solo si este flag es true — PROHIBIDO en producción
dev_mode = true

# CA local para Puerta 1 (banexus ↔ bhnexus).
# Generada con: openssl req -x509 -newkey rsa:4096 -days 365 ...
# En Etapa 3 se reemplaza por SPIFFE/SVID de Vault/SPIRE.
dev_ca_cert = "/etc/bhnexus/dev/ca.crt"
dev_ca_key  = "/etc/bhnexus/dev/ca.key"

# En dev_mode, las auth requests de Puerta 1 retornan GRANTED sin consultar bAuth.
# (Puerta 2 aún no implementada en Etapa 1.)
dev_granted_bitmask = "0xFFFFFFFFFFFFFFFF"

[bauth]
# bhnexus obtiene la clave pública de bAuth para validar JWT.
# bauth.token.jwks (RFC 7517) — EdDSA Ed25519 real, no simulado.
jwks_socket  = "/run/bos/bauth.sock"
jwks_method  = "bauth.token.jwks"
```

`banexus.toml` — sección de desarrollo:
```toml
[dev]
dev_mode     = true
dev_ca_cert  = "/etc/banexus/dev/ca.crt"
# En dev_mode: banexus genera su propio cert firmado por la dev CA al arrancar
auto_gen_cert = true
```

**Protección contra uso en producción:**
```rust
// En main.rs de bhnexus — primera comprobación al arrancar
if config.dev.dev_mode && std::env::var("SBOS_ENV").unwrap_or_default() == "production" {
    eprintln!("[FATAL] dev_mode=true está prohibido en SBOS_ENV=production");
    std::process::exit(1);
}
```

---

## 5. Lo que NO cambia entre etapas

El protocolo de wire (A.02, A.03), el formato de heartbeat (5.01), los métodos JSON-RPC
(9.01), la estructura de mensajes (A.02) y la Interface Dual (2.03) son **idénticos** en las
tres etapas. Lo único que cambia es el mecanismo de autenticación y los módulos de hardware.

El desktop desarrollado en Etapa 2 **no necesita modificarse** cuando bNexus pase a Etapa 3
con auth real — el protocolo que consume es el mismo.

---

## Changelog

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.3.0 | 2026-08-05 | Corrección: banexus reorganizado en 5 formas — daemon+gateway (mismo binario en `daemon/`), sdk (`libbauth_nexus` en `sdk/`), virtual (endpoints en `bhnexus/virtual/`, no en banexus), implicit (sin código). Tabla de formas + árbol con marcas 🟢/○ por etapa. |
| 1.2.0 | 2026-08-05 | Corrección: código en `BauthAgent/src/bnexus/bhnexus/` y `BauthAgent/src/bnexus/banexus/` — igual que desktop en src/desktop/ (SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md §23.4) |
| 1.1.0 | 2026-08-05 | Corrección: JWT no se simula — bAuth ya emite tokens EdDSA Ed25519 reales (token_issue + token_jwks). Solo la CA de Puerta 1 es simulada en E1. Eliminado dev_jwt_secret incorrecto. |
| 1.0.0 | 2026-08-05 | Versión inicial — 3 etapas bootstrap, estructura Rust E1, config dev_mode, mapa de dependencias |
