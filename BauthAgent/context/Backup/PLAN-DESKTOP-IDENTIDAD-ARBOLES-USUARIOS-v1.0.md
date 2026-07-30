# Plan Desktop — Identidad → Árboles → Usuarios

## Ruta crítica para el dashboard Windows

**Versión:** 1.0
**Fecha:** 2026-07-14
**Estado:** Planificación — no se ha iniciado implementación

---

## 1. Diagnóstico: dónde estamos parados

### El desktop (54 archivos Dart, Flutter + Riverpod 3.x)

| Hecho | Estado |
|---|---|
| Layout 3 columnas (sidebar + centro + panel derecho) | ✅ Completo |
| Tema SBOS Dark (Slate + Cyan, 5 bases, 8 acentos) | ✅ Completo |
| Navegación SPA con router manual | ✅ Completo |
| Conexión RPC WebSocket | ✅ Completo |
| Vista Dashboard (6 KPIs con datos mock) | ✅ Completo |
| Vista RolTemplate (árbol AtomLang con tabs) | ✅ Completo |
| 13 vistas restantes | ❌ Solo placeholder |
| **Vista de Empresas, Sucursales, POS** | ❌ No existe |
| **Vista de Usuarios** | ❌ No existe |
| **Vista de Roles funcional** (asignación átomos→roles) | ❌ No existe |

### El backend (bAuth Rust)

| Hecho | Estado |
|---|---|
| CRUD de roles completo (create, read, update, delete, lifecycle) | ✅ |
| CRUD de usuarios completo (get, create, update, delete, assign_role, revoke_role) | ✅ |
| CRUD organizacional: empresa, sucursal create/list | ✅ |
| SucursalUpdateHandler, PosUpdateHandler, PosDeleteHandler | ❌ No existen |
| TenantUpdateHandler | ❌ No existe |
| Tabla `idn_atributo` | ❌ No existe (P1) |
| Seeds D00 (20 átomos semánticos) | ❌ No creados |
| Migración ADR-016 (`is_internal`) | ❌ No aplicada |

---

## 2. Orden de dependencias (lo que hay que resolver primero)

```
FASE A — IDENTIDAD (bloqueante para todo lo demás)
──────────────────────────────────────────────────
A1. Crear tabla idn_atributo (DDL + migración)
A2. Completar CRUD organizacional (handlers faltantes)
A3. Aplicar ADR-016 (is_internal, seeds D00)
A4. Verificar que el flujo tenant→empresa→sucursal→pos funciona

FASE B — ÁRBOLES (el corazón de AtomLang)
──────────────────────────────────────────
B1. Crear tabla atom_tree (DDL + migración)
B2. Implementar API bauth.atom.tree_get, node_get, node_create, node_update, node_delete
B3. Migrar datos desde rol_template_datos.dart → atom_tree
B4. Verificar que el dashboard carga el árbol desde BD (no desde Dart hardcodeado)

FASE C — USUARIOS (el consumidor final)
───────────────────────────────────────
C1. Vista de Usuarios en el desktop (lista + editor)
C2. Vista de Roles funcional (asignación átomos→roles, no solo el árbol)
C3. Vista de Empresas/Sucursales/POS
C4. Integrar llamadas JSON-RPC reales (eliminar datos mock)
C5. Flujo completo: crear usuario → asignar rol → ver UserBitMask → probar acceso
```

---

## 3. Diseño de la interfaz — pantallas a construir

### 3.1 Vista de Identidad Organizacional (NUEVA)

**Ruta:** `empresasAdmin`, `sucursalesAdmin`, `pos`
**Propósito:** Gestionar la jerarquía tenant→empresa→sucursal→pos del usuario

