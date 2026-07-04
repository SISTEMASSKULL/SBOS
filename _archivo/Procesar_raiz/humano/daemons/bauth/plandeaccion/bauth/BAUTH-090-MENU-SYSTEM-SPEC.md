# BAUTH-090 — Sistema de Menús con Control de Acceso por BitMask

**Versión:** 2.0.0 — Alineado con DDL_skSBOS_db.sql  
**Fecha:** 2026-06-24  
**Dominio:** bAuth · D1 Lógico · Capa de presentación  
**Estado:** BORRADOR — Pendiente implementar en DDL  
**Clasificación:** INTERNO  
**DDL referencia:** `BauthAgent/db/migrations/DDL_skSBOS_db.sql`  
**Schema:** `bauth` (prefijo `menu_`)

---

## 1. Propósito

Este documento especifica la arquitectura de datos y la lógica de resolución
del sistema de menús de SBOS. El sistema cubre dos tipos de menú — jerárquico
y contextual — y los dota de control de acceso nativo mediante el modelo de
atoms/BitMask del dominio bAuth (D1–D11).

**Principio central:** un ítem de menú no tiene permisos propios. Su
visibilidad y ejecutabilidad se derivan exclusivamente de los atoms que el
usuario posee en su BitMask de rol. La UI nunca renderiza ítems que el usuario
no puede ejecutar; el filtrado ocurre en base de datos, no en el frontend.

---

## 2. Conceptos Clave

| Concepto | Definición |
|----------|-----------|
| **Menú jerárquico** | Árbol de navegación principal. Padre → hijos con profundidad arbitraria. Ejemplo: Finanzas → Transacciones → Nueva transferencia. |
| **Menú contextual** | Conjunto de acciones que aparece al interactuar con una entidad concreta (click derecho, botón de opciones). Ejemplo: acciones disponibles sobre una `Transacción` específica. |
| **Atom** | Unidad mínima de permiso en el motor BitMask. Formato: `app × group × domain × verb`. Vive en `privilege_atom`. Ejemplo: `tryton.account.D3.verb=create` → "Crear factura en Tryton". |
| **BitMask** | Entero de 64 bits por dominio. Cada bit representa la presencia (1) o ausencia (0) de un átomo en el rol del usuario. |
| **LoA** | Level of Assurance. Fuerza del método de autenticación: AAL1 (password), AAL2 (MFA/biométrico), AAL3 (hardware dedicado). |
| **Step-up** | Flow de Keycloak que eleva el LoA del usuario en tiempo de ejecución cuando una acción lo requiere. |
| **context_key** | Identificador de entidad de negocio para menús contextuales. Ejemplo: `transaccion`, `usuario`, `cuenta_onchain`. |

---

## 3. Tipos de Menú

### 3.1 Menú Jerárquico

Construye la barra de navegación lateral o superior de la aplicación.
La estructura es un árbol auto-referenciado con `parent_id`.

```
Finanzas
├── Transacciones
│   ├── Nueva transferencia      [atom: Transferencia.crear.nuevo]
│   ├── Ver historial            [atom: Transferencia.ver.lista]
│   └── Exportar                 [atom: Transferencia.exportar.csv]
└── Reportes
    ├── Balance general          [atom: Reporte.financiero.ver]
    └── Auditoría                [atom: Reporte.auditoria.ver, min_loa: 2]

Administración
├── Usuarios                     [atom: Usuario.admin.ver]
│   ├── Crear usuario            [atom: Usuario.admin.crear]
│   └── Revocar acceso           [atom: Usuario.admin.revocar, min_loa: 3]
└── Roles                        [atom: Rol.admin.ver]
```

Un nodo padre puede ser visible aunque el usuario no tenga acceso a ninguno
de sus hijos — en ese caso, el padre se muestra colapsado sin ítems. O puede
configurarse como invisible si todos sus hijos están bloqueados (comportamiento
controlado por el frontend con los datos que retorna `fn_resolve_menu`).

### 3.2 Menú Contextual

Aparece asociado a una entidad de negocio específica. El `context_key`
identifica el tipo de entidad; la lógica de negocio de la app pasa ese
`context_key` al resolver el menú.

