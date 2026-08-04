# Plan de Documentación — bNexus (bhnexus + banexus)

**Versión:** 3.0.0  
**Fecha:** 2026-08-04  
**Estado:** ACTIVO — incorpora decisiones de sesión 2026-08-04  
**Autor:** bnexus-developer  
**Destinatario:** HITL (humano) — aprobación requerida antes de comenzar Sprint 1  
**Reemplaza:** v2.0.0 (corregía Puerta A falsa pero quedó desactualizado tras decisiones de sesión)

---

## 0. Decisiones de sesión que este plan incorpora

Esta versión actualiza el plan v2.0.0 con cuatro decisiones arquitectónicas tomadas
el 2026-08-04 que cambian elementos concretos del árbol documental:

| Decisión | Impacto en el plan v2.0.0 |
|----------|--------------------------|
| **No hay Device Fichas YAML** — el registro de dispositivos y nodos vive en SBOSDB (`bauth.idn_identity_entity`, árbol universal de bAuth) | `1.03_MANUAL-DEVICE-FICHAS` → `1.03_MANUAL-IDENTIDADES-NEXUS`; `A.04`/`A.05` fichas YAML → eliminados; nuevos `A.04`/`A.05` sobre identidades en SBOSDB |
| **bNexus no tiene base de datos propia** — los nodos banexus y dispositivos se registran en SBOSDB como entidades del árbol universal | Sección "Qué NO entra" corregida; bhnexus_db eliminado del plan |
| **Cinco formas de banexus** (daemon, gateway, sdk, virtual, implicit) — banexus no es solo un daemon de workstation | Nuevo manual `1.06_MANUAL-FORMAS-BANEXUS.md` y nuevo anexo `A.05` |
| **La Puerta 2 es bidireccional** — además del canal request/response (bhnexus→bAuth), existe un canal privilegiado de push (`/run/bos/bauth-nexus.sock`) donde bAuth empuja eventos críticos a bhnexus y bhnexus reporta hardware events a bAuth | `2.02_MANUAL-PUERTA-2-BAUTH` ampliado; dos sub-canales documentados |
| **La conceptualización v3.6 ya es el 1.01** — `SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md` tiene nivel y profundidad de manual formal; puede promoverse directamente como 1.01 | `1.01_MANUAL-TOPOLOGIA-NEXUS` no se escribe desde cero — se formaliza desde la conceptualización existente |

---

## 1. Arquitectura real de bNexus — las dos puertas y el canal privilegiado

```
Aplicaciones (desktop Flutter, web, CLI, backend)
          │
          │  Motor de Comunicación 2.18 — bAuth
          │  WebSocket + JSON-RPC 2.0
          │  JWT Bearer + mTLS + W3C Trace Context
          ▼
       /run/bos/bauth.sock
       bAuth (PDP — fuente de verdad de identidad)
          ▲  ▲
          │  └──────── CANAL PRIVILEGIADO BIDIRECCIONAL ──────────┐
          │            /run/bos/bauth-nexus.sock                   │
          │  PUERTA 2  bAuth → bhnexus: emergency_revoke,         │
          │  (request) policy_sync, blacklist_node,               │
          │  Unix socket TLV security_level_up                    │
          │  bitmask_request   bhnexus → bAuth: device_tamper,    │
          │  bitmask_response  node_offline, auth_spike,          │
          │                    hardware_failure, integrity_breach  │
       bhnexus:9444  ◄─────────────────────────────────────────────┘
       (Rust, tokio)
       Auth Cache (in-memory, TTL 30s, 100K entradas)
       HAL (6 drivers: OSDP, MQTT, ONVIF, Wiegand, USB HID, HTTP)
       Policy Dispatcher (invalida cache + push policy_update a banexus)
          ▲
          │  PUERTA 1
          │  WebSocket mTLS (SPIFFE/SVID X.509)
          │  auth_request / auth_response / policy_update / heartbeat
          │  Reconexión backoff: 1s → 5s → 15s → 30s → 60s
          │
       banexus  (cinco formas — ver §1.2)
```

