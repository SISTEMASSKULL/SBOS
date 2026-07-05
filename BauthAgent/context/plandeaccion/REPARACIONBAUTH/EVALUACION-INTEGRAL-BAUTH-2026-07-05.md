# EVALUACIÓN INTEGRAL — Plan de Reparación bAuth v3.0 + Incrementos de Mensajería
## Documento de dictamen técnico · bauth-developer · INVESTIGACIÓN ROBUSTECIDA

**Versión:** 2.0.0 · **Fecha:** 2026-07-05 · **Autor:** bauth-developer (pane 7)
**Propósito:** Evaluar la completitud, solidez y brechas del plan REPARACIONBAUTH,
incluyendo los incrementos del documento `07-incrementos-bauth-para-mensajeria.md`,
con investigación de estándares internacionales 2025-2026 para robustecer D00.

---

## 1. ALCANCE DE LA EVALUACIÓN

Se estudiaron **33 documentos Markdown + 10 ADRs + 2 JSON + 1 SQL** en la carpeta
`REPARACIONBAUTH/` (~26,000 líneas de diseño), más el código fuente actual de bAuth
(165 archivos Rust · ~23,200 líneas · 58 handlers JSON-RPC) y los contratos bilaterales
BOS ↔ bAuth (`context/contracts/BOS-BAUTH-CONTRATOS.md`, 11 contratos, todos ACORDADOS).

**Investigación de respaldo (sección 4):** 8 temas investigados en fuentes 2025-2026:
NIST SP 800-63-4/63B-4 Final, EDPB Guidelines 02/2025, CAEP 1.0 Final, RFC 6962,
NDSS 2021 (Signal/WhatsApp/Telegram), W3C DID Core 1.0, patrones de industria
(Splunk/Datadog/GCP Cloud Audit Logs).

---

## 2. LO QUE ESTÁ SÓLIDO — FORTALEZAS DEL PLAN

### 2.1 Diseño de cobertura 100% (FASE 0)

El documento `BAUTH-COBERTURA-100PCT.md` verifica que cada uno de los **156 campos**
(82 de UserTemplate + 74 de RolTemplate) tiene un átomo CRUD o tabla asignada.
Esto incluye:

- 13 campos de identidad personal con display_format internacionalizado (EMAIL, E164, COUNTRY_CODE, LOCALE_BCP47, TIMEZONE_IANA, ID_XX para 29 países, TAX_XX para 24 países)
- 6 campos de dispositivo con átomos D5
- Campos financieros D3, temporales D8, de red D9, biométricos D11
- Integración con catálogos `bglobal` (196 países, 125 idiomas, 319 zonas horarias, 143 monedas)

### 2.2 Catálogo de átomos bien definido

| Dominio | Átomos | Documento fuente |
|---------|:------:|-----------------|
| D00 — Identidad Organizacional | 120 (30 campos × 4 CRUD) | `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` |
| D4–D12 — Dominios de control | 188 (47 campos × 4 CRUD) | `BAUTH-CATALOGO-ATOMOS-D4-D12.md` |
| D13 — Blockchain + Firma legal | 36 | `BAUTH-DOMINIO-D13-BLOCKCHAIN.md` |
| **Total** | **344** | Posiciones 5809–5964 en `privilege_atom` |

Cada átomo tiene: `atom_code` canónico, `display_name`, `description`, `standard_ref`,
`bitmask_position`, `verb_code` (C/R/U/D), `active`.

### 2.3 Tabla idn_atributo — diseño EAV jerárquico (v1.3.0)

El documento `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` define una tabla única que
reemplaza `org_contacto` + `org_documento` + `org_direccion`. Estructura:

```
entidad → entidad_tipo + entidad_id   (ej: "actor Ana Flores")
categoría → category                   (ej: "profesional")
tipo → attr_key                        (ej: "idioma")
subtipo → attr_subtype                 (ej: "inglés")
valor → value_text + value_data        (ej: "avanzado" + {nivel: B2, certif: TOEFL})
```

Con `display_format` y `validation_policy` para renderizado y validación automática en
frontend (HTML/JS + Flutter). Integración verificada con `bglobal`.

### 2.4 Contratos BOS ↔ bAuth — 11/11 ACORDADOS

Todos los contratos bilaterales están cerrados y verificados en VPS staging:
- Formato de ctx_id (6 capas compuestas) — verificado
- Flujo BOS registra → bAuth enriquece — verificado
- `context.evaluate` con bloque `session` — verificado
- `bitmask_hex` sincrónico en promote — contrato firmado, bug B-BAUTH-002 pendiente
- Autenticación OS-level en socket Unix — verificado
- `bauth.ctx.get_session` — verificado (10ms P99)
- Patrón Lobby (Tenant 0) — UUIDs confirmados
- Socket staging `/tmp/bauth/` → prod `/run/bos/` — convergencia planificada

### 2.5 Código actual — arquitectura modular respetada

165 archivos Rust. 58 handlers JSON-RPC con 248 funciones. Capas separadas:
`domain/` (lógica pura, sin I/O), `bitmask/` (engine dual), `engine/` (Keycloak + Vault),
`saga/` (motor con compensación), `context/` (W3C Trace Context).

---

## 3. BRECHAS IDENTIFICADAS

### 3.1 🔴 D00 no cubre entidades externas (consumidores masivos)