```
Entidad: Transacción
context_key: 'transaccion'
─────────────────────────────────────────────
✅ Ver detalle              [atom: Transferencia.ver.detalle]
✅ Descargar comprobante    [atom: Transferencia.exportar.pdf]
❌ Anular                   [atom: Transferencia.anular] ← usuario no tiene este bit
❌ Aprobar (supervisor)     [atom: Transferencia.aprobar, min_loa: 2]

Entidad: Usuario
context_key: 'usuario'
─────────────────────────────────────────────
✅ Ver perfil               [atom: Usuario.ver.perfil]
✅ Editar datos             [atom: Usuario.editar.datos]
❌ Revocar sesiones         [atom: Usuario.admin.revocar_sesion]
❌ Eliminar cuenta          [atom: Usuario.admin.eliminar, min_loa: 3]
```

---

## 4. Schema de Base de Datos

### 4.1 Tabla `menu_item`

Catálogo unificado de todos los ítems de menú (jerárquicos y contextuales).

```sql
CREATE TABLE bauth.menu_item (
    id           UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id    UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    parent_id    UUID REFERENCES bauth.menu_item(id) ON DELETE SET NULL,
    label        TEXT NOT NULL,
    route        TEXT,
    icon         TEXT,
    sort_order   INT NOT NULL DEFAULT 0,
    is_visible   BOOLEAN NOT NULL DEFAULT true,
    menu_type    menu_type_enum NOT NULL,
    context_key  TEXT,
    ctx_id       TEXT NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_context_key CHECK (
        (menu_type = 'CONTEXTUAL' AND context_key IS NOT NULL) OR
        (menu_type = 'HIERARCHICAL')
    )
);

CREATE INDEX idx_menu_item_tenant   ON bauth.menu_item(tenant_id);
CREATE INDEX idx_menu_item_parent   ON bauth.menu_item(parent_id);
CREATE INDEX idx_menu_item_ctx      ON bauth.menu_item(tenant_id, context_key)
    WHERE menu_type = 'CONTEXTUAL';

CREATE INDEX idx_menu_item_tenant   ON bauth.menu_item(tenant_id);
CREATE INDEX idx_menu_item_parent   ON bauth.menu_item(parent_id);
CREATE INDEX idx_menu_item_ctx      ON bauth.menu_item(tenant_id, context_key)
    WHERE menu_type = 'contextual';
```

### 4.2 Tabla `menu_context`

Registro de los contextos de entidad disponibles por tenant.

```sql
CREATE TABLE bauth.menu_context (
    id           UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id    UUID NOT NULL REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,
    context_key  TEXT NOT NULL,
    entity_type  TEXT NOT NULL,
    description  TEXT,
    ctx_id       TEXT NOT NULL DEFAULT 'system',
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),

    UNIQUE (tenant_id, context_key)
);
```

**Contextos estándar SBOS:**

| `context_key` | `entity_type` | Descripción |
|---------------|--------------|-------------|
| `transaccion` | Transaccion | Operaciones sobre una transacción financiera |
| `usuario` | Usuario | Acciones de administración sobre un usuario |
| `cuenta_onchain` | CuentaOnchain | Operaciones sobre cuenta blockchain |
| `rol` | Rol | Gestión de roles y permisos |
| `documento` | Documento | Acciones sobre documentos anclados (Trust Layer) |
| `tenant` | Tenant | Administración del tenant (solo SU) |

### 4.3 Tabla `menu_item_atom` — Tabla Puente

Relaciona cada ítem de menú con los atoms necesarios para verlo y ejecutarlo.

```sql
CREATE TABLE bauth.menu_item_atom (
    menu_item_id  UUID NOT NULL REFERENCES bauth.menu_item(id) ON DELETE CASCADE,
    atom_code     INTEGER NOT NULL,  -- FK lógica → privilege_atom.atom_code. Label encoding, no UUID
    require_all   BOOLEAN NOT NULL DEFAULT true,
    min_loa       INT NOT NULL DEFAULT 1 CHECK (min_loa BETWEEN 1 AND 3),
    step_up_flow  TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),

    PRIMARY KEY (menu_item_id, atom_code)
);

CREATE INDEX idx_mia_atom ON bauth.menu_item_atom(atom_code);
```

