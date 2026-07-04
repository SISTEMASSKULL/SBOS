# ESPECIFICACIÓN — Modales de Catálogo: Aplicación, Grupo Funcional, Verbo

**Versión:** 2.0.0 · **Fecha:** 2026-06-29 · **Autor:** sbos-coordinador
**Proyecto:** bAuthDEV + bAuth Desktop — Modales de selección/creación del árbol D1
**Objetivo:** Especificar los 3 modales que alimentan el árbol jerárquico D1 (Lógico)
**DDL verificada:** `DDL_skSBOS_db.sql` · Seeds: `seed_privilege_application.sql`,
  `seed_privilege_group.sql`, `seed_privilege_verb.sql`, `seed_privilege_atom.sql`

---

## 0. CORRESPONDENCIA DDL → CONCEPTO DE NEGOCIO

| Concepto UI | Tabla DDL real | PK | Campos |
|-------------|---------------|-----|--------|
| **Aplicación** | `bauth.privilege_application` | `app_code` SMALLINT (1-511) | `app_name` (64), `app_slug` (32), `tenant_id` (UUID), `active`, `registered_at` |
| **Grupo Funcional** (alias "Módulo") | `bauth.privilege_group` | `(app_code, group_code)` | `group_name` (128) |
| **Verbo** | `bauth.privilege_verb` | `verb_code` SMALLINT (1-255) | `verb_name` (32) UNIQUE, `verb_slug` (32) |
| **Átomo** | `bauth.privilege_atom` | `(app_code, group_code, atom_code)` | `atom_name` (255), `atom_slug` (255), `atom_position`, `domain_code`, `verb_code`, `contextual_mask`, `logical_mask` |
| **Zona** | `bauth.log_zone` | `zona_id` TEXT | `nombre`, `descripcion`, `categoria`, `ambito`, `es_critica`, `activo` |
| **Zona↔App** | `bauth.zone_application_map` | `(zone_id, app_code)` | `app_scopes`, `client_id`, `modules` (TEXT[]), `is_active` |

### Datos reales (desde seeds)

**12 aplicaciones:** Tryton, Keycloak, Kong, Vault, Cal.com, Mattermost, Novu, Grafana, Prometheus, Besu QBFT, MinIO, PostgreSQL

**48 grupos funcionales** (por app):
- Tryton: Contabilidad, Inventario, Ventas, Compras, Gestión de Tiempo, Proyectos, Administración, Punto de Venta, Calendario, Marketing (10)
- Keycloak: Admin Realm, Admin Clientes, Admin Usuarios, Proveedor Identidad, Auditor (5)
- Kong: Administrador, Desarrollador, Consumidor, Monitor (4)
- Vault: Administrador, Operador, Auditor, App Role (4)
- Cal.com: Admin Calendario, Usuario Calendario, Visualizador Agenda (3)
- Mattermost: Admin Canal, Usuario, Auditor (3)
- Novu: Admin Workflows, Gestor Suscriptores, Visualizador (3)
- Grafana: Editor, Viewer, Admin (3)
- Prometheus: Administrador, Operador, Viewer (3)
- Besu QBFT: Validador, Usuario RPC, Auditor (3)
- MinIO: Administrador, Lectura/Escritura, Solo Lectura (3)
- PostgreSQL: Superusuario, Lectura/Escritura, Solo Lectura, Replicador (4)

**50 verbos:** create/nuevo, update/editar, delete/eliminar, read/ver, print/imprimir, lock/bloquear, unlock/desbloquear, check/verificar, post/contabilizar, release/liberar, undo_release/deshacer_liberar, complete/completar, reverse/reversar, execute/ejecutar, approve/aprobar, reject/rechazar, block_entity/bloquear_entidad, unblock_entity/desbloquear_entidad, archive/archivar, copy/copiar, save/guardar, submit/enviar, transfer/transferir, close/cerrar, reopen/reabrir, display_totals/ver_totales, display_items/ver_partidas, settle_rule/liquidar_regla, settle_params/param_liq, duplicate/duplicar, export/exportar, import/importar, reconcile/conciliar, validate/validar, void/anular, draft/borrador, confirm/confirmar, assign/asignar, share/compartir, append/anexar, append_to/ser_anexado, schedule/programar, delegate/delegar, impersonate/suplantar, notify/notificar, configure/configurar, schedule_task/programar_tarea, delegate_access/delegar_acceso, impersonate_user/suplantar_usuario, emergency_access/acceso_emergencia

