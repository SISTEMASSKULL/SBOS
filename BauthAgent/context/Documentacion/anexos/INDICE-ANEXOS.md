# Anexos del corpus bAuth — Índice y patrón
## La capa de respaldo documental: los manuales afirman, los anexos respaldan

**Versión:** 1.4.0 · **Fecha:** 2026-07-11 · **Estado: COBERTURA TOTAL** — los 36 manuales con anexo(s); 40 anexos publicados (14 de traslado A.01–A.14 + 26 de sustentación A.15–A.40)
**Regla de origen (decisión del humano, 2026-07-11):** los anexos NO son copias de documentos
de trabajo — son **documentos de respaldo nuevos, organizados y estructurados**, que toman el
conocimiento disperso (SSOT de diseño, análisis de reparación, investigación en internet
basada en normas y estándares internacionales) y lo reorganizan para **referencia con detalle
y consulta sin fricción** desde los manuales.

**Regla de autosuficiencia (decisión del humano, 2026-07-11):** los anexos son **LA NUEVA
DOCUMENTACIÓN** — la documentación de origen (legacy) **ya no será consultada** una vez
construido el anexo. Por eso cada anexo TRASLADA todo lo relevante de sus fuentes (estructuras
completas incluidas, por extracción fiel — jamás transcripción), verifica la completitud
contra el corpus, y cita el origen solo como referencia histórica. Excepción: los documentos
de TRACKING activo (p. ej. el mapa de gaps G-B*) siguen vivos como registro — el anexo refleja
su estado, no los sustituye como registro.

---

## 1. Qué es un anexo (el patrón canónico)

Todo anexo cumple esta estructura:

| Elemento | Regla |
|---|---|
| **Nombre** | `A.NN_ANEXO-<TEMA>-vX.Y.md` — numeración secuencial de la serie |
| **Cabecera** | Tipo · versión del anexo · **a qué manual(es) y secciones respalda** · fuentes de origen · normas base |
| **§1 Propósito y cómo citarlo** | La convención de cita fina (`A.NN §X`) |
| **Cuerpo** | Secciones numeradas y referenciables: el conocimiento curado en tablas (parte · qué define · norma), no prosa suelta ni JSON crudo |
| **Estado de materialización** | Qué está en la BD/código real vs qué es diseño — honestidad de madurez (carta rectora directriz 4) |
| **Marcas de época** | El contenido histórico se conserva marcado (`[pre-ADR-010]`), jamás se destruye |
| **Mapa anexo → manuales** | Tabla final: qué sección respalda a qué manual |
| **Referencias + historial** | Fuentes del proyecto + fuentes primarias de internet (normas), con fecha de verificación |

| **Traslado fiel (autosuficiencia)** | La estructura completa de la fuente viaja AL anexo (sección «Traslado fiel», extracción literal) — el lector jamás necesita abrir la legacy |
| **Frontera con los manuales** | **El anexo NO repite al manual** (decisión del humano, 2026-07-11): el manual lleva la doctrina, los conceptos y el estado del arte; el anexo lleva el CONOCIMIENTO RESPALDATORIO — estructuras completas, contratos, catálogos, verificación normativa a nivel de campo, evidencia. Donde el anexo necesite un concepto del manual, lo REFERENCIA (`manual §X`), jamás lo re-explica |

**Relación con los SSOT de origen:** el anexo LOS REEMPLAZA como fuente de lectura (regla de
autosuficiencia). El original queda en su ubicación como pieza histórica citada. Si el diseño
evoluciona, **se actualiza el anexo** (bump de versión e historial) — no el documento legacy.

---

## 2. Anexos publicados