**Lógica de `require_all`:**

```
require_all = TRUE  → el usuario necesita TODOS los atoms listados (AND)
                       Ejemplo: [Transferencia.crear AND Cuenta.ver]

require_all = FALSE → el usuario necesita AL MENOS UN atom (OR)
                       Ejemplo: [Supervisor.aprobar OR Gerente.aprobar]
```

### 4.4 Tabla `privilege_atom` (referencia — YA EXISTE en DDL nueva)

El átomo es la unidad mínima de permiso. Formato: `app_code × group_code × domain_code × verb_code`.
El sistema de menús referencia átomos por `atom_code` (INTEGER, label encoding), NO por UUID.
Ver `BAUTH-D1-MANUAL-COMPLETO.md` §2.3 para la estructura completa.

**Formato del atom usado por menús:** `{app_slug}.{group_slug}.{domain}.{verb_slug}`
Ejemplos: `tryton.account.D3.create` (crear factura), `keycloak.realm_admin.D1.update` (editar realm).

### 4.5 Tabla `privilege_role_atom` (referencia — YA EXISTE en DDL nueva)

Asignación de átomos a roles. Ver `bos_privilege.bos_role_atom` → `privilege_role_atom`.

---

### 4.6 — Tablas nuevas requeridas en DDL (no existentes aún)

El sistema de menús requiere 3 tablas nuevas + 1 ENUM type que deben agregarse a `DDL_skSBOS_db.sql`:

| # | Tabla | Schema | Prefijo | Propósito |
|---|-------|--------|---------|-----------|
| M01 | `menu_item` | bauth | `menu_` | Catálogo de ítems de menú jerárquico (parent_id) |
| M02 | `menu_context` | bauth | `menu_` | Contextos de entidad para menús contextuales |
| M03 | `menu_item_atom` | bauth | `menu_` | Puente menú↔átomo (1 ítem puede requerir N átomos) |
| M04 | `menu_type_enum` | — | ENUM | `HIERARCHICAL`, `CONTEXTUAL` |

**Estas tablas van en el SUBSISTEMA 2 (Catálogo de Roles) del D1.**
Prefijo `menu_`. El menú se resuelve evaluando el BitMask del usuario contra `menu_item_atom`.

### 4.7 — Seeds requeridos para el sistema de menús

| # | Seed | Registros | Fuente |
|---|------|-----------|--------|
| M01-S | `seed_menu_context.sql` | 6 | Contextos estándar SBOS (transaccion, usuario, cuenta_onchain, rol, documento, tenant) |
| M02-S | `seed_menu_item.sql` | ~50 | Menú jerárquico base: Finanzas, Administración, Usuarios, Roles, Reportes, etc. |

---

## 5. Función de Resolución

### 5.1 `fn_resolve_menu` — Menú jerárquico completo

Retorna solo los ítems que el usuario puede ver, ordenados para construir
el árbol de navegación.

