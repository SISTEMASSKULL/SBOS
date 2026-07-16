# Documentación Técnica — bi18n (i18n-orchestrator)

**Versión:** 1.2.0
**Mantenido por:** bauth-developer
**Última actualización:** 2026-07-16
**Estado:** Activo — diseño completo, gaps resueltos, Interface Triple C11 incorporada, implementación lista para iniciar

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
| 1.01 | [bi18n — Arquitectura del Orquestador](1.01_MANUAL-BI18N-ARQUITECTURA-v1.2.md) | [i18n-orchestrator-rust.md](../i18n-orchestrator-rust.md) · [1.07 Atributos](../../BauthAgent/context/Documentacion/1.07_MANUAL-ATRIBUTOS-v2.0.md) · [2.15 Motor Identidad](../../BauthAgent/context/Documentacion/2.15_MANUAL-MOTOR-IDENTIDAD-v1.0.md) | ✅ 1.3.0 |

---

## Registro de implementación

| Documento | Contenido | Estado |
|---|---|---|
| [REGISTRO-ESTADO-IMPLEMENTACION — Hoja de ruta accionable](REGISTRO-ESTADO-IMPLEMENTACION.md) | Inventario completo de pendientes por bloque de prioridad. Archivos exactos, criterio de done, checklist de sesión. Actualizar con ✅ al completar cada ítem. | 🔄 v1.0.0 activo |

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

---

## Código

| Componente | Ubicación | Estado |
|---|---|---|
| Crate `i18n-orchestrator` | `src/` | Diseño completo |
| Daemon `bi18nd` | `src/main.rs` | Diseño completo |
| CLI `i18nctl` | `src/bin/i18nctl.rs` | Diseño completo |
| Reglas Bolivia | `country-rules/bo.toml` | Diseño completo |

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-16 | Índice inicial. Manual 1.01 v1.2.0, Anexos A.01 v2.1.0 + A.02 v1.0.0, GAPS v1.0.0. |
| 1.1.0 | 2026-07-16 | GAPS-BI18N actualizado a v2.0.0 (todos los gaps resueltos). Estado del índice actualizado a "lista para implementar". |
| 1.2.0 | 2026-07-16 | Interface Triple C11 incorporada. Manual 1.01 actualizado a v1.3.0. Nuevo Anexo A.03 (proto gRPC completo). CLAUDE.md actualizado de Interface Dual a Interface Triple. |