---

## 1. FLUJO DE INTERACCIÓN

```
ÁRBOL D1 (Editor de Rol)
  │
  ├── Zona (ej: AREA-CAJA) [catálogo: log_zone, 29 zonas]
  │     │
  │     ├── [➕ Agregar Aplicación]  ──→  MODAL APLICACIONES (12 reales)
  │     │     ├── [Seleccionar] → cierra, app + sus grupos se integran al árbol
  │     │     └── [Crear]       →  MODAL CREAR APLICACIÓN
  │     │
  │     └── 📱 Tryton (app_code=1)
  │           │
  │           ├── [➕ Agregar Grupo]  ──→  MODAL GRUPOS (filtrado por app)
  │           │     ├── [Seleccionar] → cierra, grupo se integra al árbol
  │           │     └── [Crear]       →  MODAL CREAR GRUPO
  │           │
  │           └── 📦 Punto de Venta (group_code=8)
  │                 │
  │                 ├── [➕ Agregar Verbo]  ──→  MODAL VERBOS (50 disponibles)
  │                 │     ├── [Seleccionar] → cierra, verbo → átomo creado
  │                 │     └── [Crear]       →  MODAL CREAR VERBO
  │                 │
  │                 └── ☑ ver (read, verb_code=4) → átomo: tryton.8.4
```

---

## 2. REGLAS GENERALES DE LOS 3 MODALES

| Regla | Detalle |
|-------|---------|
| **Ancho** | 600px (lista) / 520px (crear) |
| **Alto** | Máximo 70vh, scroll interno si excede |
| **Fondo** | Overlay oscuro `rgba(0,0,0,0.6)` |
| **Header** | Título + contador "X disponibles" + ✕ cerrar |
| **Buscar** | Input con filtro en vivo |
| **Lista** | Radio buttons (selección única) con nombre, slug/descripción |
| **Footer** | [Seleccionar] (primario) + [Crear nuevo] (secundario) |
| **Teclado** | `↑↓` navegar, `Enter` seleccionar, `Esc` cerrar, `Ctrl+N` crear |
| **Estado empty** | "No hay X disponibles. [Crear el primero]" |
| **Estado loading** | Skeleton de 5 filas grises pulsantes |

---

## 3. MODAL — SELECCIÓN DE APLICACIÓN

### 3.1 Lista de Aplicaciones (12 reales)

```
┌── 📱 SELECCIONAR APLICACIÓN — 12 disponibles ──────────────────┐
│                                                                │
│  🔍 [Buscar aplicación...___________________________________]   │
│  ────────────────────────────────────────────────────────────  │
│                                                                │
│  ○ Tryton (tryton)                                             │
│    ERP completo — 10 grupos: Contabilidad, Ventas, Inventario  │
│                                                                │
│  ○ Keycloak (keycloak)                                         │
│    Identity Provider — 5 grupos: Admin Realm, Clientes, Users │
│                                                                │
│  ○ Kong (kong)                                                 │
│    API Gateway — 4 grupos: Admin, Dev, Consumidor, Monitor    │
│                                                                │
│  ○ Vault (vault)                                               │
│    Secret Management — 4 grupos: Admin, Operador, Auditor     │
│                                                                │
│  ○ Grafana (grafana)                                           │
│    Dashboards — 3 grupos: Editor, Viewer, Admin               │
│                                                                │
│  ○ Besu QBFT (besu)                                            │
│    Blockchain permissioned — 3 grupos: Validador, RPC, Auditor│
│                                                                │
│  ─── 12 aplicaciones ─────────────────────────────────────────  │
│                                                                │
│  [CANCELAR]                       [➕ CREAR NUEVA] [SELECCIONAR] │
└────────────────────────────────────────────────────────────────┘
```

### 3.2 Formulario — Crear Aplicación