### 1.1 Puerta 1 — banexus ↔ bhnexus

| Aspecto | Valor |
|---------|-------|
| Transporte | WebSocket sobre mTLS (SPIFFE/SVID, CA interna SBOS) |
| Endpoint bhnexus | `wss://<host>:9444/ws` |
| Identidad cliente | SVID X.509 → SPIFFE ID: `spiffe://sbos.skull/agent/banexus/<node_id>` |
| Heartbeat | cada 15 segundos (desde banexus) |
| Reconexión | backoff exponencial: 1 → 5 → 15 → 30 → 60 s |
| Latencia objetivo | < 50ms total (credencial física → actuator_commands) |

Frames: `auth_request` · `auth_response` · `policy_update` · `heartbeat`

### 1.2 Las cinco formas de banexus

banexus siempre existe en alguna forma — la pregunta no es "¿se necesita?" sino "¿qué forma toma?":

| Forma | Cómo se despliega | Escenario típico |
|-------|-------------------|-----------------|
| **banexus-daemon** | Binario Rust MUSL, systemd en workstation/POS Fedora | Terminal de venta, PC de control |
| **banexus-gateway** | Mismo binario, `mode = gateway`, en SBC/Pi remoto | Sucursal a distancia, otro edificio |
| **banexus-sdk** | Librería nativa iOS/Android — estándar Aliro (CSA 2023) BLE+UWB+NFC | App móvil corporativa |
| **banexus-virtual** | Dispositivo auto-actuante con HTTP/REST — llama endpoint bAuth, ejecuta él mismo | Cerradura WiFi con firmware fijo |
| **banexus-implicit** | Sin binario — mTLS X.509 + JWT/OIDC + W3C Trace Context | App web, mobile, backend API |

El único escenario sin ninguna forma de banexus es el **HAL Directo de bhnexus**: hardware
mudo en el mismo edificio que el servidor (chapa OSDP local, sensor MQTT en LAN, cámara ONVIF).

### 1.3 Puerta 2 — bhnexus ↔ bAuth (dos sub-canales)

**Sub-canal A — request/response** (bitmask resolution):

| Aspecto | Valor |
|---------|-------|
| Socket | `/run/bos/bauth.sock` |
| Framing | TLV: `[4 bytes uint32 BE: longitud][N bytes JSON UTF-8]` |
| Timeout | 1000ms · Pool: máx 100 conexiones |
| Iniciador | siempre bhnexus → bAuth |

Frames: `bitmask_request` · `bitmask_response`

**Sub-canal B — canal privilegiado** (push bidireccional):

| Aspecto | Valor |
|---------|-------|
| Socket | `/run/bos/bauth-nexus.sock` |
| Carácter | Persistente · bidireccional · latencia < 5ms |

| Dirección | Eventos |
|-----------|---------|
| bAuth → bhnexus | `emergency_revoke` · `invalidate_cache` · `security_level_up` · `blacklist_node` · `policy_sync` |
| bhnexus → bAuth | `device_tamper` · `node_offline` · `auth_spike` · `hardware_failure` · `integrity_breach` |

### 1.4 Registro de identidades — SBOSDB, no YAML

Los nodos banexus y dispositivos físicos **no se registran en ficheros YAML**.
Se registran en SBOSDB como entidades del árbol universal de bAuth:

```
bAuth (idn_identity_entity — árbol de 5 niveles)
  └── Nivel ACTOR (entity_type variable)
        ├── entity_type = 'banexus_node'    → nodo banexus registrado
        ├── entity_type = 'osdp_reader'     → lector OSDP
        ├── entity_type = 'nfc_reader'      → lector NFC
        ├── entity_type = 'iot_sensor'      → sensor MQTT
        └── entity_type = 'ip_camera'       → cámara ONVIF
```