```
┌─────────────────────────────────────────────────────────┐
│ [Empresas] [Sucursales] [POS]                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─ Lista de Empresas ─────────────────────────────┐    │
│  │ [Buscar...]                          [+ Nueva]  │    │
│  │ ┌──────────────────────────────────────────────┐ │    │
│  │ │ Empresa Demo SRL        │ Activa │ [Editar]  │ │    │
│  │ │ tenant: skull           │        │ [Eliminar] │ │    │
│  │ │ sucursales: 3           │        │            │ │    │
│  │ ├──────────────────────────────────────────────┤ │    │
│  │ │ Empresa Norte SA        │ Activa │ [Editar]  │ │    │
│  │ │ tenant: skull           │        │ [Eliminar] │ │    │
│  │ └──────────────────────────────────────────────┘ │    │
│  └──────────────────────────────────────────────────┘    │
│                                                         │
│  ┌─ Editor de Empresa (modal o panel derecho) ──────┐   │
│  │ Nombre: [Empresa Norte SA            ]           │   │
│  │ NIT:    [12345678901234              ]           │   │
│  │ Tenant: [skull                  ▾   ]           │   │
│  │ Activo: [✓]                                       │   │
│  │                                [Guardar] [Cancelar]│   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Handlers requeridos:**
- `bauth.org.empresa.list` ✅
- `bauth.org.empresa.create` ✅
- `bauth.org.empresa.update` ✅
- `bauth.org.empresa.delete` ✅
- `bauth.org.sucursal.list` ✅
- `bauth.org.sucursal.create` ✅
- `bauth.org.sucursal.update` ❌ (implementar)
- `bauth.org.pos.list` ✅
- `bauth.org.pos.create` ✅
- `bauth.org.pos.update` ❌ (implementar)
- `bauth.org.pos.delete` ❌ (implementar)

### 3.2 Vista de Usuarios (NUEVA)

**Ruta:** `usuarios`
**Propósito:** CRUD de usuarios + asignación de roles + atributos personales

```
┌─────────────────────────────────────────────────────────────┐
│ [Lista] [Editor]                                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Lista de Usuarios ─────────────────────────────────┐    │
│  │ [Buscar...]  [Filtrar por rol ▾]      [+ Nuevo]     │    │
│  │ ┌──────────────────────────────────────────────────┐ │    │
│  │ │ Juan Pérez        │ vendedor_senior │ Activo     │ │    │
│  │ │ jperez@email.com  │ Norte           │ [Editar]   │ │    │
│  │ ├──────────────────────────────────────────────────┤ │    │
│  │ │ María Gómez       │ cajero          │ Activo     │ │    │
│  │ │ mgomez@email.com  │ Central         │ [Editar]   │ │    │
│  │ └──────────────────────────────────────────────────┘ │    │
│  └──────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─ Editor de Usuario ─────────────────────────────────┐    │
│  │ ┌─────────────┐ ┌──────────────────────────────────┐ │    │
│  │ │ IDENTIDAD   │ │ ROLES                            │ │    │
│  │ │             │ │                                  │ │    │
│  │ │ Nombre:     │ │ Rol base: [vendedor_senior ▾]    │ │    │
│  │ │ [Juan Pérez]│ │                                  │ │    │
│  │ │             │ │ Roles temporales:                 │ │    │
│  │ │ Email:      │ │ ┌──────────────────────────────┐ │ │    │
│  │ │ [jperez@..] │ │ │ Supervisor (hasta 15/08)     │ │ │    │
│  │ │             │ │ │ Modo: REPLACE · Delega: Ana  │ │ │    │
│  │ │ Tenant:     │ │ │ [Quitar]                     │ │ │    │
│  │ │ [skull  ▾]  │ │ └──────────────────────────────┘ │ │    │
│  │ │             │ │                                  │ │    │
│  │ │ Empresa:    │ │ [+ Agregar rol temporal]         │ │    │
│  │ │ [Norte  ▾]  │ │                                  │ │    │
│  │ │             │ │ Átomos extra:                     │ │    │
│  │ │ Sucursal:   │ │ ☑ descuento_20% (override)       │ │    │
│  │ │ [Central ▾] │ │ ☐ transferencia (bloqueado)       │ │    │
│  │ │             │ │                                  │ │    │
│  │ │ Pos:        │ │                                  │ │    │
│  │ │ [CAJA-04 ▾] │ │                                  │ │    │
│  │ └─────────────┘ └──────────────────────────────────┘ │    │
│  │                              [Guardar] [Cancelar]     │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

**Handlers requeridos:**
- `bauth.user.list` ✅
- `bauth.user.get` ✅
- `bauth.user.create` ✅
- `bauth.user.update` ✅
- `bauth.user.delete` ✅
- `bauth.user.assign_role` ✅
- `bauth.user.revoke_role` ✅
- `bauth.role.template.list` ✅ (para el selector de rol)
- `bauth.atom.catalog_lookup` ❌ (nuevo — para autocompletado de átomos)

### 3.3 Vista de Roles funcional (MEJORAR existente)

**Ruta:** `rtpl` (existente, expandir)
**Propósito:** Además del árbol AtomLang actual, agregar asignación átomos→roles