| Anexo | Contenido | Respalda a | Estado |
|---|---|---|:---:|
| [A.01 — El Contrato RolTemplate v6.0](A.01_ANEXO-ROLTEMPLATE-v1.0.md) | **FUENTE AUTOSUFICIENTE**: los 14 bloques con lectura normativa (§B1–§B14, códigos G-B*, verificación contra fuentes primarias) · §17 la estructura COMPLETA por dominios D00–D13 (matriz + pipeline 1.01, bloques nuevos B15–B19, 3 enriquecimientos, 3 defases HITL) · **§19 el traslado fiel de la estructura JSONB íntegra** (+mappings `[pre-ADR-010]` +JSON de los bloques propuestos) · validaciones | 1.09 · 1.13 · 1.04 · 2.05 · 1.01 | ✅ 2.1.0 |
| [A.02 — El Contrato UserTemplate v6.0](A.02_ANEXO-USERTEMPLATE-v1.0.md) | **FUENTE AUTOSUFICIENTE**: los 16 bloques de la identidad en lectura normativa a nivel de campo con la **materialización NATIVA vigente** (framework declarativo `ath_*`/`auth_method`, OIDC Provider nativo, biedata, JML soberano 1.08 §7) · **§19 verificación de completitud RESUELTA** (normas+estándares+industria): matriz D00–D13 del SUJETO **14/14** + resoluciones U1–U7 (U1 `identity_proofing` IAL 800-63A verificado vs industria · U2 ML-DSA FIPS 204 · U3 Argon2id · U4 uuidv7 · U5 sms_otp retirado · U6 `legal_signature_identity` wallet/ADSIB · U7 nativo por manuales) · validaciones+PII+invariantes · JML soberano · **§22 traslado fiel** (JSONB íntegro + reglas) | 1.08 · 1.13-F5 · 2.01 · 2.10 · 1.01 | ✅ 1.1.0 |
| [A.03 — Catálogo de Roles Empresariales v2.1](A.03_ANEXO-CATALOGO-ROLES-v1.0.md) | Todos los actores (sistémicos SU/N1–N4 con PAM · 174 internos · externos CAEB 21 sectores) + **el motor BitMask Dual v2.1 íntegro** (la corrección label/one-hot) · cifra vigente 548 en BD · traslado fiel completo | 1.09 · 1.04 · 2.06 · 1.01 | ✅ 1.0.0 |
| [A.04 — Cadenas de Jerarquía v1.2](A.04_ANEXO-CADENAS-JERARQUIA-v1.0.md) | El DAG completo por sector (`Padre ← Hijo`), reglas (aciclicidad, remoción, SoD, closure), verificación vs BD (547/1126/1673, prof. 7) · traslado fiel | 1.09 §9 · 1.04 · A.03 | ✅ 1.0.0 |
| [A.05 — Catálogo de Átomos de Dominio v2.0](A.05_ANEXO-CATALOGO-ATOMOS-DOMINIOS-v1.0.md) | El modelo de átomo de elemento (fin del CRUD-por-campo: ~128 átomos semánticos D00–D13), mapa de posiciones, plan HITL · traslado fiel | 1.03 · 1.01 · 1.02 · 1.06 | ✅ 1.0.0 |
| [A.06 — Authentication Framework](A.06_ANEXO-AUTHENTICATION-FRAMEWORK-v1.0.md) | Mapa de los 36+1 grupos con acceso por línea · divergencia de versión resuelta (rige fw_01) · **recurso fiel adjunto** (.json5, 12.945 líneas) | 2.01 · 2.02 · 7.03 | ✅ 1.0.0 |
| [A.07 — Policies Framework](A.07_ANEXO-POLICIES-FRAMEWORK-v1.0.md) | Mapa de los 14 grupos de políticas · rige fw_02 · **recurso fiel adjunto** (.json5) | 2.05 · 2.01 §8 · 3.01 | ✅ 1.0.0 |
| [A.08 — Motores de Firma Digital v1.0](A.08_ANEXO-MOTORES-FIRMA-v1.0.md) | El doble motor (interno Ed25519 · externo ADSIB RSA — Ley 164) con la relación D12↔D13 resuelta · traslado fiel (arquitectura, perfiles, API) | 2.04 · A.01 §B20 · A.02 U6 | ✅ 1.0.0 |
| [A.09 — Registro y Ciclo de Credenciales v1.0](A.09_ANEXO-REGISTRO-CREDENCIALES-v1.0.md) | Proofing IAL 1–3 (fuente de A.02 U1), diceware, self-service, recuperación, notificaciones ASVS · traslado fiel | 2.01 · 1.08 §7 · 7.02 | ✅ 1.0.0 |
| [A.10 — Revocación y Eliminación de Accesos v1.0](A.10_ANEXO-REVOCACION-ACCESOS-v1.0.md) | Revocación <30 s, suspensión, offboarding (retención Ley 843), access review, privilege creep, emergencia, ghost accounts · traslado fiel | 7.01 · 1.08 §7 · 5.01 | ✅ 1.0.0 |
| [A.11 — Seguridad de Red (SBOS-054) v1.3.0](A.11_ANEXO-SEGURIDAD-RED-v1.0.md) | Superficie mínima, STRIDE, ZT interno, reglas NRS, ctx_id-token, wss, DoS, sanitización · traslado fiel | 2.09 · 1.11 · 2.03 | ✅ 1.0.0 |
| [A.12 — Blockchain D12 v2.1](A.12_ANEXO-BLOCKCHAIN-D12-v1.0.md) | Suficiencia (D3+D11), las 3 variantes D12 (anclaje/liquidación/producto), materialización (blk_*, merkle.rs) L2 honesto · traslado fiel | 5.02 · 1.01 · A.01 §B19 | ✅ 1.0.0 |
| [A.13 — Las Decisiones Arquitectónicas (ADRs)](A.13_ANEXO-ADRS-v1.0.md) | **Tabla de vigencia REAL de los 11 ADRs** (ADR-007 obsoleto — KC eliminado; ADR-008→010; ADR-003→009) · los 11 íntegros | 0.00 · todos | ✅ 1.0.0 |
| [A.14 — Context Plane B16](A.14_ANEXO-CONTEXT-PLANE-B16-v1.0.md) | La investigación (W3C Trace Context, Baggage, 800-207 ZTA), arquitectura de responsabilidades, implementación, API · traslado fiel | 1.11 · 5.01 §6 | ✅ 1.1.0 |
| ⭐ [A.41 — EVALUACIÓN CRUDA del código](A.41_ANEXO-EVALUACION-CRUDA-CODIGO-v1.0.md) | **Auditoría de veracidad:** qué funciona vs fachada/estafa. **WebAuthn bypass ✅ CORREGIDO** (verify_assertion real W3C §7.2, 372 tests) · 🟢 robusto (login Argon2, token_validate, JWT Ed25519, BitMask, Context Plane) · 🟡 a medio · ⚫ muerto (risk/audit) · viola reglas propias (175 unwrap) · **§11 base arquitectónica (20 contratos BA)** | TODO el corpus | ✅ 1.0.0 |
| ⭐ [A.42 — ESPECIFICACIÓN DE IMPLEMENTACIÓN](A.42_ANEXO-ESPECIFICACION-IMPLEMENTACION-v1.0.md) | **Las funciones a desarrollar con FIRMA (parámetros) + CUERPO paso a paso de la norma** — para desarrollar sin inventar. Fichas: BA2 DPoP (12 pasos RFC 9449), BA3 pipeline fail-closed, BA4 rate-limit, BA6 IAL, BA7 idn_atributo DDL, BA8 ADSIB, BA11 emisor auditoría (AU-3), BA13 IGA, BA17 RLS. Complementa el código `src/domain/andamiaje.rs` (las firmas) | A.41 §11 · todo el corpus | ✅ 1.0.0 |
| ⭐ [A.43 — MAPA COMPLETO IAM ENTERPRISE](A.43_ANEXO-MAPA-IAM-ENTERPRISE-v1.0.md) | **Los 108 contratos de la categoría** (derivación sistemática de los 7 pilares 0.00 §4/§8/§10), cada uno con estado ✅ desarrollado / 🔄 en proceso / ⬜ por desarrollar. **Scorecard de completitud: ~42% (32 ✅ / 27 🔄 / 49 ⬜).** Pilares menos maduros: PAM ~25%, ITDR ~23%. Incluye lo que A.41 §11 omitía: PAM completo, federación entrante, ITDR continuo, NHI, SCIM bidir, SPIFFE, HA. **+CORE-11 Módulo Criptográfico (FIPS 140-3, ADR-012)** | CARTA RECTORA 0.00 · todo el corpus | ✅ 1.1.0 |
| ⭐ [A.44 — ARQUITECTURA Y COMPLETITUD DE MÉTODOS](A.44_ANEXO-ARQUITECTURA-METODOS-v1.0.md) | **Los 47 métodos de 2.02 explicados como operación:** petición → verificar/producir → devuelve, con las 3 capas (motor / Módulo Criptográfico / bóveda), **los campos exactos que consume del `UserTemplate §5` (autenticador enrolado) y del `RolTemplate B4` (`requiredMethods[]{method,order,loa}`, step-up)**, un **🌍 ejemplo de la vida real** y **✔ cómo validar completitud + cumplimiento de norma** (vectores RFC, `cargo test`). Doctrina identidad(§5)/autoridad(§4). Categorías A-F completas | 2.02 · 1.08 · 1.09 · A.42 · ADR-012 | ✅ 1.3.0 |
| [A.15 — Stack Rust de Autenticación](A.15_ANEXO-STACK-RUST-AUTENTICACION-v1.0.md) | **El patrón de sustentación (tipo D):** el stack real verificado (RustCrypto/ring + implementaciones nativas = independencia), cobertura por método con evidencia, y **6 brechas específicas** (attestation WebAuthn, XSW SAML, X.509, **Redis H-019 desactivado**, vectores JOSE, PQC) con exigencia normativa y resolución | 2.01 · 2.02 · 2.03 | ✅ 1.0.0 |
| [A.16 — Protocolos: por qué JSON-RPC 2.0 + WebSocket y NO REST/gRPC/GraphQL](A.16_ANEXO-PROTOCOLOS-JSONRPC-v1.0.md) | **Tipo C+B+D:** los 6 requisitos que gobiernan (HTTP vetado P9, agentes IA de primera clase, soberanía), la comparativa completa contra la industria (UDS ~0.01ms disuelve la ventaja gRPC; JSON-RPC transport-agnostic), la prueba de no-dogma (gRPC selectivo CAEP), verificación de código (primer byte 'G'/'{', anti-DoS, ≈151 métodos) y **5 brechas** (OpenRPC P1, colisión token.validate→registro fail-closed, huérfano, gate discovery) | 9.02 · ADR-002 · 2.09 | ✅ 1.0.0 |

