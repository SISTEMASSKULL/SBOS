# RETOMA-BAUTH-2026-07-05 — Sesión bauth-developer
## Estado completo al cierre · 2026-07-05 ~17:00 UTC

---

## 1. QUÉ SE ESTABA HACIENDO

**Objetivo principal:** Inicializar BnotifyAgent y planificar bChat (Rocket.Chat 8.5.0 personalizado
como super-app tipo WeChat, gobernado por SBOS, con bAuth reemplazando el Enterprise Edition).

**Contexto:** El usuario decidió reemplazar Mattermost por Rocket.Chat como herramienta de
mensajería/notificaciones. Rocket.Chat Community Edition es gratis pero no incluye funciones de
identidad avanzadas (LDAP role mapping, SAML, OAuth role assignment, auto-join channels) — bAuth
las reemplaza completamente.

---

## 2. PLAN APROBADO (valiant-coalescing-hippo)

Archivo: `/home/skull/.claude/plans/valiant-coalescing-hippo.md`

5 bloques:
- **Bloque A:** Inicializar BnotifyAgent (esqueleto Rust + docs de diseño)
- **Bloque B:** Actualizar ficha Rocket.Chat (v6.12 → v8.5.0, integración bAuth)
- **Bloque C:** Crear contrato bilateral BNOTIFY-BAUTH-CONTRATOS.md
- **Bloque D:** Eliminar TODAS las referencias a Mattermost (~15 archivos, 3 copias de ficha)
- **Bloque E:** Actualizar informe EVALUACION-INTEGRAL-BAUTH-2026-07-05.md

---

## 3. EN QUÉ BLOQUE NOS QUEDAMOS

**Etapa 0 — Cimientos. Bloque A (documentación) parcialmente completado.**

### Documentos creados en BnotifyAgent/context/ (3 archivos):

| Archivo | Versión | Contenido |
|---------|:-------:|-----------|
| `BNOTIFY-000-INDEX.md` | 2.0.0 | Índice de navegación. Estructura del proyecto, referencias externas, warnings |
| `BNOTIFY-001-VISION.md` | **3.0.0** | Visión corregida 3 veces. Estado final: bnotify = orquestador multi-canal, bChat = canal principal (Rocket.Chat 8.5.0), bAuth = OIDC Provider nativo, Keycloak = backup, REST API interna VETADA, Unix socket + JSON-RPC estándar |
| `BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT.md` | 2.0.0 | 6 etapas (0 a 5): Cimientos → Chat básico → Identidad gobernada → Negocio integrado → Super-app → Escala. ~56 entregables con criterios de salida |

### Decisiones arquitectónicas tomadas (3 correcciones mayores):

1. **bAuth ES el OIDC Provider nativo.** Verificado en código real (`oidc_provider.rs:4`: "Sin dependencia de Keycloak", `jwt_builder.rs:5-6`: "bAuth emite su PROPIO token"). Keycloak es solo backup. Dirección: eliminar dependencia KC.

2. **REST API interna VETADA.** Entre daemons SBOS solo Unix socket + JSON-RPC 2.0. REST solo hacia afuera (bChat no es daemon, no habla socket). bnotify es el ÚNICO puente autorizado hacia bChat REST API.

3. **bnotify es el orquestador, bChat es un canal.** Patrón event-driven multi-channel de la industria. bnotify = dispatcher central con 6 canales (bChat, Email, SMS, Push, In-App, Webhook). bChat es el principal (único bidireccional) pero es un canal, no el producto.

### Datos técnicos verificados (no inventados):

- Rocket.Chat Server: 8.5.0 (latest stable, mayo 2026). Node 22.16.0 + Deno 1.43.5 + MongoDB 8.0
- Rocket.Chat Desktop: 4.14.1. Android: 4.72.0
- MongoDB: dependencia OBLIGATORIA. Ficha `mongodb` ya existe en `servers/S01-dataserver/`
- bAuth: 165 archivos Rust, 58 handlers, OIDC Provider nativo funcionando
- BnotifyAgent: SOLO 2 archivos (CLAUDE.md, PROPOSITO.md). src/ y tests/ vacíos

---

## 4. ARCHIVOS MODIFICADOS (por esta sesión)