Tablas complementarias (no son la identidad — son postura/gobernanza):
- `bauth.auth_device` — postura de hardware (trust_level, MDM, OSDP config)
- `bauth.idn_roles_nhi_identity` — gobernanza NHI (lifecycle, secret rotation)

### 1.5 Relación con Motor de Comunicación 2.18 de bAuth

| | Motor 2.18 | Puerta 1 | Puerta 2 |
|--|------------|----------|----------|
| Cliente | App Flutter/web/CLI | banexus (cinco formas) | bhnexus broker |
| Servidor | bAuth | bhnexus:9444 | bAuth Unix socket |
| Transporte | WebSocket + JWT | WebSocket + mTLS | Unix socket TLV |
| ctx_id | Obligatorio (SBOS-049) | Obligatorio (generado por banexus) | Obligatorio (propagado) |
| Latencia | < 200ms (UX) | < 50ms (físico) | < 10ms (interno) |

Los tres son caminos **paralelos**, no en cadena. Las aplicaciones NO pasan por bhnexus.

---

## 2. Estado actual — qué existe y qué falta

### 2.1 Documentación existente (`context/docs/`)

| Archivo | Contenido | Calidad |
|---------|-----------|---------|
| `SBOS-NEXUS-CONCEPTUALIZACION-v3_0.md` (v3.6) | Topología tres capas, HAL, flujos, modelo identidad SBOSDB, cinco formas banexus, PDP/PEP/PEA, canal privilegiado | **Alta — actúa como 1.01** |
| `bhnexus/SBOS_bhnexus_ARQUITECTURA.md` | Stack Rust, WebSocket, HAL, SPIFFE | Buena |
| `bhnexus/SBOS_bhnexus_FUNCIONALIDADES.md` | Auth cache, hardware bridge, policy dispatcher | Buena |
| `bhnexus/SBOS_bhnexus_INTEGRACIONES.md` | Contratos INT-BHNEXUS-001..004 con frames completos | Buena |
| `bhnexus/SBOS_bhnexus_SEGURIDAD.md` | mTLS, Wazuh, 8 reglas de alerta | Buena |
| `bhnexus/SBOS_bhnexus_DATOS.md` | Estructuras, SAM-128 | Buena |
| `banexus/SBOS_banexus_ARQUITECTURA.md` | Stack Rust, udev, PAM, serial, AES cache | Buena |
| `banexus/SBOS_banexus_FUNCIONALIDADES.md` | Input hooking, shell sentinel, actuadores | Buena |
| `banexus/SBOS_banexus_INTEGRACIONES.md` | Contratos INT-BANEXUS-001..004 con flujos | Buena |
| `banexus/SBOS_banexus_SEGURIDAD.md` | AES-256-GCM, integridad SHA-256, fail-secure | Buena |

### 2.2 Qué falta

| Gap | Impacto |
|-----|---------|
| No existe `INDICE.md` ni manuales numerados | Sin mapa de entrada — no navegable |
| No hay `MOTORES/` | Sin punto único de referencia por capacidad |
| **Puerta 1** no tiene manual canónico dedicado | Los frames están en INTEGRACIONES pero no formalizados como spec |
| **Puerta 2** (bidireccional) no tiene contrato formal que incluya el canal privilegiado | Riesgo de desincronización bAuth↔bhnexus |
| No hay manual de las cinco formas de banexus | Los equipos no saben qué forma desplegar por escenario |
| No hay manual de registro de identidades en SBOSDB para bNexus | Confusión sobre cómo registrar nodos y dispositivos |
| No hay manual de normas (OSDP SIA, mTLS, NIST SP 800-207, ISO 27001 A.7) | Sin trazabilidad normativa |
| No hay manuales de SAM-128, HAL, Input Hooking, Shell Sentinel | El código no tiene spec de referencia |

---

## 3. Mapa de manuales propuesto