```
┌── 📱 NUEVA APLICACIÓN ───────────────────────────────────────┐
│                                                              │
│  Nombre *                                                    │
│  [___Mi Sistema de Facturación____________________________]  │
│  ⓘ Máximo 64 caracteres                                     │
│                                                              │
│  Slug *                                                      │
│  [___mi_facturacion______________________________________]   │
│  ⓘ minúsculas, snake_case, máx 32 chars.                    │
│    Único dentro del tenant. Define átomos:                   │
│    mi_facturacion.{grupo}.{verbo}                            │
│                                                              │
│  Código *                                                    │
│  [___13_________________]  ⓘ 1-511, debe ser ÚNICO          │
│                                                              │
│  Tenant *                                                    │
│  [skull ▼]  ⓘ Tenant al que pertenece esta app              │
│                                                              │
│  ☑ Activo (disponible para asignar en zonas y roles)         │
│                                                              │
│  ⚠ Al crear la app no se generan grupos ni átomos.           │
│    Debes crear los grupos funcionales manualmente.           │
│                                                              │
│  [CANCELAR]                    [📱 CREAR APLICACIÓN]        │
└──────────────────────────────────────────────────────────────┘

CAMPOS (según DDL privilege_application):
┌──────────────────────┬──────────┬───────┬────────────────────────────────────┐
│ Campo                │ Tipo     │ Req   │ Validación                         │
├──────────────────────┼──────────┼───────┼────────────────────────────────────┤
│ app_name             │ text     │ SI    │ max 64 chars                       │
│ app_slug             │ text     │ SI    │ regex: ^[a-z][a-z0-9_]{1,31}$      │
│                      │          │       │ ÚNICO por (tenant_id, app_slug)     │
│ app_code             │ number   │ SI    │ 1-511, ÚNICO global (PK)           │
│ tenant_id            │ select   │ SI    │ UUID del tenant actual             │
│ active               │ checkbox │ —     │ default: ☑                         │
│ registered_at        │ hidden   │ —     │ auto: NOW()                        │
└──────────────────────┴──────────┴───────┴────────────────────────────────────┘
```

---

## 4. MODAL — SELECCIÓN DE GRUPO FUNCIONAL

### 4.1 Lista de Grupos (filtrada por aplicación)

```
┌── 📦 SELECCIONAR GRUPO — Tryton · 10 disponibles ───────────────┐
│  App: Tryton (app_code=1)                                       │
│  ──────────────────────────────────────────────────────────────  │
│                                                                 │
│  🔍 [Buscar grupo...________________________________________]   │
│  ─────────────────────────────────────────────────────────────  │
│                                                                 │
│  ○ Contabilidad (group_code=1)                                  │
│  ○ Inventario (group_code=2)                                    │
│  ○ Ventas (group_code=3)                                        │
│  ○ Compras (group_code=4)                                       │
│  ○ Gestión de Tiempo (group_code=5)                             │
│  ○ Proyectos (group_code=6)                                     │
│  ○ Administración (group_code=7)                                │
│  ○ Punto de Venta (group_code=8)                                │
│  ○ Calendario (group_code=9)                                    │
│  ○ Marketing (group_code=10)                                    │
│                                                                 │
│  ─── 10 grupos ──────────────────────────────────────────────── │
│                                                                 │
│  [CANCELAR]                        [➕ CREAR NUEVO] [SELECCIONAR] │
└─────────────────────────────────────────────────────────────────┘
```

### 4.2 Formulario — Crear Grupo Funcional

```
┌── 📦 NUEVO GRUPO FUNCIONAL — para Tryton ──────────────────────┐
│  App: Tryton (app_code=1)                                      │
│  ─────────────────────────────────────────────────────────────  │
│                                                                │
│  Nombre del grupo *                                            │
│  [___Notificaciones Automáticas_____________________________]  │
│  ⓘ Máximo 128 caracteres. Nombre descriptivo.                 │
│                                                                │
│  Código del grupo *                                            │
│  [___11_________________]  ⓘ 1-2047, ÚNICO dentro de esta app │
│                                                                │
│  ⚠ Al crear el grupo no se generan átomos automáticamente.     │
│    Debes agregar verbos manualmente desde el árbol.            │
│                                                                │
│  [CANCELAR]                     [📦 CREAR GRUPO]               │
└────────────────────────────────────────────────────────────────┘

CAMPOS (según DDL privilege_group):
┌──────────────────────┬──────────┬───────┬────────────────────────────────────┐
│ Campo                │ Tipo     │ Req   │ Validación                         │
├──────────────────────┼──────────┼───────┼────────────────────────────────────┤
│ app_code             │ hidden   │ —     │ heredado del contexto (app padre)  │
│ group_name           │ text     │ SI    │ max 128 chars                      │
│ group_code           │ number   │ SI    │ 1-2047, ÚNICO por (app_code)       │
│                      │          │       │ (PK es compuesta: app_code+group_code) │
└──────────────────────┴──────────┴───────┴────────────────────────────────────┘
```