```sql
CREATE OR REPLACE FUNCTION bauth.fn_resolve_menu(
    p_user_id    UUID,
    p_tenant_id  UUID
)
RETURNS TABLE (
    id          UUID,
    parent_id   UUID,
    label       TEXT,
    route       TEXT,
    icon        TEXT,
    sort_order  INT,
    depth       INT
)
LANGUAGE sql STABLE AS $$
    WITH user_role AS (
        -- obtener el rol activo del usuario
        SELECT role_id
        FROM bauth.bos_user_role
        WHERE user_id = p_user_id
          AND tenant_id = p_tenant_id
          AND (expires_at IS NULL OR expires_at > now())
        LIMIT 1
    ),
    user_atoms AS (
        -- BitMask consolidado del usuario por atom
        SELECT bra.atom_id, bra.bitmask_64
        FROM bauth.bos_role_atom bra
        JOIN user_role ur ON ur.role_id = bra.role_id
        WHERE (bra.expires_at IS NULL OR bra.expires_at > now())
    ),
    authorized_items AS (
        -- ítems donde el usuario tiene TODOS los atoms requeridos (require_all=TRUE)
        SELECT mia.menu_item_id
        FROM bauth.menu_item_atom mia
        JOIN user_atoms ua ON ua.atom_id = mia.atom_id
        JOIN bauth.bos_atom a ON a.id = mia.atom_id
        WHERE mia.require_all = TRUE
        GROUP BY mia.menu_item_id
        HAVING COUNT(*) = COUNT(*) FILTER (
            WHERE (ua.bitmask_64 & (1::bigint << a.bit_position)) <> 0
        )

        UNION

        -- ítems donde el usuario tiene AL MENOS UN atom (require_all=FALSE)
        SELECT DISTINCT mia.menu_item_id
        FROM bauth.menu_item_atom mia
        JOIN user_atoms ua ON ua.atom_id = mia.atom_id
        JOIN bauth.bos_atom a ON a.id = mia.atom_id
        WHERE mia.require_all = FALSE
          AND (ua.bitmask_64 & (1::bigint << a.bit_position)) <> 0
    ),
    menu_tree AS (
        -- árbol con profundidad
        SELECT mi.id, mi.parent_id, mi.label, mi.route, mi.icon,
               mi.sort_order, 0 AS depth
        FROM bauth.menu_item mi
        WHERE mi.tenant_id = p_tenant_id
          AND mi.menu_type = 'hierarchical'
          AND mi.is_visible = TRUE
          AND mi.id IN (SELECT menu_item_id FROM authorized_items)
          AND mi.parent_id IS NULL

        UNION ALL

        SELECT mi.id, mi.parent_id, mi.label, mi.route, mi.icon,
               mi.sort_order, mt.depth + 1
        FROM bauth.menu_item mi
        JOIN menu_tree mt ON mt.id = mi.parent_id
        WHERE mi.is_visible = TRUE
          AND mi.id IN (SELECT menu_item_id FROM authorized_items)
    )
    SELECT * FROM menu_tree
    ORDER BY depth, parent_id NULLS FIRST, sort_order;
$$;
```

### 5.2 `fn_resolve_context_menu` — Menú contextual

Retorna las acciones disponibles para una entidad concreta, incluyendo
el `step_up_flow` cuando el LoA actual del usuario no alcanza.

```sql
CREATE OR REPLACE FUNCTION bauth.fn_resolve_context_menu(
    p_user_id     UUID,
    p_tenant_id   UUID,
    p_context_key TEXT,
    p_current_loa INT DEFAULT 1
)
RETURNS TABLE (
    id             UUID,
    label          TEXT,
    icon           TEXT,
    sort_order     INT,
    is_executable  BOOLEAN,   -- FALSE si el atom existe pero el LoA no alcanza
    step_up_flow   TEXT,      -- flow a lanzar si is_executable=FALSE
    min_loa        INT
)
LANGUAGE sql STABLE AS $$
    WITH user_role AS (
        SELECT role_id
        FROM bauth.bos_user_role
        WHERE user_id = p_user_id
          AND tenant_id = p_tenant_id
          AND (expires_at IS NULL OR expires_at > now())
        LIMIT 1
    ),
    user_atoms AS (
        SELECT bra.atom_id, bra.bitmask_64
        FROM bauth.bos_role_atom bra
        JOIN user_role ur ON ur.role_id = bra.role_id
        WHERE (bra.expires_at IS NULL OR bra.expires_at > now())
    ),
    authorized_items AS (
        SELECT mia.menu_item_id,
               MAX(mia.min_loa)      AS required_loa,
               MAX(mia.step_up_flow) AS step_up_flow
        FROM bauth.menu_item_atom mia
        JOIN user_atoms ua ON ua.atom_id = mia.atom_id
        JOIN bauth.bos_atom a ON a.id = mia.atom_id
        WHERE (ua.bitmask_64 & (1::bigint << a.bit_position)) <> 0
        GROUP BY mia.menu_item_id
    )
    SELECT
        mi.id,
        mi.label,
        mi.icon,
        mi.sort_order,
        (ai.required_loa <= p_current_loa) AS is_executable,
        CASE WHEN ai.required_loa > p_current_loa THEN ai.step_up_flow END AS step_up_flow,
        ai.required_loa AS min_loa
    FROM bauth.menu_item mi
    JOIN authorized_items ai ON ai.menu_item_id = mi.id
    WHERE mi.tenant_id = p_tenant_id
      AND mi.menu_type = 'contextual'
      AND mi.context_key = p_context_key
      AND mi.is_visible = TRUE
    ORDER BY mi.sort_order;
$$;
```