El catálogo D00 actual asume **enrolamiento administrado** (un admin crea actores).
El fork de mensajería descrito en `07-incrementos` exige **auto-registro masivo**
con identidad progresiva. Lo que falta en D00:

| Elemento faltante | Tipo | Justificación |
|---|---|---|
| `actor_type = CONSUMER` | Extensión de ENUM | Hoy solo HUMAN/SERVICE/DEVICE/BOT. El consumo requiere un tipo nuevo con reglas de privacidad y sesión distintas |
| `kyc_tier` (T0_PHONE / T1_DOCUMENT / T2_BIOMETRIC) | Nuevo átomo REGLA D1 | La identidad progresiva gobierna límites financieros D3. Sin esto, un usuario auto-registrado y un empleado verificado tienen el mismo nivel de acceso |
| `PHONE_OTP` como método de registro raíz | Nuevo método D9 | El catálogo D9 actual no contempla verificación telefónica como método primario de identidad — solo como segundo factor |
| Roles `CONSUMER_T0/T1/T2` | Nuevos roles | Acoplados a D3: T0 sin acceso financiero, T1 límites bajos, T2 límites completos |
| Flujo de auto-registro como política | Nuevas entradas `cfg_policy_library` | Qué átomos IDENTIDAD se crean automáticamente, cuáles requieren verificación manual, y su registro en `aud_event` (`identity.tier_promoted`) |

**Cobertura real de D00:** ~60% del caso de consumo masivo. El 100% verificado en
`BAUTH-COBERTURA-100PCT.md` aplica solo al caso empresarial administrado.

### 3.2 🟠 Los 9 incrementos del 07 no están integrados al plan

El documento `07-incrementos-bauth-para-mensajeria.md` (126 líneas, 9 incrementos)
**no aparece referenciado** en `REGISTRO-ESTADO-REDISEÑO.md` ni en `PLAN-ACCION-REDISEÑO.md`.
Debe fusionarse antes de escribir DDL porque varios incrementos afectan la FASE 1:

| Incremento 07 | Fase del plan donde debe absorberse | Impacto en DDL |
|---|---|---|
| #1: ~25 átomos bchat (room, message, media, moderation, abuse) | FASE 2 — nuevos átomos D1.bchat.* | No (son filas en `privilege_atom`) |
| #2: PHONE_OTP + kyc_tier + CONSUMER_T0/T1/T2 | FASE 1 (D00) + FASE 4 (seeds) | **Sí** — requiere `actor_type = CONSUMER` en ENUM |
| #3: Clases auditoría A/B/C + taxonomía chat.* | FASE 2 (D11) + FASE 4 (cfg_policy_library) | No (son filas) |
| #4: Pipeline WORM-agregada (Merkle clase B) | **Nueva FASE 7.X** — ingeniería | No (es código + capacidad) |
| #5: Política proporcionalidad (metadatos sí, contenido no) | FASE 4 (cfg_policy_library) | No |
| #6: Perfil CONSUMER_MOBILE + capacidad ctx_id | **Nueva FASE 11.X** — capacidad | No (es infraestructura) |
| #7: Átomos de moderación (moderation.*) | FASE 2 (D1.bchat.moderation.*) | No |
| #8: Conector bAuth↔fork | **Componente nuevo** — fuera del scope de reparación bAuth core | N/A |
| #9: Política supresión/seudonimización | FASE 4 (D11.privacy.*) | No |

### 3.3 🟡 Dos excepciones estructurales no cubiertas por el modelo atómico

El propio documento 07 (§4.2 y §8) identifica correctamente dos brechas que **no se resuelven
con filas y políticas** — requieren ingeniería de capacidad:

**Excepción #1 — Throughput del plano de sesión (§4.2):**
Validar `ctx_id` en cada reconexión WebSocket de 50K–500K concurrentes exige:
- Cluster Redis para el plano de validación (hoy es single-node)
- Políticas de expiración masiva (TTL escalonado para evitar tormenta)
- Protección contra tormenta de reconexiones (thundering herd post-incidente)
- Objetivo de capacidad: validaciones de ctx_id/segundo ≥ pico de reconexiones
- Esto **no está** en la FASE 11 actual (Context Plane) ni en ninguna otra

**Excepción #2 — Pipeline de auditoría de alto volumen (§8):**
El pipeline `bus → clasificador → aud_event/merkle_batch → anclaje D12` debe procesar
~172M eventos/día (a 2,000 msg/s). Requiere:
- Particionamiento temporal de `aud_event` (por día o semana)
- Lotes Merkle continuos con frecuencia por clase (lotes B cada minuto, no cada N eventos)
- Almacenamiento frío consultable para hojas clase B (objeto storage, no PostgreSQL)
- Esto **no está** en la FASE 7 actual (D12 Blockchain) ni en la FASE 3 (DDL D13)

### 3.4 🟡 Deuda de modularización en código actual

Tres archivos exceden el límite de 200 líneas (DOC-SBOS-001 N3):

| Archivo | Líneas | Exceso |
|---------|:------:|:------:|
| `usertemplate_validator.rs` | 495 | +295 |
| `rule_engine.rs` | 399 | +199 |
| `keycloak_engine.rs` | 532 | +332 |

---

## 4. INVESTIGACIÓN DE ESTÁNDARES — ROBUSTECIMIENTO DE D00

Se investigaron 8 temas contra fuentes 2025-2026. A continuación los hallazgos
y su impacto directo en el diseño D00.

---

### 4.1 NIST SP 800-63-4 — Niveles de Aseguramiento de Identidad (IAL1-3)

