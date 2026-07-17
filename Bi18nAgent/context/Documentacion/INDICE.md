# Documentación Técnica — bi18n (i18n-orchestrator)

**Versión:** 2.4.0
**Mantenido por:** bauth-developer
**Última actualización:** 2026-07-18
**Estado:** Activo — Fase 1 ✅ (18 RPC) + Fase 2 ✅ (108 RPC nuevos). Total: **126 métodos RPC**. P4 ✅ (admin.* + WebSocket push + Bundle Prefetch). P4b ✅ (auditoría namespace CLI: 100% alineado). Documentación completa: 4 manuales · 25 anexos.

---

## ⭐ Documento rector

| Documento | Archivo | Rol |
|-----------|---------|-----|
| **Directrices de Categoría IAM Enterprise** | [0.00 (bAuth)](../../BauthAgent/context/Documentacion/0.00_MANUAL-DIRECTRICES-IAM-ENTERPRISE.md) | **Carta rectora del ecosistema** — bi18n se alinea a los 7 pilares, las 10 directrices editoriales y la categoría IAM Enterprise definidas por bAuth |

---

## Manuales disponibles

Los manuales se numeran `N.M` desde 1.01 (primer manual de bi18n).

| N° | Manual | Depende de | Estado |
|:--:|--------|------------|:------:|
| 1.01 | [bi18n — Arquitectura del Orquestador](1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) | [i18n-orchestrator-rust.md](../i18n-orchestrator-rust.md) · [1.07 Atributos](../../BauthAgent/context/Documentacion/1.07_MANUAL-ATRIBUTOS-v2.0.md) · [2.15 Motor Identidad](../../BauthAgent/context/Documentacion/2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) | ✅ 1.4.0 |
| 1.02 | [Manual de Usuario bi18n](MANUAL-USUARIO-BI18N-v1.0.md) | 1.01 · A.02 · A.07 | ✅ 1.0.0 |
| 1.03 | [**Manual del Programador — Mantenimiento y Actualización**](1.03_MANUAL-PROGRAMADOR-BI18N-v1.0.md) | 1.01 · A.01 · A.10 · ISO 14764 · ISO 12207 | ✅ 1.0.0 |
| 1.04 | [**Manual del Usuario Programador — Consumir bi18n**](1.04_MANUAL-USUARIO-PROGRAMADOR-v1.0.md) | 1.01 · A.07 · A.09 · A.10 | ✅ 1.0.0 |

---

## Registro de implementación

| Documento | Contenido | Estado |
|---|---|---|
| [REGISTRO-ESTADO-IMPLEMENTACION — Fase 1](REGISTRO-ESTADO-IMPLEMENTACION.md) | Bloques 1-12 ✅ completos. 18 métodos RPC, Interface Triple C11, BO/AR/BR, Weblate, ArcSwap, hot-reload, manual, batería de pruebas, garantía de completitud. | ✅ v1.1.0 cerrado |
| [**REGISTRO-ESTADO-DOS — Fase 2**](REGISTRO-ESTADO-DOS.md) | 15 bloques (A-N + Ω). Exposición completa de las 23 librerías de Cargo.toml como métodos RPC. **103 métodos RPC implementados** (total acumulado 121). P4: 4 métodos `bi18n.admin.*` por JSON-RPC (sin servidor HTTP). APIs verificadas directamente en `~/.cargo/registry/src/` — v3.0.0 corrige 5 errores de la v2.0.0. | ✅ v3.1.0 |
| [**PLAN-FASE-2-IMPLEMENTACION**](PLAN-FASE-2-IMPLEMENTACION-v1.0.md) | Protocolo de trabajo para los 14 handlers Rust de Fase 2. **Un anexo = una librería = un handler.** Mapa A.08.01→14 a `lib_*.rs`, convención de naming, estructura del dispatcher, tabla de progreso con commit por handler. | ✅ v1.0.0 |
| [BATERIA-PRUEBAS-TESTEADOR — Fase 1](BATERIA-PRUEBAS-TESTEADOR-v1.0.md) | 28 verificaciones VERDADERO/FALSO para los 18 métodos RPC de Fase 1. | ✅ 1.0.0 |

---

## Gaps de diseño