---

## 6. Flujo de Runtime

### 6.1 Menú jerárquico (al cargar la app)

```
1. Usuario se autentica → JWT contiene {user_id, role_id, loa_level}
2. Frontend llama: GET /api/v1/{tenant}/menu/hierarchical
3. bAuth llama: fn_resolve_menu(user_id, tenant_id)
4. PostgreSQL evalúa BitMask por AND/OR de atoms
5. Retorna árbol filtrado → solo ítems permitidos
6. Frontend renderiza el árbol completo sin lógica de permisos propia
```

### 6.2 Menú contextual (al interactuar con una entidad)

```
1. Usuario hace click derecho sobre una Transacción
2. Frontend llama: GET /api/v1/{tenant}/menu/context/transaccion
   Headers: Authorization: Bearer {jwt}
3. bAuth llama: fn_resolve_context_menu(user_id, tenant_id, 'transaccion', loa)
4. Retorna lista con is_executable y step_up_flow por ítem
5. Frontend muestra todas las acciones autorizadas:
   - is_executable=TRUE  → acción habilitada, ejecuta directamente
   - is_executable=FALSE → acción visible pero deshabilitada, con tooltip
     "Requiere autenticación adicional" y botón para iniciar step-up
```

### 6.3 Step-up de LoA en acción contextual

```
Usuario intenta ejecutar "Anular transacción" (min_loa=2, usuario en loa=1)
  │
  ├── Frontend recibe is_executable=FALSE, step_up_flow='sbos-webauthn-2fa'
  ├── Muestra modal: "Esta acción requiere verificación adicional"
  ├── Lanza Keycloak flow: sbos-webauthn-2fa
  │     → Usuario presenta huella dactilar / Face ID / YubiKey
  │     → Keycloak emite nuevo JWT con loa_level=2
  ├── Frontend repite la llamada al endpoint con el nuevo JWT
  └── Acción ejecutada ✅
```

---

## 7. API Endpoints

| Método | Endpoint | Descripción |
|--------|----------|-------------|
| `GET` | `/api/v1/{tenant}/menu/hierarchical` | Árbol de navegación del usuario |
| `GET` | `/api/v1/{tenant}/menu/context/{context_key}` | Acciones contextuales sobre entidad |
| `POST` | `/api/v1/{tenant}/admin/menu/item` | Crear ítem de menú (admin) |
| `PUT` | `/api/v1/{tenant}/admin/menu/item/{id}` | Editar ítem (admin) |
| `POST` | `/api/v1/{tenant}/admin/menu/item/{id}/atom` | Asignar atom a ítem |
| `DELETE` | `/api/v1/{tenant}/admin/menu/item/{id}/atom/{atom_id}` | Revocar atom de ítem |
| `GET` | `/api/v1/{tenant}/admin/menu/contexts` | Listar contextos disponibles |

**Formato de respuesta — menú jerárquico:**

```json
{
  "menu": [
    {
      "id": "uuid",
      "parent_id": null,
      "label": "Finanzas",
      "route": "/finanzas",
      "icon": "ti-currency-dollar",
      "sort_order": 1,
      "depth": 0,
      "children": [
        {
          "id": "uuid",
          "parent_id": "uuid",
          "label": "Nueva transferencia",
          "route": "/finanzas/transferencias/nueva",
          "icon": "ti-transfer",
          "sort_order": 1,
          "depth": 1,
          "children": []
        }
      ]
    }
  ]
}
```

**Formato de respuesta — menú contextual:**