---

## 3. La segunda ola — el plan de SUSTENTACIÓN del desarrollo (A.16+)

**Redefinición del propósito (decisión del humano, 2026-07-11):** los anexos son la capa de
**sustentabilidad del desarrollo y programación sin fricciones**. No basta respaldar los SSOT
existentes — si un manual afirma algo SIN fuente interna, el anexo se construye **investigando
en internet** (normas + industria del sector). Todo anexo entrega al lector: **lo que bAuth
HACE hoy (verificado en código), lo que está PARCIAL (con la brecha específica), y lo que NO
PUEDE hacer todavía pero las normas, los estándares y la industria EXIGEN**. La lógica de
cantidad: **debe haber muchos más anexos que manuales** — cada afirmación relevante de cada
manual merece su respaldo.

**Los 4 tipos de anexo (combinables):**

| Tipo | Qué aporta | Ejemplo |
|---|---|---|
| **A — Traslado de SSOT** | Estructuras/contratos/catálogos de diseño, íntegros y curados | A.01–A.14 |
| **B — Respaldo normativo/industria** | La investigación en internet que sustenta afirmaciones sin fuente interna | A.20, A.22, A.26 |
| **C — Justificación de decisión técnica** | Por qué X y no Y (protocolos, librerías, modelos de GUI) con comparativa de industria | A.16, A.18, A.28 |
| **D — Verificación de código** | Qué cubre el código real / qué está parcial / qué falta — con evidencia de módulos y brechas específicas | **A.15** (el patrón), A.17, A.19 |