---

## 5. MODAL — SELECCIÓN DE VERBO

### 5.1 Lista de Verbos (50 disponibles)

```
┌── ✏ SELECCIONAR VERBO — Tryton › Punto de Venta · 50 disponibles ─┐
│  App: Tryton (1) · Grupo: Punto de Venta (8)                       │
│  ─────────────────────────────────────────────────────────────────  │
│                                                                    │
│  🔍 [Buscar verbo...___________________________________________]   │
│  ────────────────────────────────────────────────────────────────  │
│                                                                    │
│  ─── CRUD BASE (1-4) ───                                          │
│  ○ crear     (create, 1)     ★                                     │
│  ○ editar    (update, 2)     ★                                     │
│  ○ eliminar  (delete, 3)                                          │
│  ○ ver       (read, 4)       ★                                     │
│                                                                    │
│  ─── ACCIONES DE NEGOCIO (5-29) ───                                │
│  ○ imprimir       (print, 5)        ○ bloquear     (lock, 6)       │
│  ○ desbloquear    (unlock, 7)       ○ verificar    (check, 8)      │
│  ○ contabilizar   (post, 9)         ○ liberar      (release, 10)   │
│  ○ completar      (complete, 12)    ○ reversar     (reverse, 13)   │
│  ○ ejecutar       (execute, 14)     ○ aprobar      (approve, 15)   │
│  ○ rechazar       (reject, 16)      ○ archivar     (archive, 19)   │
│  ○ copiar         (copy, 20)        ○ guardar      (save, 21)      │
│  ○ enviar         (submit, 22)      ○ transferir   (transfer, 23)  │
│  ○ cerrar         (close, 24)       ○ reabrir      (reopen, 25)    │
│  ○ ver totales    (display_totals, 26)                             │
│  ○ ver partidas   (display_items, 27)                              │
│  ○ liquidar regla (settle_rule, 28)                                │
│                                                                    │
│  ─── EXTENDIDOS (30-46) ───                                       │
│  ○ duplicar  (30)  ○ exportar  (31)  ○ importar    (32)           │
│  ○ conciliar (33)  ○ validar   (34)  ○ anular      (35)           │
│  ○ borrador  (36)  ○ confirmar (37)  ○ asignar     (38)           │
│  ○ compartir (39)  ○ anexar    (40)  ○ programar   (42)           │
│  ○ delegar   (43)  ○ notificar (45)  ○ configurar  (46)           │
│                                                                    │
│  ─── ESPECIALES (47-50) ───                                       │
│  ○ programar tarea (47)    ○ delegar acceso (48)                  │
│  ○ suplantar usuario (49)  ○ acceso emergencia (50)               │
│                                                                    │
│  ─── 50 verbos ──────────────────────────────────────────────────  │
│  ⓘ Al seleccionar un verbo se crea 1 átomo:                       │
│    {app_slug}.{group_code}.{verb_code}                            │
│    Ej: tryton.8.4 → "tryton.Punto de Venta.ver"                   │
│                                                                    │
│  [CANCELAR]                         [➕ CREAR NUEVO] [SELECCIONAR]  │
└────────────────────────────────────────────────────────────────────┘
```

### 5.2 Formulario — Crear Verbo

