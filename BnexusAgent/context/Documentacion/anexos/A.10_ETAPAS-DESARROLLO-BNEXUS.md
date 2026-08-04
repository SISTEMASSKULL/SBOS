# A.10 — Etapas de Desarrollo de bNexus
## Estrategia bootstrap para romper el ciclo huevo-gallina

**Versión:** 1.0.0
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

**Solución:** desarrollo por etapas con **auth simulada** en la Etapa 1. Se abre el canal de
comunicación con una CA local de desarrollo (sin Vault, sin SPIRE) solo para tener los binarios
compilando y el puerto 9444 vivo. Con eso se desbloquean el desktop y el módulo de identidad.
Luego se reemplaza la simulación con la auth real.

---

## 2. Las tres etapas

### Etapa 1 — Canal vivo (Bootstrap)

**Objetivo:** bhnexus y banexus compilados, conectados, canal Puerta 1 activo con auth simulada.

**Qué se implementa:**

| Componente | Qué hace | Auth |
|-----------|----------|------|
| `bhnexus` | Unix socket `/run/bos/bhnexus.sock` (Interface Dual ADR-020) + TCP 9444 escuchando | Dev CA local — acepta cualquier cert firmado por ella |
| `banexus` | Se conecta a bhnexus por TCP 9444, envía heartbeat cada 30s, JSON-RPC básico funciona | Dev CA local — cert autogenerado al arrancar |
| Auth requests | Retornan `GRANTED` hardcodeado en modo dev | Flag `dev_mode = true` en `bhnexus.toml` |
| Interface Dual | `bhnexus.health`, `bhnexus.node.list`, `bhnexus.status` — métodos mínimos | JWT simulado (firma local, no Vault) |

**Lo que NO se implementa en Etapa 1:**
- SPIFFE/SVID real (necesita SPIRE + Vault)
- HAL (OSDP, MQTT, ONVIF, Wiegand)
- Auth Cache con invalidación real desde bAuth
- Policy Cache cifrado en banexus

**Estructura Rust mínima para Etapa 1:**
```
BnexusAgent/src/
├── bhnexus/
│   ├── Cargo.toml
│   └── src/
│       ├── main.rs          # Entry point, señales systemd, tokio runtime
│       ├── config/mod.rs    # bhnexus.toml — dev_mode, puertos, certs
│       ├── server/
│       │   ├── mod.rs
│       │   ├── unix_socket.rs   # /run/bos/bhnexus.sock — Interface Dual
│       │   ├── jsonrpc.rs       # Dispatcher JSON-RPC 2.0
│       │   ├── websocket.rs     # WebSocket RPC (operadores)
│       │   └── puerta1.rs       # TCP 9444 — acepta banexus agents
│       ├── auth/
│       │   ├── mod.rs
│       │   └── dev_auth.rs  # Etapa 1: auth simulada (dev_mode=true)
│       └── node/
│           ├── mod.rs
│           └── registry.rs  # Registro en memoria de nodos conectados
└── banexus/
    ├── Cargo.toml
    └── src/
        ├── main.rs          # Entry point, señales, tokio runtime
        ├── config/mod.rs    # banexus.toml — host_url, node_id, dev_mode
        └── transport/
            ├── mod.rs
            ├── conexion.rs  # WebSocket client → bhnexus TCP 9444
            └── heartbeat.rs # Ping cada 30s, reconexión con backoff
```

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

# CA local generada con: openssl req -x509 -newkey rsa:4096 -days 365 ...
dev_ca_cert  = "/etc/bhnexus/dev/ca.crt"
dev_ca_key   = "/etc/bhnexus/dev/ca.key"

# En dev_mode, toda auth request retorna GRANTED con este bitmask ficticio
dev_granted_bitmask = "0xFFFFFFFFFFFFFFFF"

# JWT simulado: firmado con clave local, no Vault Ed25519
dev_jwt_secret = "dev-only-secret-cambiar-en-etapa-3"
dev_jwt_ttl_s  = 3600
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
| 1.0.0 | 2026-08-05 | Versión inicial — 3 etapas bootstrap, estructura Rust E1, config dev_mode, mapa de dependencias |