**El plan (por manual — construcción en orden de prioridad, cada anexo con lectura COMPLETA
del manual respaldado + verificación de código + investigación):**

| Anexo | Tipo | Contenido | Respalda a |
|---|:---:|---|---|
| ✅ A.16 | C+B+D | **Protocolos: por qué JSON-RPC 2.0 + WebSocket y NO REST/gRPC/GraphQL** — requisitos R1-R6, comparativa de industria, código verificado (primer byte, ≈151 métodos), 5 brechas (OpenRPC P1) — **PUBLICADO** | 9.02 · ADR-002 · 2.09 |
| ✅ [A.17](A.17_ANEXO-BITMASK-CODIGO-v1.0.md) | D+B | **El BitMask Dual en código** — `src/bitmask/` (2.640 líneas, L3 real); identifica los SHIMS (domain/bitmask,inheritance,sod re-exportan); corrige 1.04 §14.2 (Redis H-019); 7 brechas (C1 átomos sin sembrar, C2 SAM-128 cero en código, C3 cache, C4 decision-log, C5 what-if, C6 AuthZEN, C7 ReBAC) — **PUBLICADO** | 1.04 · 1.03 |
| ✅ A.18 | C+B+D | **El modelo de GUI/frontend** — Flutter desktop soberano justificado; **divergencia P1 RESUELTA (§3.1, 2026-07-12)**: dos apps, dos propósitos — **bAuth Desktop** (producto → tf_shadcn+Riverpod+SBOS Dark) y **bAuthDEV** (tester → Material/provider); forUI/Abyss descartado y purgado del skill/plan/manual. Prototipo `bAuthDEV` (646 líneas) verificado — **PUBLICADO** | 2.11 · CLAUDE §7 |
| ✅ A.19 | D | **La superficie JSON-RPC real** — ≈151 métodos (29 familias); **corrige 9.02 §17-R3: la colisión `token.validate` es FALSO POSITIVO** (string de config, no registro); huérfano `domain_remaining` restante — **PUBLICADO** | 9.02 |
| ✅ A.20 | D+B | OIDC Provider nativo (discovery+JWKS reales, IdP soberano); brechas conformance, FAPI/PAR, **federación entrante P1** — **PUBLICADO** | 2.01 · 2.03 |
| ✅ A.21 | D+B | **El pipeline de dominios en código** — orden `EVAL_ORDER` coincide con 1.01 §5.1; 12 dominios existen (D1/D2/D3 reales, D5–D12 delgados); **hallazgo P1 seguridad: FAIL-OPEN** (`None => permitido` cuando falta evaluador) — **PUBLICADO** | 1.01 · 2.09 |
| ✅ A.22 | D+B | **Aislamiento multi-tenant** — **0 políticas RLS en todo el DDL** (verificado); aislamiento solo por `WHERE tenant_id` de 29 archivos; brecha P2 seguridad — **PUBLICADO** | 1.12 · 2.09 |
| ✅ A.23 | D | Validadores reales (774 líneas, no stubs); auditar cobertura regla-por-regla — **PUBLICADO** | 1.08 · 1.09 |
| ✅ A.24 | C+D | sqlx justificado (SQL crudo verificado=soberanía); 12 migraciones+101 seeds; bauth_44 sin aplicar P1 — **PUBLICADO** | 1.05 |
| ✅ A.25 | D+B | Compliance: DDL superior (bauth_30+16 marcos) SIN código de población; emisor ausente P1 — **PUBLICADO** | 7.02 · 7.03 |
| ✅ A.26 | D+B | **Risk Engine en código** — `risk.rs` (4 factores) existe pero **`#![allow(dead_code)]`**: escrito y SIN CABLEAR (0 invocaciones en pipeline; risk_score del JWT siempre None) — **PUBLICADO** | 3.01 |
| ✅ A.27 | D+B | **Auditoría en código** — la paradoja: **DDL superior + emisor ESQUELETO** (`src/audit/` = solo mod.rs 94 líneas); WORM bauth_44 sin aplicar; AU1 emisor P1, AU2 aplicar WORM P1 — **PUBLICADO** | 5.01 §11 |
| ✅ A.28 | D+C | JWT propio real; **hallazgo P1: DPoP es stub que retorna verified:true sin criptografía**; mTLS-binding ausente — **PUBLICADO** | 2.03 |
| ✅ A.29 | D+B | systemd Type=notify real; WatchdogSec sin evidenciar; runbook P1 — **PUBLICADO** | 6.01 |
| ✅ A.30 | B+D | IGA: sustrato (tablas+SoD) pero motores ausentes (campañas, barrido, role mining, JML) P1 — **PUBLICADO** | 7.01 |
| ✅ A.31 | D+B | **`idn_atributo` = 0 menciones en DDL: la tabla NO existe** (confirma brecha Directory); AT1 DDL P1 — **PUBLICADO** | 1.07 |
| ✅ A.32 | D+B | Catálogo apps (16 seed), zona→app; integración real vía biedata por verificar — **PUBLICADO** | 1.10 |
| ✅ A.33 | D | Motor Versionado L1 (0 código, correcto); F2 bloqueado por bauth_44 sin aplicar — **PUBLICADO** | 1.13 |
| ✅ A.34 | D+B | D99 garante, piso ≥365d (doctrina+CHECK propuesto 1.13); enforcement en código pendiente — **PUBLICADO** | 2.06 |
| ✅ A.35 | D+B | D4 evaluador real + integración bcalendar; encadenamiento a D1 por verificar — **PUBLICADO** | 2.07 |
| ✅ A.36 | D | menu_context (41 DDL/7 seeds), regla de oro ENUM↔entrada; auditar cobertura — **PUBLICADO** | 2.08 |
| ✅ A.37 | D+B | Cifrado tránsito real (JWE); **reposo por verificar** (SD1 P1); enmascaramiento declarado vs implementado — **PUBLICADO** | 2.10 |
| ✅ A.38 | D+B | Cliente CAEP salida real (caep_client.rs 260, gRPC); falta lazo de ENTRADA (conecta A.26) — **PUBLICADO** | 4.01 |
| ✅ A.39 | D | CLI pruebas real (bos_verify 256 + verify_policies 380 compilados); cobertura por medir; nota Q2 — **PUBLICADO** | 7.04 |
| ✅ A.40 | D+C | Producto real (binario MUSL release + systemd + CLI + SDK); incoherencia Redis service-vs-Cargo; doctrina Java obsoleta — **PUBLICADO** | 9.01 |
| A.41+ | — | Cobertura restante hasta que TODA afirmación relevante tenga respaldo (auditoría §3.1 en cada revisión) | todos |