```
1 Topología → 2 Conectividad → 3 Hardware → 4 Intercepción
→ 5 Cache & Resiliencia → 6 Integración → 7 Normas & Operación · 9 Producto
```

### Fase 1 — TOPOLOGÍA

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 1.01 | La unidad bNexus: tres capas, misión, topología, posición en los 8 daemons | **CONCEPTUALIZACION v3.6 — promover directamente** | P1 |
| 1.02 | Árbol jerárquico físico (11 niveles: TENANT → ACTOR) | CONCEPTUALIZACION §10 | P1 |
| 1.03 | Identidades bNexus en SBOSDB — registro de nodos y dispositivos en `idn_identity_entity` | CONCEPTUALIZACION §11 + DDL Manual T-156 | P1 |
| 1.04 | Tipos de credencial (QR, NFC, RFID, biométrico, smartcard, BLE, PIN) | CONCEPTUALIZACION §14 | P2 |
| 1.05 | SAM-128: estructura 128 bits, evaluación O(1), relación con bAuth BitMask | CONCEPTUALIZACION §12 + bhnexus_DATOS | P1 |
| 1.06 | Las cinco formas de banexus — taxonomía, criterios de selección, árbol de decisión | CONCEPTUALIZACION §20.5 + §20.8 + §20.9 | P1 |

### Fase 2 — CONECTIVIDAD ★ PRIORIDAD BLOQUEANTE

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 2.01 | **Puerta 1 — Protocolo banexus ↔ bhnexus** (WebSocket mTLS, SPIFFE, frames auth_request/response/policy_update/heartbeat) | bhnexus_INTEGRACIONES INT-001 + banexus_INTEGRACIONES INT-001 | **P0** |
| 2.02 | **Puerta 2 — Protocolo bhnexus ↔ bAuth** (dos sub-canales: Unix socket TLV bitmask_request/response + canal privilegiado bidireccional bauth-nexus.sock) | bhnexus_INTEGRACIONES INT-002 + canal privilegiado | **P0** |
| 2.03 | Interface Dual de bNexus (ADR-020 aplicado: `/run/bos/bhnexus.sock` + TCP 9444) | CLAUDE.md + CONCEPTUALIZACION | P1 |
| 2.04 | Sagas de comunicación bNexus (conexión mTLS, reconexión backoff, policy push, offline recovery) | CONCEPTUALIZACION §13 | P1 |

### Fase 3 — HARDWARE

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 3.01 | HAL: DeviceDriver interface, pipeline de captura, 6 implementaciones | bhnexus_ARQUITECTURA + bhnexus_INTEGRACIONES INT-003 | P2 |
| 3.02 | Drivers: OSDP v2.2, MQTT 5.0, ONVIF Profile C, Wiegand, USB HID, HTTP | CONCEPTUALIZACION §9 | P2 |
| 3.03 | Flujos por tipo de credencial (QR dinámico, NFC DESFire, biométrico hash, smartcard X.509) | CONCEPTUALIZACION §14 | P2 |
| 3.04 | Políticas físicas: Anti-passback, Two-Person Rule, Mantrap | CONCEPTUALIZACION §9 | P3 |

### Fase 4 — INTERCEPCIÓN (banexus — el sentinel de borde)

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 4.01 | Input Hooking: udev + libusb (captura antes de evdev, anti-inyección) | banexus_ARQUITECTURA + banexus_INTEGRACIONES INT-002 | P2 |
| 4.02 | Shell Sentinel: pam_banexus.so — interceptación de comandos sensibles | banexus_INTEGRACIONES INT-003 | P2 |
| 4.03 | Actuator Controller: relés, puertas, cajones (RS-232, timer auto-close) | banexus_INTEGRACIONES INT-004 | P3 |
| 4.04 | Integridad de banexus: SHA-256 cada 5 min, auto-shutdown, alerta Wazuh | banexus_SEGURIDAD | P2 |