| Documento | Contenido | Estado |
|---|---|---|
| [GAPS-BI18N — 4 decisiones resueltas](GAPS-BI18N-v1.0.md) | **Todas las decisiones de diseño resueltas (v2.0.0):** RegionalConfig estático → request, sin PostgreSQL, SIGHUP, patrones fijos en format_map. | ✅ 2.0.0 |

---

## Anexos

| Anexo | Contenido | Respalda a | Estado |
|---|---|---|---|
| [A.01 — Cobertura de Librerías](anexos/A.01_ANEXO-BI18N-COBERTURA-LIBRERIAS-v1.0.md) | **Tipo D:** 23 librerías verificadas en 9 categorías. Cobertura 100%. Datos por país vía TOML. | 1.01 · 1.07 · 2.15 | ✅ 2.1.0 |
| [A.02 — Interfaces de Consumo](anexos/A.02_ANEXO-BI18N-INTERFACES-CONSUMO-v1.0.md) | **Tipo A:** cómo consumen bi18n los dos mundos de cliente — UI remota (JSON-RPC, adapters por plataforma) y CLI interno (i18nctl, scripts, CI/CD). | 1.01 · A.01 | ✅ 1.0.0 |
| [A.03 — Interfaz gRPC (Interface Triple C11)](anexos/A.03_ANEXO-BI18N-GRPC-INTERFACE-v1.0.md) | **Tipo A:** proto canónico `bi18n.proto` completo — 7 servicios, 14 métodos MVP. Transporte Unix domain socket. Servidor tonic, `build.rs`, paridad JSON-RPC ↔ gRPC, checklist C11 para Revisor y Testeador. | 1.01 | ✅ 1.0.0 |
| [A.04 — Ligadura bi18n a UI Frontend](anexos/A.04_ANEXO-BI18N-TECNICA-LIGADURA-FRONTEND-v2.1.md) | **Tipo R/G:** *Metadata-driven attribute binding* + guía de implementación. bi18n es **agnóstico de plataforma** — expone WebSocket + JSON-RPC 2.0 neutro; cualquier cliente lo consume sin importar su lenguaje o framework. Técnicas servidor (dispatch, actor, caché, rate limiting); principios de adapter para clientes (singleton, cache, debounce, máquina de estados, fallback); §9 contiene referencias de implementación ilustrativas (no entregables del daemon). | 1.01 · A.02 | ✅ 2.2.0 |
| [A.05 — Cierre de Gaps de bi18n](anexos/A.05_ANEXO-BI18N-CIERRE-GAPS-v1.1.md) | **Tipo G:** 6 gaps ejecutables: RTL (`text_direction` en locale.resolve), gobernanza CODEOWNERS sobre country-rules, CI de paridad de claves (`i18nctl translations check-parity`), alta disponibilidad (2+ réplicas bi18nd + Kong), requisito a11y en la especificación de protocolo (contrato de comportamiento, no prescripción de mecanismo), especificación formal del protocolo WebSocket A.07 (agnóstico de plataforma). | 1.01 · A.04 | ✅ 1.2.0 |
| [A.06 — bi18n como Daemon de Traducciones](anexos/A.06_ANEXO-BI18N-DAEMON-TRADUCCIONES-v1.1.md) | **Tipo G:** edición de traducciones sin fricción. Weblate self-hosteado (recomendado sobre Tolgee por licencia GPLv3+). Hot-reload con `arc-swap` (swap atómico sin bloqueo, patrón estándar). Nuevo RPC `bi18n.admin.reload_translations`. Gobernanza diferenciada: `country-rules/` (aprobación obligatoria) vs `translations/` (solo gate CI). | 1.01 · A.05 | ✅ 1.1.0 |
| [A.07 — Protocolo WebSocket bi18n](anexos/A.07_ANEXO-BI18N-PROTOCOLO-WEBSOCKET-v1.0.md) | **Tipo A:** especificación formal del protocolo WebSocket agnóstico de plataforma — URL Kong, handshake JWT, framing JSON-RPC 2.0 newline-delimited, tabla de métodos, códigos de error, requisito a11y, pseudocódigo neutro de sesión mínima. | 1.01 · A.04 · A.05 | ✅ 1.0.0 |
| [A.08 — Garantía de Cobertura de Librerías](anexos/A.08_ANEXO-BI18N-GARANTIA-LIBRERIAS-v1.0.md) | **Tipo V:** 19 librerías Categoría A, 13 Categoría B. Garantía formal de compilación. **Sub-anexos A.08.01–A.08.22:** inventario de exposición de las 22 librerías (función fuente → método RPC → estado ✅/📋/🔮/❌). | A.01 · REGISTRO Bloque 12 | ✅ 1.0.0 |
| [A.09 — bi18n como Servidor Canónico de Traducciones](anexos/A.09_ANEXO-BI18N-SERVIDOR-TRADUCCIONES-v1.0.md) | **Tipo A/G:** rol arquitectónico de bi18n como servidor único de traducciones de texto para todo SBOS. Locales soportados (BCP 47), estructura de archivos FTL, namespacing de claves por daemon, jerarquía de fallback de idioma, métodos RPC `bi18n.translate.*` (fluent-bundle) y `bi18n.i18n.*` (rust-i18n), contrato de consumo para daemons, integración con bglobal, cumplimiento normativo (BCP 47, CLDR, Ley 164). | 1.01 · A.06 · A.08.01 · A.08.02 | ✅ 1.0.0 |
| [A.08.01 — Inventario fluent-bundle 0.15.3](anexos/A.08.01_INVENTARIO-LIB-FLUENT-BUNDLE-v1.0.md) | **Inventario de exposición:** 6 métodos RPC Fase 2 (✅/📋/🔮/❌). Handler: `lib_fluent.rs`. Fuente: cargo registry. | A.08 · REGISTRO Bloque A | ✅ 1.0.0 |
| [A.08.02 — Inventario rust-i18n 4.x](anexos/A.08.02_INVENTARIO-LIB-RUST-I18N-v1.0.md) | **Inventario de exposición:** 4 métodos RPC Fase 2. Handler: `lib_rust_i18n.rs`. Macros compile-time ❌. | A.08 · REGISTRO Bloque B | ✅ 1.0.0 |
| [A.08.03 — Inventario icu_datetime 2.2.0](anexos/A.08.03_INVENTARIO-LIB-ICU-DATETIME-v1.0.md) | **Inventario de exposición:** 6 métodos RPC Fase 2. Handler: `lib_icu_datetime.rs`. API 2.x field-sets. | A.08 · REGISTRO Bloque D | ✅ 1.0.0 |
| [A.08.04 — Inventario icu_locale_core + icu_locale 2.2.0](anexos/A.08.04_INVENTARIO-LIB-ICU-LOCALE-v1.0.md) | **Inventario de exposición:** 4 métodos RPC Fase 2. Handler: `lib_icu_locale.rs`. ⚠️ `LocaleCanonicalizer` no `Locale::canonicalize`. | A.08 · REGISTRO Bloque E | ✅ 1.0.0 |
| [A.08.05 — Inventario icu_decimal 2.2.0](anexos/A.08.05_INVENTARIO-LIB-ICU-DECIMAL-v1.0.md) | **Inventario de exposición:** 4 métodos RPC Fase 2 (GroupingStrategy). Handler: `lib_icu_decimal.rs`. ⚠️ Sin CompactDecimalFormatter. | A.08 · REGISTRO Bloque F | ✅ 1.0.0 |
| [A.08.06 — Inventario validator 0.19.0](anexos/A.08.06_INVENTARIO-LIB-VALIDATOR-v1.0.md) | **Inventario de exposición:** 12 métodos RPC Fase 2. Handler: `lib_validator.rs`. ⚠️ API 0.19: traits, no funciones libres. | A.08 · REGISTRO Bloque G | ✅ 1.0.0 |
| [A.08.07 — Inventario scrutiny 0.1.2](anexos/A.08.07_INVENTARIO-LIB-SCRUTINY-v1.0.md) | **Inventario de exposición:** 6 métodos RPC Fase 2 + 35 funciones 🔮 Futuro. Handler: `lib_scrutiny.rs`. | A.08 · REGISTRO Bloque H | ✅ 1.0.0 |
| [A.08.08 — Inventario mask-pii 0.2.0](anexos/A.08.08_INVENTARIO-LIB-MASK-PII-v1.0.md) | **Inventario de exposición:** 4 métodos RPC Fase 2. Handler: `lib_mask_pii.rs`. ⚠️ FIX P1: mask.rs:81. | A.08 · REGISTRO Bloque I | ✅ 1.0.0 |
| [A.08.09 — Inventario universal_mask 0.1.0](anexos/A.08.09_INVENTARIO-LIB-UNIVERSAL-MASK-v1.0.md) | **Inventario de exposición:** 5 métodos RPC Fase 2. Handler: `lib_universal_mask.rs`. Una sola función pública `mask()`. | A.08 · REGISTRO Bloque J | ✅ 1.0.0 |
| [A.08.10 — Inventario jiff 0.2.32](anexos/A.08.10_INVENTARIO-LIB-JIFF-v1.0.md) | **Inventario de exposición:** 18 métodos RPC Fase 2. Handler: `lib_jiff.rs`. ⚠️ `strptime` no `parse`. DST-aware. | A.08 · REGISTRO Bloque K | ✅ 1.0.0 |
| [A.08.11 — Inventario chrono 0.4.45](anexos/A.08.11_INVENTARIO-LIB-CHRONO-v1.0.md) | **Inventario de exposición:** 15 métodos RPC Fase 2. Handler: `lib_chrono.rs`. strftime + RFC3339 + localized. | A.08 · REGISTRO Bloque L | ✅ 1.0.0 |
| [A.08.12 — Inventario regex 1.13.1](anexos/A.08.12_INVENTARIO-LIB-REGEX-v1.0.md) | **Inventario de exposición:** 6 métodos RPC Fase 2. Handler: `lib_regex.rs`. Cachear compilaciones. | A.08 · REGISTRO Bloque M | ✅ 1.0.0 |
| [A.08.13 — Inventario phonenumber 0.3.10](anexos/A.08.13_INVENTARIO-LIB-PHONENUMBER-v1.0.md) | **Inventario de exposición:** 8 métodos RPC Fase 2 + 1 Fase 1 ya impl. Handler: `lib_phonenumber.rs`. ⚠️ `Type` no `PhoneNumberType`. | A.08 · REGISTRO Bloque N | ✅ 1.0.0 |
| [A.08.14 — Inventario prism3-core 0.2.0](anexos/A.08.14_INVENTARIO-LIB-PRISM3-v1.0.md) | **Inventario de exposición:** 12 métodos RPC Fase 2. Handler: `lib_prism3.rs`. Guards/precondiciones. | A.08 · REGISTRO Bloque Ω | ✅ 1.0.0 |
| [A.08.15 — Inventario validy 1.2.4](anexos/A.08.15_INVENTARIO-LIB-VALIDY-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — infra interna exclusiva. Derive macros Validate + Modificate. | A.08 · REGISTRO Bloque Ω | ✅ 1.0.0 |
| [A.08.16 — Inventario valida 1.1.2](anexos/A.08.16_INVENTARIO-LIB-VALIDA-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — infra interna exclusiva. RulesBuilder + i18n errors. | A.08 · REGISTRO Bloque Ω | ✅ 1.0.0 |
| [A.08.17 — Inventario clipass_rs 0.1.0](anexos/A.08.17_INVENTARIO-LIB-CLIPASS-RS-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — uso exclusivo en `bi18nctl` CLI. ⚠️ Sin `read_password`/`verify_hash` libres. | A.08 · REGISTRO Bloque Ω | ✅ 1.0.0 |
| [A.08.18 — Inventario arc-swap 1.9.2](anexos/A.08.18_INVENTARIO-LIB-ARC-SWAP-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — infra interna ya implementada Fase 1 (`c92e20b`). | A.08 · Fase 1 | ✅ 1.0.0 |
| [A.08.19 — Inventario notify 6.1.1](anexos/A.08.19_INVENTARIO-LIB-NOTIFY-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — infra interna ya implementada Fase 1 (`c92e20b`). | A.08 · Fase 1 | ✅ 1.0.0 |
| [A.08.20 — Inventario shakehand 0.1.3](anexos/A.08.20_INVENTARIO-LIB-SHAKEHAND-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — proc-macro compile-time puro. | A.08 · REGISTRO Bloque C | ✅ 1.0.0 |
| [A.08.21 — Inventario veil 0.3.0](anexos/A.08.21_INVENTARIO-LIB-VEIL-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — derive macro de redacción en logs (ISO 27001 A.8.15). | A.08 · REGISTRO Bloque C | ✅ 1.0.0 |
| [A.08.22 — Inventario serde_with 3.21.0](anexos/A.08.22_INVENTARIO-LIB-SERDE-WITH-v1.0.md) | **Inventario de exposición:** 0 métodos RPC — adaptadores de serialización serde. `#[serde_as]` + `TimestampSeconds`. | A.08 · REGISTRO Bloque C | ✅ 1.0.0 |
| [**A.10 — Inventario API y Librerías v3.0**](anexos/A.10_INVENTARIO-API-LIBRERIAS-v3.0.md) | **Tipo R:** referencia completa de API de las 23 librerías con firmas reales del cargo registry. Fuente de verdad de parámetros y tipos para handlers y CLI. | 1.03 · 1.04 · A.08 | ✅ 3.0.0 |
| [**A.11 — Batería de Pruebas CLI (bi18nctl)**](anexos/A.11_ANEXO-BATERIA-PRUEBAS-CLI-v1.0.md) | **Tipo T:** batería completa de pruebas para los 126 métodos RPC via `bi18nctl`. 261 casos de prueba (TC-CLI-001 a TC-CLI-E03). Destinada al Agente Testeador. | 1.03 · A.08 | ✅ 1.0.0 |
| [**A.12 — Batería de Pruebas Frontend/WebSocket**](anexos/A.12_ANEXO-BATERIA-PRUEBAS-FRONTEND-v1.0.md) | **Tipo T:** batería completa de pruebas para los 126 métodos RPC via WebSocket JSON-RPC 2.0 (websocat). Incluye pruebas de push events y errores de protocolo. Destinada al Agente Testeador. | 1.04 · A.07 · A.09 | ✅ 1.0.0 |
| [**A.13 — Listado de Métodos por Librería**](anexos/A.13_LISTADO-METODOS-LIBRERIAS-v1.0.md) | **Tipo R:** listado unificado de métodos y funciones públicas de las 23 librerías (fluent-bundle, rust-i18n, regex, jiff, chrono, validator, scrutiny, etc.) con estado de verificación (🟢/🟡/🔴). Complementa A.10 con una vista más compacta. | 1.03 · 1.04 · A.10 | ✅ 1.0.0 |

---

## Código

| Componente | Ubicación | Estado |
|---|---|---|
| Crate `i18n-orchestrator` | `src/` | ✅ Implementado — Fase 1 (Bloques 1-12) + Fase 2 (14 handlers A.08.01–A.08.14, 103 RPC) |
| Daemon `bi18nd` | `src/main.rs` | ✅ preflight + sd_notify + watchdog + SIGHUP |
| CLI `bi18nctl` | `src/bin/bi18nctl.rs` | ✅ Subcomandos Fase 1 + 10 namespaces Fase 2 + `Admin` (clipass_rs) + `Translations` local |
| Reglas Bolivia | `country-rules/bo.toml` | ✅ Completo — 7 documentos, 14 enums |
| Reglas Argentina | `country-rules/ar.toml` | ✅ Completo — 5 documentos, 16 enums (Bloque 7) |
| Reglas Brasil | `country-rules/br.toml` | ✅ Nuevo — 6 documentos, 16 enums pt-BR (Bloque 7) |
| Unit systemd | `deploy/bi18nd.service` | ✅ Type=notify, WatchdogSec=30, hardening ISO 27001 |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-16 | Índice inicial. Manual 1.01 v1.2.0, Anexos A.01 v2.1.0 + A.02 v1.0.0, GAPS v1.0.0. |
| 1.1.0 | 2026-07-16 | GAPS-BI18N actualizado a v2.0.0 (todos los gaps resueltos). Estado del índice actualizado a "lista para implementar". |
| 1.2.0 | 2026-07-16 | Interface Triple C11 incorporada. Manual 1.01 actualizado a v1.3.0. Nuevo Anexo A.03 (proto gRPC completo). CLAUDE.md actualizado de Interface Dual a Interface Triple. |
| 1.3.0 | 2026-07-17 | Bloques 1-7 implementados y commiteados (`83ceb80`). Sección Código actualizada con estado real. Nuevos anexos A.04 (ligadura frontend — metadata-driven binding + adapters), A.05 (cierre de 6 gaps: RTL, gobernanza, CI paridad, HA, a11y, SDKs), A.06 (daemon traducciones: Weblate + ArcSwap + reload_translations + gobernanza diferenciada). |
| 1.4.0 | 2026-07-17 | Principio agnóstico de plataforma aplicado sistemáticamente. A.04 v2.2.0: principio agregado al inicio, §5 desacoplado de Flutter, §9 reenmarcado como referencias. A.05 v1.2.0: §6 eliminada la tarea de crear SDKs (no es responsabilidad del daemon), reemplazada por especificación formal del protocolo WebSocket (A.07). Bloques 9/10/11 agregados al REGISTRO. |
| 1.5.0 | 2026-07-17 | REGISTRO corregido: Bloque 9 reescrito sin menciones de plataformas como tareas del daemon (WebSocket listener, `attr.*`, locale, rate limiting, A.07); 10.5 reescrito como requisito de contrato en A.07; nota redundante de 10.6 eliminada. Manual 1.01 actualizado a v1.4.0. A.07 registrado como pendiente en la tabla de anexos. |
| 1.6.0 | 2026-07-17 | Bloque 12 completado. Nuevo Manual 1.02 (manual de usuario completo). A.07 marcado ✅. Nuevo A.08 (garantía de librerías). BATERIA-PRUEBAS-TESTEADOR añadida al índice. REGISTRO marcado ✅ v1.1.0 cerrado. Estado del índice actualizado a "Bloques 1-12 completos". |
| 1.7.0 | 2026-07-17 | REGISTRO-ESTADO-DOS creado (Fase 2 en curso). 14 bloques para exposición completa de 23 librerías + servidor web de traducciones. Estado del índice actualizado a "Fase 2 EN CURSO". |
| 1.8.0 | 2026-07-17 | REGISTRO-ESTADO-DOS reescrito a v2.0.0 DEFINITIVO con datos verificados de 4 agentes. 108 métodos RPC nuevos (total 126) + 5 endpoints HTTP. API exhaustiva de las 23 librerías. |
| 1.9.0 | 2026-07-17 | Nuevo A.09 — bi18n como Servidor Canónico de Traducciones de Lenguajes: rol arquitectónico, estructura FTL, namespacing de claves, fallback de idioma, contrato de consumo para daemons, integración bglobal. |
| 2.0.0 | 2026-07-17 | PLAN-FASE-2-IMPLEMENTACION v1.0.0 — protocolo formal de trabajo: un anexo = una librería = un handler Rust. Mapa A.08.01–A.08.14 → 14 `lib_*.rs`, convención de naming, estructura del dispatcher, tabla de progreso. |
| 2.1.0 | 2026-07-17 | Fase 2 completa. Tabla de tracking REGISTRO-ESTADO-DOS actualizada (⏳→✅ con SHAs reales para los 15 bloques A-Ω). INDICE actualizado a v2.1.0 con estado "Fase 2 ✅". Recuentos corregidos: H scrutiny 4→6, I mask-pii 4→3, K jiff 18→17, L chrono 15→10. Total acumulado: 121 métodos RPC. |
| 2.2.0 | 2026-07-17 | Limpieza arquitectónica: servidor HTTP (puerto 9456) eliminado del plan. P4 redefinido como 4 métodos `bi18n.admin.*` por JSON-RPC sobre WebSocket existente — sin nuevo puerto, sin parser HTTP manual. REGISTRO-ESTADO-DOS y INDICE actualizados en consecuencia. |
| 2.3.0 | 2026-07-17 | P4 completo (`25973cc`): 4 métodos `bi18n.admin.*` implementados. Total acumulado: 125 RPC. Pendiente: P3 CLI (103 subcomandos bi18nctl). |
| 2.4.0 | 2026-07-18 | P4b completo (`75165d2`, `9fc8587`): auditoría namespace CLI al 100%, WebSocket push events, Bundle Prefetch. Total definitivo: **126 métodos RPC**. Documentación completa: nuevos manuales 1.03 (programador) y 1.04 (usuario programador); nuevos anexos A.10 (inventario API, renombrado de MANUAL-METODOS-LIBRERIAS-SBOS.md), A.11 (batería CLI completa: 261 TCs) y A.12 (batería Frontend completa: 204 TCs). |