```
┌── ✏ NUEVO VERBO ───────────────────────────────────────────────┐
│                                                                │
│  Nombre (en) *              Slug (es) *                        │
│  [___generate_report____]   [___generar_reporte_____________]  │
│  ⓘ Máx 32 chars c/u       ⓘ Máx 32 chars, minúsculas,        │
│    Debe ser ÚNICO             snake_case                       │
│                                                                │
│  Código *                                                      │
│  [___51________________]  ⓘ 1-255. Debe ser ÚNICO.            │
│    Códigos 1-50 ya están ocupados por el catálogo estándar.    │
│    Sugerencia: usar 51+ para verbos personalizados.            │
│                                                                │
│  ⚠ Los verbos son GLOBALES (no por app).                       │
│    Una vez creado, cualquier app/grupo puede usarlo.           │
│                                                                │
│  ⚠ Al crear el verbo y seleccionarlo, se generará 1 átomo:     │
│    tryton.8.51 → atom_position asignada del catálogo global    │
│                                                                │
│  [CANCELAR]                       [✏ CREAR VERBO]             │
└────────────────────────────────────────────────────────────────┘

CAMPOS (según DDL privilege_verb):
┌──────────────────────┬──────────┬───────┬────────────────────────────────────┐
│ Campo                │ Tipo     │ Req   │ Validación                         │
├──────────────────────┼──────────┼───────┼────────────────────────────────────┤
│ verb_name            │ text     │ SI    │ max 32 chars, ÚNICO global         │
│ verb_slug            │ text     │ SI    │ regex: ^[a-z][a-z0-9_]{1,31}$      │
│ verb_code            │ number   │ SI    │ 1-255, ÚNICO global (PK)           │
│                      │          │       │ 1-50 reservados (catálogo estándar) │
└──────────────────────┴──────────┴───────┴────────────────────────────────────┘
```

---

## 6. GENERACIÓN DE ÁTOMOS

Cuando se selecciona un verbo en un grupo de una app, se crea automáticamente un átomo en `privilege_atom`:

```
VERBO SELECCIONADO: read (verb_code=4)
EN APP: Tryton (app_code=1)
EN GRUPO: Punto de Venta (group_code=8)

→ ÁTOMO GENERADO:
  atom_code:      5809          (siguiente disponible, auto-incremental)
  app_code:       1
  group_code:     8
  domain_code:    1             (D1 Lógico, heredado de la zona)
  verb_code:      4
  atom_name:      "tryton.Punto de Venta.ver"
  atom_slug:      "tryton.8.4"
  atom_position:  5809          (siguiente posición en el RolBitMask)
  contextual_mask: {calculado}   (8 device_allowed|1 domain|1 app|8 group)
  logical_mask:    {calculado}   (3 trust|2 token|1 blk|2 policy|24 verb)

ATOM_SLUG CANÓNICO: "{app_slug}.{group_code}.{verb_code}"
Ejemplos:
  tryton.1.4       → Contabilidad.ver
  tryton.3.15      → Ventas.aprobar
  keycloak.1.46    → Admin Realm.configurar
  grafana.2.4      → Viewer.ver
  besu.1.14        → Validador.ejecutar
```

---

## 7. REGLAS DE NEGOCIO

| # | Regla | Detalle |
|---|-------|---------|
| R1 | **Verbos son globales** | `privilege_verb` no depende de app ni grupo. Los 50 existentes aplican a cualquier app. |
| R2 | **Grupos son por app** | `privilege_group` tiene PK compuesta (app_code, group_code). Mismo group_code puede repetirse en distintas apps. |
| R3 | **Apps son por tenant** | `privilege_application.app_slug` es único por (tenant_id, app_slug). |
| R4 | **atom_slug canónico** | `{app_slug}.{group_code}.{verb_code}` — ej: `tryton.8.4` |
| R5 | **atom_position secuencial** | Cada átomo recibe la siguiente posición disponible (~5809 actualmente). |
| R6 | **Códigos 1-50 de verbo reservados** | No se pueden modificar ni eliminar. Nuevos verbos deben usar código 51+. |
| R7 | **Catálogo inmutable** | No se eliminan apps/grupos/verbos. Soft-delete solo si no hay átomos dependientes activos en roles publicados. |
| R8 | **Zona↔App vía zone_application_map** | Una app solo aparece en el árbol si está mapeada a la zona actual. El campo `modules` (TEXT[]) filtra grupos visibles. |

---

## 8. GUÍA PARA CLAUDE DESIGN — Cómo NO confundirse

> **⚠️ LEE ESTO PRIMERO.** Claude Design tiende a olvidar partes de especificaciones complejas.
> Esta sección es la más importante del documento.

### 8.1 Checklist de verificación

Antes de generar cualquier HTML, verifica:

- [ ] El modal de SELECCIÓN tiene **radio buttons** (○), no checkboxes (☑). Solo se puede elegir UN item.
- [ ] El modal tiene exactamente **DOS botones** en el footer: [Seleccionar] + [Crear nuevo]
- [ ] El botón [Seleccionar] está a la DERECHA (acción primaria, color accent)
- [ ] El botón [Crear nuevo] está a la IZQUIERDA del [Seleccionar] (acción secundaria, estilo ghost)
- [ ] El modal de CREAR tiene los campos exactos de la DDL, sin inventar campos extra
- [ ] El formulario de crear app NO incluye campos que no existen en `privilege_application`
- [ ] El formulario de crear grupo (módulo) NO incluye `group_slug` (no existe en la DDL)
- [ ] El formulario de crear verbo NO incluye `description` (no existe en `privilege_verb`)
- [ ] Los nombres de apps son los 12 REALES del seed, no inventados
- [ ] Los verbos son los 50 REALES del seed, no 8 inventados
- [ ] El atom_slug se muestra en formato `{app_slug}.{group_code}.{verb_code}` (ej: `tryton.8.4`)
- [ ] Cada modal muestra el contexto (app padre, grupo padre) en el header

### 8.2 Jerarquía de creación (NUNCA mezclar)

```
Zona (log_zone) → Aplicación (privilege_application) → Grupo (privilege_group) → Verbo (privilege_verb)
                                                             ↑                            ↑
                                                         "Módulo" en UI             50 verbos reales
                                                         48 grupos reales           NO inventar verbos
```

### 8.3 Do's and Don'ts

| ✅ DO | ❌ DON'T |
|------|---------|
| Usar los 12 nombres reales: Tryton, Keycloak, Kong, Vault, Cal.com, Mattermost, Novu, Grafana, Prometheus, Besu QBFT, MinIO, PostgreSQL | Inventar aplicaciones como "OrangeHRM", "Saleor" (no existen en el seed) |
| Usar los 50 verbos reales: create/nuevo(1), update/editar(2), delete/eliminar(3), read/ver(4)... | Inventar solo 8 verbos (hay 50) |
| Mostrar `group_code` como identificador (es numérico: 1-2047) | Inventar un `group_slug` (no existe en la tabla) |
| atom_slug = `{app_slug}.{group_code}.{verb_code}` | `{app}.{modulo}.{verbo}` con nombres inventados |
| Campos de app: app_code, app_name(64), app_slug(32), tenant_id, active | Agregar description, url, icon, domain_code (no existen en DDL) |
| Campos de grupo: app_code, group_code, group_name(128) | Agregar group_slug, description (no existen) |
| Campos de verbo: verb_code, verb_name(32), verb_slug(32) | Agregar description (no existe) |
| Deshabilitar códigos 1-50 en el form de crear verbo (son reservados) | Permitir cualquier código en verbo nuevo |
| El modal de crear verbo sugiere código 51+ | Sugerir códigos ya ocupados |

### 8.4 Prompt Guide — Orden de generación

```
1. PRIMERO el modal de SELECCIÓN DE APLICACIÓN:
   - 12 apps reales con radio buttons
   - Cada una muestra: nombre, slug entre paréntesis, grupos disponibles
   - Footer: [Cancelar] [➕ Crear nueva] [Seleccionar]

2. LUEGO el modal de CREAR APLICACIÓN:
   - Solo 5 campos (app_name, app_slug, app_code, tenant_id, active)
   - SIN description, url, icon, domain_code

3. DESPUÉS el modal de SELECCIÓN DE GRUPO (filtrado por app):
   - Título: "Seleccionar Grupo — Tryton · 10 disponibles"
   - Mostrar group_code entre paréntesis

4. LUEGO el modal de CREAR GRUPO:
   - Solo 2 campos editables (group_name, group_code)
   - SIN group_slug

5. DESPUÉS el modal de SELECCIÓN DE VERBO:
   - 50 verbos en lista con scroll
   - Agrupados: CRUD (1-4) / Negocio (5-29) / Extendidos (30-46) / Especiales (47-50)

6. FINALMENTE el modal de CREAR VERBO:
   - Solo 3 campos (verb_name, verb_slug, verb_code)
   - Códigos 1-50 deshabilitados visualmente (ya ocupados)
   - Sugerir código 51 por defecto
```

### 8.5 Datos reales (verificados en VPS 13.140.128.230:15432)

| Tabla | Registros | NO inventar |
|-------|:---:|------|
| privilege_application | 12 | Tryton, Keycloak, Kong, Vault, Cal.com, Mattermost, Novu, Grafana, Prometheus, Besu QBFT, MinIO, PostgreSQL |
| privilege_group | 48 | 10 Tryton + 5 Keycloak + 4 Kong + 4 Vault + 3 Cal.com + ... |
| privilege_verb | 50 | 4 CRUD + 25 negocio + 17 extendidos + 4 especiales |
| privilege_atom | 5,808 | atom_slug = `{app}.{group_code}.{verb_code}` |