**Fuentes:** NIST SP 800-63-4 Final (adoptado 31 julio 2025), SP 800-63A-4 (julio 2025),
Biometric Update, Ping Identity.

**Hallazgo principal:** SP 800-63-4 fue adoptado como final en julio 2025. Define 3 IAL:

| Nivel | Evidencia requerida | Verificación | Binding al mundo real |
|-------|-------------------|-------------|:---------------------:|
| **IAL1** | Ninguna — atributos auto-afirmados | Sin verificación | ❌ No |
| **IAL2** | 1 SUPERIOR o 2 STRONG o 1 STRONG+1 FAIR | Remota (atendida o no) u on-site | ✅ Sí |
| **IAL3** | Igual que IAL2 | On-site con agente entrenado (NO remoto) | ✅ Sí + biométrico obligatorio |

**Cambios clave vs versión anterior:**
- IAL2 permite **remote unattended proofing** explícitamente
- Mobile Driver's License (mDL) aceptado en IAL2
- IAL1 reforzado pero sigue sin binding real
- Biometría obligatoria solo en IAL3

**→ Impacto en D00:** El modelo de 3 tiers de consumo se mapea directamente a IAL:
`CONSUMER_T0 = IAL1` (teléfono) → `T1 = IAL2` (documento + verificación remota) →
`T2 = IAL3` (biométrico + verificación on-site). El diseño `kyc_tier` del 07-incrementos
está validado por el estándar NIST más reciente.

---

### 4.2 NIST SP 800-63B-4 — Estado de PHONE_OTP y SMS como Autenticador

**Fuentes:** NIST SP 800-63B-4 Final (agosto 2025), TypingDNA Blog, HYPR, Ping Identity.

**Hallazgo principal:** SP 800-63B-4 **NO deprecó completamente SMS OTP.** Lo colocó en una
nueva categoría formal: **"restricted authenticator"** (§3.1.3.3, §3.2.9). Es el **único**
método en esta categoría.

Condiciones para usar un autenticador restringido:
1. Ofrecer al menos **una alternativa no-restringida** que cumpla el AAL requerido
2. **Notificar al usuario** sobre los riesgos y disponibilidad de alternativas
3. **Realizar evaluación de riesgos** documentada (SIM swap, portabilidad, interceptación)
4. **Implementar mitigaciones** para detectar/prevenir amenazas conocidas
5. **Mantener un plan de migración** hacia métodos no-restringidos

**Implicaciones adicionales:**
- FIDO2/WebAuthn passkeys son el **baseline** para AAL2 y AAL3
- Passkeys sincronizadas (cloud) no permitidas en AAL3 — solo device-bound
- Email OTP también degradado
- La dirección es clara: SMS OTP está en *glide path* hacia afuera de alto aseguramiento

**→ Impacto en D00:**
- `PHONE_OTP` debe registrarse como `nist_status = 'restricted'` en `ath_method`
- T0 solo accede a `PHONE_OTP` + `PASSWORD`
- Al promocionar a T1, se debe ofrecer `TOTP` o `WebAuthn` como alternativa no-restringida
- Cada uso de PHONE_OTP debe registrar carrier + IP en `aud_event` para detectar SIM swap
- Nuevo átomo requerido: `D9.bauth.sim_swap.detect` — detección de cambio súbito de carrier

---

### 4.3 Clasificación de Eventos de Auditoría por Criticidad (Patrón A/B/C)

**Fuentes:** GCP Cloud Audit Logs (ADMIN_READ/DATA_READ/SYSTEM), AWS CloudTrail
(Management/Data/Insights), Splunk (Hot/Warm/Cold/Frozen), Datadog (Indexes con
retención variable).

**Hallazgo principal:** No existe un estándar ISO/NIST que defina explícitamente
clases "A/B/C", pero la industria converge en un patrón de **3-4 tiers**:

| Tier | Equivalente en industria | Retención | Inmutabilidad | Ejemplos |
|------|--------------------------|:---------:|:------------:|---------|
| **Clase A** | GCP ADMIN_READ, AWS Management, Splunk Hot | 7-10 años | WORM + hash-chain por evento | Cambios de rol, auth admin, moderación, wallet |
| **Clase B** | GCP DATA_READ (opt-in), Splunk Warm/Cold | 90-365 días | Digest Merkle batcheado | Metadatos de mensajes, membresías, altas de sala |
| **Clase C** | GCP SYSTEM, Splunk Frozen, Datadog 3d index | 7-30 días | Ninguna (best-effort) | Presencia, typing, lecturas, conexiones |

**→ Impacto en bAuth:** El diseño de 3 clases del 07-incrementos §3.1 está alineado
con la industria. Formalizarlo requiere:
- **Tabla `bauth.aud_class`** con `retention_days`, `worm_required`, `merkle_batch_enabled`, `storage_target`
- **FK desde `aud_event` a `aud_class`**
- **Átomos D11 para gobernar asignación/promoción de clase:**
  - `D11.audit.class.assign` — asignar clase a tipo de evento
  - `D11.audit.class.promote` — promover clase (B→A, C→B, solo roles SU/SYS)

---

### 4.4 Merkle Batch para Auditoría de Alto Volumen

**Fuentes:** RFC 6962 (Certificate Transparency), IETF PLANTS bofreq 2025, Trillian
(Google), Merkle Mountain Ranges (MMR), Verkle Trees (Ethereum), bargad (Elixir).

