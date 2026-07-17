# Documentación Técnica — bi18n (i18n-orchestrator)

**Versión:** 1.5.0
**Mantenido por:** bauth-developer
**Última actualización:** 2026-07-17
**Estado:** Activo — Bloques 1-7 implementados y commiteados; Bloques 9-11 planificados (agnóstico de plataforma); A.04/A.05/A.06 incorporados y corregidos

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

---

## Registro de implementación

| Documento | Contenido | Estado |
|---|---|---|
| [REGISTRO-ESTADO-IMPLEMENTACION — Hoja de ruta accionable](REGISTRO-ESTADO-IMPLEMENTACION.md) | Inventario completo de pendientes por bloque de prioridad. Bloques 1-7 ✅ commiteados. Bloques 9-11 planificados (WebSocket agnóstico, gaps RTL/CI/HA/a11y/A.07, daemon traducciones). Archivos exactos, criterio de done, checklist de sesión. | 🔄 v1.1.0 activo |

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
| A.07 — Protocolo WebSocket bi18n *(pendiente — Bloque 10.6)* | **Tipo A:** especificación formal del protocolo WebSocket agnóstico de plataforma — URL Kong, handshake JWT, framing JSON-RPC 2.0 newline-delimited, tabla de métodos, códigos de error, requisito a11y, pseudocódigo neutro de sesión mínima. Permite a cualquier equipo implementar un cliente en cualquier lenguaje. | 1.01 · A.04 · A.05 | ⏳ pendiente |

---

## Código

| Componente | Ubicación | Estado |
|---|---|---|
| Crate `i18n-orchestrator` | `src/` | ✅ Implementado — Bloques 1-7 commiteados |
| Daemon `bi18nd` | `src/main.rs` | ✅ preflight + sd_notify + watchdog + SIGHUP |
| CLI `i18nctl` | `src/bin/i18nctl.rs` | ✅ 14 subcomandos JSON-RPC + flags globales |
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