```json
{
  "context_key": "transaccion",
  "actions": [
    {
      "id": "uuid",
      "label": "Ver detalle",
      "icon": "ti-eye",
      "sort_order": 1,
      "is_executable": true,
      "step_up_flow": null,
      "min_loa": 1
    },
    {
      "id": "uuid",
      "label": "Anular transacción",
      "icon": "ti-ban",
      "sort_order": 4,
      "is_executable": false,
      "step_up_flow": "sbos-webauthn-2fa",
      "min_loa": 2
    }
  ]
}
```

---

## 8. Datos de Ejemplo

### 8.1 Seed de contextos estándar

```sql
INSERT INTO bauth.menu_context (tenant_id, context_key, entity_type, description)
VALUES
  ($tenant, 'transaccion',    'Transaccion',   'Acciones sobre transacciones financieras'),
  ($tenant, 'usuario',        'Usuario',        'Administración de usuarios'),
  ($tenant, 'cuenta_onchain', 'CuentaOnchain',  'Operaciones sobre cuentas blockchain'),
  ($tenant, 'rol',            'Rol',            'Gestión de roles y permisos'),
  ($tenant, 'documento',      'Documento',      'Acciones sobre documentos Trust Layer'),
  ($tenant, 'tenant',         'Tenant',         'Administración del tenant (SU only)');
```

### 8.2 Seed de menú jerárquico básico (Producto C — IAM Soberano)

```sql
-- Nivel 0: secciones principales
INSERT INTO bauth.menu_item (tenant_id, label, icon, sort_order, menu_type)
VALUES
  ($tenant, 'Finanzas',        'ti-currency-dollar', 1, 'hierarchical'),
  ($tenant, 'Usuarios',        'ti-users',           2, 'hierarchical'),
  ($tenant, 'Reportes',        'ti-chart-bar',       3, 'hierarchical'),
  ($tenant, 'Administración',  'ti-settings',        4, 'hierarchical');

-- Nivel 1: ítems hijos (parent_id referencia los de arriba)
-- (ejemplo para Finanzas)
INSERT INTO bauth.menu_item (tenant_id, parent_id, label, route, icon, sort_order, menu_type)
VALUES
  ($tenant, $fin_id, 'Transferencias',      '/finanzas/transferencias', 'ti-transfer',      1, 'hierarchical'),
  ($tenant, $fin_id, 'Historial',           '/finanzas/historial',      'ti-history',       2, 'hierarchical'),
  ($tenant, $fin_id, 'Reportes financieros','/finanzas/reportes',       'ti-report-money',  3, 'hierarchical');
```

### 8.3 Seed de menú contextual — Transacción

```sql
-- Ítems del contexto 'transaccion'
INSERT INTO bauth.menu_item (tenant_id, label, icon, sort_order, menu_type, context_key)
VALUES
  ($tenant, 'Ver detalle',         'ti-eye',           1, 'contextual', 'transaccion'),
  ($tenant, 'Descargar PDF',       'ti-download',      2, 'contextual', 'transaccion'),
  ($tenant, 'Anular',              'ti-ban',           3, 'contextual', 'transaccion'),
  ($tenant, 'Aprobar',             'ti-check',         4, 'contextual', 'transaccion'),
  ($tenant, 'Anclar en blockchain','ti-link',          5, 'contextual', 'transaccion');

-- Asignar atoms con sus requisitos de LoA
-- Ver detalle: solo loa=1
INSERT INTO bauth.menu_item_atom (menu_item_id, atom_id, min_loa)
  VALUES ($ver_detalle_id, $atom_transferencia_ver_id, 1);

-- Anular: requiere loa=2 y step-up a webauthn-2fa
INSERT INTO bauth.menu_item_atom (menu_item_id, atom_id, min_loa, step_up_flow)
  VALUES ($anular_id, $atom_transferencia_anular_id, 2, 'sbos-webauthn-2fa');

-- Aprobar: requiere loa=2 (supervisor)
INSERT INTO bauth.menu_item_atom (menu_item_id, atom_id, min_loa, step_up_flow)
  VALUES ($aprobar_id, $atom_transferencia_aprobar_id, 2, 'sbos-webauthn-2fa');

-- Anclar blockchain: requiere loa=3 (AAL3 hardware)
INSERT INTO bauth.menu_item_atom (menu_item_id, atom_id, min_loa, step_up_flow)
  VALUES ($blockchain_id, $atom_trust_anclar_id, 3, 'sbos-passkey-aal3');
```