### 3.1 La matriz de cobertura TOTAL — **absolutamente todos los manuales** (regla del humano, 2026-07-11)

**Ningún manual queda sin anexo(s) de sustentación.** El propósito: saber por manual **qué ya
está implementado, qué falta por implementar y qué hay que corregir.** Estado de cobertura:

| Manual | Anexos que lo respaldan | Cobertura |
|---|---|:---:|
| 0.00 Carta rectora | A.13 (ADRs vigencia) | ✅ |
| 1.01 Dominios | A.05 · **A.21** ✅ (fail-open P1) | ✅ |
| 1.02 Verbos | A.05 (elementos semánticos) | ✅ |
| 1.03 Átomos | A.05 · A.17 (BitMask código) | ✅+⏳ |
| 1.04 BitMask | A.03 §6 · **A.17** ✅ | ✅ |
| 1.05 DDL y Seeds | **A.24** ✅ | ✅ |
| 1.06 D00 Identidad | A.05 · A.31 ✅ | ✅ |
| 1.07 Atributos | **A.31** ✅ (idn_atributo sin DDL) | ✅ |
| 1.08 UserTemplate | A.02 · A.09 · A.23 ✅ | ✅ |
| 1.09 Roles | A.01 · A.03 · A.04 · A.23 | ✅ |
| 1.10 Aplicaciones | **A.32** ✅ | ✅ |
| 1.11 Context Plane | A.14 | ✅ |
| 1.12 Multi-tenancy | **A.22** ✅ (0 RLS, P2) | ✅ |
| 1.13 Motor de Versionado | **A.33** ✅ (L1) | ✅ |
| 2.01 Autenticación | A.06 · A.09 · A.15 · A.20 ✅ | ✅ |
| 2.02 Métodos | A.06 · A.15 | ✅ |
| 2.03 Tokens | A.15 · A.16 · **A.28** ✅ (DPoP stub P1) | ✅ |
| 2.04 Firma Digital | A.08 | ✅ |
| 2.05 Políticas | A.07 | ✅ |
| 2.06 D99 | **A.34** ✅ | ✅ |
| 2.07 Calendario D4 | **A.35** ✅ | ✅ |
| 2.08 Menú Contextual | **A.36** ✅ | ✅ |
| 2.09 Seguridad | A.11 | ✅ |
| 2.10 Seguridad de Datos | **A.37** ✅ | ✅ |
| 2.11 Frontend | **A.18** ✅ (divergencia P1 detectada) | ✅ |
| 2.12 Canales Protegidos | A.11 · A.16 · A.28 · A.42 §10.bis · A.13 (ADR-011) | ✅ (manual nuevo) |
| 3.01 Riesgo Adaptativo | **A.26** ✅ (dead_code) | ✅ |
| 4.01 bAuth↔bNotify | **A.38** ✅ (CAEP salida) | ✅ |
| 5.01 Auditoría | A.27 ✅ (emisor esqueleto) · 1.13 §2 | ✅ |
| 5.02 Blockchain D12 | A.12 | ✅ |
| 6.01 Operación | **A.29** ✅ (runbook P1) | ✅ |
| 7.01 IGA | A.10 · **A.30** ✅ | ✅ |
| 7.02 Calidad | **A.25** ✅ | ✅ |
| 7.03 Normas | A.06/A.07 · A.25 ✅ | ✅ |
| 7.04 CLI Pruebas | **A.39** ✅ | ✅ |
| 9.01 Producto | **A.40** ✅ | ✅ |
| 9.02 Referencia API | **A.16** ✅ · **A.19** ✅ (corrige colisión) | ✅ |

