# Anexos del corpus bAuth — Índice y patrón
## La capa de respaldo documental: los manuales afirman, los anexos respaldan

**Versión:** 2.6.0 · **Fecha:** 2026-07-20 · **Estado: COBERTURA TOTAL** — 38 manuales con anexo(s); 63 anexos. A.66 Gaps nombres tablas DDL. A.67 B6 · Registro Aplicaciones Lógicas (arquitectura Zona=App, nomenclatura Tryton).
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
| [A.01 — El Contrato RolTemplate v6.0](A.01_ANEXO-ROLTEMPLATE-v1.0.md) | FUENTE AUTOSUFICIENTE: 14 bloques + D00 átomos identidad + idn_identidad_atributo roles (§22) | 1.09 · 1.04 · 2.05 · 1.06 v2.0 · 2.15 | ✅ 2.2.0 |
| [A.02 — El Contrato UserTemplate v6.0](A.02_ANEXO-USERTEMPLATE-v1.0.md) | FUENTE AUTOSUFICIENTE: idn_identidad_entidad + idn_identidad_atributo + D94 + gobernanza D00 (§23) | 1.08 · 2.01 · 1.06 v2.0 · 1.07 v2.0 · 2.15 | ✅ 1.2.0 |
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
| ⭐ [A.42 — ESPECIFICACIÓN DE IMPLEMENTACIÓN](A.42_ANEXO-ESPECIFICACION-IMPLEMENTACION-v1.0.md) | **Las funciones a desarrollar con FIRMA (parámetros) + CUERPO paso a paso de la norma** — para desarrollar sin inventar. Fichas: BA2 DPoP (12 pasos RFC 9449), BA3 pipeline fail-closed, BA4 rate-limit, BA6 IAL, BA7 idn_identidad_atributo DDL, BA8 ADSIB, BA11 emisor auditoría (AU-3), BA13 IGA, BA17 RLS. Complementa el código `src/domain/andamiaje.rs` (las firmas) | A.41 §11 · todo el corpus | ✅ 1.0.0 |
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
| ✅ A.31 | D+B | **`idn_identidad_atributo` = 0 menciones en DDL: la tabla NO existe** (confirma brecha Directory); AT1 DDL P1 — **PUBLICADO** | 1.07 |
| ✅ A.32 | D+B | Catálogo apps (16 seed), zona→app; integración real vía biedata por verificar — **PUBLICADO** | 1.10 |
| ✅ A.33 | D | Motor Versionado L1 (0 código, correcto); F2 bloqueado por bauth_44 sin aplicar — **PUBLICADO** | 1.13 |
| ✅ A.34 | D+B | D99 garante, piso ≥365d (doctrina+CHECK propuesto 1.13); enforcement en código pendiente — **PUBLICADO** | 2.06 |
| ✅ A.35 | D+B | D4 evaluador real + integración bcalendar; encadenamiento a D1 por verificar — **PUBLICADO** | 2.07 |
| ✅ A.36 | D | menu_context (41 DDL/7 seeds), regla de oro ENUM↔entrada; auditar cobertura — **PUBLICADO** | 2.08 |
| ✅ A.37 | D+B | Cifrado tránsito real (JWE); **reposo por verificar** (SD1 P1); enmascaramiento declarado vs implementado — **PUBLICADO** | 2.10 |
| ✅ A.38 | D+B | Cliente CAEP salida real (caep_client.rs 260, gRPC); falta lazo de ENTRADA (conecta A.26) — **PUBLICADO** | 4.01 |
| ✅ A.39 | D | CLI pruebas real (bos_verify 256 + verify_policies 380 compilados); cobertura por medir; nota Q2 — **PUBLICADO** | 7.04 |
| ✅ A.40 | D+C | Producto real (binario MUSL release + systemd + CLI + SDK); incoherencia Redis service-vs-Cargo; doctrina Java obsoleta — **PUBLICADO** | 9.01 |
| ✅ [A.45 — Fundamentos Normativos AtomLang v1.2.0](A.45_ANEXO-FUNDAMENTOS-NORMATIVOS-ATOMLANG-v1.0.md) | B+C | **Mapa normativo de 22 constructos**: 14 planos de control D00-D13 (Manual 1.01 §4) + 5 dominios del lenguaje D95-D99 (2.13 v2.0 §4.3). D95 (Catálogo, NIST SP 800-162 §4.2), D96 (Contratos, NIST SP 800-63B §4, RFC 9470), D97 (Normas, XACML §7.3), D98 (Registro), D99 (Global, NIST SP 800-207 §3.1). Tabla D00-D13 corregida con los 14 planos (D3=Financiero PCI DSS, D13=Firma Ley 164). **v1.1.0** | 2.13 v2.0 §2–§7 · 2.14 §3–§7 · 2.05 §2 |
| ✅ [A.46 — Gramática y Compilador atomc v1.0.3](A.46_ANEXO-ATOMLANG-GRAMATICA-COMPILADOR-v1.0.md) | A+D | EBNF, reglas G-01..G-10, JSON Schema, algoritmo evaluador, catálogo errores ATOMC-E/W, arquitectura atomc 3 fases, DDL privilege_atom_compiled WORM. **v1.0.2** — cabecera actualizada a 2.13 v2.0. | 2.13 v2.0 §5, §8 |
| ✅ [A.47 — Clasificación y Composición del Árbol v1.0.3](A.47_ANEXO-CLASIFICACION-COMPOSICION-ARBOL-v1.0.md) | B+C | Árbol de decisión ampliado con D95-D99, reglas A-01..A-08, glosario, diagnóstico D1, checklist. **v1.0.2** — 4 nuevas reglas para dominios del lenguaje. | 2.13 v2.0 §4 · 2.14 §8–§10 |
| ✅ [A.48 — Parametrización bauth_config_param v1.0.2](A.48_ANEXO-PARAMETRIZACION-BAUTH-CONFIG-PARAM-v1.0.md) | B+C+A | PIP, DDL, 20 parámetros tipados, gobernanza IAM_PARAM_ADMIN. **v1.0.2** — cabecera actualizada a 2.13 v2.0. | 2.13 v2.0 §5.2 · 2.14 §9 |
| ✅ [A.49 — Constructor Visual AtomLang v1.1.0](A.49_ANEXO-EDITOR-VISUAL-ATOMLANG-v1.0.md) | A+D | **Especificación del editor visual**: paleta de 9 objetos arrastrables (dominio, bloque, policyset, política, regla, atributo, lista, enumerado), reglas de drop por tipo de nodo contenedor, 6 tipos de campo en el panel de propiedades (texto libre, desplegable, búsqueda con autocompletado, selector de constante, toggle booleano, sub-formulario), validación post-construcción con atomc validate, tres vistas filtradas (General/Rol/Usuario), integración con 6 catálogos PostgreSQL vía JSON-RPC — **PUBLICADO** | 2.13 §6 |
| ✅ [A.50 — Modelo Simplificado v1.1.0](A.50_ANEXO-MODELO-SIMPLIFICADO-ROLES-USUARIOS-v1.0.md) | B+C | **Pipeline de 5 pasos + comparativa industria**: definir → compilar → asignar átomos a roles → inscribir usuarios → evaluar (BitMask <0.5ns). Tres vistas del árbol (General/Rol/Usuario) con filtro progresivo. Comparativa detallada con Cedar, OPA/Rego y XACML 3.0 en 9 dimensiones. Tesis: la complejidad se resuelve en la fábrica (compile time), no en runtime — **PUBLICADO** | 2.13 §7 · 2.13 §9 |
| ✅ [A.51 — Merge de Roles y Asignación Temporal](A.51_ANEXO-MERGE-ROLES-TEMPORAL-v1.0.md) | B+C+A | Fusión de roles + suplencia: 3 modos, D10, extensión idn_user_role — **PUBLICADO** | 2.13 §7 · A.50 §2 |
| ✅ [A.52 — Tipos y Dominios de Identidad](A.52_ANEXO-TIPOS-DOMINIOS-IDENTIDAD-v1.0.md) | B+C | **37 dominios, 8 tipos base.** Respaldo SAP Business Partner, Odoo res.partner, ISO 9001 — **PUBLICADO** | 1.06 v2.1.0 §4,§5,§12 |
| ✅ [A.53 — Entidad como Acumulador de Capas](A.53_ANEXO-ENTIDAD-CAPAS-ATRIBUTOS-v1.0.md) | C | **Toyota Carina 97 (5 dueños, 28 años), Juan Pérez (8 dominios, 45 años), DEPO (6 simultáneos)** — **PUBLICADO** | 1.06 v2.1.0 §2,§12 |
| ✅ [A.54 — Catálogo de Autopartes y Referencias Cross-Tenant](A.54_ANEXO-CATALOGO-AUTOPARTES-REFERENCIAS-v1.0.md) | B+C | **N-to-N, multi-tenant, visibilidad PRIVADA/COMPARTIDA/PUBLICA, distribución, custodia** — **PUBLICADO** | 1.06 v2.1.0 §12 |
| ✅ [A.55 — Catálogo Automotriz](A.55_ANEXO-CATALOGO-AUTOMOTRIZ-SECCIONES-v1.0.md) | A+C | 8 secciones, 20 subsistemas, 40+ posiciones. 30 fabricantes. ISO 3833 · UN/ECE WP.29 — **PUBLICADO** | 1.06 v2.1.0 §4,§12 · A.54 |
| ✅ [A.56 — Diseño BD Identidad](A.56_ANEXO-DISENO-BD-IDENTIDAD-v1.0.md) | A+C | 3 tablas, UUID v7, 7 índices GIN, búsquedas fuzzy/full-text, sinónimos, seguridad, compartición externa — **PUBLICADO** | 1.06 v2.1.0 · 1.07 v2.0 |
| ✅ [A.57 — Rendimiento Identidad](A.57_ANEXO-RENDIMIENTO-IDENTIDAD-v1.0.md) | D | 165M filas, <100ms con GIN, Magento evidence, particionamiento — **PUBLICADO** | A.56 |
| ✅ [A.59 — Tipos de Átomos y Dominios](A.59_ANEXO-TIPOS-ATOMOS-DOMINIOS-v1.0.md) | A | 6,000 átomos, 64-bit BitMask, 4 operaciones, G-01..G-10 — **PUBLICADO** | 2.17 v1.1.0 · 1.03 · 1.04 · A.46 |
| ✅ [A.60 — Ciclo de Vida Átomos y Roles](A.60_ANEXO-CICLO-VIDA-ATOMOS-ROLES-v1.0.md) | A+C | 6 estados del rol, herencia DAG (1,673 filas), merge OR, 3 modos de asignación, trazabilidad — **PUBLICADO** | 2.17 v1.1.0 · 1.09 · 1.04 · A.51 |
| ✅ [A.61 — Diseño BD Motor de Roles](A.61_ANEXO-DISENO-BD-ROLES-v1.0.md) | A+C | 7 tablas existentes + 3 nuevas, patrones de consulta, comparación con Identidad. Absorbe A.58 — **PUBLICADO** | 2.17 v1.1.0 · 1.03 · 1.04 |
| ✅ [A.62 — Rendimiento Motor de Roles](A.62_ANEXO-RENDIMIENTO-ROLES-v1.0.md) | D | 3.3M filas, <6ms por operación, 50× más pequeño que Identidad — **PUBLICADO** | A.61 · 2.17 v1.1.0 |
| ✅ [A.63 — Objetos Compuestos del Árbol AtomLang v2.2.0](A.63_ANEXO-ARBOL-OBJETOS-COMPUESTOS-v2.2.0.md) | A+C | **COMPLETO v2.2.0 — Arquitectura total del Desktop**: shell + sidebar + breadcrumbs, landing page KPIs, selector multi-tenant, 2 editores con 12 paneles de propiedades, menú contextual (clic derecho), drag crear/mover/copiar, flujo Verificar (SEGIP/SIN/ADSIB), flujo Vincular HW (bNexus), compilación atomc inline, Usuario↔Rol + SoD, SETs D94/D98, vista Atributos D93, consola atomc, reportes, admin, auditoría, offline/reconexión, operaciones en lote, undo/redo + 30 atajos — **PUBLICADO** | 2.15 v1.2.0 · 2.17 v1.1.0 · 1.06 v2.1 |
| ✅ [A.64 — Maquetas de Texto: bAuth Desktop v1.0](A.64_ANEXO-MAQUETAS-DESKTOP-v1.0.md) | C | Maquetas ASCII fieles al código Flutter real: shell global (3 bloques), sidenav (expandido/colapsado), 5 vistas implementadas (Dashboard, RolTemplate, Roles, Usuarios, Árbol de Entidades), capas fijas (BarraSuperior/Breadcrumb/StatusBar/BloqueDerecho), tabla de 17 rutas con estado — **PUBLICADO** | `src/desktop/lib/` · 1.06 v2.0 |
| ✅ [A.65 — Inventario de Tablas DDL · Revisión de Diseño v1.3](A.65_ANEXO-INVENTARIO-TABLAS-DDL-v1.0.md) | A+C | **155 tablas del esquema bAuth** (151 originales + 4 MVU T-152–T-155): principio rector del árbol jerárquico, 26 grupos (GLOBAL/IDENTIDAD/ROLES/USUARIOS/PRIVILEGIOS/SOD/AUTENTICACIÓN/SESIÓN/ORGANIZACIÓN/FINANCIERO/FÍSICO/GEOLOCALIZACIÓN/RED-ZTNA/AUDITORÍA/BLOCKCHAIN/SEGURIDAD/DISPOSITIVOS/ZONAS-UI/CALENDARIO/OIDC-IDP/VERSIONADO/SINCRONIZACIÓN/CONFIG/EMERGENCIA/VISITANTES/LEGADO), clasificación C1-C4, 122 CONSERVAR + 33 ELIMINAR con razón y reemplazo exacto — **PUBLICADO** | 1.13 · 5.01 · A.01 · A.62 |
| ✅ [A.65.01 — Guía de Desarrollo: Tablas del Esquema bAuth v2.0.0](A.65.01_ANEXO-GUIA-DESARROLLO-TABLAS-DDL-v1.0.md) | B+C | **Manual práctico para el desarrollador** (Parte I + Parte II): axioma de trazabilidad, las dos mitades C2+C3, las 4 clases de información, cuándo escribir en cada clase, flujo RolTemplate (MAJOR/MINOR/PATCH, fotografía en anclas), UserTemplate con RGPD Art.17, patrón `aud_event` con `iso_control[]` y hash-chain, transición atómica de 9 pasos, flujo MAJOR con quórum, retención KEEP_ANCHORS, 33 tablas eliminadas, 12 errores comunes, mapa de relaciones; **Parte II:** guía de uso para los 26 grupos del A.65 (qué es, por qué existe, cuándo INSERT/SELECT/DELETE, qué no tocar con alternativa en el árbol) — **PUBLICADO** | 5.01 §2/§3/§7 · 1.13 §5-§10 · A.65 |
| ✅ [A.65.02 — Nueva DDL: Inventario limpio v1.0](A.65.02_ANEXO-NUEVA-DDL-v1.0.md) | A | **Inventario de partida para la nueva DDL completa**: 16 secciones IAM Enterprise. Secciones fijas (41 tablas): GLOBAL 8, TENANT 8, ROLES 6, VERSIONADO 4, IDENTIDAD 6, CALENDARIO 9. Secciones nuevas (tablas por definir): USUARIOS · AUTENTICACIÓN · SESIÓN · PRIVILEGIOS · AUDITORÍA · FIRMA DIGITAL · FEDERACIÓN/OIDC · RIESGO/ITDR · PAM · DISPOSITIVOS. Cada sección alineada con NIST 800-63-4, ISO/IEC 24760-2:2025, ANSI INCITS 359, CAEP RFC 9396, Ley 164 — **PUBLICADO** | 1.05 · 1.13 · A.65 · A.61 · A.56 · 2.07 |
| ✅ [A.66 — Gaps de Nombres y Arquitectura DDL v1.0](A.66_ANEXO-GAPS-NOMBRES-TABLAS-DDL-v1.0.md) | C | **Decisiones pendientes sobre nombres y arquitectura de tablas DDL**: mapa legacy→canónico (9 tablas renombradas), análisis de `idn_tier_policy` (9 tiers, 4 gaps menores), gap de `idn_role_template.template` (sync-state no B1-B14), tablas T-162/T-163 a crear — PENDIENTE DE RESPUESTA | A.65 · A.65.02 · 1.13 |
| ✅ [A.67 — Bloque Zona de Negocios del RolTemplate v1.1](A.67_ANEXO-BLOQUE-ZONAS-NEGOCIO-ROL-TEMPLATE-v1.0.md) | A+C | **Business Zone (NGAC INCITS 565-2020 · SABSA SCF · ISO 27001 A.5.15)**: bloque `Zona de Negocios` presente en **todos los dominios** D01–D13/D98/D99; solo acepta nodos `politica` de aplicación con Z0·Identidad (`app_code` obligatorio); rechaza áreas de negocio abstractas; jerarquía D01: `Zona→model/actions/field/button/record_rule→Módulo→Átomo` (5 niveles Tryton verificados); tabla de prefijos por dominio (`zona_logical_*` / `zona_financial_*` / etc.); niveles internos por dominio D02–D13; 5 apps D01 registradas; slug `{dominio}.{app}.{módulo}.{verbo}` — **PUBLICADO v1.1** | 2.14 · `rol_template_datos.dart` B6 |

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
| 1.06 D00 Identidad v2.1.0 | A.05 · A.31 · **A.52** ✅ (tipos y dominios) · **A.53** ✅ (capas) · **A.54** ✅ (autopartes) | ✅ |
| 1.07 Atributos | **A.31** ✅ (idn_identidad_atributo sin DDL) | ✅ |
| 1.08 UserTemplate | A.02 · A.09 · A.23 ✅ | ✅ |
| 1.09 Roles | A.01 · A.03 · A.04 · A.23 | ✅ |
| 1.10 Aplicaciones | **A.32** ✅ | ✅ |
| 1.11 Context Plane | A.14 | ✅ |
| 1.12 Multi-tenancy | **A.22** ✅ (0 RLS, P2) | ✅ |
| 1.13 Motor de Versionado | **A.33** ✅ (L1) · **A.65** ✅ (inventario DDL, sección VERSIONADO T-152–T-155) · **A.65.01** ✅ (guía desarrollo: C2 patrones, transición atómica, quórum MAJOR, retención) | ✅ |
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
| 2.13 AtomLang — Lenguaje v2.0 | **A.45** ✅ (v1.1.0) · **A.46** ✅ (v1.0.2) · **A.47** ✅ (v1.0.2) · **A.48** ✅ (v1.0.2) · **A.49** ✅ (constructor visual) · **A.50** ✅ (modelo simplificado) · **A.51** ✅ (merge roles temporal) | ✅ |
| 2.14 Composición del Árbol | **A.45** ✅ · **A.47** ✅ (clasificación + diagnóstico D1) · **A.48** ✅ (bauth_config_param PIP) | ✅ |
| 2.15 Motor de Identidad | **A.31** ✅ (idn_identidad_atributo) · **A.02** ✅ (UserTemplate) · **A.01** ✅ (RolTemplate) | ✅ |
| 2.17 Motor de Roles v1.1.0 | **A.59** ✅ (tipos y dominios) · **A.60** ✅ (ciclo de vida) · **A.61** ✅ (diseño BD) · **A.62** ✅ (rendimiento) · **A.46** ✅ (G-01..G-10) · **A.01** ✅ (RolTemplate) | ✅ |
| 3.01 Riesgo Adaptativo | **A.26** ✅ (dead_code) | ✅ |
| 4.01 bAuth↔bNotify | **A.38** ✅ (CAEP salida) | ✅ |
| 5.01 Auditoría | A.27 ✅ (emisor esqueleto) · **A.65** ✅ (inventario DDL, sección AUDITORÍA T-091–T-098) · **A.65.01** ✅ (guía desarrollo: axioma, C3 patrones, hash-chain, 30 tipos, iso_control[]) | ✅ |
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
| 1.7.0 | 2026-07-14 | **47 anexos totales.** A.51 (Merge de Roles y Asignación Temporal): 3 modos (PERMANENTE, MERGE, REPLACE), integración D10, propuesta extensión `idn_user_role`, pipeline Paso 4 refinado, nodo `asignacion_temporal`. |
| 2.6.0 | 2026-07-20 | **63 anexos totales.** A.66 Gaps de Nombres DDL (mapa legacy→canónico, 9 tablas, gaps idn_tier_policy/idn_role_template). A.67 Bloque Zonas de Negocio del RolTemplate — B6 D01: arquitectura Zona=App, jerarquía Tryton (model/actions/field/button/record_rule), separación por dominio (zona_logical_* → D01, zona_financial_* → D03, etc.), 5 apps registradas. |
| 2.5.0 | 2026-07-20 | **A.65.02 ampliado a 16 secciones IAM Enterprise.** Se agregan 10 secciones nuevas (sin tablas aún, solo cabecera + propósito): USUARIOS (NIST 800-63-4 §3, SCIM 2.0), AUTENTICACIÓN (18 métodos, FIDO2, NIST 800-63B-4 §5), SESIÓN (CAEP RFC 9396, SBOS-049), PRIVILEGIOS (motor BitMask, ANSI INCITS 359, XACML 3.0), AUDITORÍA (WORM, ISO 27001 A.8.15, PCI DSS Req 10), FIRMA DIGITAL (Vault Ed25519 + ADSIB RSA-SHA256, Ley 164), FEDERACIÓN/OIDC (RFC 6749/9449, FAPI 2.0), RIESGO/ITDR (NIST 800-207 ZTA, MITRE ATT&CK), PAM (AC-6(9), quórum N-de-M), DISPOSITIVOS (FIDO2 attestation, IEEE 802.1X). |
| 2.4.0 | 2026-07-20 | **61 anexos totales.** A.65.02 Nueva DDL — inventario limpio de 41 tablas en 6 secciones (GLOBAL 8, TENANT 8, ROLES 6, VERSIONADO 4, IDENTIDAD 6, CALENDARIO 9) con nombre canónico definitivo y propósito por tabla. Punto de partida para el diseño DDL completo desde cero. |
| 2.3.0 | 2026-07-19 | **60 anexos totales.** Renumeración: A.62 DDL Inventario → **A.65** (resuelve solapamiento con A.62 Rendimiento Motor de Roles). A.65 anterior (Guía de Desarrollo) → **A.65.01**. A.65 Inventario DDL: 155 tablas, 26 grupos, 122 CONSERVAR + 33 ELIMINAR, clasificación C1-C4. A.65.01 Guía Desarrollo: Parte I (axioma, C2+C3, transición atómica, MAJOR, retención) + Parte II nueva (26 grupos con qué-es, por-qué-existe, cuándo-usar, qué-no-tocar). |
| 2.2.0 | 2026-07-19 | **59 anexos totales.** A.65 Guía de Desarrollo Tablas Auditoría+Versionado (axioma, C2+C3, transición atómica, 33 tablas eliminadas). A.62 DDL Inventario v1.3: sección VERSIONADO (T-152–T-155 MVU), análisis AUDITORÍA, clasificación C1-C4. |
| 2.1.0 | 2026-07-15 | **58 anexos totales.** Motor de Roles completo: A.59 (tipos, 6,000 átomos, BitMask), A.60 (ciclo vida, DAG 1,673 filas), A.61 (diseño BD, absorbe A.58), A.62 (rendimiento, 3.3M filas, <6ms). Motor de Identidad v1.2.0. Motor de Roles v1.1.0. |
| 2.0.0 | 2026-07-15 | A.52-A.54 (Identidad: 37 dominios, capas, catálogo autopartes). 6 análisis sueltos eliminados. |
| 1.9.0 | 2026-07-15 | **D00 v2.1.0 (37 dominios, N-to-N, multi-tenant, visibilidad).** 1.06 actualizado con §12: potencial completo del sistema de identidad. 2.15 v1.1.0 (N-to-N, cross-tenant). 2.16 v1.1.0. +6 análisis de identidad. |
| 1.8.0 | 2026-07-14 | **D00 Identidad v2.0 + Atributos v2.0 + Motor de Identidad.** Manual 1.06 reescrito (catálogo universal, 3 tablas, 5 niveles con tipos variables, D93, prueba de escritorio 11 sectores). Manual 1.07 reescrito (EAV con type explícito, 60+ atributos, 18 display formats, validación vía motor de identidad). Nuevo manual 2.15 Motor de Identidad (validate/verify/format, catálogo completo de validación, API bauth.entidad.atributo.*). |
| 2.17 Motor de Roles v1.1.0 | **A.59** ✅ (tipos y dominios) · **A.60** ✅ (ciclo de vida) · **A.61** ✅ (diseño BD) · **A.62** ✅ (rendimiento) · **A.46** ✅ (G-01..G-10) · **A.01** ✅ (RolTemplate) | ✅ |
| 1.6.0 | 2026-07-14 | **AtomLang v2.0: 46 anexos totales.** Manual 2.13 v2.0. A.49 + A.50 nuevos. A.45 v1.1.0. A.46-A.48 v1.0.2. Manual 2.13 v1.0 y 4 legacy eliminados. |
| 1.5.0 | 2026-07-13 | **AtomLang A.45–A.48 publicados: 38 manuales con cobertura, 44 anexos totales.**
| 1.4.0 | 2026-07-11 | **COBERTURA TOTAL COMPLETADA: los 36 manuales con anexo(s), 40 anexos publicados.** Segunda ola de sustentación cerrada (A.15–A.40) con verificación de código real. **Hallazgos crudos de reparación:** 🔴 seguridad P1 — pipeline FAIL-OPEN (A.21), DPoP stub que retorna verified:true sin criptografía (A.28), RLS ausente 0 policies (A.22); ⚠️ código sin cablear — Risk Engine `#![allow(dead_code)]` (A.26), emisor de auditoría esqueleto (A.27), Redis desactivado H-019 (A.15/A.17/A.40); ❌ ausentes — `idn_identidad_atributo` sin DDL (A.31), SAM-128 sin calcular (A.17), compliance sin población (A.25); 🟠 divergencias — frontend 3 stacks (A.18); ✅ corrección — colisión token.validate era falso positivo (A.19). Motor de Versionado L1 (A.33). A.17 reescrito por el humano (identifica shims) conservado. |
| 1.3.0 | 2026-07-11 | **Cobertura TOTAL decretada (decisión del humano): absolutamente TODOS los manuales tendrán anexos de sustentación** — nueva §3.1: matriz de cobertura de los 36 manuales (18 ya cubiertos ✅, 18 con anexo planificado ⏳; anexos A.31–A.40 añadidos al plan para los manuales sin cobertura: atributos, aplicaciones, motor de versionado, D99, calendario, menú contextual, seguridad de datos, bNotify/CAEP, CLI de pruebas, producto). Publica **A.16 (Protocolos: JSON-RPC vs REST/gRPC/GraphQL)** — el justificativo que faltaba, con requisitos, comparativa de industria, verificación de código y 5 brechas. |
| 1.2.0 | 2026-07-11 | **Redefinición del propósito (decisión del humano): los anexos son la capa de SUSTENTACIÓN del desarrollo** — taxonomía de 4 tipos (A traslado · B respaldo internet · C justificación de decisión · D verificación de código), regla de cantidad (muchos más anexos que manuales), y el mandato de entregar "lo que bAuth hace / lo parcial con brecha específica / lo que no puede todavía pero las normas y la industria exigen". Publica **A.15 (Stack Rust de Autenticación)** como patrón del tipo D — con la verificación de código real (Cargo.toml + módulos) y 6 brechas específicas, incluida **Redis H-019 desactivado** (la invalidación de cache no operativa). Plan de la segunda ola A.16–A.31+ por manual (§3): protocolos JSON-RPC-vs-REST/gRPC, BitMask Dual qué-falta, GUI/frontend, superficie real, OIDC conformance, pipeline de dominios, RLS multi-tenant, validadores, sqlx, calidad, riesgo, auditoría, JWT/DPoP, runbook, IGA. |
| 1.1.0 | 2026-07-11 | **Plan COMPLETADO: los 14 anexos publicados** (A.01 RolTemplate 2.1.0 · A.02 UserTemplate 1.1.0 · A.03 Catálogo de Roles · A.04 Cadenas · A.05 Átomos de Dominio · A.06/A.07 Frameworks con recursos fieles adjuntos · A.08 Firma · A.09 Credenciales · A.10 Revocación · A.11 Red · A.12 Blockchain · A.13 ADRs con tabla de vigencia real · A.14 Context Plane). Reglas incorporadas al patrón: autosuficiencia (traslado fiel — la legacy no se consulta), frontera (respaldo, no repetición del manual) y **aclaración permanente KC/Tryton** (toda mención de época se lee bajo ADR-010: eliminados — bAuth autosuficiente). |