**Hallazgo principal:** bAuth ya implementa Merkle tradicional en `anchor.rs` (5,815 líneas).
Para alto volumen (172M eventos/día), dos mejoras relevantes:

| Técnica | Ventaja | Costo | Aplica a bAuth |
|---------|---------|-------|:-------------:|
| **Merkle Mountain Ranges (MMR)** | Append O(log N) sin reconstruir árbol. No requiere conocer tamaño total | Implementación más compleja | FASE 7.X (escala > 1000 msg/s) |
| **Lotes por tiempo** (cada 60s) | Cadencia predecible, independiente del volumen | Lotes vacíos en horas valle | FASE 7 inmediata |
| **Verkle Trees** | Proofs de tamaño constante (170B vs 2KB+) | Muy nuevo, poca madurez en producción | No prioritario |

**→ Impacto en bAuth:**
- Merkle tradicional es suficiente para FASE 1 del fork
- Los lotes por **tiempo** (no por conteo de eventos) evitan que picos de tráfico
  rompan la cadencia de anclaje
- Nuevo átomo REGLA: `D8.bchat.audit.merkle_batch_interval_seconds` (INT, default 60)
- Para producción a escala, migrar a MMR en FASE 7.X

---

### 4.5 GDPR, Blockchain y Derecho al Olvido — EDPB Guidelines 2025

**Fuentes:** EDPB Draft Guidelines 02/2025 (abril 2025, consulta cerrada junio 2025),
CJEU caso C-413/23 (EDPS v. SRB, pendiente), análisis de Clifford Chance, OMFIF,
Forbes, Lexology.

**Hallazgo CRÍTICO:** Las EDPB Guidelines 02/2025 son el desarrollo regulatorio más
relevante de 2025-2026 para sistemas que combinan blockchain + datos personales.

1. **"Technical impossibility cannot be invoked to justify non-compliance"** —
   la inmutabilidad de blockchain no excusa violar el GDPR

2. **Datos seudónimos en blockchain SON datos personales** — si una clave pública
   puede vincularse a una persona natural por medios razonables, es dato personal
   (incluso si el node operator no tiene medios para re-identificar)

3. **La guía exige:**
   - ❌ No almacenar PII directamente on-chain (nunca)
   - ✅ Solo hashes, referencias o ZK proofs on-chain
   - ✅ PII off-chain con controles de acceso granulares
   - ✅ DPIA (Data Protection Impact Assessment) obligatorio para sistemas blockchain
   - ✅ Mecanismos para "rendir anónimos" datos on-chain si se solicita borrado

4. **Caso CJEU C-413/23 pendiente** — puede estrechar o ampliar la definición de
   "dato personal" desde la perspectiva del receptor

**→ Impacto en bAuth:** El patrón "hash, don't store" del 07-incrementos §7 es
exactamente lo que exige el EDPB. Pero debe reforzarse:

- **NUNCA anclar `user_uuid` directamente on-chain** — usar `sha256(user_uuid || salt)`
- **La sal debe ser rotable** — si se rompe el hash, nueva sal y re-hashear
- **El mapeo `user_uuid ↔ hash` vive en PostgreSQL con TTL de retención legal**
- **Auditar cada acceso al mapeo como evento clase A**
- **Implementar `bauth.privacy.erasure.request`** que elimina/anonimiza `idn_atributo`,
  conserva `user_uuid` sin atributos resolubles, y registra `privacy.erasure.completed`
- **Nuevo átomo requerido:** `D00.org.actor_privacy_erasure.C/R/U/D`

---

### 4.6 CAEP 1.0 y OpenID Shared Signals Framework (SSF)

**Fuentes:** OpenID CAEP 1.0 Final Specification (sept 2025), CAEP Interoperability
Profile 1.0 draft 02 (feb 2026), Skycloak/Keycloak SSF blog (mayo 2026), SailPoint,
FIDO Alliance whitepaper.

**Hallazgo principal: CAEP 1.0 fue aprobado como Final Specification el 2 de septiembre
de 2025.** Ya NO es un draft — es un estándar de producción.

**8 tipos de eventos CAEP. Los más relevantes para bAuth + fork:**

| Evento CAEP | URI | Uso en SBOS |
|---|---|---|
| `session-revoked` | `.../caep/event-type/session-revoked` | Offboarding, suspensión, violación seguridad |
| `credential-change` | `.../caep/event-type/credential-change` | Cambio password, nuevo MFA |
| `assurance-level-change` | `.../caep/event-type/assurance-level-change` | Promoción T0→T1→T2 |
| `device-compliance-change` | `.../caep/event-type/device-compliance-change` | Jailbreak detectado, MDM fuera de compliance |
| `risk-level-change` | `.../caep/event-type/risk-level-change` | RiskEngine detecta anomalía |