### 8.6 Ubicación en la UI — Dónde van estos modales

> **⚠️ IMPORTANTE PARA CLAUDE DESIGN:** Los modales de Aplicación, Grupo y Verbo se acceden desde la
> opción **"Aplicaciones"** del menú lateral izquierdo.

```
Menú Lateral Izquierdo (Left Sidebar — bAuth Desktop):
  │
  ├── 📊 Dashboard
  ├── 👥 Roles
  ├── 👤 Usuarios
  ├── 🛡️ Políticas
  ├── 📱 Aplicaciones              ← ★ AQUÍ se accede a Apps/Grupos/Verbos
  │     ├── 📄 Aplicaciones         ← Lista de 12 apps (privilege_application)
  │     ├── 📦 Grupos Funcionales   ← Lista de 48 grupos (privilege_group)
  │     └── ✏ Verbos               ← Lista de 50 verbos (privilege_verb)
  ├── 🔄 Sincronización
  ├── 📊 Auditoría
  └── ...
```

**Comportamiento al hacer click en "Aplicaciones":**
1. Se abre una vista con **3 tabs/pestañas**: Aplicaciones | Grupos Funcionales | Verbos
2. El tab activo por defecto es **Aplicaciones**
3. Cada tab muestra una tabla con los registros existentes + botón [➕ Nuevo]
4. **NO se puede editar ni eliminar apps/grupos/verbos estándar** (son catálogo base)

```
┌──────────────────────────────────────────────────────────────────┐
│  📱 Aplicaciones                                                 │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  [📱 Aplicaciones] [📦 Grupos] [✏ Verbos]                        │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  🔍 [Buscar...]  [➕ NUEVA APLICACIÓN]                            │
│  ─────────────────────────────────────────────────────────────── │
│                                                                  │
│  App Code │ Nombre        │ Slug       │ Tenant │ Activa         │
│  ─────────┼───────────────┼────────────┼────────┼────────────────│
│  1        │ Tryton        │ tryton     │ skull  │ 🟢             │
│  2        │ Keycloak      │ keycloak   │ skull  │ 🟢             │
│  3        │ Kong          │ kong       │ skull  │ 🟢             │
│  ...      │ ...           │ ...        │ ...    │ ...            │
│                                                                  │
│  ⚠ Apps del catálogo base — no editables ni eliminables          │
└──────────────────────────────────────────────────────────────────┘
```

**Regla para Claude Design:**
- El menú lateral IZQUIERDO debe incluir "📱 Aplicaciones" como item independiente
- Al hacer click, muestra 3 tabs: Aplicaciones, Grupos Funcionales, Verbos
- Cada tab tiene su propia tabla de datos + botón [➕ Nuevo]
- El botón [➕ Nuevo] en cada tab abre el modal correspondiente de CREACIÓN (no de selección)
- Los modales de SELECCIÓN (con radio buttons) se usan desde el árbol D1 del Editor de Rol
- Los modales de CREACIÓN (formulario) se usan desde esta vista de administración
- NO confundir: una cosa es ADMINISTRAR apps (esta vista) y otra es SELECCIONARLAS para un rol (árbol D1)

**Diferencia entre ADMINISTRAR y SELECCIONAR:**
| Contexto | Donde se usa | Modal |
|------|------|------|
| **ADMINISTRAR** | Aplicaciones (menú lateral) → [➕ Nuevo] | Modal CREAR (formulario completo) |
| **SELECCIONAR** | Editor de Rol → Árbol D1 → Zona → [➕ Agregar App] | Modal SELECCIÓN (radio buttons + opción crear) |

---

*ESPECIFICACION-MODALES-APP-MODULO-VERBO.md v2.1.0 · 2026-06-29 · SKULL · SBOS*
*DDL verificada: DDL_skSBOS_db.sql líneas 2580-2755 · Seeds: seed_privilege_application.sql,
seed_privilege_group.sql, seed_privilege_verb.sql, seed_privilege_atom.sql*
*VPS: 13.140.128.230:15432 · Formato Claude Design: Do's/Don'ts + Prompt Guide*