---

## 9. Reglas de Negocio

| ID | Regla |
|----|-------|
| **MNU-01** | Un ítem de menú sin atoms asignados es invisible para todos los usuarios. |
| **MNU-02** | Un ítem de menú contextual sin `context_key` es inválido (constraint en DB). |
| **MNU-03** | `fn_resolve_menu` nunca retorna ítems con `is_visible=FALSE`. |
| **MNU-04** | La visibilidad de un ítem padre no depende de si el hijo está autorizado. |
| **MNU-05** | `is_executable=FALSE` no oculta el ítem — lo muestra deshabilitado con opción de step-up. |
| **MNU-06** | El `step_up_flow` debe corresponder a un Authentication Flow existente en Keycloak. |
| **MNU-07** | Los atoms expirados (`expires_at < now()`) no contribuyen al BitMask del usuario. |
| **MNU-08** | `fn_resolve_menu` es `STABLE` — cacheable por request, no por sesión. |
| **MNU-09** | El frontend no implementa lógica de permisos. Solo consume la respuesta de la API. |
| **MNU-10** | Modificar la estructura del menú requiere el atom `Menu.admin.editar` en el tenant admin. |

---

## 10. Relación con el Catálogo de Métodos de Autenticación (§8.1)

El campo `step_up_flow` de `menu_item_atom` referencia directamente los flows
de Keycloak definidos en BAUTH-081:

| `step_up_flow` | Flow Keycloak | LoA que otorga | Dispositivos |
|----------------|--------------|----------------|--------------|
| `sbos-webauthn-2fa` | Método #5 WebAuthn 2FA | AAL2 | Huella celular, Face ID, Windows Hello |
| `sbos-webauthn-passwordless` | Método #4 WebAuthn Passwordless | AAL2 | Touch ID, Face ID, YubiKey Bio |
| `sbos-passkey-aal3` | Método #7 Passkey Device-Bound | AAL3 | YubiKey 5, YubiKey Bio, SoloKey, chapa electrónica FIDO2 |

Cuando un usuario intenta ejecutar una acción con `min_loa` superior a su LoA
actual, el frontend lanza el `step_up_flow` correspondiente. Tras la
autenticación exitosa, Keycloak emite un nuevo JWT con el `loa_level`
actualizado y el usuario puede ejecutar la acción sin repetir el flujo completo
de login.

---

## 11. Consideraciones de Rendimiento

- `fn_resolve_menu` y `fn_resolve_context_menu` son `STABLE`: el planner de
  PostgreSQL puede cachearlas dentro del mismo request.
- El BitMask (`bitmask_64`) está precalculado en `bos_role_atom`. La evaluación
  es una operación AND sobre enteros — O(1) por atom.
- El índice `idx_menu_item_ctx` cubre las consultas de menú contextual con
  filtro por `tenant_id` y `context_key`.
- En deployments con alto volumen de usuarios concurrentes, el resultado de
  `fn_resolve_menu` puede cachearse en Redis con TTL de 60 segundos, invalidado
  por evento `role_changed` en el bus de bnotify.

---

## 12. Referencias

| Documento | Descripción |
|-----------|-------------|
| `BAUTH-081-WEBAUTHN-BIOMETRIC-SPEC.md` | Flows de autenticación WebAuthn/FIDO2 y LoA |
| `BAUTH-060-PRIVILEGE-ADMIN-MANUAL.md` | Modelo de atoms y BitMask Dual v3.0 |
| `BAUTH-011-DOMAIN-CATALOG.md` | Catálogo de dominios D1–D11 |
| `SBOS-053-DAEMON-TUI-DECOUPLING.md` | Principio Headless-First — la API es la fuente de verdad |
| RFC 8693 | OAuth 2.0 Token Exchange (step-up de LoA) |
| NIST SP 800-63B | Niveles AAL1/AAL2/AAL3 |

---

*Documento generado como parte del dominio bAuth — SBOS v1.x*  
*Próxima revisión: cuando se implemente el primer tenant de Producto C*