### Fase 5 — CACHE & RESILIENCIA

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 5.01 | Auth Cache de bhnexus (in-memory, TTL 30s, 100K entradas, invalidación por policy_update) | CONCEPTUALIZACION §12 + bhnexus_DATOS | P1 |
| 5.02 | Policy Cache de banexus (AES-256-GCM, clave derivada cert mTLS via HKDF-SHA256, TTL 4h, fail-secure) | banexus_INTEGRACIONES INT-001 | P1 |
| 5.03 | Comportamiento offline y fail-secure (banexus sin bhnexus; bhnexus sin bAuth; gateway en sucursal) | CONCEPTUALIZACION §13 + §20.8 | P1 |

### Fase 6 — INTEGRACIÓN

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 6.01 | Flujo de política: cambio de RolTemplate → bAuth → canal privilegiado → bhnexus → policy_update → banexus | CONCEPTUALIZACION §15 + §22 | P1 |
| 6.02 | bhnexus ↔ bkernel: registro de eventos de acceso físico en WAL | CONCEPTUALIZACION §5 | P3 |
| 6.03 | bhnexus ↔ bsearch: indexación de eventos de autenticación | bhnexus_INTEGRACIONES INT-004 | P3 |

### Fase 7 — NORMAS & OPERACIÓN

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 7.01 | Normas aplicables (OSDP SIA/IEC 60839-11-5, MQTT OASIS, ONVIF, Aliro CSA 2023, ISO 27001 A.7, NIST SP 800-207) | CONCEPTUALIZACION §9 | P2 |
| 7.02 | Seguridad de bNexus (mTLS, SPIFFE, AES-256-GCM, canal privilegiado, Wazuh 8 reglas, integridad banexus) | bhnexus_SEGURIDAD + banexus_SEGURIDAD | P2 |
| 7.03 | Operación (systemd bhnexus.service + banexus.service --user, TOML config, Prometheus 9 métricas) | CONCEPTUALIZACION §16,17 | P2 |
| 7.04 | CLI y pruebas (bnexusctl, verificación de Puerta 1 y Puerta 2 con herramientas) | NUEVO | P3 |

### Serie 9 — PRODUCTO

| N° | Manual | Fuente | P |
|:--:|--------|--------|:-:|
| 9.01 | Producto bNexus: binarios, API JSON-RPC (~30 métodos `bhnexus.*`/`banexus.*`) | CONCEPTUALIZACION + ARQUITECTURA | P3 |

**Total: 23 manuales** (añade 1.06 formas de banexus respecto a v2.0.0)

---

## 4. Mapa de motores propuesto (`MOTORES/`)

| Motor | Portada | Verbo | Estado |
|-------|---------|-------|:------:|
| Conectividad-1 | `motor-conectividad-agentes.md` | Recibir-agentes (Puerta 1) | ⬜ nuevo |
| Conectividad-2 | `motor-identidad-bauth.md` | Resolver-identidad (Puerta 2 — bidireccional) | ⬜ nuevo |
| Hardware | `motor-hardware.md` | Normalizar | ⬜ nuevo |
| Cache | `motor-cache.md` | Cachear | ⬜ nuevo |
| Intercepción | `motor-intercepcion.md` | Interceptar (Input Hooking + Shell Sentinel) | ⬜ nuevo |
| Actuación | `motor-actuacion.md` | Actuar (relay, RS-232, GPIO) | ⬜ nuevo |

---

## 5. Mapa de anexos propuesto (`anexos/`)