**Regla de construcción:** cada anexo se construye leyendo su fuente COMPLETA (jamás se inventa
contenido), verificando contra las normas en internet (fuentes primarias, con fecha), y
aplicando el patrón §1. Un anexo por entrega, con revisión del humano (HITL) antes del
siguiente. Si un manual afirma algo sin fuente interna, el anexo lo respalda con investigación
en internet **siempre con base en la norma y los estándares internacionales**.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-11 | Creación de la capa de anexos (decisión del humano: respaldo documental estructurado del corpus). Define el patrón canónico del anexo (8 elementos), publica A.01 (Contrato RolTemplate v6.0) y planifica A.02–A.14 con fuentes identificadas y regla de construcción (leer completo · verificar en internet contra normas · un anexo por entrega con HITL). |
| 1.4.0 | 2026-07-11 | **COBERTURA TOTAL COMPLETADA: los 36 manuales con anexo(s), 40 anexos publicados.** Segunda ola de sustentación cerrada (A.15–A.40) con verificación de código real. **Hallazgos crudos de reparación:** 🔴 seguridad P1 — pipeline FAIL-OPEN (A.21), DPoP stub que retorna verified:true sin criptografía (A.28), RLS ausente 0 policies (A.22); ⚠️ código sin cablear — Risk Engine `#![allow(dead_code)]` (A.26), emisor de auditoría esqueleto (A.27), Redis desactivado H-019 (A.15/A.17/A.40); ❌ ausentes — `idn_atributo` sin DDL (A.31), SAM-128 sin calcular (A.17), compliance sin población (A.25); 🟠 divergencias — frontend 3 stacks (A.18); ✅ corrección — colisión token.validate era falso positivo (A.19). Motor de Versionado L1 (A.33). A.17 reescrito por el humano (identifica shims) conservado. |
| 1.3.0 | 2026-07-11 | **Cobertura TOTAL decretada (decisión del humano): absolutamente TODOS los manuales tendrán anexos de sustentación** — nueva §3.1: matriz de cobertura de los 36 manuales (18 ya cubiertos ✅, 18 con anexo planificado ⏳; anexos A.31–A.40 añadidos al plan para los manuales sin cobertura: atributos, aplicaciones, motor de versionado, D99, calendario, menú contextual, seguridad de datos, bNotify/CAEP, CLI de pruebas, producto). Publica **A.16 (Protocolos: JSON-RPC vs REST/gRPC/GraphQL)** — el justificativo que faltaba, con requisitos, comparativa de industria, verificación de código y 5 brechas. |
| 1.2.0 | 2026-07-11 | **Redefinición del propósito (decisión del humano): los anexos son la capa de SUSTENTACIÓN del desarrollo** — taxonomía de 4 tipos (A traslado · B respaldo internet · C justificación de decisión · D verificación de código), regla de cantidad (muchos más anexos que manuales), y el mandato de entregar "lo que bAuth hace / lo parcial con brecha específica / lo que no puede todavía pero las normas y la industria exigen". Publica **A.15 (Stack Rust de Autenticación)** como patrón del tipo D — con la verificación de código real (Cargo.toml + módulos) y 6 brechas específicas, incluida **Redis H-019 desactivado** (la invalidación de cache no operativa). Plan de la segunda ola A.16–A.31+ por manual (§3): protocolos JSON-RPC-vs-REST/gRPC, BitMask Dual qué-falta, GUI/frontend, superficie real, OIDC conformance, pipeline de dominios, RLS multi-tenant, validadores, sqlx, calidad, riesgo, auditoría, JWT/DPoP, runbook, IGA. |
| 1.1.0 | 2026-07-11 | **Plan COMPLETADO: los 14 anexos publicados** (A.01 RolTemplate 2.1.0 · A.02 UserTemplate 1.1.0 · A.03 Catálogo de Roles · A.04 Cadenas · A.05 Átomos de Dominio · A.06/A.07 Frameworks con recursos fieles adjuntos · A.08 Firma · A.09 Credenciales · A.10 Revocación · A.11 Red · A.12 Blockchain · A.13 ADRs con tabla de vigencia real · A.14 Context Plane). Reglas incorporadas al patrón: autosuficiencia (traslado fiel — la legacy no se consulta), frontera (respaldo, no repetición del manual) y **aclaración permanente KC/Tryton** (toda mención de época se lee bajo ADR-010: eliminados — bAuth autosuficiente). |