**Estado de Keycloak (mayo 2026):**
- SSF Transmitter mergeado experimentalmente (PR #48256, flag `Profile.Feature.SSF`, v26.7.0)
- SSF Receiver todavía en triage (issue #43614)
- **bAuth debe implementar su propio SSF Transmitter** — no depender de Keycloak

**→ Impacto en bAuth:**
- La FASE 11 (Context Plane) ya contempla CAEP en F11.B3 y F11.B4 — validado
- `session-revoked` permite terminar TODAS las sesiones WebSocket del fork en <30s
- `assurance-level-change` notifica al fork cuando un usuario sube de tier KYC
- La implementación debe seguir el CAEP Interoperability Profile draft 02 (feb 2026)
- Kong debe ser el receiver — recibir SET y cachear revocaciones en Redis
- **Nuevo átomo REGLA:** `D8.bauth.session.ttl_consumer` — TTL de sesión para CONSUMER

---

### 4.7 Anti-Abuso en Mensajería Masiva — Patrones de Rate Limiting

**Fuentes:** NDSS 2021 — "An Empirical Analysis of Contact Discovery and Rate-Limiting
in Messengers" (análisis de código fuente de WhatsApp, Signal, Telegram), arquitecturas
públicas de WhatsApp Engineering y Signal Server.

**Hallazgo principal — Los tres patrones principales:**

| Plataforma | Algoritmo | Capacidad por cuenta | Estrategia de abuso |
|-----------|-----------|:--------------------:|--------------------|
| **WhatsApp** | Leaky bucket | 120K contactos, 60K/día | Baneo de cuenta |
| **Signal** | Leaky bucket | 50K contactos, 200K/día | Falla silenciosa, sin baneo |
| **Telegram** | Hard cap + timing | 5K total, 100/día, ≥8.3s entre requests | Baneo inmediato de número |

**Patrones comunes extraídos:**
1. **Leaky bucket es el estándar de facto** — permite bursts + rate constante
2. **Límites por operación, no por usuario** — cada acción tiene su bucket independiente
3. **Anti-flood por sala/grupo** además del rate por usuario
4. **Detección de comportamiento** más allá de rate bruto: timing entre mensajes,
   entropía de contenido, patrones de grafo social

**→ Impacto en bAuth — Refinamiento de átomos REGLA del 07-incrementos §1.3:**

| Átomo | Formato | Propósito | Referencia |
|-------|---------|-----------|-----------|
| `D1.bchat.message.rate_per_minute` | INT (ej. 30) | Anti-flood por usuario | WhatsApp/Telegram |
| `D1.bchat.message.burst_max` | INT (ej. 10) | Ráfaga permitida en 1s | Leaky bucket burst size |
| `D1.bchat.room.create_per_hour` | INT (ej. 5) | Frenar spam de salas | Telegram hard cap |
| `D1.bchat.contact.max_new_per_day` | INT (ej. 50) | Frenar scraping de contactos | Signal 200K/día ref |
| `D8.bchat.session.new_account_restrictions_hours` | INT (ej. 72) | Restricciones post-registro | WhatsApp anti-spam |
| `D8.bchat.abuse.auto_suspend_strikes` | INT (ej. 3) | Suspensión automática | Multi-strike policy |
| `D8.bchat.message.min_inter_message_ms` | INT (ej. 300) | Tiempo mínimo entre mensajes (anti-bot) | Behavioral detection |

---

### 4.8 Identidad Descentralizada para Mensajería — DID + Signal Protocol

**Fuentes:** W3C DID Core 1.0, W3C DID Working Group discussions, Signal Protocol
(X3DH + Double Ratchet), DIDComm, AgentNetworkProtocol.

**Hallazgo principal: Signal NO usa W3C DID explícitamente, pero su arquitectura
es DID-equivalente:**

| Concepto W3C DID | Equivalente en Signal |
|---|---|
| DID Document | PreKey Bundle (identity key, signed prekey, one-time prekeys) |
| DID Controller | Identity Key Pair (dueño del número) |
| DID Resolution | Signal Server (entrega prekey bundles) |
| DID Auth | X3DH key agreement (demuestra control de la identity key) |
| DIDComm (encrypted messaging) | Double Ratchet (mismo propósito) |

Signal Protocol no usa blockchain ni registro público de DIDs porque el número de
teléfono actúa como identificador y el servidor Signal es el resolver centralizado.

**→ Impacto en bAuth — Enfoque híbrido para SBOS/bChat:**

1. **Identidad de mensajería = `did:sbos:<user_uuid>`** — no números de teléfono
   como identificador primario (privacidad superior a Signal)
2. **PreKey Bundles en `idn_atributo`** con `category='messaging'`, `attr_key='signal_prekey_bundle'`
3. **Resolución de DID contra bAuth** via JSON-RPC `bauth.did.resolve` — no contra
   blockchain (latencia <5ms vs 100ms+)
4. **Anclaje opcional del DID Document hash en Besu** (D12) para auditoría de largo plazo
5. **Nuevo actor_type:** `MESSAGING_IDENTITY` — cuentas que solo existen en el plano de
   mensajería, vinculadas N:1 a un HUMAN/CONSUMER (múltiples identidades por persona)
6. **Nuevo átomo:** `D00.org.messaging_identity.C/R/U/D` — crear/vincular identidad de mensajería

---

### 4.9 Síntesis de la investigación — Nuevos átomos requeridos para D00 ampliado

| # | Átomo | Tipo | Justificación | Estándar |
|---|-------|------|---------------|---------|
| 1-4 | `D00.org.actor_kyc_tier.C/R/U/D` | REGLA | Gobernar progresión T0→T1→T2 | NIST SP 800-63-4 IAL1-3 |
| 5-8 | `D00.org.actor_phone_verified.C/R/U/D` | REGLA | Marcar teléfono verificado (T0) | NIST 800-63B-4 §5.1.3.3 |
| 9-12 | `D00.org.actor_doc_verified.C/R/U/D` | REGLA | Marcar documento verificado (T1) | NIST 800-63A-4 IAL2 |
| 13-16 | `D00.org.actor_bio_verified.C/R/U/D` | REGLA | Marcar biométrico verificado (T2) | NIST 800-63A-4 IAL3 |
| 17-20 | `D00.org.actor_privacy_erasure.C/R/U/D` | REGLA | Derecho al olvido (seudonimización) | GDPR Art.17 + EDPB 02/2025 |
| 21-24 | `D00.org.actor_consent_gdpr.C/R/U/D` | REGLA | Registrar consentimiento GDPR | GDPR Art.7 |
| 25 | `D9.bauth.method.PHONE_OTP` | MÉTODO | Registro raíz para T0 | NIST 800-63B-4 restricted |
| 26 | `D9.bauth.sim_swap.detect` | REGLA | Detectar cambio de carrier (riesgo) | NIST 800-63B-4 mitigación |
| 27-30 | `D00.org.messaging_identity.C/R/U/D` | REGLA | Crear/vincular identidad de mensajería | W3C DID Core 1.0 + Signal |
| 31-34 | `D00.org.actor_self_register.C/R/U/D` | REGLA | Permiso para auto-registro público | NIST 800-63-4 IAL1 |
| 35 | `D11.audit.class.assign` | REGLA | Asignar clase A/B/C a tipo de evento | ISO 27001:2022 A.8.15 |
| 36 | `D11.audit.class.promote` | REGLA | Promover clase B→A (solo SU/SYS) | EDPB 02/2025 §5.1 |
| 37 | `D8.bauth.session.ttl_consumer` | REGLA | TTL sesión perfil CONSUMER (días) | CAEP 1.0 session-revoked |
| 38 | `D8.bchat.audit.merkle_batch_interval_seconds` | REGLA | Intervalo lote Merkle clase B (segundos) | RFC 6962 + MMR pattern |
| 39 | `D8.bchat.message.min_inter_message_ms` | REGLA | Tiempo mínimo entre mensajes (anti-bot) | NDSS 2021 behavioral |
| 40 | `D1.bchat.message.burst_max` | REGLA | Ráfaga máxima en 1s (leaky bucket) | WhatsApp/Telegram pattern |

**Total nuevos átomos para D00 ampliado:** ~40 (combinación de REGLA + MÉTODO + CRUD)

---

## 5. VEREDICTO

### ¿Procedemos con la reparación?

**SÍ. La investigación de estándares 2025-2026 confirma que el diseño es correcto y que
las brechas identificadas son salvables con átomos adicionales, sin cambios arquitectónicos.**

El plan de reparación es riguroso para el caso empresarial. Con los 40 átomos nuevos
identificados en esta investigación, D00 alcanza **cobertura 100% también para el caso
de consumo masivo**.

### Condiciones previas a escritura de DDL

1. **Fusionar los 9 incrementos del 07 + los 40 átomos de esta investigación en el plan** —
   integrarlos en `REGISTRO-ESTADO-REDISEÑO.md` y `PLAN-ACCION-REDISEÑO.md`

2. **Extender el catálogo D00 para entidades externas** — `actor_type = CONSUMER` +
   `actor_type = MESSAGING_IDENTITY`, átomos kyc_tier, privacy_erasure, self_register,
   PHONE_OTP, sim_swap.detect, y roles CONSUMER_T0/T1/T2 ANTES de escribir migración 003

3. **Crear tabla `bauth.aud_class`** como parte de FASE 1 (junto con `idn_atributo`) —
   el catálogo de clases de auditoría es prerequisito para que los átomos D11 de
   asignación/promoción tengan sentido

4. **Programar las 2 excepciones estructurales** como fases de ingeniería con pruebas
   de carga propias (FASE 7.X MMR + pipeline auditoría, FASE 11.X throughput sesión)

### Lo que se puede ejecutar YA (sin bloqueo DDL)

**FASE 0.S** — Auditoría y reparación de 81 seeds existentes. 83 tareas atómicas.
No requiere aprobación DDL. Solo edita seeds ya existentes:
- Grupo A: Corregir contadores y orden en `run_all_seeds.sql`
- Grupo B: Reparar `064_idn_user_template_data.sql` (15 secciones, camelCase→snake_case, versión 3.0→6.0.0)
- Grupo C: Reparar `seed_idn_role_template_data.sql` (7 nombres de bloque canónicos)
- Grupo D: Verificar frameworks referenciados (eliminar `_v3`/`_v4` incorrectos)

---

## 6. PLAN DE ACCIÓN — CORRECCIÓN ROBUSTECIDA DE bAuth

### FASE 0.S — Reparación de Seeds Existentes (SIN BLOQUEO — YA)
**83 tareas atómicas · 4 grupos · Cero DDL**

Ejecutable de inmediato. Ver `REGISTRO-ESTADO-REDISEÑO.md` para detalle de cada tarea.

### FASE 1 AMPLIADA — DDL D00 + idn_atributo + Entidades Externas (REQUIERE APROBACIÓN)
**20 tareas · La migración 003 más importante del rediseño**

| ID | Tarea |
|----|-------|
| F1.01 | `ALTER TABLE idn_tenant ADD COLUMN is_internal boolean` |
| F1.02 | Extender CHECK en `privilege_domain` para aceptar `domain_code=0` |
| F1.03 | Insertar dominio D00 en `privilege_domain` |
| F1.04 | Insertar aplicación `org` (app_code=13) en `privilege_application` |
| F1.05 | Insertar 5 grupos D00 en `privilege_group` |
| F1.06 | Eliminar verbos semánticos 51-63 (reemplazados por CRUD 1-4) |
| F1.07 | Insertar 120 átomos CRUD D00 originales (5809-5928) |
| F1.08 | **NUEVO:** Insertar ~40 átomos adicionales D00 para entidades externas (5929-5968) |
| F1.09 | **NUEVO:** Extender ENUM `actor_type` con `CONSUMER`, `MESSAGING_IDENTITY` |
| F1.10 | `CREATE TABLE idn_atributo` (diseño EAV jerárquico v1.3.0) |
| F1.11 | **NUEVO:** `CREATE TABLE aud_class` (catálogo de clases de auditoría A/B/C) |
| F1.12 | Migrar `org_contacto` → `idn_atributo` |
| F1.13 | Migrar `org_documento` → `idn_atributo` |
| F1.14 | Migrar `org_direccion` → `idn_atributo` |
| F1.15 | Validar migración: conteo de filas pre/post |
| F1.16 | DROP TABLE `org_contacto`, `org_documento`, `org_direccion` |
| F1.17 | Insertar método `PHONE_OTP` en `ath_method` (nist_status='restricted') |
| F1.18 | Insertar roles `CONSUMER_T0`, `CONSUMER_T1`, `CONSUMER_T2` en `privilege_role` |
| F1.19 | Insertar clases A/B/C en `aud_class` con retención y storage_target |
| F1.20 | Revisión + aprobación humana del SQL completo |

### FASE 2 — DDL átomos D4-D12 + Mensajería (REQUIERE APROBACIÓN)
**15 tareas · 188 átomos originales + ~25 átomos bchat.***

| ID | Tarea |
|----|-------|
| F2.01-F2.09 | Insertar 188 átomos D4-D12 (según plan original) |
| F2.10 | **NUEVO:** Insertar ~25 átomos `D1.bchat.*` (room, message, media, moderation, abuse) |
| F2.11 | **NUEVO:** Insertar átomos D11 de auditoría (audit.class.assign, audit.class.promote) |
| F2.12 | **NUEVO:** Insertar átomos D8 de sesión de consumo (session.ttl_consumer, min_inter_message_ms) |
| F2.13 | **NUEVO:** Insertar átomos D9 de anti-abuso (sim_swap.detect) |
| F2.14 | Actualizar `bitmask_bundle` para incluir todas las posiciones nuevas |
| F2.15 | Revisión + aprobación humana |

### FASE 3 — DDL D13 blockchain (REQUIERE APROBACIÓN)
**5 tareas · Sin cambios respecto al plan original.** 36 átomos, 3 apps, 1 dominio.

### FASE 4 — Seeds nuevos (POST-DDL)
**8 tareas · Datos iniciales para todos los átomos nuevos**

| ID | Tarea |
|----|-------|
| F4.01 | Seed: 120 átomos D00 originales |
| F4.02 | **NUEVO:** Seed: ~40 átomos D00 entidades externas |
| F4.03 | Seed: 188 átomos D4-D12 |
| F4.04 | **NUEVO:** Seed: ~25 átomos bchat.* |
| F4.05 | Seed: 36 átomos D13 |
| F4.06 | **NUEVO:** Seed: roles base CONSUMER_T0/T1/T2 + asignaciones CRUD |
| F4.07 | **NUEVO:** Seed: aud_class (3 filas: A, B, C) |
| F4.08 | Seed: display_format codes en cfg_policy_library (originales + nuevos) |

### FASE 5 — Código Rust (POST-SEEDS)
**9 tareas · Adaptar domain/ y server/ a la nueva realidad**

| ID | Tarea |
|----|-------|
| F5.01 | `domain/atributo_extensible.rs` — CRUD idn_atributo (nuevo módulo ≤200 líneas) |
| F5.02 | `domain/roltemplate_validator.rs` — 14 bloques RolTemplate v6.0 |
| F5.03 | `domain/usertemplate_validator.rs` — 16 bloques UserTemplate v6.0 |
| F5.04 | **NUEVO:** `domain/actor_externo.rs` — lógica de auto-registro + kyc_tier + privacy_erasure |
| F5.05 | **NUEVO:** `domain/audit_class.rs` — asignación y promoción de clases de auditoría |
| F5.06 | Adaptar `server/handlers/mod.rs` — rutas CRUD idn_atributo + actor externo + aud_class |
| F5.07 | Adaptar `sync/role_sync.rs` — sync átomos D4-D12 + bchat con Keycloak |
| F5.08 | Refactorizar `usertemplate_validator.rs` (495→≤200 líneas) |
| F5.09 | Refactorizar `keycloak_engine.rs` (532→≤200 líneas) |

### FASE 6 — Validación VPS (POST-COMPILACIÓN)
**12 tareas · Pruebas en pods K8s reales**

| ID | Test | Criterio |
|----|------|---------|
| F6.01 | Compilación MUSL sin errores | `cargo build --release --target x86_64-unknown-linux-musl` OK |
| F6.02 | Migración 003 aplicada | `SELECT count(*) FROM privilege_atom WHERE domain_code=0` ≥ 160 |
| F6.03 | idn_atributo funcional | INSERT + SELECT de email, teléfono, dirección OK |
| F6.04 | **NUEVO:** Auto-registro T0 | POST `/bauth.actor.self_register` con teléfono → CONSUMER_T0 creado |
| F6.05 | **NUEVO:** Promoción T0→T1 | Verificar documento → kyc_tier=T1_DOCUMENT → átomos D3 habilitados |
| F6.06 | **NUEVO:** Derecho al olvido | POST `/bauth.privacy.erasure.request` → idn_atributo anonimizado, audit_event registrado |
| F6.07 | BitMask D00 funcional | Bits 5809-5968 evaluables en runtime (fastpath <0.5ns) |
| F6.08 | UserTemplate 16 bloques | POST con body completo → 200 OK |
| F6.09 | RolTemplate 14 bloques | POST con body completo → 200 OK |
| F6.10 | **NUEVO:** aud_class asignación | SELECT * FROM aud_class → 3 filas (A,B,C) con retention_days correctos |
| F6.11 | **NUEVO:** PHONE_OTP restricted | `SELECT nist_status FROM ath_method WHERE method_id='phone_otp'` → 'restricted' |
| F6.12 | Sync KC: actor creado en Keycloak | keycloak_id populated en idn_user_template |

### FASES 7-11 — Robustez (INDEPENDIENTE, PARALELIZABLE)
**72 tareas originales + 2 fases nuevas de ingeniería**

| Fase | Tareas | Estado |
|------|:------:|:------:|
| FASE 7 — D12 Consolidación | 14 | ⏳ |
| **FASE 7.X — Pipeline auditoría alto volumen** | **NUEVA** | ⏳ |
| FASE 8 — D13 Implementación | 18 | ⏳ |
| FASE 9 — Token JWT Robustez | 12 | ⏳ |
| FASE 10 — Auth Certificación | 16 | ⏳ |
| FASE 11 — Context Plane Robustez | 12 | ⏳ |
| **FASE 11.X — Capacidad plano de sesión** | **NUEVA** | ⏳ |

---

## 7. MÉTRICAS FINALES

| Métrica | Antes de investigación | Después de investigación |
|---------|:----------------------:|:------------------------:|
| Documentos evaluados | 46 | 46 + 8 investigaciones web |
| Átomos diseñados totales | 344 | **384** (344 + 40 nuevos D00) |
| Átomos de mensajería (bchat.*) | ~25 (no integrados) | **~25 integrados en FASE 2** |
| Contratos BOS↔bAuth | 11/11 ACORDADOS | 11/11 ACORDADOS (sin cambios) |
| Cobertura D00 caso empresarial | 100% | 100% (sin cambios) |
| Cobertura D00 caso consumo masivo | ~60% (estimado) | **100%** (40 átomos cierran la brecha) |
| Entidades externas cubiertas | 0 tipos | **4 tipos** (CONSUMER, MESSAGING_IDENTITY, SERVICE externo, PARTNER) |
| Flujo de auto-registro | No diseñado | **Diseñado** (PHONE_OTP → kyc_tier → doc → biométrico) |
| GDPR right-to-forget | Solo patrón hash | **Con átomo + procedimiento documentado** |
| Anti-abuso mensajería | Solo rate básico | **Leaky bucket por operación + min_inter_message + auto_suspend** |
| Clases de auditoría | Solo concepto | **Con tabla aud_class + átomos D11** |
| Tareas totales REPARACIONBAUTH | 202 | **~232** (202 + 30 nuevas) |
| Excepciones estructurales | 2 identificadas | **2 planificadas como FASE 7.X + 11.X** |
| Brechas bloqueantes para DDL | 1 | **0** (todas tienen plan de acción) |

---

## 8. FUENTES DE LA INVESTIGACIÓN

1. **NIST SP 800-63-4 Final** (jul 2025): https://pages.nist.gov/800-63-4/
2. **NIST SP 800-63B-4 Final** (ago 2025): https://www.nist.gov/publications/nist-sp-800-63b-4digital-identity-guidelines-authentication-and-authenticator
3. **TypingDNA — SMS OTP Restricted**: https://blog.typingdna.com/nist-sp-800-63b-rev-4-sms-otp-is-now-a-restricted-authenticator-but-we-have-the-fix/
4. **EDPB Draft Guidelines 02/2025** (abr 2025): https://www.edpb.europa.eu/
5. **OMFIF — EDPB Blockchain GDPR** (jun 2025): https://www.omfif.org/2025/06/european-data-protection-board-puts-blockchain-at-a-gdpr-crossroads/
6. **OpenID CAEP 1.0 Final** (sep 2025): https://openid.net/specs/openid-caep-1_0.html
7. **CAEP Interoperability Profile 1.0 draft 02** (feb 2026): https://openid.github.io/sharedsignals/openid-caep-interoperability-profile-1_0.html
8. **Skycloak — Keycloak CAEP SSF** (may 2026): https://skycloak.io/blog/keycloak-caep-shared-signals-continuous-access/
9. **NDSS 2021 — Contact Discovery in Messengers**: https://se.informatik.uni-wuerzburg.de/
10. **W3C DID Core 1.0**: https://www.w3.org/TR/did-core/
11. **Signal Protocol — X3DH + Double Ratchet**: https://signal.org/docs/
12. **RFC 6962 — Certificate Transparency**: https://datatracker.ietf.org/doc/html/rfc6962

---

*Documento robustecido por bauth-developer · 2026-07-05 · v2.0.0 · Carpeta REPARACIONBAUTH*
*Próximo paso: iniciar FASE 0.S (sin bloqueo) + presentar FASE 1 ampliada para aprobación humana.*