```
┌─────────────────────────────────────────────────────────────┐
│ [Árbol Fuente] [Árbol AtomLang] [Árbol Compilado] [Asignación]│
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─ Panel izquierdo ────┐ ┌─ Panel central ──────────────┐  │
│  │                       │ │                              │  │
│  │ Roles y Conjuntos     │ │ Átomos del rol seleccionado  │  │
│  │ (D98)                 │ │                              │  │
│  │                       │ │ ROL: vendedor_senior         │  │
│  │ ┌───────────────────┐ │ │                              │  │
│  │ │ 🔍 Buscar rol     │ │ │ ┌──────────────────────────┐ │  │
│  │ │                   │ │ │ │ ☑ d1.password_policy     │ │  │
│  │ │ 📁 vendedores      │ │ │ │   .longitud_minima      │ │  │
│  │ │  └─ vendedor_sen. │ │ │ │ ☑ d1.zona_ventas        │ │  │
│  │ │  └─ vendedor_jun. │ │ │ │   .descuento_tier1      │ │  │
│  │ │  └─ ejecutivo_v.  │ │ │ │ ☑ d1.field_restrictions │ │  │
│  │ │                   │ │ │ │   .campo_margin_oculto  │ │  │
│  │ │ 📁 gerentes_ventas │ │ │ │ ☑ d1.field_restrictions │ │  │
│  │ │  └─ gerente_reg.  │ │ │ │   .campo_cost_price_oc. │ │  │
│  │ │  └─ director_v.   │ │ │ │ ☑ d1.field_restrictions │ │  │
│  │ │                   │ │ │ │   .campo_credit_limit   │ │  │
│  │ │ 📁 financieros     │ │ │ │                          │ │  │
│  │ │  └─ analista_p.   │ │ │ │ ☐ d3.payment_approvals  │ │  │
│  │ │  └─ contador_j.   │ │ │ │   .pago_aprobacion      │ │  │
│  │ └───────────────────┘ │ │ │ └──────────────────────────┘ │  │
│  │                       │ │ │                              │  │
│  │ [+ Nuevo conjunto]    │ │ │ [Guardar asignación]         │  │
│  └───────────────────────┘ │ └──────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### 3.4 Navegación actualizada

```
┌─────────────────────────────────────────────┐
│ BARRA SUPERIOR                               │
│ [☰] bauth · Windows · SBOS    🔍  🔌  🎨  🔔  👤 │
├──────────┬──────────────────────────────────┤
│ SIDENAV  │ CONTENIDO                        │
│          │                                  │
│ GENERAL  │ (vista activa según ruta)         │
│  📊 Dash │                                  │
│  🌐 Conec │                                  │
│          │                                  │
│ PLANTILL.│                                  │
│  🌳 Roles │  ← existente, expandir           │
│  👥 Usuar │  ← NUEVA                         │
│  📋 Polít │  ← placeholder → UNIR con árbol  │
│          │                                  │
│ ACCESO   │                                  │
│  🔑 Atrib │  ← placeholder                   │
│  📱 Apps  │  ← placeholder                   │
│  ⚛️ Átomos│  ← NUEVA: asignación átomos→roles │
│          │                                  │
│ SISTEMA  │                                  │
│  🏢 Empre │  ← NUEVA: CRUD org              │
│  🏬 Sucur │  ← NUEVA: CRUD org              │
│  🏷️ POS   │  ← NUEVA: CRUD org              │
│  🔄 Sync  │  ← placeholder                   │
│  📊 Audit │  ← placeholder                   │
│          │                                  │
│ NEGOCIO  │                                  │
│  🏦 BOS   │  ← placeholder                   │
│  ⛓️ Block  │  ← placeholder                   │
│  💰 Comer │  ← placeholder                   │
│          │                                  │
│ CUENTA   │                                  │
│  🏢 Empre │  ← placeholder                   │
│  🏬 Sucur │  ← placeholder                   │
│  📍 Pos   │  ← placeholder                   │
│  📈 Uso   │  ← placeholder                   │
│  👤 Cuent │  ← placeholder                   │
│  🆘 Sopor │  ← placeholder                   │
│  ⚙️ Config│  ← existente (tema)              │
└──────────┴──────────────────────────────────┘
```

---

## 4. Plan de trabajo — orden de implementación

### Semana 1: Identidad (FASE A)
1. Crear DDL `idn_atributo` + migración `bauth_45__idn_atributo.sql`
2. Implementar handlers faltantes: `SucursalUpdate`, `PosUpdate`, `PosDelete`, `TenantUpdate`
3. Aplicar migración ADR-016, crear seeds D00
4. Probar: crear tenant → empresa → sucursal → pos desde CLI

### Semana 2: Árboles (FASE B)
1. Crear DDL `atom_tree` + migración
2. Implementar API `bauth.atom.tree_get`, `node_get`, `node_create`, `node_update`, `node_delete`
3. Script de migración: `rol_template_datos.dart` → inserts SQL → `atom_tree`
4. Dashboard: reemplazar `arbolRolTemplate` hardcodeado con llamada JSON-RPC a `bauth.atom.tree_get`

### Semana 3: Usuarios (FASE C)
1. Vista de Empresas/Sucursales/POS en Flutter
2. Vista de Usuarios en Flutter (lista + editor con asignación de roles)
3. Vista de Roles funcional (panel de asignación átomos→roles)
4. Integración JSON-RPC real (eliminar datos mock de KPIs)
5. Prueba end-to-end: crear empresa → crear usuario → asignar rol → ver UserBitMask

---

## 5. Lo que NO se toca (ya funciona)

- Layout de 3 columnas
- Tema SBOS Dark
- Navegación SPA
- Conexión RPC WebSocket
- Vista Dashboard
- Vista RolTemplate (árbol AtomLang)
- Backend de roles (CRUD completo)
- Backend de usuarios (CRUD completo)
- BitMask y motor de evaluación