| Anexo | Respalda | P |
|-------|---------|:-:|
| A.01 — Flujo soberano completo (QR → banexus → bhnexus → bAuth → actuator, tiempos verificados) | 1.01, 2.01, 2.02 | P1 |
| A.02 — Spec protocolo wire Puerta 1 (frames JSON banexus↔bhnexus, mTLS, reconexión, timing) | 2.01 | **P0** |
| A.03 — Spec protocolo wire Puerta 2 (TLV Unix socket bitmask_request/response + canal privilegiado bauth-nexus.sock, todos los eventos) | 2.02 | **P0** |
| A.04 — Identidades bNexus en SBOSDB (ejemplos completos: nodo banexus, lector OSDP, sensor MQTT en `idn_identity_entity`) | 1.03 | P1 |
| A.05 — Árbol de decisión formas de banexus (matriz escenario × forma, criterios de selección) | 1.06 | P1 |
| A.06 — SAM-128: mapeo de bits (Q1-Q8) con correspondencia a bAuth BitMask 64-bit | 1.05 | P1 |
| A.07 — HAL: inventario de drivers y tipos de credencial (tabla completa con LoA y timing) | 3.01, 3.02 | P2 |
| A.08 — Contrato bilateral bhnexus ↔ bAuth (ubicar en `context/contracts/` — ver HITL H-01) | 2.02, 6.01 | P1 |
| A.09 — Seguridad: mTLS spec, SPIFFE IDs, AES-256-GCM key derivation, canal privilegiado threat model, Wazuh 8 reglas | 7.02 | P2 |

---

## 6. Secuencia de escritura — orden estricto

```
SPRINT 1 — PRIORIDAD BLOQUEANTE (las dos puertas + base documental)

  1.  0.00_MANUAL-DIRECTRICES-NEXUS.md
  2.  INDICE.md
  3.  MOTORES/MOTORES-INDEX.md
  4.  1.01_MANUAL-TOPOLOGIA-NEXUS.md        ← promover desde CONCEPTUALIZACION v3.6
  5.  1.03_MANUAL-IDENTIDADES-NEXUS.md      ← NUEVO (reemplaza device fichas YAML)
  6.  1.05_MANUAL-SAM128.md
  7.  1.06_MANUAL-FORMAS-BANEXUS.md         ← NUEVO
  8.  2.01_MANUAL-PUERTA-1-AGENTES.md       ← ★ BLOQUEANTE
  9.  2.02_MANUAL-PUERTA-2-BAUTH.md         ← ★ BLOQUEANTE (incluye canal privilegiado)
  10. anexos/A.02_PROTOCOLO-WIRE-PUERTA-1.md
  11. anexos/A.03_PROTOCOLO-WIRE-PUERTA-2.md
  12. anexos/A.04_IDENTIDADES-BNEXUS-SBOSDB.md
  13. anexos/A.05_ARBOL-DECISION-FORMAS-BANEXUS.md

SPRINT 2 — BASE TOPOLÓGICA Y RESILIENCIA

  14. 1.02_MANUAL-ARBOL-FISICO.md
  15. 1.04_MANUAL-TIPOS-CREDENCIAL.md
  16. 2.03_MANUAL-INTERFACE-DUAL-NEXUS.md
  17. 2.04_MANUAL-SAGAS-NEXUS.md
  18. 5.01_MANUAL-AUTH-CACHE-BHNEXUS.md
  19. 5.02_MANUAL-POLICY-CACHE-BANEXUS.md
  20. 5.03_MANUAL-OFFLINE-FAILSECURE.md
  21. 6.01_MANUAL-FLUJO-POLITICA.md
  22. anexos/A.01_FLUJO-SOBERANO-COMPLETO.md
  23. anexos/A.06_SAM128-MAPA-BITS.md
  24. anexos/A.08_CONTRATO-BHNEXUS-BAUTH.md

SPRINT 3 — HARDWARE & INTERCEPCIÓN

  25. 3.01_MANUAL-HAL.md
  26. 3.02_MANUAL-DRIVERS.md
  27. 3.03_MANUAL-FLUJOS-CREDENCIAL.md
  28. 4.01_MANUAL-INPUT-HOOKING.md
  29. 4.02_MANUAL-SHELL-SENTINEL.md
  30. 4.04_MANUAL-INTEGRIDAD-BANEXUS.md
  31. anexos/A.07_HAL-INVENTARIO-DRIVERS.md

SPRINT 4 — NORMAS, OPERACIÓN & PRODUCTO
  (el resto en orden de dependencia)
```