### Creados (6 archivos):
```
BnotifyAgent/context/BNOTIFY-000-INDEX.md
BnotifyAgent/context/BNOTIFY-001-VISION.md
BnotifyAgent/context/BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT.md
BauthAgent/context/BAUTH-ERRORES-INICIALIZACION-2026-07-05.md
BauthAgent/context/plandeaccion/REPARACIONBAUTH/EVALUACION-INTEGRAL-BAUTH-2026-07-05.md
BauthAgent/context/RETOMA-BAUTH-2026-07-05.md (este archivo)
```

### Modificados por el bibliotecario (no por esta sesión):
```
BauthAgent/CLAUDE.md   → actualizado con UUID proyecto, rutas de contratos, buzón
BosAgent/CLAUDE.md     → staff de fábrica, buzón bibliotecario
CLAUDE.md (SBOS)       → staff de fábrica, contracts/, buzon-bibliotecario/
paths.yml              → actualizado
```

---

## 5. PENDIENTE (próxima sesión)

### Etapa 0 — Entregables NO completados:

| ID | Entregable | Archivo |
|----|-----------|---------|
| E0.04 | Arquitectura del daemon bnotify | `BNOTIFY-ARQUITECTURA.md` |
| E0.05 | Integración bnotify↔bChat | `BNOTIFY-ROCKETCHAT-INTEGRACION.md` |
| E0.06 | Contrato bilateral | `context/contracts/BNOTIFY-BAUTH-CONTRATOS.md` |
| E0.07 | Ficha bChat v8.5.0 | `servers/S10-commsserver/bchat/manifest.yml` |
| E0.08 | Esqueleto Rust bnotify | `BnotifyAgent/src/main.rs` + `Cargo.toml` + `config/` + `server/` |
| E0.09 | PROPOSITO.md actualizado | `BnotifyAgent/PROPOSITO.md` |
| E0.10 | CLAUDE.md actualizado | `BnotifyAgent/CLAUDE.md` |
| E0.11 | Eliminar Mattermost | ~15 archivos en BauthAgent + 3 copias de ficha |

### Bloque D (Eliminar Mattermost) — Archivos a modificar:
- `BauthAgent/context/plandeaccion/BAUTH-CLASIFICACION-FUNCIONAL.md`
- `BauthAgent/context/plandeaccion/REGISTRO-ESTADO.md`
- `BauthAgent/context/plandeaccion/REPARACIONBAUTH/REGISTRO-ESTADO-BAUTH-PRINCIPAL.md`
- `BauthAgent/context/plandeaccion/BAUTH-CALENDAR-SUBSYSTEM.md`
- `BauthAgent/src/domain/notify_config.rs`
- `BauthAgent/context/MEMORIA-RECUPERADA-BAUTH-2026-06-29.md`
- `servers/S10-commsserver/mattermost/` (eliminar directorio)
- `BosAgent/src/servers/S06/mattermost/` (eliminar)
- `BosAgent/src/servers/S10/mattermost/` (eliminar)
- `BosAgent/staging/core/servers/commsserver/mattermost/` (eliminar)
- `servers/S06-appsserver/novu/manifest.yml` (quitar referencia)
- `servers/S06-appsserver/calcom/manifest.yml` (quitar referencia)

---

## 6. REGLA C12 ACTIVA — EVIDENCIA OBLIGATORIA

Toda afirmación verificable DEBE adjuntar evidencia con:
```bash
bash /opt/skull/orquestador/proyectos/fabrica/scripts/verificar_afirmacion.sh \
  'descripción' 'comando a ejecutar'
```

Sin comando ejecutado = sin afirmación.

---

## 7. ESTADO DEL COORDINADOR

- Coordinador: activo en `:8095`, 0 tareas en grafo
- UUID proyecto SBOS: `4c697f66-d204-45a5-ac36-c104f07c7046`
- 11 métodos JSON-RPC disponibles: `orquesta.coordinador.*`

---

## 8. CONTEXTO PARA RETOMA

Al iniciar sesión:
1. Leer este archivo (`context/RETOMA-BAUTH-2026-07-05.md`)
2. Leer `BNOTIFY-001-VISION.md` v3.0.0 — es la visión corregida
3. Leer `BNOTIFY-002-LAS-ETAPAS-RUMBO-A-WECHAT.md` v2.0.0 — es el roadmap
4. Continuar con entregables E0.04 a E0.11 de Etapa 0
5. Prioridad: Bloque D (eliminar Mattermost) + Bloque A (esqueleto Rust)
6. C12 obligatorio: ejecutar comando antes de afirmar

---

*Retoma escrita por bauth-developer · 2026-07-05 · BnotifyAgent y BauthAgent*
