# SBOS-009
## Contratos de Identidad: RolTemplate + UserTemplate
### El Lenguaje Declarativo del Dominio de Identidad SBOS

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026 · CONFIDENCIAL**

---

**Código:** SBOS-009
**Versión:** 1.0
**Estado:** ACTIVO — Complemento en SBOS-MP01 §PARTE-B
**Complemento:** SBOS-MP01-CompletarDocs-v1_0.md PARTE B (Catálogo de Roles por sector — integrado en v2.0)
**Clasificación:** Especificación Técnica — Contratos de Identidad

---

## Tabla de Contenidos

1. [Propósito — por qué contratos declarativos de identidad](#1-propósito)
2. [RolTemplate vs UserTemplate — separación de responsabilidades](#2-separación-de-responsabilidades)
3. [Ciclo de vida de un RolTemplate](#3-ciclo-de-vida-de-un-roltemplate)
4. [Ciclo de vida de un UserTemplate](#4-ciclo-de-vida-de-un-usertemplate)
5. [Proceso de creación de un RolTemplate nuevo](#5-proceso-de-creación-de-un-roltemplate-nuevo)
6. [Catálogo inicial de RolTemplates por sector](#6-catálogo-inicial-de-roltemplate-por-sector)
7. [ANEXO A — RolTemplate-SBOS-v2.json completo con documentación](#anexo-a)
8. [ANEXO B — UserTemplate-SBOS-v1.json completo con documentación](#anexo-b)
9. [Registro de cambios v1.0](#registro-de-cambios)

---

## 1. Propósito

### 1.1 El Problema que Resuelven los Contratos Declarativos

Los sistemas empresariales tradicionales definen los privilegios de sus usuarios de forma fragmentada: un administrador configura permisos en el ERP, otro configura métodos de autenticación en el IdP, otro activa accesos físicos en un sistema de control de acceso, y un cuarto gestiona los horarios de trabajo en el sistema de RRHH. Estas cuatro configuraciones no están relacionadas formalmente. Ningún documento las unifica. Cuando un empleado cambia de rol, el administrador debe recordar actuar en cuatro sistemas distintos. Inevitablemente, algunos quedan desactualizados.

El RolTemplate elimina este problema con una premisa radical: **la especificación completa de un rol empresarial existe en un solo lugar, en un solo formato, y es la fuente de verdad única para todos los sistemas del SBOS**.

Un RolTemplate no es un formulario de administración — es un **contrato técnico y organizacional** que el RolFramework procesa para sincronizar Keycloak y Tryton de forma automática, idempotente y auditable.

### 1.2 Qué Garantiza el Sistema de Contratos

- **Un cambio, propagación total:** modificar un campo en el RolTemplate desencadena una sincronización automática en todos los sistemas afectados. No hay pasos manuales.
- **Auditoría completa:** cada versión del contrato queda registrada en `bkernel_db.audit_events`. Cualquier pregunta de auditoría ("¿qué permisos tenía este rol en febrero?") tiene respuesta exacta.
- **Enforcement estructural:** los permisos que declara el contrato no son sugerencias — son configuraciones estructurales de Keycloak y Tryton que no pueden saltarse por error de código.
- **Onboarding predecible:** cuando un empleado nuevo recibe un RolTemplate asignado, su entorno completo — credenciales, menús, accesos, horarios — está definido antes de que llegue al sistema.

### 1.3 Relación con Otros Documentos

| Documento | Relación |
|---|---|
| **SBOS-008** | Describe el motor RolFramework que procesa estos contratos. Este documento es el contrato; SBOS-008 es el motor. |
| **SBOS-019** | Especificación técnica de los métodos de autenticación Keycloak referenciados en el RolTemplate. |
| **SBOS-020** | Especificación técnica de los datos y respuestas de Keycloak que el UserTemplate refleja. |

---

## 2. Separación de Responsabilidades

### 2.1 El Principio Central de Diseño

El sistema usa dos contratos distintos porque responden a dos preguntas distintas:

> **RolTemplate → ¿Qué PUEDE HACER un tipo de rol en la organización?**
> **UserTemplate → ¿Quién ES y qué TIENE un usuario concreto?**

Esta separación no es cosmética — tiene consecuencias técnicas precisas:

| Dimensión | RolTemplate | UserTemplate |
|---|---|---|
| **Granularidad** | Define una categoría de persona | Define una persona concreta |
| **Multiplicidad** | Un RolTemplate → muchos usuarios | Un UserTemplate → un usuario |
| **Quién lo modifica** | Administrador de TI / RRHH según tipo de cambio | RolFramework (automático) + admin con aprobación |
| **Cuándo se modifica** | Cuando cambia la política del rol | Cuando cambia el empleado (nuevo dispositivo, cambio de rol, etc.) |
| **Qué sincroniza en KC** | Authentication Flows, Session Settings, User Attributes del rol | User record, credenciales registradas, rol asignado |
| **Qué sincroniza en Tryton** | Grupos, ir.model.access, ir.action.groups, ir.model.button | res.user, company.employee, idioma, empresa activa |

### 2.2 Lo que el UserTemplate NO Duplica del RolTemplate

El UserTemplate no contiene permisos, políticas de MFA, horarios, ni restricciones geográficas. Esos son exclusivos del RolTemplate. Lo que el UserTemplate sí contiene es:

- Qué **métodos tiene registrados** el usuario concreto (no qué métodos requiere el rol — eso es el RolTemplate)
- Cuál es el **rol actualmente asignado** al usuario
- Los **datos personales y profesionales** del empleado
- El **estado de sincronización** del usuario en KC y Tryton
- El **estado de compliance** del usuario (certificaciones, trainings)

El RolFramework valida que lo que tiene registrado el usuario (UserTemplate) cubra lo que requiere su rol (RolTemplate). Si hay un gap, emite una alerta al administrador.

### 2.3 Regla de Separación Precisa

```
RolTemplate define:
  ✓ availableMethods  → qué métodos puede usar este tipo de rol
  ✓ requiredMethods   → qué métodos DEBE usar para operar
  ✓ transaction_limits → límites financieros del rol
  ✓ temporal_control  → horarios permitidos del rol
  ✓ geospatial_control → ubicaciones permitidas del rol
  ✓ model_access      → CRUD por modelo Tryton
  ✓ visible_actions   → menús visibles en Tryton

UserTemplate define:
  ✓ keycloak_credentials → qué tiene REGISTRADO este usuario concreto
  ✓ roles_assignments    → a qué rol(es) está asignado
  ✓ personal_info        → nombre, email, teléfono, dirección
  ✓ professional_info    → cargo, departamento, empresa, supervisor
  ✓ tryton_binding       → employee_id, company, language
  ✓ credentials_compliance → si cubre los requiredMethods de su rol
  ✓ sync_state           → estado de sincronización KC + Tryton
```

---

## 3. Ciclo de Vida de un RolTemplate

### 3.1 Estados

```
DRAFT → REVIEW → ACTIVE → DEPRECATED → ARCHIVED
         │                    │
         └── REJECTED         └── puede reactivarse como nueva versión
```

| Estado | Descripción | Quién puede modificarlo |
|---|---|---|
| `DRAFT` | En diseño. No sincronizado. | Admin de TI |
| `REVIEW` | En aprobación formal. Bloqueado para edición. | Solo aprobadores |
| `ACTIVE` | Sincronizado en KC y Tryton. Operacional. | Solo via flujo de cambio |
| `DEPRECATED` | Reemplazado por versión nueva. Usuarios migrados. | Solo lectura |
| `ARCHIVED` | Fuera de uso. Solo auditoría histórica. | Solo lectura |

### 3.2 Transiciones y Disparadores

**DRAFT → REVIEW:** El administrador completa el RolTemplate y solicita aprobación desde el Core UI.

**REVIEW → ACTIVE:** El aprobador designado (definido en `approval_workflow` del RolTemplate) confirma la revisión. El RolFramework inicia sincronización con KC y Tryton. El `sync_status` pasa a `PENDING` y luego a `SYNCED`.

**ACTIVE → DEPRECATED:** Se crea una nueva versión del RolTemplate (incremento de `version_number`). El RolFramework migra automáticamente a los usuarios afectados a la nueva versión.

**Modificación de un RolTemplate ACTIVE:** No se modifica directamente. Se crea una nueva versión en estado DRAFT. Al aprobarse, la versión anterior pasa a DEPRECATED. El historial completo se preserva en `bkernel_db.audit_events`.

### 3.3 Detección de Cambios por el bKernel

Cuando el RolFramework guarda un RolTemplate en `bos_rol_template`, el bKernel detecta el cambio vía WAL de PostgreSQL y activa el plugin `rolframework_sync` según la regla ROLF-001:

```yaml
rule:
  id:   "ROLF-001"
  when:
    source:    "bos_core"
    table:     "bos_rol_template"
    operation: "INSERT, UPDATE"
  then:
    - action: "plugin"
      name:   "rolframework_sync"
    - action: "catalog"
      task:   "log_audit_event"
```

El tiempo de sincronización objetivo es inferior a 5 segundos desde que se guarda el cambio hasta que KC y Tryton reflejan el nuevo estado.

---

## 4. Ciclo de Vida de un UserTemplate

### 4.1 Estados

```
ACTIVE → INACTIVE → SUSPENDED → TERMINATED
```

| Estado | KC | Tryton | Descripción |
|---|---|---|---|
| `ACTIVE` | Habilitado | Habilitado | Operacional normal |
| `INACTIVE` | Deshabilitado | Deshabilitado | Ausencia temporal (licencia, baja médica) |
| `SUSPENDED` | Deshabilitado | Deshabilitado | Investigación de seguridad o incidente |
| `TERMINATED` | Eliminado del realm | Deshabilitado (historial preservado) | Fin de relación laboral |

### 4.2 Creación de un UserTemplate

La creación ocurre cuando el administrador registra a un empleado nuevo desde el Core UI:

1. Admin completa el formulario de empleado nuevo en Core UI
2. Core UI genera el UserTemplate JSON con `sync_state.sync_status = "PENDING"`
3. RolFramework escribe el UserTemplate en la base de datos del SBOS
4. bKernel detecta el INSERT vía WAL y activa el plugin de sincronización de usuario
5. RolFramework crea el usuario en Keycloak y lo asigna al grupo del rol
6. RolFramework crea o actualiza el `res.user` y `company.employee` en Tryton
7. `sync_state.sync_status` pasa a `"SYNCED"` cuando ambos sistemas confirman

### 4.3 Cambio de Rol de un Usuario

Cuando un empleado cambia de rol (promoción, transferencia, reorganización):

1. Admin actualiza `roles_assignments.active_roles` en el Core UI
2. RolFramework calcula la diferencia entre el rol anterior y el nuevo
3. En KC: mueve al usuario al nuevo grupo, actualiza atributos del usuario
4. En Tryton: actualiza los grupos del `res.user`
5. El rol anterior pasa a `roles_assignments.history` con la fecha de remoción y el motivo
6. Si el nuevo rol tiene requiredMethods no cubiertos por las credenciales del usuario: alerta al admin

### 4.4 Detección de Drift

El RolFramework verifica periódicamente (cadencia configurable, por defecto diaria) que el estado de KC y Tryton coincide exactamente con lo que declara el UserTemplate. Si detecta divergencia:

- `sync_status` pasa a `"DRIFT"`
- Se emite alerta ALTA en Wazuh SIEM
- Si el drift implica permisos de más (el usuario tiene más acceso del declarado): alerta CRÍTICA + re-sincronización automática inmediata

---

## 5. Proceso de Creación de un RolTemplate Nuevo

Este proceso aplica cuando se necesita definir un rol empresarial que no existe todavía en el catálogo del SBOS.

### Paso 1 — Definición organizacional (con RRHH y el cliente)

Antes de abrir el Core UI, el proceso comienza con preguntas organizacionales:
- ¿Qué funciones realiza esta persona?
- ¿A qué módulos del ERP necesita acceder?
- ¿Qué operaciones puede ejecutar sola y cuáles requieren aprobación?
- ¿Trabaja en horario fijo o flexible?
- ¿Trabaja desde ubicaciones específicas?
- ¿Maneja transacciones financieras? ¿Con qué límites?

El resultado de esta conversación es el insumo para el RolTemplate. Sin esta conversación, el RolTemplate producirá un rol técnicamente correcto pero organizacionalmente equivocado.

### Paso 2 — Identificar la jerarquía de herencia

El RolFramework implementa H-RBAC con operaciones bitwise. Antes de crear un rol nuevo, identificar:
- ¿Este rol hereda de un rol padre? (operación `OR` — hereda todos los permisos del padre)
- ¿Este rol es un subconjunto de un rol padre? (operación `AND NOT` — hereda los permisos del padre menos los que se excluyen explícitamente)

El hijo siempre hereda menos que el padre. Esta es la regla de oro del H-RBAC de SBOS.

### Paso 3 — Abrir el Core UI y crear el RolTemplate

Desde el Core UI (sección Administración → Roles → Nuevo Rol):

1. Definir el identificador canónico: `DEPARTAMENTO-SUBNIVEL-NNN` (ej: `VEN-GER-001`)
2. Definir `parent_id` si hay herencia
3. Configurar `logical_access`:
   - `availableMethods` y `requiredMethods`
   - `temporal_control` (horario de trabajo)
   - `geospatial_control` (ubicaciones permitidas)
   - `session_management` (duración de sesión, concurrencia)
4. Configurar `tryton_privileges`:
   - `model_access` (CRUD por modelo)
   - `visible_actions` (menús)
   - `field_restrictions` (campos visibles/editables)
   - `button_rules` (buttons con SoD)
   - `record_rules` (filtros automáticos de datos)
5. Configurar `financial_transactions` si aplica
6. Definir `validity_period` y `approval_workflow`
7. Guardar como DRAFT

### Paso 4 — Revisión y prueba en entorno de staging

Antes de activar el rol en producción:
- Crear un usuario de prueba con el nuevo RolTemplate asignado
- Verificar en KC que el Authentication Flow se creó correctamente
- Verificar en Tryton que los grupos, menús, y accesos son los esperados
- Probar cada operación crítica definida en el RolTemplate

### Paso 5 — Aprobación formal

El administrador cambia el estado de DRAFT a REVIEW desde el Core UI. El aprobador designado recibe una notificación (via bCompass → SBOS VDI). El aprobador revisa y confirma. El RolFramework activa el rol en producción.

### Paso 6 — Asignación a usuarios

El rol ACTIVE ya aparece en el selector de roles del Core UI. Los administradores pueden asignar el nuevo RolTemplate a los UserTemplates de los empleados correspondientes.

---

## 6. Catálogo Inicial de RolTemplates por Sector

Este catálogo proporciona RolTemplates de referencia para los sectores objetivo del SBOS. Son puntos de partida — cada cliente los adapta a su organización específica.

### 6.1 Sector Contabilidad

#### `CON-JUN-001` — Contador Junior

| Campo | Valor |
|---|---|
| Descripción | Registro de transacciones, conciliaciones básicas, emisión de facturas |
| LoA requerido | LoA 2 (password + TOTP) |
| Horario | Lunes a Viernes, 08:00 – 18:00 |
| Límite financiero | Sin permisos de aprobación de pagos |

Accesos Tryton:
- `account.invoice`: read, create (NO delete, NO approve)
- `account.payment`: read
- `account.move.line`: read, create
- `account.account`: read

Menus visibles: facturación, diario contable, consulta de cuentas, reportes básicos

Restricciones: no puede ver márgenes, no puede ver cuentas bancarias completas, no puede ejecutar cierres de período.

---

#### `CON-SEN-001` — Contador Senior

| Campo | Valor |
|---|---|
| Descripción | Conciliaciones complejas, cierres de período, supervisión de junior |
| LoA requerido | LoA 3 (password + TOTP + Smart Card para cierres) |
| Horario | Lunes a Viernes, 08:00 – 20:00 (extensión en cierres de período) |
| Límite financiero | Puede aprobar pagos hasta USD 5,000 |

Accesos Tryton (adicionales a Junior):
- `account.invoice`: write, approve (con Button Rule — requiere 2 aprobadores para montos > USD 2,000)
- `account.payment`: write, create, approve (hasta USD 5,000)
- `account.period`: write (cierre de período)

Herencia: `parent_id: "CON-JUN-001"` con ampliación de privilegios (operación OR)

---

#### `CON-GER-001` — Gerente de Contabilidad

| Campo | Valor |
|---|---|
| Descripción | Control total del módulo contable, aprobación de pagos de alto valor, reportes ejecutivos |
| LoA requerido | LoA 4 (password + Smart Card + Biométrico para pagos > USD 50,000) |
| Horario | Lunes a Viernes, 07:00 – 22:00 |
| Límite financiero | Hasta USD 50,000 individual, ilimitado con segundo aprobador |

Herencia: `parent_id: "CON-SEN-001"` con ampliación total del módulo contable.

---

### 6.2 Sector Recursos Humanos

#### `RRHH-REC-001` — Reclutador

| Campo | Valor |
|---|---|
| Descripción | Gestión de candidatos, entrevistas, ofertas de trabajo |
| LoA requerido | LoA 2 |
| Horario | Lunes a Viernes, 08:00 – 18:00 |

Accesos Tryton: módulo de empleados (solo candidatos), sin acceso a nómina, sin acceso a contratos activos de otros empleados.

---

#### `RRHH-ANA-001` — Analista de RRHH

| Campo | Valor |
|---|---|
| Descripción | Gestión de empleados activos, contratos, ausencias, evaluaciones |
| LoA requerido | LoA 2 |
| Horario | Lunes a Viernes, 08:00 – 18:00 |

Accesos Tryton: módulo completo de empleados (excepto nómina y retribuciones), gestión de ausencias, evaluaciones de desempeño.

Restricción crítica: no puede ver el salario de ningún empleado (field_restriction sobre `company.employee.wage`).

---

#### `RRHH-JEF-001` — Jefe de RRHH

| Campo | Valor |
|---|---|
| Descripción | Control total del departamento, acceso a nómina, aprobación de contrataciones |
| LoA requerido | LoA 3 (password + TOTP + Smart Card para acceso a nómina) |
| Límite financiero | Puede aprobar contratos hasta el límite presupuestario del departamento |

Step-up authentication: al acceder al módulo de nómina, Keycloak solicita LoA 3 aunque la sesión principal sea LoA 2.

---

### 6.3 Sector Ventas

#### `VEN-VEN-001` — Vendedor

| Campo | Valor |
|---|---|
| Descripción | Gestión de oportunidades, creación de pedidos, seguimiento de clientes |
| LoA requerido | LoA 2 |
| Horario | Lunes a Sábado, 07:00 – 20:00 (vendedores con actividad de campo) |
| Geolocalización | Oficina + VPN corporativa + ubicaciones de clientes registradas |

Accesos Tryton: `sale.order` (CRUD), `sale.opportunity` (CRUD), `party.party` (read/write), `account.invoice` (read), `stock.shipment.out` (read).

Restricción: no puede ver márgenes, no puede ver precios de costo.

---

#### `VEN-SUP-001` — Supervisor de Ventas

| Campo | Valor |
|---|---|
| Descripción | Supervisión del equipo, aprobación de descuentos, reportes de equipo |
| LoA requerido | LoA 2 (LoA 3 para descuentos > 20%) |
| Límite de descuento | Hasta 30% con aprobación automática; >30% requiere segundo aprobador |

Herencia: `parent_id: "VEN-VEN-001"` con adición de aprobación de descuentos y reportes de equipo.

---

#### `VEN-GER-001` — Gerente Comercial

Equivalente al RolTemplate de referencia incluido en el ANEXO A de este documento. Ver el JSON completo para la especificación técnica exhaustiva incluyendo control de acceso físico, transacciones financieras, y delegaciones.

---

### 6.4 Administración de TI

#### `TI-ADM-001` — Administrador de TI

| Campo | Valor |
|---|---|
| Descripción | Gestión del sistema SBOS, administración de usuarios y roles, monitoreo |
| LoA requerido | LoA 4 para todas las operaciones administrativas |
| Acceso | 24/7 con aprobación fuera de horario laboral |
| SoD | No puede aprobar sus propios cambios de permisos |

Accesos: Core UI completo, Keycloak Admin Console (a través del Core UI — no acceso directo), tablero de observabilidad (monitorserver), gestión de fichas del IAM Installer.

Restricción crítica (SoD): el administrador de TI no puede crear un RolTemplate y activarlo sin un segundo aprobador. No puede darse a sí mismo permisos adicionales.

---

### 6.5 Auditor de Solo Lectura

#### `AUD-RO-001` — Auditor (Solo Lectura)

| Campo | Valor |
|---|---|
| Descripción | Acceso de solo lectura a todos los módulos para auditoría interna o externa |
| LoA requerido | LoA 3 |
| Horario | Horario de auditoría acordado (configurable por engagement) |
| Vigencia | Fecha de inicio y fin explícitas (`validity_period`) |

Accesos Tryton: `read: true`, `write: false`, `create: false`, `delete: false` en absolutamente todos los modelos del sistema.

El auditor puede ver todo pero no puede modificar nada. Esta restricción es estructural — no puede saltarse por ningún error de código de la aplicación porque vive en `ir.model.access` de Tryton.

Vigencia obligatoria: el `validity_period` siempre tiene `end_date` explícita. Al vencer la fecha, el RolFramework deshabilita el usuario automáticamente en KC y Tryton.

---

## ANEXO A

### RolTemplate-SBOS-v2.json — Especificación Completa

El siguiente JSON es el contrato formal del `RolTemplate`. Incluye todos los bloques con sus comentarios arquitectónicos. El ejemplo corresponde al rol `Gerente Regional de Ventas — Norte` de la empresa `ACME S.A.`, seleccionado como referencia por ser el rol más complejo del catálogo (incluye acceso lógico, físico, financiero, delegaciones y herencia jerárquica).

```json
{
  "role": {

    // ═══════════════════════════════════════════════════════════════
    // PRINCIPIO DE DISEÑO DEL ROLTEMPLATE
    //
    // El RolTemplate es la especificación técnica completa de un rol
    // empresarial. No es un formulario de administración — es el
    // CONTRATO FORMAL que el RolFramework procesa para sincronizar
    // Keycloak y Tryton.
    //
    // Lo que el RF necesita del RolTemplate:
    //   - id (nombre canónico) → Composite Role en KC + Grupo en Tryton
    //   - logical_access → Authentication Flow personalizado en KC
    //   - tryton_privileges → 5 capas de enforcement en Tryton
    //   - financial_transactions → Button Rules y Record Rules en Tryton
    //
    // El RolTemplate NUNCA se modifica directamente en producción.
    // Siempre via flujo de cambio con aprobación (Core UI → bos_rol_template).
    //
    // Basado en:
    //   - ANSI/INCITS 359-2004 (H-RBAC)
    //   - Keycloak 26.x SPI + Authentication Flows
    //   - Tryton 7.0 ir.model.access + ir.model.button + ir.rule.group
    //   - GDPR, ISO 27001:2022, SOC 2 Type II (diseño)
    // ═══════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 1 — IDENTIFICACIÓN DEL ROL
    // id → nombre canónico: Composite Role en KC, Grupo en Tryton
    // parent_id → rol padre para herencia H-RBAC (AND NOT en bitwise)
    // ═══════════════════════════════════════════════════════════════
    "id":             "RGV-001",
    "name":           "Gerente Regional de Ventas — Norte",
    "description":    "Gerente responsable del territorio Norte. Gestión de equipo, aprobación de pedidos y pagos dentro de límites, reportes regionales.",
    "department":     "Ventas",
    "parent_id":      "VENTAS-BASE",
    "version_number": 7,
    "status":         "ACTIVE",

    "audit": {
      "created_by": "ADMIN.SISTEMA",
      "created_at": "2024-01-01T00:00:00Z",
      "updated_by": "DGV-CARLOS.RUIZ",
      "updated_at": "2025-03-01T10:30:00Z",
      "approved_by": "CFO",
      "approved_at": "2025-03-01T10:31:00Z"
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 2 — CONTROL DE VIGENCIA
    // start_date: desde cuándo existe este rol en el sistema
    // end_date: cuándo expira automáticamente (null = indefinido)
    // El RF verifica via RolRoleValidityAuthenticator (SPI Keycloak)
    // ═══════════════════════════════════════════════════════════════
    "validity_period": {
      "start_date": "2024-01-15T00:00:00Z",
      "end_date":   "2025-12-31T23:59:59Z",
      "review_date": "2025-07-01T00:00:00Z"
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 3 — FLUJO DE APROBACIÓN DE CAMBIOS
    // Define quién aprueba cambios a este RolTemplate en producción.
    // El RF bloquea cualquier cambio sin aprobación del nivel correcto.
    // ═══════════════════════════════════════════════════════════════
    "approval_workflow": {
      "required_approvers": 2,
      "approver_roles": ["DIRECTOR_VENTAS", "CFO"],
      "notification_channel": "bcompass_SBOS VDI"
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 4 — ACCESO LÓGICO (DOMINIO 1)
    // Todo lo que Keycloak controla en el momento del login.
    // El RF traduce este bloque a:
    //   - Authentication Flow personalizado para este rol
    //   - User attributes del usuario en KC
    //   - Session settings del cliente KC
    // ═══════════════════════════════════════════════════════════════
    "logical_access": {

      // Métodos disponibles y requeridos para este rol.
      // availableMethods → qué métodos puede usar (lista permitida)
      // requiredMethods  → qué métodos DEBE completar (orden obligatorio)
      "availableMethods": [
        "username_password",
        "2fa_app",
        "biometric_login",
        "smart_card_logical",
        "hardware_token"
      ],
      "requiredMethods": {
        "standard_login": [
          {"method": "username_password", "order": 1},
          {"method": "2fa_app",           "order": 2}
        ],
        "elevated_login": [
          {"method": "username_password", "order": 1},
          {"method": "biometric_login",   "order": 2}
        ]
      },
      "alternativeMethods": [
        {
          "replaces": "biometric_login",
          "with":     "hardware_token",
          "requires_approval": false
        },
        {
          "replaces": "2fa_app",
          "with":     "email_otp",
          "requires_approval": true,
          "approver_roles": ["ADMIN_SISTEMA"]
        }
      ],

      // Control geoespacial → JavaScript Policy en Keycloak.
      "geospatial_control": {
        "allowed_locations": [
          {
            "type": "office",
            "name": "Oficina Regional Norte — Bilbao",
            "network_ranges": ["192.168.10.0/24", "192.168.11.0/24"],
            "coordinates": {
              "latitude":      43.2627,
              "longitude":    -2.9253,
              "radius_meters": 150
            }
          },
          {
            "type": "home_office",
            "name": "Residencia Registrada — Getxo",
            "network_ranges": ["81.44.200.0/24"],
            "coordinates": {
              "latitude":      43.3563,
              "longitude":    -3.0106,
              "radius_meters": 75
            }
          },
          {
            "type":              "vpn",
            "name":              "Red VPN Corporativa ACME",
            "network_ranges":    ["10.10.0.0/16"],
            "coordinates":       null,
            "physical_location": null
          }
        ],
        "validation_rules": {
          "require_vpn":               true,
          "require_corporate_network": false,
          "allow_roaming":             false
        }
      },

      // Control temporal → Time-based Policy en Keycloak.
      "temporal_control": {
        "schedule_type": "SPECIFIC_DAYS",
        "allowed_days": [
          {"day": "MONDAY",    "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "TUESDAY",   "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "WEDNESDAY", "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "THURSDAY",  "shifts": [{"start": "08:00", "end": "18:00"}]},
          {"day": "FRIDAY",    "shifts": [{"start": "08:00", "end": "15:00"}]}
        ],
        "timezone": "Europe/Madrid",
        "exceptions": {
          "holidays":     "BLOCKED",
          "special_dates": [
            {"date": "2025-07-25", "status": "BLOCKED", "reason": "Cierre semestral"},
            {"date": "2025-12-31", "status": "BLOCKED", "reason": "Cierre anual"}
          ]
        },
        "session_management": {
          "max_session_duration":       28800,
          "inactivity_timeout":           900,
          "force_logout_at_end_shift":   true,
          "concurrent_sessions_allowed": false
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 5 — ACCESO FÍSICO (DOMINIO 2)
    // El RF registra esta config; sistemas físicos externos la leen.
    // ═══════════════════════════════════════════════════════════════
    "physical_access": {
      "zones": [
        {
          "zone_id":   "ZONE-NORTE-01",
          "name":      "Oficina Regional Norte — Planta 3",
          "schedule":  "business_hours",
          "access_level": "FULL"
        },
        {
          "zone_id":   "ZONE-SERVER-01",
          "name":      "Sala de Servidores",
          "schedule":  "never",
          "access_level": "DENIED"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 6 — PRIVILEGIOS EN TRYTON (5 NIVELES)
    // El RF traduce este bloque a configuraciones nativas de Tryton.
    // Nivel 1: ir.model.access — CRUD por modelo
    // Nivel 2: ir.action.groups — menús y acciones visibles
    // Nivel 3: ir.model.field.access — campos visibles/editables
    // Nivel 4: ir.model.button — botones con condiciones PYSON y SoD
    // Nivel 5: ir.rule.group — filtros automáticos de datos (Record Rules)
    // ═══════════════════════════════════════════════════════════════
    "tryton_privileges": {

      "sequence_access": [
        {"sequence_type": "sale.order",    "can_edit": false},
        {"sequence_type": "account.invoice","can_edit": false}
      ],

      "model_access": [
        {"model": "sale.order",        "read": true, "write": true, "create": true,  "delete": false},
        {"model": "sale.opportunity",  "read": true, "write": true, "create": true,  "delete": false},
        {"model": "account.invoice",   "read": true, "write": false,"create": false, "delete": false},
        {"model": "account.payment",   "read": true, "write": true, "create": true,  "delete": false},
        {"model": "party.party",       "read": true, "write": true, "create": true,  "delete": false},
        {"model": "stock.shipment.out","read": true, "write": false,"create": false, "delete": false},
        {"model": "res.user",          "read": false,"write": false,"create": false, "delete": false}
      ],

      "visible_actions": [
        "menu_sale_orders",
        "menu_sale_opportunities",
        "menu_sale_reports_regional",
        "menu_party_customers",
        "menu_stock_shipments_view",
        "menu_account_payment_view",
        "menu_dashboard_ventas_norte",
        "report_sales_regional_monthly",
        "report_sales_team_performance",
        "wizard_sale_order_confirm"
      ],

      "field_restrictions": [
        {"model": "account.invoice", "field": "margin",               "read": false, "write": false},
        {"model": "account.invoice", "field": "cost_center",          "read": false, "write": false},
        {"model": "sale.order",      "field": "internal_notes_finance","read": false, "write": false},
        {"model": "party.party",     "field": "credit_limit_amount",  "read": true,  "write": false}
      ],

      "button_rules": [
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  1,
          "condition_pyson": "Eval('amount_total', 0) <= 10000",
          "step_up_loa":     null
        },
        {
          "model":           "sale.order",
          "button":          "confirm",
          "users_required":  2,
          "condition_pyson": "Eval('amount_total', 0) > 10000",
          "step_up_loa":     3
        },
        {
          "model":           "account.payment",
          "button":          "approve",
          "users_required":  2,
          "condition_pyson": "Eval('amount', 0) > 5000",
          "step_up_loa":     3
        }
      ],

      "record_rules": [
        {
          "model":       "sale.order",
          "domain_pyson":"[('team.territory', '=', 'NORTH')]",
          "description": "Solo ve pedidos de su territorio"
        },
        {
          "model":       "party.party",
          "domain_pyson":"[('category', 'in', ['CUSTOMER', 'PROSPECT'])]",
          "description": "Solo ve clientes y prospectos, no proveedores"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 7 — TRANSACCIONES FINANCIERAS (DOMINIO 3)
    // Nivel adicional de autenticación para operaciones financieras.
    // step_up_loa → Keycloak verifica LoA antes de operar.
    // transaction_limits → Button Rules en Tryton (Nivel 4).
    // ═══════════════════════════════════════════════════════════════
    "financial_transactions": {
      "availableMethods": [
        "smart_card_pin",
        "mobile_token",
        "biometric_validation"
      ],
      "requiredMethods": {
        "standard_transactions": [
          {"method": "smart_card_pin", "order": 1},
          {"method": "mobile_token",   "order": 2}
        ],
        "high_value_transactions": [
          {"method": "smart_card_pin",      "order": 1},
          {"method": "mobile_token",         "order": 2},
          {"method": "biometric_validation", "order": 3}
        ]
      },
      "transaction_schedule": {
        "type": "SCHEDULED",
        "schedules": [
          {
            "name": "Pagos Quincenales",
            "periods": [
              {"days_of_month": [13, 14, 15], "hours": {"start": "09:00", "end": "16:00"}},
              {"days_of_month": [28, 29, 30, 31], "hours": {"start": "09:00", "end": "16:00"}}
            ]
          }
        ],
        "emergency_override": {
          "allowed":           true,
          "requires_approval": true,
          "approver_roles":    ["FINANCE_DIRECTOR", "CEO"]
        }
      },
      "transaction_limits": {
        "single_transaction_limit": 10000,
        "daily_limit":              50000,
        "monthly_limit":           200000,
        "per_period_limit":        100000
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 8 — DELEGACIÓN DE PRIVILEGIOS
    // Define bajo qué condiciones este rol puede delegar temporalmente
    // sus privilegios a otro rol.
    // ═══════════════════════════════════════════════════════════════
    "delegation_config": {
      "can_delegate":    true,
      "max_duration_days": 21,
      "delegable_to_roles": ["SUPERVISOR-NORTE-001", "GERENTE-VENTAS-SUR"],
      "requires_approval": true,
      "approver_roles":    ["DIRECTOR_VENTAS"],
      "delegation_history": [
        {
          "id":           "DEL-2024-003",
          "delegated_to": {"user_id": "JUAN.PEREZ", "role_id": "SUPERVISOR-NORTE-001"},
          "period":       {"start_date": "2024-12-20T00:00:00Z", "end_date": "2025-01-07T23:59:59Z"},
          "outcome":      "SUCCESSFUL",
          "approved_by":  "DGV-CARLOS.RUIZ"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 9 — COMPLIANCE Y AUDITORÍA
    // ═══════════════════════════════════════════════════════════════
    "compliance_audit": {
      "compliance_reviews": {
        "last_review":      "2025-01-01T00:00:00Z",
        "next_review":      "2025-07-01T00:00:00Z",
        "review_frequency": "SEMIANNUAL"
      },
      "change_tracking": [
        {
          "change_id":    "CHG-2025-003",
          "timestamp":    "2025-03-01T10:30:00Z",
          "element_type": "PERMISSION",
          "element_id":   "PAYMENT_APPROVAL",
          "change_type":  "MODIFY",
          "old_value":    {"single_transaction_limit": 8000},
          "new_value":    {"single_transaction_limit": 10000},
          "reason":       "Ajuste por inflación Q1 2025",
          "approved_by":  "CFO"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 10 — ESTADO DE SINCRONIZACIÓN
    // Gestionado por el RF. No editable por el admin.
    // PENDING: cambio detectado, sincronización pendiente.
    // SYNCED:  KC y Tryton reflejan exactamente este RolTemplate.
    // ERROR:   falló la sincronización, detalle en sync_error.
    // DRIFT:   KC o Tryton tienen un estado diferente al esperado.
    // ═══════════════════════════════════════════════════════════════
    "sync_state": {
      "sync_status":  "SYNCED",
      "last_sync_at": "2025-03-01T10:35:00Z",
      "sync_targets": {
        "keycloak": {
          "status":         "SYNCED",
          "last_sync_at":   "2025-03-01T10:35:00Z",
          "composite_role": "RGV_001",
          "group_path":     "/Empresa-ACME/Ventas/Norte"
        },
        "tryton": {
          "status":       "SYNCED",
          "last_sync_at": "2025-03-01T10:35:22Z",
          "group_id":     847,
          "group_name":   "RGV_001"
        }
      },
      "sync_error": null
    }

  }
}
```

---

## ANEXO B

### UserTemplate-SBOS-v1.json — Especificación Completa

El siguiente JSON es el contrato formal del `UserTemplate`. El ejemplo corresponde a la usuaria `María García`, Gerente Regional de Ventas Norte, con el RolTemplate `RGV-001` asignado.

```json
{
  "user": {

    // ═══════════════════════════════════════════════════════════════
    // PRINCIPIO DE DISEÑO DEL USERTEMPLATE
    //
    // El UserTemplate NO duplica lo que ya vive en el RolTemplate.
    // La regla de separación es precisa:
    //
    //   RolTemplate → define QUÉ PUEDE HACER un tipo de rol
    //                 (políticas, privilegios, horarios, límites)
    //
    //   UserTemplate → define QUIÉN ES y QUÉ TIENE un usuario concreto
    //                  (credenciales, dispositivos, datos personales,
    //                   qué roles tiene asignados y su estado actual)
    //
    // Lo que el RF necesita del UserTemplate para sincronizar KC+Tryton:
    //   - username (KC: preferred_username)
    //   - email (KC: email claim)
    //   - roles_assignments.active_roles → qué grupos asignar en KC y Tryton
    //   - keycloak_credentials → qué métodos tiene REGISTRADOS
    //   - tryton_binding → employee_id, company, language
    //   - status → ACTIVE/INACTIVE controla si se habilita en KC y Tryton
    // ═══════════════════════════════════════════════════════════════

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 1 — IDENTIFICACIÓN DEL USUARIO
    // uuid → Keycloak sub claim. Identificador inmutable en todo el SBOS.
    // username → KC preferred_username, Tryton login
    // external_id → ID en sistema de RRHH externo para sincronización
    // ═══════════════════════════════════════════════════════════════
    "id":          1001,
    "uuid":        "550e8400-e29b-41d4-a716-446655440000",
    "username":    "maria.garcia",
    "external_id": "EMP789456",
    "status":      "ACTIVE",
    "version":     "1.1.0",

    "audit": {
      "created_by": "ADMIN.SISTEMA",
      "created_at": "2024-01-15T08:00:00Z",
      "updated_by": "ADMIN.SISTEMA",
      "updated_at": "2025-03-01T10:00:00Z"
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 2 — DATOS PERSONALES
    // Van a Keycloak como user profile attributes y se mapean a
    // OIDC claims estándar (OpenID Connect Core spec).
    // También van a Tryton como party.party del empleado.
    // ═══════════════════════════════════════════════════════════════
    "personal_info": {
      "given_name":   "María",
      "family_name":  "García López",
      "email":        "maria.garcia@acme.com",
      "email_verified": true,
      "phone_number": "+34 600 123 456",
      "locale":       "es-ES",
      "zoneinfo":     "Europe/Madrid",
      "addresses": [
        {
          "type":        "work",
          "street":      "Alameda de Mazarredo 61",
          "city":        "Bilbao",
          "state":       "País Vasco",
          "country":     "ES",
          "postal_code": "48009",
          "is_primary":  true
        },
        {
          "type":       "home",
          "street":     "Calle Algorta 12, 3ºA",
          "city":       "Getxo",
          "state":      "País Vasco",
          "country":    "ES",
          "postal_code":"48990",
          "is_primary": false
        }
      ],
      "emergency_contacts": [
        {
          "name":         "Carlos García López",
          "relationship": "spouse",
          "phone":        "+34 600 123 457"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 3 — INFORMACIÓN PROFESIONAL
    // Van a Tryton como datos del company.employee y res.user.
    // También como custom attributes en KC para claims adicionales.
    // ═══════════════════════════════════════════════════════════════
    "professional_info": {
      "employee_id":   "EMP-ACME-2024-156",
      "position":      "Gerente Regional de Ventas — Norte",
      "department":    "Ventas",
      "cost_center":   "VEN-NORTE-001",
      "territory":     "NORTH",
      "company_id":    "ACME-001",
      "company_name":  "Empresa ACME S.A.",
      "supervisor_id": "DGV-CARLOS.RUIZ",
      "language":      "es",
      "employment": {
        "start_date": "2024-01-15",
        "end_date":   null,
        "type":       "full-time",
        "status":     "active"
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 4 — FIRMA DIGITAL DEL USERTEMPLATE
    // El RF verifica esta firma antes de procesar cualquier
    // sincronización del usuario.
    // ═══════════════════════════════════════════════════════════════
    "digital_signature": {
      "signature":              "MEQCIAx7z3...base64_encoded...pQ3mNwR==",
      "algorithm":              "SHA512withRSA",
      "certificate_thumbprint": "b4:f3:55:02:c4:09:35:b1:2e:cc:34:55:g2:01:3d:23",
      "timestamp":              "2025-03-01T10:00:00Z",
      "quantum_resistant": {
        "enabled":   true,
        "algorithm": "CRYSTALS-Dilithium",
        "key_size":  4096
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 5 — CREDENCIALES DE AUTENTICACIÓN REGISTRADAS
    // CRÍTICO: esto define QUÉ TIENE REGISTRADO el usuario concreto.
    // No es lo mismo que lo que el RolTemplate REQUIERE — eso es la
    // política del rol.
    // El RF valida que lo registrado cubre los requiredMethods del rol.
    // ═══════════════════════════════════════════════════════════════
    "keycloak_credentials": {
      "totp": {
        "registered":   true,
        "registered_at":"2024-01-15T09:00:00Z",
        "algorithm":    "SHA1",
        "digits":       6,
        "period":       30
      },
      "webauthn": {
        "registered":   true,
        "credentials": [
          {
            "id":              "cred-001",
            "type":            "platform",
            "description":     "Touch ID — MacBook Pro trabajo",
            "registered_at":   "2024-01-15T09:05:00Z",
            "aaguid":          "adce0002-35bc-c60a-648b-0b25f1f05503"
          }
        ]
      },
      "password": {
        "registered":    true,
        "last_changed":  "2025-01-15T08:00:00Z",
        "expires_at":    "2025-07-15T00:00:00Z",
        "policy_version":"2025-01"
      },
      "backup_codes": {
        "registered":   true,
        "remaining":    6,
        "generated_at": "2024-01-15T09:10:00Z"
      },
      "smart_card": {
        "registered":    true,
        "card_id":       "SC-ACME-2024-0156",
        "certificate_dn":"CN=maria.garcia,OU=Ventas,O=ACME,C=ES",
        "expiry":        "2027-01-15"
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 6 — COMPLIANCE DE CREDENCIALES
    // El RF usa esto para detectar cuando un usuario no cubre los
    // requiredMethods de su RolTemplate → alerta al admin.
    // ═══════════════════════════════════════════════════════════════
    "credentials_compliance": {
      "covers_required_methods": true,
      "gaps": [],
      "last_verified":    "2025-03-07T09:05:00Z",
      "next_verification":"2025-06-07T00:00:00Z",
      "details": {
        "username_password":   "COVERED",
        "2fa_app":             "COVERED",
        "biometric_login":     "COVERED",
        "smart_card_logical":  "COVERED",
        "smart_card_physical": "COVERED"
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 7 — DISPOSITIVOS Y REDES DE CONFIANZA
    // device_id puede ser un KC custom attribute para correlación.
    // trusted_networks se usa para validar la JavaScript Policy de geo.
    // ═══════════════════════════════════════════════════════════════
    "devices": [
      {
        "device_id":   "DEV-2024-MGARCL-001",
        "type":        "laptop",
        "os":          "macOS 14.3",
        "model":       "MacBook Pro M3",
        "registered_at":"2024-01-15T09:30:00Z",
        "trusted":     true,
        "mdm_enrolled": true,
        "compliance_status": "COMPLIANT"
      },
      {
        "device_id":    "DEV-2024-MGARCL-002",
        "type":         "mobile",
        "os":           "iOS 17.4",
        "model":        "iPhone 15 Pro",
        "registered_at":"2024-01-15T09:45:00Z",
        "trusted":      true,
        "mdm_enrolled": true,
        "compliance_status": "COMPLIANT"
      }
    ],
    "trusted_networks": [
      {"name": "VPN Corporativa ACME", "range": "10.10.0.0/16"},
      {"name": "Oficina Bilbao",        "range": "192.168.10.0/24"}
    ],

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 8 — ASIGNACIONES DE ROL
    // active_roles → RF asigna en KC grupo path + en Tryton grupo name canónico
    // temporary_assignments → asignación temporal con vigencia
    // history → historial para reportes y decisiones de reasignación
    // ═══════════════════════════════════════════════════════════════
    "roles_assignments": {
      "active_roles": [
        {
          "role_id":       "RGV-001",
          "role_name":     "Gerente Regional de Ventas — Norte",
          "assigned_date": "2024-01-15T00:00:00Z",
          "expiry_date":   "2025-12-31T23:59:59Z",
          "assigned_by":   "ADMIN.SISTEMA",
          "approved_by":   "DGV-CARLOS.RUIZ",
          "status":        "ACTIVE",
          "kc_group_path": "/Empresa-ACME/Ventas/Norte",
          "tryton_group":  "RGV_001"
        }
      ],
      "temporary_assignments": [
        {
          "role_id":       "BUDGET_APPROVER_NORTE",
          "role_name":     "Aprobador de Presupuesto Temporal",
          "start_date":    "2025-04-01T00:00:00Z",
          "end_date":      "2025-04-30T23:59:59Z",
          "assigned_by":   "DGV-CARLOS.RUIZ",
          "reason":        "Cobertura cierre Q1 2025",
          "status":        "SCHEDULED",
          "kc_group_path": "/Empresa-ACME/Finanzas/Aprobadores",
          "tryton_group":  "BUDGET_APPROVER_NORTE"
        }
      ],
      "history": [
        {
          "role_id":       "VENDEDOR-NORTE-001",
          "role_name":     "Vendedor Norte",
          "assigned_date": "2020-01-15T00:00:00Z",
          "removed_date":  "2024-01-14T23:59:59Z",
          "assigned_by":   "HR_SISTEMA",
          "removed_by":    "HR_SISTEMA",
          "reason":        "PROMOTION"
        }
      ]
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 9 — BINDING CON SISTEMAS (Keycloak + Tryton)
    // Centraliza los IDs técnicos del usuario en cada sistema.
    // El RF los usa para hacer upsert idempotente.
    // Estos valores los escribe el RF — no los edita el admin.
    // ═══════════════════════════════════════════════════════════════
    "system_bindings": {
      "keycloak": {
        "user_id":    "550e8400-e29b-41d4-a716-446655440000",
        "realm":      "ACME-PROD",
        "username":   "maria.garcia",
        "enabled":    true
      },
      "tryton": {
        "user_id":    847,
        "employee_id":1203,
        "company_id": 1,
        "language":   "es"
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 10 — PREFERENCIAS DE UI
    // Se propagan a Tryton como res.user preferences.
    // No afectan privilegios — son de UX solamente.
    // ═══════════════════════════════════════════════════════════════
    "ui_preferences": {
      "language": {"preferred": "es", "fallback": "en"},
      "theme":    {"mode": "light", "color_scheme": "blue", "font_size": "medium"},
      "notifications": {
        "email":   true,
        "push":    true,
        "desktop": true,
        "quiet_hours": {"enabled": true, "start": "18:30", "end": "08:00"}
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 11 — COMPLIANCE Y CERTIFICACIONES DEL USUARIO
    // El RF puede bloquear la asignación de un rol si el usuario
    // no tiene las certificaciones requeridas completadas.
    // ═══════════════════════════════════════════════════════════════
    "compliance_control": {
      "certifications": [
        {
          "id":       "CERT-ISO27001-2024",
          "name":     "ISO 27001 — Seguridad de la Información",
          "status":   "current",
          "issued":   "2024-01-24",
          "expiry":   "2026-01-24",
          "required": true,
          "issuer":   "Bureau Veritas"
        },
        {
          "id":       "CERT-GDPR-2025",
          "name":     "GDPR Training Anual",
          "status":   "current",
          "issued":   "2025-01-10",
          "expiry":   "2026-01-10",
          "required": true,
          "issuer":   "ACME Training"
        }
      ],
      "training_status": {
        "required_courses": [
          {
            "id":       "SEC-2025-001",
            "name":     "Security Awareness 2025",
            "deadline": "2025-06-30",
            "status":   "pending"
          }
        ],
        "completed_courses": [
          {
            "id":             "SEC-2024-001",
            "name":           "Security Awareness 2024",
            "completed_date": "2024-11-15",
            "score":          95
          }
        ]
      },
      "territorial_compliance": {
        "primary_jurisdiction":    "ES",
        "applicable_regulations": ["GDPR", "LOPDGDD", "PSD2"],
        "data_residency": {
          "personal_data":  "EU",
          "financial_data": "ES"
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 12 — ESTADO OPERACIONAL DEL USUARIO
    // Solo lectura para el admin. Poblado por el sistema.
    // Alimenta Wazuh SIEM para correlación de incidentes.
    // ═══════════════════════════════════════════════════════════════
    "operational_state": {
      "last_access": {
        "logical":  "2025-03-07T09:15:00Z",
        "physical": "2025-03-07T08:55:00Z"
      },
      "security_incidents": {
        "count":         1,
        "last_incident": "2025-02-12T22:10:00Z",
        "last_type":     "LOGIN_OUTSIDE_SCHEDULE",
        "resolved":      true
      },
      "physical_logical_correlation": {
        "enabled": true,
        "last_event": {
          "type":            "NORMAL_ENTRY",
          "physical":        "2025-03-07T08:50:00Z",
          "logical":         "2025-03-07T09:05:00Z",
          "delta_minutes":   15,
          "anomaly":         false
        }
      }
    },

    // ═══════════════════════════════════════════════════════════════
    // BLOQUE 13 — ESTADO DE SINCRONIZACIÓN DEL USUARIO
    // Gestionado exclusivamente por el RF.
    // PENDING: cambio detectado, sincronización pendiente
    // SYNCED:  KC y Tryton reflejan exactamente este UserTemplate
    // ERROR:   falló la sync, detalle en sync_error
    // DRIFT:   un sistema tiene estado diferente al esperado
    // ═══════════════════════════════════════════════════════════════
    "sync_state": {
      "sync_status":  "SYNCED",
      "last_sync_at": "2025-03-01T10:05:12Z",
      "sync_targets": {
        "keycloak": {
          "status":       "SYNCED",
          "last_sync_at": "2025-03-01T10:05:00Z",
          "user_id":      "550e8400-e29b-41d4-a716-446655440000"
        },
        "tryton": {
          "status":       "SYNCED",
          "last_sync_at": "2025-03-01T10:05:12Z",
          "user_id":      847,
          "employee_id":  1203
        }
      },
      "sync_error": null
    }

  }
}
```

---

## Registro de Cambios

### v1.0 — Marzo 2026

**Acción:** Creación del documento formal SBOS-009 a partir de las fuentes:
- `RolTemplate-SBOS-v2.json` — incluido íntegro como Anexo A con comentarios arquitectónicos
- `UserTemplate-SBOS-v1.json` — incluido íntegro como Anexo B con comentarios arquitectónicos
- `MANUAL-INTEGRACION-ROLFRAMEWORK-v1.1` — expandido en secciones §1, §2, §3, §4, §5

**Contenido nuevo en v1.0:**
- §1 Propósito — contexto arquitectónico de por qué contratos declarativos
- §2 Separación de responsabilidades — tabla comparativa formal con consecuencias técnicas
- §3 Ciclo de vida del RolTemplate — estados, transiciones, regla ROLF-001
- §4 Ciclo de vida del UserTemplate — estados KC+Tryton, creación, cambio de rol, drift
- §5 Proceso de creación de un RolTemplate nuevo — 6 pasos desde conversación organizacional hasta activación
- §6 Catálogo inicial de RolTemplates — 10 plantillas para 5 sectores objetivo de SBOS

**Numeración:** Documento renumerado de JSONs aislados a SBOS-009 formal.

---

*SKULL · SBOS · SBOS-009 — Contratos de Identidad · v1.0 · Marzo 2026*
*CONFIDENCIAL — Propiedad de SKULL Desarrollo de Software*
*Prohibida su reproducción total o parcial sin autorización*
-e 
---

## Catálogo de Roles por Sector Industrial

> **Integrado desde SBOS-MP01 PARTE B en v2.0.**

## PARTE B — Para insertar en SBOS-009: Catálogo de Roles por Sector Industrial

### B.1 Sector Manufactura

| Rol | Descripción | Módulos con acceso | Nivel de acceso | SPI relevante |
|-----|-------------|-------------------|----------------|---------------|
| **Gerente de Producción** | Supervisa toda la cadena de producción | Tryton (Manufacturing), OrangeHRM (Read), SBOS AI Tools (analyst) | Full en manufactura, Read en RRHH | SkbosRolFrameworkProvider |
| **Operario de Planta** | Ejecuta órdenes de producción | Tryton (Manufacturing — solo su área), OrangeHRM (portal empleado) | Restricted — solo órdenes asignadas | SkbosBehavioralScoreAuthenticator |
| **Jefe de Almacén** | Gestiona inventario y logística | Tryton (Inventory, Purchase), OrangeHRM (Read) | Full en inventario | SkbosRolFrameworkProvider |
| **Contador** | Contabilidad y reportes financieros | Tryton (Accounting, Invoicing), SBOS Data Integration (View) | Full en contabilidad | SkbosRolFrameworkProvider |
| **Responsable RRHH** | Gestión de empleados | OrangeHRM (Full), Tryton (Party — Read) | Full en RRHH, Read en ERP | SkbosRolFrameworkProvider |
| **Auditor Interno** | Solo lectura de todo el sistema | Tryton (Read All), OrangeHRM (Read), SBOS AI Tools (report) | Read-only global | SkbosTimeWindowAuthenticator |

### B.2 Sector Servicios

| Rol | Descripción | Módulos con acceso | Nivel de acceso | SPI relevante |
|-----|-------------|-------------------|----------------|---------------|
| **Director de Operaciones** | Supervisa servicios y contratos | Tryton (All), OrangeHRM (Read), SBOS AI Tools (analyst/report) | Full en operaciones | SkbosRolFrameworkProvider |
| **Gestor de Clientes** | Gestión de relaciones y contratos | Tryton (Party, Sale, Contract), EspoCRM (Full) | Full en CRM y ventas | SkbosBehavioralScoreAuthenticator |
| **Técnico de Campo** | Ejecuta órdenes de servicio | Tryton (Service Orders — asignadas), SBOS VDI (móvil) | Restricted por asignación | SkbosGeoFencingAuthenticator |
| **Facturador** | Emite y envía facturas | Tryton (Invoicing, SBOS Data Integration — Submit), SBOS Data Integration (Bolivia/AR/MX) | Full en facturación | SkbosRolFrameworkProvider |
| **Administrador TI** | Gestión del propio tenant SBOS | Core UI (Full), Grafana (Read), Keycloak (Realm Admin) | Admin del tenant | Keycloak Admin |

### B.3 Sector Comercial / Retail

| Rol | Descripción | Módulos con acceso | Nivel de acceso | SPI relevante |
|-----|-------------|-------------------|----------------|---------------|
| **Gerente de Tienda** | Supervisa operaciones de venta | Saleor (Full), Tryton (Inventory, Accounting — Read), OrangeHRM (Read) | Full en retail | SkbosRolFrameworkProvider |
| **Vendedor** | Atención al cliente y ventas | Saleor (Orders, Customers), Tryton (Inventory — Read) | Restricted a su área/turno | SkbosTimeWindowAuthenticator + SkbosBehavioralScoreAuthenticator |
| **Cajero** | Procesa pagos y cierres de caja | Saleor (Checkout, Payments) | Muy restringido — solo flujo de caja | SkbosTimeWindowAuthenticator (horario de turno) |
| **Jefe de Inventario** | Gestiona stock y compras | Tryton (Inventory, Purchase), Saleor (Products — Read) | Full en inventario | SkbosRolFrameworkProvider |
| **E-Commerce Manager** | Gestiona tienda online | Saleor (Full), SBOS AI Tools (analyst) | Full en Saleor | SkbosRolFrameworkProvider |
| **Customer Service** | Atención post-venta y devoluciones | Saleor (Orders — Read, Returns), EspoCRM (Full) | Restricted — no puede ver precios de costo | SkbosRolFrameworkProvider |

---