---

## 7. Decisiones HITL pendientes antes de Sprint 1

| ID | Decisión | Opciones | Impacto |
|----|----------|----------|---------|
| **H-01** | ¿El contrato bhnexus ↔ bAuth se escribe en `context/contracts/` del proyecto SBOS (bilateral, patrón establecido por BOS-BAUTH-CONTRATOS.md) o como `anexos/A.08` interno de bNexus? | `contracts/BHNEXUS-BAUTH-CONTRATOS.md` (recomendado — coherente con patrón SBOS, cogestión bilateral) / `anexos/A.08` (interno, solo bNexus lo mantiene) | Ubicación y custodia del contrato |
| **H-02** | La carta rectora (0.00): ¿adaptar el esquema de bAuth (7 pilares IAM Enterprise) para Conectividad & Edge, o esquema propio desde cero? | Adaptar bAuth 0.00 (coherencia del corpus SBOS) / Esquema propio (especificidad de bNexus) | Coherencia editorial del corpus SBOS |

---

## 8. Qué NO entra en esta documentación

| Excluido | Razón |
|---------|-------|
| Puerta de clientes de aplicación (desktop, web, CLI) | No existe en bNexus — ese path va directo a bAuth vía Motor 2.18 |
| Gestión de identidad (crear usuarios, roles, templates) | Responsabilidad exclusiva de bAuth |
| Almacenamiento de templates biométricos | bNexus solo recibe hashes — RGPD compliance |
| Fichas YAML de dispositivos o nodos | No existen — el registro es en SBOSDB (`bauth.idn_identity_entity`) |
| Base de datos propia de bNexus | bNexus no tiene base de datos propia — lee de SBOSDB vía bAuth |
| KPIs de negocio | bNexus emite métricas Prometheus, no KPIs |
| Motor de Comunicación 2.18 duplicado | 2.18 es la spec para clientes de app → bAuth; bNexus define sus propias puertas |

---

## 9. Estructura de carpetas propuesta

```
BnexusAgent/context/Documentacion/
├── INDICE.md
├── 0.00_MANUAL-DIRECTRICES-NEXUS.md
├── 1.01_MANUAL-TOPOLOGIA-NEXUS.md            ← desde CONCEPTUALIZACION v3.6
├── 1.02_MANUAL-ARBOL-FISICO.md
├── 1.03_MANUAL-IDENTIDADES-NEXUS.md          ← NUEVO (reemplaza device fichas)
├── 1.04_MANUAL-TIPOS-CREDENCIAL.md
├── 1.05_MANUAL-SAM128.md
├── 1.06_MANUAL-FORMAS-BANEXUS.md             ← NUEVO
├── 2.01_MANUAL-PUERTA-1-AGENTES.md           ← ★ P0
├── 2.02_MANUAL-PUERTA-2-BAUTH.md             ← ★ P0 (bidireccional)
├── 2.03_MANUAL-INTERFACE-DUAL-NEXUS.md
├── 2.04_MANUAL-SAGAS-NEXUS.md
├── 3.01_MANUAL-HAL.md
├── 3.02_MANUAL-DRIVERS.md
├── 3.03_MANUAL-FLUJOS-CREDENCIAL.md
├── 3.04_MANUAL-POLITICAS-FISICAS.md
├── 4.01_MANUAL-INPUT-HOOKING.md
├── 4.02_MANUAL-SHELL-SENTINEL.md
├── 4.03_MANUAL-ACTUATOR-CONTROLLER.md
├── 4.04_MANUAL-INTEGRIDAD-BANEXUS.md
├── 5.01_MANUAL-AUTH-CACHE-BHNEXUS.md
├── 5.02_MANUAL-POLICY-CACHE-BANEXUS.md
├── 5.03_MANUAL-OFFLINE-FAILSECURE.md
├── 6.01_MANUAL-FLUJO-POLITICA.md
├── 6.02_MANUAL-BKERNEL-WAL.md
├── 6.03_MANUAL-BSEARCH-INDEX.md
├── 7.01_MANUAL-NORMAS-NEXUS.md
├── 7.02_MANUAL-SEGURIDAD-NEXUS.md
├── 7.03_MANUAL-OPERACION-NEXUS.md
├── 7.04_MANUAL-CLI-PRUEBAS.md
├── 9.01_MANUAL-PRODUCTO-NEXUS.md
├── MOTORES/
│   ├── MOTORES-INDEX.md
│   ├── motor-conectividad-agentes.md         ← Puerta 1
│   ├── motor-identidad-bauth.md              ← Puerta 2 (bidireccional)
│   ├── motor-hardware.md
│   ├── motor-cache.md
│   ├── motor-intercepcion.md
│   └── motor-actuacion.md
└── anexos/
    ├── INDICE-ANEXOS.md
    ├── A.01_FLUJO-SOBERANO-COMPLETO.md
    ├── A.02_PROTOCOLO-WIRE-PUERTA-1.md       ← ★ P0
    ├── A.03_PROTOCOLO-WIRE-PUERTA-2.md       ← ★ P0 (incluye canal privilegiado)
    ├── A.04_IDENTIDADES-BNEXUS-SBOSDB.md     ← NUEVO
    ├── A.05_ARBOL-DECISION-FORMAS-BANEXUS.md ← NUEVO
    ├── A.06_SAM128-MAPA-BITS.md
    ├── A.07_HAL-INVENTARIO-DRIVERS.md
    ├── A.08_CONTRATO-BHNEXUS-BAUTH.md
    └── A.09_SEGURIDAD-MTLS-AES.md
```

---

## 10. Resumen ejecutivo

**¿Qué cambia respecto a v2.0.0?**
Cuatro correcciones derivadas de las decisiones del 2026-08-04:
- Device Fichas YAML eliminadas → identidades en SBOSDB
- bNexus no tiene BD propia
- Cinco formas de banexus formalizadas (nuevo manual 1.06 + nuevo anexo A.05)
- Puerta 2 es bidireccional (canal privilegiado `/run/bos/bauth-nexus.sock`)

**¿Cuáles son las dos puertas reales?**
- **Puerta 1**: banexus ↔ bhnexus (WebSocket mTLS, SPIFFE, frames JSON)
- **Puerta 2**: bhnexus ↔ bAuth — dos sub-canales: Unix socket TLV (bitmask) + canal privilegiado bidireccional (push crítico)

**¿Por dónde empezar? (Sprint 1)**
Los dos manuales P0 (2.01 y 2.02) con sus dos anexos (A.02 y A.03), más el 1.01 promovido
desde la conceptualización v3.6 y los dos manuales nuevos (1.03 identidades, 1.06 formas).
Sin esa base no hay código posible — los contratos de ambas puertas no están formalizados.

**¿Qué necesita el humano decidir antes?**
Solo 2 HITL: H-01 (ubicación del contrato bilateral bhnexus↔bAuth) y H-02
(esquema de la carta rectora 0.00).

---

## Changelog

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 3.0.0 | 2026-08-04 | Incorpora decisiones de sesión: elimina device fichas YAML (→ SBOSDB), elimina bhnexus_db, añade cinco formas de banexus (1.06 + A.05), corrige Puerta 2 como bidireccional (canal privilegiado bauth-nexus.sock), promueve CONCEPTUALIZACION v3.6 como 1.01 |
| 2.0.0 | 2026-08-04 | Corrección crítica: elimina Puerta A falsa; corrige las dos puertas reales; reduce HITL de 5 a 2 |
| 1.0.0 | 2026-08-04 | Versión inicial — **ERROR**: inventó Puerta A inexistente |
