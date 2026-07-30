# A.65.03.01.02 — Informe de Completitud: D01 Control de Acceso Lógico

**Versión:** 1.8.0 · **Fecha:** 2026-07-30
**Tipo:** Informe de completitud de dominio
**SSOT bloques:** `bauth.idn_roles_template` — VPS SBOSDB (path `skull.D01.*`)
**SSOT DDL:** `SBOS_db_V2_DDL.sql` v2.0.0 + `SBOS_db_V2_DDL_MANUAL.md` v2.7.0
**Estado de D01:** ⚠️ PARCIAL — 7/9 bloques satisfechos · **5/5 gaps IAM Enterprise cerrados** ✅ · Catálogo de átomos completo ✅ · Implementación ⏸ vía árbol roles template

> **Metodología:** ver A.65.03.01.01 §1. Criterios C1–C7 aplicados a cada bloque.
> **T-code range:** T-200..T-219 (prefijo `idn_acceso_*`)

---

## 1. Metodología de completitud

Ver A.65.03.01.01 §1 — metodología, criterios C1–C7 y tabla de estados. No se duplica aquí.

---

## 2. Estado global de D01

**Dominio:** Control de Acceso Lógico | **Pipeline:** NÚCLEO (PDP + grants + SoD)
**Total bloques:** 9 | **Con átomos actuales:** 0 (depth=3 vacío — ver §14.4)

| Bloque | Slug | Nombre | Estado | Tablas que lo satisfacen |
|--------|------|--------|--------|--------------------------|
| B01 | `authorization` | Evaluación PDP | ✅ SATISFECHO | `privilege_atom_grant` + `privilege_resource_atom` + `privilege_atom_audit` |
| B02 | `roles` | Gestión Ciclo de Vida de Roles | ✅ SATISFECHO | `idn_roles_rol_hierarchical` + `idn_roles_rol_lifecycle_event` (D00/S4) |
| B03 | `zones` | Cumplimiento de Zonas de Aplicación | ✅ SATISFECHO | `idn_roles_template` (árbol de políticas — `business_zone` depth=2) |
| B04 | `fields` | Acceso a Nivel de Campo | ⚠️ PARCIAL | T-500 ✅ VPS · árbol T-162 nodo B04 ✅ · átomos depth=3+ pendientes · T-171 obligations pendientes · **T-200 descartado** |
| B05 | `contracts` | Contratos de Acceso | ⚠️ PARCIAL | T-201 ✅ VPS · trigger WORM ✅ · FK `privilege_atom_grant.contrato_id` ✅ · átomos B05 pendientes |
| B06 | `session` | Sesión Lógica | ✅ SATISFECHO | `ses_session_log` (D08) + `ctx_id` obligatorio SBOS-049 |
| B07 | `certification` | Recertificación de Accesos | ✅ SATISFECHO | `aud_certification_campaign` + `aud_certification_review` |
| B08 | `dynamic_policy` | Política Dinámica ABAC | ⚠️ PARCIAL | `ses_risk_policy` — cubre riesgo adaptativo; falta evaluador ABAC completo |
| B09 | `business_zone` | Registro de Zona de Negocio | ✅ SATISFECHO | `idn_roles_template` (nodo tipo `business_zone` en árbol) |

**Tablas implementadas en S8 (DDL NIVEL 7):** `privilege_verb` · `privilege_verb_conflict` ·
`privilege_atom_grant` · `privilege_resource_atom` · `privilege_delegation` ·
`privilege_override` · `privilege_assurance_audit` · `privilege_exception_record` ·
`privilege_atom_audit` (WORM particionada)

---

## 3. B01 — `authorization` · Evaluación PDP

### 3.1 Definición del bloque

**Propósito:** Motor algebraico NIST RBAC Nivel 3 (Constrained). Evalúa si un actor puede ejecutar un verbo sobre un recurso en un dominio, dado su BitmaskBundle actual + contexto de sesión. Latencia objetivo: < 0.5 ns (BitMask OR inline). Incluye: PAP (árbol de políticas), PDP (evaluación), PEP (Kong), PIP (proyección de grants).

**Normas:** NIST RBAC N3 (ANSI INCITS 359-2004) · XACML 3.0 · NIST SP 800-207 §3 · ISO 27001 A.9.4.1

### 3.2 Tablas que satisfacen B01

| T-code | Tabla | Columnas clave | Criterios |
|--------|-------|----------------|-----------|
| T-162 | `bauth.idn_roles_template` | `path`, `verb_id`, `effect`, `atom_position`, `condition_expr` | C1 C2 C3 C4 C5 ✅ |
| T-171 | `bauth.privilege_resource_atom` | `tipo_protocolo`, `recurso`, `operacion`, `id_atom`, `domain_code`, `evaluation_path`, `obligation JSONB`, `tenant_scope` | C1 C2 C3 C4 C5 C6 ✅ |
| T-170 | `bauth.privilege_atom_grant` | `user_id`, `role_id`, `id_atom`, `atom_position`, `bitmask_value`, `effect`, `grant_type`, `status`, `valid_from`, `valid_until`, `ctx_id` | C1 C2 C3 C4 C5 C6 C7 ✅ |
| T-170b | `bauth.privilege_atom_audit` | WORM particionada — hash-chain SHA-256 | C1 C2 C3 ✅ |
| T-173 | `bauth.privilege_override` | `id_atom`, `atom_position`, `user_id`, `override_type`, `approver_id`, `valid_from`, `valid_until`, `status` | C1 C2 C3 ✅ |
| T-176 | `bauth.privilege_assurance_audit` | `grant_id`, `required_loa`, `presented_loa`, `outcome`, `session_id` | C1 C2 C3 ✅ |
| T-179 | `bauth.privilege_exception_record` | `policy_violated`, `exception_type`, `business_reason`, `approved_by`, `valid_until` | C1 C2 C3 ✅ |
| — | `bauth.privilege_verb` | `verb_id`, `descripcion`, `activo` — catálogo de verbos atómicos | C1 C5 ✅ |
| — | `bauth.privilege_verb_conflict` | `verb_a`, `verb_b`, `tipo` — Matriz de conflictos SoD | C1 C2 C4 ✅ |

### 3.3 Gap identificado

Ninguno — B01 está completamente cubierto por las tablas S8. El PDP en Rust evalúa el BitmaskBundle en < 0.5 ns usando las proyecciones de `privilege_atom_grant`. El PAP (`idn_roles_template`) alimenta al PDP con el árbol de políticas compilado.

### 3.4 Veredicto

**✅ SATISFECHO** — Criterios C1–C7 cumplidos. PAP + PDP + PEP + PIP implementados.

---

## 4. B02 — `roles` · Gestión del Ciclo de Vida de Roles

### 4.1 Definición del bloque

**Propósito:** Gestión completa del ciclo de vida de roles (DEFINIDO→ACTIVO→SUSPENDIDO→ARCHIVADO→RETIRADO). Incluye: catálogo de tipos (T-040), estructura maestra (T-041), tiers de seguridad (T-042), lifecycle WORM (T-B02L), recertificación IGA (T-194).

**Normas:** NIST RBAC N3 · ISO 27001 A.5.18 · NIST SP 800-53 AC-2(7)

### 4.2 Tablas que satisfacen B02

| T-code | Tabla | Columnas clave | Criterios |
|--------|-------|----------------|-----------|
| T-040 | `bauth.idn_roles_rol_type` | `type_code`, `name JSONB`, 10 tipos de cuenta | C1 C2 C4 C5 ✅ |
| T-041 | `bauth.idn_roles_rol_hierarchical` | `tenant_id`, `role_code`, `sector_code`, `role_owner_id`, `accountability_chain JSONB`, `approval_required` | C1 C2 C3 C4 C5 C6 ✅ |
| T-042 | `bauth.idn_roles_rol_tier` | Parámetros de seguridad por tier (11 tiers) | C1 C2 C4 C5 C6 ✅ |
| T-063 | `bauth.idn_roles_rol_closure` | Closure table DAG herencia OR | C1 C2 C4 ✅ |
| T-B02L | `bauth.idn_roles_rol_lifecycle_event` | WORM + hash-chain SHA-256 de transiciones de estado | C1 C2 C3 ✅ |
| T-194 | IGA campaigns | Campañas de recertificación de roles | C1 C2 ✅ |

### 4.3 Gap identificado

Ninguno — cubierto por S4 (NIVEL 3) del DDL. Todas las tablas implementadas en VPS.

### 4.4 Veredicto

**✅ SATISFECHO** — Ciclo de vida completo (7 estados), WORM, closure table, IGA.

---

## 5. B03 — `zones` · Cumplimiento de Zonas de Aplicación

### 5.1 Definición del bloque

**Propósito:** El árbol de políticas define Zonas de Aplicación (ZA) como nodos `depth=3` bajo `business_zone`. Cada ZA lista los átomos que corresponden a operaciones en esa zona. El PDP aplica la política de zona antes de evaluar el grant individual.

**Normas:** NIST SP 800-207 §3.3 (micro-segmentación lógica) · XACML 3.0 §6 · SBOS-050

### 5.2 Tablas que satisfacen B03

| T-code | Tabla | Evidencia | Criterios |
|--------|-------|-----------|-----------|
| T-162 | `bauth.idn_roles_template` | Nodos `business_zone` (depth=2) + átomos (depth=3) definen zonas y sus operaciones | C1 C2 C3 C4 ✅ |

### 5.3 Gap identificado

El árbol define las zonas y la evaluación se hace por árbol. Un recurso que pertenece a múltiples zonas requiere átomos de cada zona — el AND lógico lo resuelve el BitMask de forma nativa. **T-202 `idn_acceso_zona_policy` DESCARTADA** (viola D-07: la intersección de zonas es autorización → árbol). Ver GAP-D01-05 en §15.2.

### 5.4 Veredicto

**✅ SATISFECHO** — El árbol de políticas satisface C1–C4. La brecha de políticas de zona compuestas se documenta como GAP para §14.

---

## 6. B04 — `fields` · Acceso a Nivel de Campo

### 6.1 Definición del bloque

**Propósito:** Controlar qué campos de una entidad de datos puede leer/escribir/exportar un actor según su rol. Ej.: un operador puede ver `nombre` pero no `salario`; un gerente puede ver ambos. Capa por encima del acceso a tabla — acceso sub-registro.

**Normas:** ISO 27001 A.9.4.1 · GDPR Art. 5(1)(c) · NIST SP 800-53 AC-3(9) · XACML 3.0 §4 + §5.2 · NIST SP 800-162 §3.3 · SCIM 2.0 RFC 7643 §4

---

### 6.2 Decisión arquitectónica — por qué T-200 fue descartado

El informe v1.0.0 propuso crear T-200 `idn_acceso_field_policy` como tabla separada con columnas `can_read`, `can_write`, `can_export`, `display_mask`, `field_classification`.

**Esta propuesta fue evaluada contra los estándares internacionales y el principio D-07 de A.65.02.01 §14, y descartada.** Los fundamentos:

**Principio D-07 (A.65.02.01 §14) — regla irrenunciable de este sistema:**
> *"Si la tabla define QUÉ ES la aplicación o QUÉ PUEDE HACER → no necesita tabla (vive en el árbol). Si la tabla registra QUÉ PASÓ → necesita tabla."*

El acceso a un campo ("puede leer `salario`") es una **definición de QUÉ PUEDE HACER** un actor. Por lo tanto vive en el árbol T-162, no en una tabla separada. T-200 crearía una duplicación de lógica de autorización con T-162: dos fuentes de verdad para el mismo concepto.

**Confirmación de estándares internacionales:**

| Estándar | Prescripción | Consecuencia para B04 |
|----------|-------------|----------------------|
| **XACML 3.0 §4** | Las decisiones de autorización se expresan como Policy/Rule | `can_read = true` para un atributo de identidad es una Rule → átomo en T-162 |
| **XACML 3.0 §5.2 Obligations** | Los efectos secundarios de una decisión (ej: LoA mínimo) son `Obligations` attached a la Rule | La obligation vive en T-171 como metadato del átomo — se pobla al crear el átomo vía interfaz |
| **NIST SP 800-53 AC-3(9)** | Access enforcement a nivel de objeto/atributo se expresa como control de acceso nativo del modelo | El "modelo" aquí es el árbol BitMask → átomo por campo en T-162 |

**T-200 no se crea.** El rango T-200..T-219 queda reservado para D01 pero T-200 no se asigna.

---

### 6.3 Solución canónica: árbol de roles template como única fuente de verdad

**Decisión arquitectónica final (2026-07-30):** Todo el control de acceso a nivel de campo reside **exclusivamente en el árbol `idn_roles_template` (T-162)**. No existe ningún mecanismo separado fuera del árbol para definir qué puede hacer un actor sobre un campo.

> `T-500 idn_registro_atributo_schema` tiene un propósito diferente (schema registry del modelo EAV de identidad D00) y **NO se usa como mecanismo de control de acceso para B04**. Sus registros se actualizan en sincronía con el árbol de roles template, no de forma independiente para este bloque.

---

#### 6.3.1 Átomos en T-162 — decisión de autorización

Cada combinación `campo × verbo` se convierte en un **átomo** (nodo `tipo=evaluacion`) en T-162 bajo el bloque B04.

**Convención de path canónico:**
```
skull.D01.fields.<attr_namespace>.<attr_key>.<verbo>
```

Los `attr_namespace` y `attr_key` corresponden exactamente a los de `idn_identity_attribute` (T-157). Los campos de identidad no son columnas fijas: son filas EAV con namespace + key.

**Estructura del árbol para B04:**
```
skull                                            (depth=0, tipo=root)
└── D01                                          (depth=1, tipo=dominio)
    └── B04 · fields (block_code=B04)            (depth=2, tipo=bloque) ← YA EXISTE EN VPS
        ├── core                                 (depth=3, tipo=grupo) ← namespace EAV
        │   ├── national_id                      (depth=4, tipo=grupo) ← attr_key EAV
        │   │   ├── skull.D01.fields.core.national_id.read   (depth=5, tipo=evaluacion)
        │   │   └── skull.D01.fields.core.national_id.export (depth=5, tipo=evaluacion)
        │   └── birth_date
        │       └── skull.D01.fields.core.birth_date.read    (depth=5, tipo=evaluacion)
        ├── contact
        │   ├── email
        │   │   └── skull.D01.fields.contact.email.read      (depth=5, tipo=evaluacion)
        │   └── phone
        │       └── skull.D01.fields.contact.phone.read      (depth=5, tipo=evaluacion)
        └── fiscal
            └── nit
                └── skull.D01.fields.fiscal.nit.read         (depth=5, tipo=evaluacion)
```

**Reglas de `atom_position`:**
- Solo los nodos `tipo=evaluacion` reciben `atom_position` via `SEQUENCE bauth.roles_atom_position_sequential`
- Los nodos `tipo=grupo` (namespace, attr_key) NO tienen `atom_position` — son agrupadores de navegación
- El position es INMUTABLE una vez asignado y NUNCA se recicla

**⚠️ SUSPENDIDO:** Los átomos de campo NO se insertan manualmente por SQL. Se crean a través del constructor visual AtomLang (dashboard Flutter + `atomc`). La interfaz gestiona el árbol completo incluyendo T-171 obligations en sincronía. Ver manual 2.13 AtomLang.

---

### 6.4 Separación de responsabilidades — tabla resumen

| Pregunta | Mecanismo | Tabla | Quién la usa |
|----------|-----------|-------|-------------|
| ¿Puede este actor LEER el atributo `national_id`? | Árbol + Grant | T-162 + T-170 | PDP (bAuth BitMask engine) |
| ¿Qué LoA mínimo se requiere? | Obligation del átomo | T-171 `obligation.required_loa` — poblado al crear el átomo vía interfaz | PEP (Kong) |

**T-200 no existe. T-500 no aplica a B04.** Todo el control de acceso a nivel de campo vive en el árbol T-162.

---

### 6.5 Flujo de evaluación completo — paso a paso

El siguiente flujo describe la evaluación de una solicitud de lectura del atributo `national_id` (EAV en T-157):

```
PASO 1 — Solicitud llega a Kong
  Actor → GET /api/identity/{entity_id}/attributes
  Kong intercepta. Necesita decidir qué atributos incluir en la respuesta.

PASO 2 — Kong consulta T-171 para cada attr_key sensible
  SELECT id_atom, atom_position, obligation
  FROM bauth.privilege_resource_atom
  WHERE recurso = 'bauth.idn_identity_attribute:field:core.national_id'
    AND operacion = 'read'
    AND tenant_id = '<tenant del actor>';
  → Resultado: id_atom=<uuid>, atom_position=<N>, obligation={required_loa:'AAL2', mask_fallback:'DENY'}

PASO 3 — Kong verifica BitMask del actor (desde Redis)
  BitmaskBundle del actor tiene el bit en position=<N>:
  a) bit=0 → DENY → Kong no incluye `national_id` en la respuesta ✅
  b) bit=1 → PERMIT → continúa a evaluación de obligation

PASO 4 — Kong evalúa obligation (solo si PERMIT)
  actor.current_loa (del JWT) vs obligation.required_loa:
  a) actor.loa >= 'AAL2' → LoA suficiente → atributo en claro ✅
  b) actor.loa < 'AAL2' → LoA insuficiente → Kong aplica mask_fallback ('DENY' = omite el campo)

PASO 5 — Kong devuelve respuesta filtrada al actor
  Solo los atributos para los que bit=1 Y loa suficiente se incluyen.
  bAuth NO interviene en el filtrado en runtime — solo emite el JWT con el BitmaskBundle.

INVARIANTE DE LATENCIA:
  bAuth: evaluación BitMask < 0.5ns (lookup de bits en el BitmaskBundle)
  Kong: filtrado por atributo sin llamar a bAuth en runtime
  bAuth SOLO es llamado nuevamente si el BitmaskBundle fue invalidado por CAEP.
```

---

### 6.6 Verbos válidos para átomos de campo

Los verbos que un átomo de campo puede tener:

| Verbo | Semántica | Ejemplo de atributo EAV |
|-------|-----------|------------------------|
| `read` | Ver el valor del atributo | `core.national_id.read` → ver la cédula |
| `write` | Modificar el valor del atributo | `core.national_id.write` → editar el CI (restringido) |
| `export` | Incluir el atributo en exportaciones (CSV/PDF/report) | `fiscal.nit.export` → exportar el NIT |
| `filter_by` | Usar el atributo como criterio de búsqueda | `contact.email.filter_by` → buscar por email |
| `mask` | Ver el atributo enmascarado (sin el valor real) | `core.national_id.mask` → ver `****-**-####` en lugar del CI |

**Nota:** `mask` como verbo existe para casos en que mostrar la máscara es en sí un privilegio diferente a `read`. Los atributos corresponden al modelo EAV de `idn_identity_attribute` (T-157): namespace `core`, `contact`, `fiscal`, `professional`, `verification`, `security`.

---

### 6.7 Tablas involucradas en B04

| T-code | Tabla | Rol en B04 | Norma |
|--------|-------|-----------|-------|
| T-162 | `bauth.idn_roles_template` | PAP — átomos `skull.D01.fields.<ns>.<key>.<verbo>` + nodos grupo | XACML 3.0 §4 |
| T-170 | `bauth.privilege_atom_grant` | Grant de átomos de campo a roles/usuarios | NIST AC-3(9) |
| T-171 | `bauth.privilege_resource_atom` | Mapeo recurso:field:atributo → átomo + obligation (poblado vía interfaz al crear el átomo) | XACML 3.0 §5.2 |

**T-200 NO SE CREA. T-500 NO aplica a B04.** Todo el control de acceso a nivel de campo vive en T-162.

### 6.8 Estado actual

El bloque B04 tiene el nodo raíz `skull.D01.fields` (depth=2, block_code=B04) en T-162 — **ya existe en VPS**.

**Átomos y T-171:** SUSPENDIDOS — no se insertan manualmente. Se crean a través del constructor visual AtomLang (dashboard Flutter + compilador `atomc`). La interfaz gestiona la creación de nodos grupo (depth=3,4), átomos (depth=5) y sus obligations en T-171 de forma sincronizada. Ver manual 2.13 AtomLang.

**T-500:** NO aplica a este bloque. Su propósito es otro.

**Los atributos objetivo** cuando la interfaz esté disponible son los `attr_key` del modelo EAV de T-157: `core.national_id`, `core.birth_date`, `contact.email`, `contact.phone`, `fiscal.nit`, `verification.biometric_ref`, entre otros.

### 6.9 Veredicto

**✅ CERRADO ARQUITECTURALMENTE** — Decisión canónica establecida: control de acceso a nivel de campo = átomos en T-162 exclusivamente, con obligations en T-171 creadas en sincronía por la interfaz. T-200 descartado. T-500 no aplica a B04. Implementación SUSPENDIDA hasta que el constructor visual AtomLang esté operativo.

---

## 7. B05 — `contracts` · Contratos de Acceso

### 7.1 Definición del bloque

**Propósito:** Formalizar el contrato de gobernanza entre un actor y sus permisos: quién aprobó, bajo qué justificación de negocio, con qué vigencia y con qué revisión programada. Es el registro de auditoría IGA que justifica la existencia de los grants — diferente del grant en sí (que controla el acceso en runtime) y de la delegación puntual (`privilege_delegation`).

**Normas:** ISO 27001 A.9.2.2 · NIST SP 800-53 AC-2 · PCI DSS 4.0 Req 7.2 · SOX §404 · ISO/IEC 24760-2:2025 §6

---

### 7.2 Decisión arquitectónica — ¿tabla o árbol?

Aplicando el mismo criterio D-07 que se aplicó a B04 (GAP-D01-01):

> *"Si define QUÉ PUEDE HACER → árbol. Si registra QUÉ PASÓ / POR QUÉ → tabla."*

Un contrato de acceso registra:
- Quién solicitó y quién aprobó el acceso (firmantes)
- Bajo qué justificación de negocio
- Con qué vigencia y revisión programada
- El estado del proceso de gobernanza (BORRADOR → ACTIVO → EXPIRADO/REVOCADO)

Esto es **QUÉ PASÓ y POR QUÉ** — registro de gobernanza, no regla de autorización. **T-201 sí corresponde a una tabla separada.** Los estándares son explícitos:

| Norma | Qué exige | Tipo de registro |
|-------|-----------|-----------------|
| **ISO 27001 A.9.2.2** | "Formal access provisioning process — document justification" | Registro de decisión de gobernanza → tabla |
| **NIST SP 800-53 AC-2(a)** | "Document [justification] for each account including approval process" | Cadena de aprobación con firmantes → tabla |
| **PCI DSS 4.0 Req 7.2.1** | "All user accounts and access privileges reviewed at least every 6 months" | Tracking de revisión periódica → tabla |
| **SOX §404** | "Document internal controls over financial reporting" | Aprobaciones formales con historial → tabla |
| **ISO/IEC 24760-2:2025 §6** | "Access rights shall be documented with justification and approval" | Registro de aprobación separado → tabla |

**Diferencia clave con GAP-D01-01:** field access define QUÉ PUEDE HACER (→ árbol); el contrato documenta QUÉ FUE DECIDIDO Y POR QUÉ (→ tabla). No hay conflicto entre las dos decisiones — cada una cumple D-07 correctamente.

---

### 7.3 Tablas existentes

**Ninguna.** `privilege_atom_grant` tiene `reason TEXT` y `granted_by UUID` pero no un contrato formal. Deficiencias concretas de `reason TEXT`:

| Qué falta | Consecuencia en auditoría |
|-----------|--------------------------|
| Sin firmante de negocio (solo técnico) | ISO 27001 A.9.2.2 exige aprobación de propietario del recurso |
| Sin referencia a política formal | PCI DSS Req 7.2 exige trazar hasta una política aprobada |
| Sin ciclo de revisión programado independiente | PCI DSS Req 7.2.1 exige revisión cada 6 meses con trazabilidad |
| Sin estado de ciclo de vida del contrato | SOX §404 exige evidenciar que el acceso tiene vigencia controlada |
| Sin inmutabilidad de la justificación | ISO 27001 A.8.15 exige protección contra modificación no autorizada |

---

### 7.4 Gap identificado

**T-201 `idn_access_contract`** — ✅ IMPLEMENTADA EN VPS (migración 004, 2026-07-29). Trigger WORM `trg_iac_protect_active` ✅. FK inversa `privilege_atom_grant.contrato_id` ✅. Ver §12.2 para DDL completo.

**Átomos B05** (`skull.D01.contracts.*`) — ⏸ pendientes de validación vía árbol de roles template. Cuando el árbol sea actualizable (interfaz AtomLang operativa), los procesos/triggers propagarán las operaciones `create`, `approve`, `revoke`, `review` como átomos en T-162 y sus obligations correspondientes en T-171.

---

### 7.5 Veredicto

**✅ CERRADO ARQUITECTURALMENTE** — T-201 implementada en VPS con DDL completo, trigger WORM e integración con T-170 (FK `contrato_id`). Decisión D-07 aplicada: T-201 registra QUÉ PASÓ/POR QUÉ (gobernanza), no QUÉ PUEDE HACER (autorización). Átomos B05 pendientes de validación vía árbol de roles template.

---

## 8. B06 — `session` · Sesión Lógica

### 8.1 Definición del bloque

**Propósito:** Ciclo de vida de la sesión lógica: `ctx_id` generado en login → mantenido en cada request → terminado por logout/timeout/revocación CAEP. Incluye: método de autenticación, LoA inicial y pico, IP, user agent, razón de terminación.

**Normas:** NIST SP 800-63B §7 (Session Management) · CAEP RFC 8935 · SBOS-049 (ctx_id)

### 8.2 Tablas que satisfacen B06

| T-code | Tabla | Columnas clave | Criterios |
|--------|-------|----------------|-----------|
| T-181 | `bauth.ses_session_log` | `session_id`, `user_id`, `auth_method`, `loa_initial`, `loa_peak`, `ip_address`, `started_at`, `last_active_at`, `terminated_at`, `termination_reason`, `ctx_id` | C1 C2 C3 C4 C5 C6 ✅ |
| T-191 | `bauth.ses_caep_event_log` | Eventos CAEP de sesión (revocación, step-up) | C1 C2 C3 ✅ |
| T-192 | `bauth.ses_ssf_stream` | Streams SSF para entrega de eventos CAEP | C1 C2 ✅ |
| — | `ctx_id` | Campo obligatorio en toda tabla (SBOS-049) | C5 C6 ✅ |

### 8.3 Veredicto

**✅ SATISFECHO** — Ciclo de vida completo de sesión lógica + CAEP + SSF + ctx_id SBOS-049.

---

## 9. B07 — `certification` · Recertificación de Accesos

### 9.1 Definición del bloque

**Propósito:** Campañas periódicas de revisión de accesos (IGA) — un revisor decide CERTIFY/REVOKE/ESCALATE sobre cada grant activo. Obligatorio para ISO 27001 A.9.2.5 y PCI DSS Req 7.2.3.

**Normas:** ISO 27001 A.9.2.5 · NIST SP 800-53 AC-2(7) · PCI DSS 4.0 Req 7.2.3

### 9.2 Tablas que satisfacen B07

| T-code | Tabla | Columnas clave | Criterios |
|--------|-------|----------------|-----------|
| T-177 | `bauth.aud_certification_campaign` | `campaign_type`, `scope_type`, `scope_id`, `initiated_by`, `due_date`, `status` | C1 C2 C3 C4 C5 ✅ |
| T-178 | `bauth.aud_certification_review` | `campaign_id`, `grant_id`, `reviewer_id`, `decision` (CERTIFY/REVOKE/ESCALATE), `justification`, `reviewed_at`, `revocation_at` | C1 C2 C3 C4 C5 ✅ |

### 9.3 Veredicto

**✅ SATISFECHO** — Campaña + revisión implementadas. Cubre IGA access review completo.

---

## 10. B08 — `dynamic_policy` · Política Dinámica ABAC

### 10.1 Definición del bloque

**Propósito:** Evaluación de atributos en tiempo real (ABAC): el PDP enriquece la decisión con contexto dinámico (hora, IP, postura de dispositivo, score de riesgo) además del BitmaskBundle estático. Habilita el modelo "never trust, always verify" de Zero Trust.

**Normas:** NIST SP 800-207 §3.3 (ZTA) · XACML 3.0 §4 (ABAC) · NIST SP 800-162 (ABAC guide)

### 10.2 Tablas existentes

| T-code | Tabla | Columnas clave | Cobertura |
|--------|-------|----------------|-----------|
| T-180 | `bauth.ses_risk_policy` | `tier_id`, `trigger_event`, `condition JSONB`, `action`, `required_loa`, `priority` | ⚠️ Parcial — cubre riesgo adaptativo, no ABAC puro |

### 10.3 Decisión arquitectónica — T-203 DESCARTADA

**T-203 `idn_acceso_abac_policy` fue propuesta y descartada.** Aplica el mismo principio D-07 que rechazó T-200:

> *"Si define QUÉ PUEDE HACER → árbol (T-162). Si registra QUÉ PASÓ → tabla separada."*

Una regla ABAC como `subject.department == resource.owner_department` define QUÉ PUEDE HACER un actor bajo ciertas condiciones → es autorización → vive en el árbol, no en una tabla separada.

**T-162 ya tiene `condition_expr JSONB`** diseñado exactamente para esto: el compilador AtomLang genera el JSON AST de la condición y lo almacena en el átomo. El PDP evalúa `condition_expr` en runtime junto con el BitMask. No hay necesidad de una tabla separada que duplicaría la lógica de autorización del árbol.

**Sobre el ejemplo temporal (`env.time BETWEEN '09:00' AND '18:00'`):** las condiciones temporales no son ABAC genérico — pertenecen al **dominio D04 (Temporal)**. Las restricciones de horario, vigencia y ventanas de tiempo son responsabilidad de D04, que define sus propios átomos con `condition_expr` temporal en T-162.

**T-180 `ses_risk_policy` se mantiene** — cubre riesgo adaptativo (`trigger_event → action`), que es un mecanismo ortogonal al árbol: no define QUÉ PUEDE HACER sino cómo reacciona el sistema ante eventos de riesgo (step-up, bloqueo, alerta). No duplica T-162.

**Solución completa para B08:**

| Necesidad | Mecanismo | Tabla |
|-----------|-----------|-------|
| ABAC condición sobre atributos del sujeto/recurso | `condition_expr` del átomo, compilado por AtomLang | T-162 |
| Condición temporal (horario, vigencia) | `condition_expr` del átomo — responsabilidad D04 | T-162 |
| Riesgo adaptativo (step-up, bloqueo por anomalía) | Trigger → action | T-180 `ses_risk_policy` |

### 10.4 Veredicto

**✅ CERRADO ARQUITECTURALMENTE** — T-203 DESCARTADA (viola D-07). Las condiciones ABAC viven en `condition_expr JSONB` de los átomos en T-162, compiladas por AtomLang. Las condiciones temporales pertenecen a D04. T-180 cubre el riesgo adaptativo ortogonal. No hay duplicación ni dispersión de datos.

---

## 11. B09 — `business_zone` · Registro de Zona de Negocio

### 11.1 Definición del bloque

**Propósito:** Registro de las Zonas de Negocio (aplicaciones/módulos) bajo este dominio dentro del árbol de políticas. Cada ZN es un nodo `depth=2` con `tipo='business_zone'` en `idn_roles_template`.

**Normas:** SBOS arquitectura · SBOS-050 Port Catalog

### 11.2 Tablas que satisfacen B09

| T-code | Tabla | Evidencia | Criterios |
|--------|-------|-----------|-----------|
| T-162 | `bauth.idn_roles_template` | Nodo `skull.D01.business_zone` (depth=2, block_code=B09, alias=`business_zone`) | C1 C2 C4 ✅ |

### 11.3 Veredicto

**✅ SATISFECHO** — El nodo de zona de negocio existe en el árbol. Listo para recibir aplicaciones concretas (depth=3 business zones).

---

## 12. DDL de tablas faltantes

### 12.1 T-200 · DESCARTADO — B04 se implementa mediante átomos en T-162

**⚠️ DECISIÓN ARQUITECTÓNICA IRRENUNCIABLE — NO CREAR T-200**

T-200 `idn_acceso_field_policy` fue propuesto en v1.0.0 de este informe y **rechazado** al evaluarse contra los estándares internacionales y el principio D-07 de A.65.02.01 §14.

**Razón del rechazo:**
- T-200 define QUÉ PUEDE HACER un actor → debe vivir en el árbol T-162 (principio D-07)
- T-200 mezclaría autorización (can_read, can_write) con metadatos de atributo (display_mask, field_classification), violando la separación PDP/PIP de XACML 3.0 y NIST SP 800-162 §3.3
- T-200 crearía una segunda fuente de verdad de autorización paralela al árbol T-162, rompiendo la coherencia del modelo BitMask

**Implementación correcta de B04:** ver §6 completo (átomos + T-171 obligation + T-500).

**Rango T-200..T-219** queda reservado para D01 pero T-200 en específico no se asigna.

**Resumen de la solución por tabla:**

| Necesidad | Tabla | Columna clave |
|-----------|-------|--------------|
| Autorización: ¿puede leer el campo? | T-162 `idn_roles_template` | átomo `skull.D01.fields.<tabla>.<campo>.read` con `atom_position` |
| Grant: ¿a quién se le asignó el átomo? | T-170 `privilege_atom_grant` | `id_atom`, `atom_position`, `bitmask_value` |
| Obligation: ¿qué hace Kong si PERMIT? | T-171 `privilege_resource_atom` | `obligation = {required_loa, mask_ref, mask_fallback}` |
| Clasificación y máscara del campo | T-500 `idn_registro_atributo_schema` | `clasificacion`, `display_mask`, `returned` |

### 12.2 T-201 · `bauth.idn_access_contract` (B05 — ✅ IMPLEMENTADA VPS) — DDL canónico

**Bloque:** D01-B05 `contracts` · **Nivel DDL:** NIVEL 8 (después de T-170 `privilege_atom_grant`)

**Propósito:** Registro de gobernanza formal que documenta quién aprobó un acceso, con qué justificación de negocio, bajo qué política, hasta cuándo y con qué revisión programada. No controla el acceso en runtime (eso es T-170) — es el artefacto de auditoría IGA exigido por ISO 27001 A.9.2.2 / PCI DSS / SOX.

**Tres correcciones aplicadas respecto a v1.0.0:**
1. `grant_ids UUID[]` **eliminado** — la relación se navega por FK inversa en T-170 (`privilege_atom_grant.contrato_id`), evitando anti-patrón de array y permitiendo JOINs eficientes en auditoría
2. `CONSTRAINT chk_iac_subject` **agregado** — al menos role_id O id_atom debe estar presente (no puede existir un contrato sin sujeto definido)
3. `version_number` + trigger WORM **agregados** — ISO 27001 A.8.15 exige que los registros de control de acceso estén protegidos contra modificación no autorizada; los campos de gobernanza son inmutables una vez el contrato pasa a ACTIVO

```sql
-- ============================================================
-- T-201 · idn_access_contract
-- ============================================================
CREATE TABLE IF NOT EXISTS bauth.idn_access_contract (
    contrato_id          UUID PRIMARY KEY DEFAULT uuidv7(),
    tenant_id            UUID NOT NULL
        REFERENCES bauth.idn_tenant(tenant_id) ON DELETE CASCADE,

    -- Tipo de contrato de gobernanza
    tipo                 TEXT NOT NULL
        CONSTRAINT chk_iac_tipo CHECK (tipo IN (
            'ACCESO_ROL',        -- Contrato para grant de rol completo
            'ACCESO_ATOMICO',    -- Contrato para grant de átomo individual
            'ACCESO_TEMPORAL',   -- Acceso con expiración definida (D04)
            'ACCESO_EMERGENCIA', -- Breakglass temporal (requiere aprobación posterior)
            'ACCESO_DELEGADO'    -- Delegación de acceso (D10)
        )),

    -- Beneficiario del contrato (el actor que recibe el acceso)
    beneficiario_id      UUID NOT NULL
        REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,

    -- Sujeto: el rol O el átomo al que aplica el contrato (al menos uno obligatorio)
    role_id              UUID NULL
        REFERENCES bauth.idn_roles_rol_hierarchical(id) ON DELETE SET NULL,
    id_atom              UUID NULL
        REFERENCES bauth.idn_roles_template(id) ON DELETE SET NULL,
    -- CORRECCIÓN 1: constraint de integridad del sujeto — no puede ser ambos NULL
    CONSTRAINT chk_iac_subject CHECK (role_id IS NOT NULL OR id_atom IS NOT NULL),

    -- Estado del ciclo de vida del contrato
    -- Solo `estado`, `proxima_revision` y `revisor_id` son mutables después de ACTIVO
    estado               TEXT NOT NULL DEFAULT 'BORRADOR'
        CONSTRAINT chk_iac_estado CHECK (estado IN
            ('BORRADOR','ACTIVO','SUSPENDIDO','EXPIRADO','REVOCADO')),

    -- Justificación formal de negocio (INMUTABLE una vez estado != BORRADOR)
    justificacion_negocio TEXT NOT NULL,
    politica_ref         TEXT NULL,    -- código de política interna (ej: 'POL-IAM-007-v2')

    -- Firmantes (INMUTABLES una vez estado != BORRADOR)
    solicitante_id       UUID NOT NULL
        REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    aprobador_id         UUID NOT NULL
        REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE RESTRICT,
    aprobado_at          TIMESTAMPTZ NULL,   -- NULL mientras está en BORRADOR

    -- Vigencia del acceso
    valid_from           TIMESTAMPTZ NOT NULL DEFAULT now(),
    valid_until          TIMESTAMPTZ NULL,   -- NULL = indefinido (requiere revisión periódica)

    -- Revisión programada (mutable — se actualiza en cada ciclo IGA)
    proxima_revision     TIMESTAMPTZ NULL,
    revisor_id           UUID NULL
        REFERENCES bauth.idn_identity_entity(entity_id) ON DELETE SET NULL,

    -- CORRECCIÓN 2: integridad documental (ISO 27001 A.8.15)
    -- version_number se incrementa en cada UPDATE; los campos de gobernanza son inmutables
    version_number       INTEGER NOT NULL DEFAULT 1,
    hash_anterior        TEXT NULL,    -- SHA-256 del estado anterior (chain de integridad)

    -- Auditoría estándar SBOS
    ctx_id               TEXT NOT NULL DEFAULT 'system',
    created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Índices para consultas frecuentes de auditoría y gobernanza
CREATE INDEX IF NOT EXISTS idx_iac_beneficiario ON bauth.idn_access_contract(beneficiario_id);
CREATE INDEX IF NOT EXISTS idx_iac_estado       ON bauth.idn_access_contract(estado);
CREATE INDEX IF NOT EXISTS idx_iac_revision     ON bauth.idn_access_contract(proxima_revision)
    WHERE proxima_revision IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iac_role         ON bauth.idn_access_contract(role_id)
    WHERE role_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iac_atom         ON bauth.idn_access_contract(id_atom)
    WHERE id_atom IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_iac_vigencia     ON bauth.idn_access_contract(tenant_id, valid_until)
    WHERE valid_until IS NOT NULL;

-- ============================================================
-- CORRECCIÓN 3: Trigger WORM de campos de gobernanza
-- Protege los campos de justificación y firmantes una vez que el contrato
-- pasa de BORRADOR a cualquier otro estado (ISO 27001 A.8.15).
-- Los campos mutables permitidos después de ACTIVO: estado, proxima_revision, revisor_id.
-- ============================================================
CREATE OR REPLACE FUNCTION bauth.fn_iac_protect_active()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF OLD.estado <> 'BORRADOR' THEN
        IF (NEW.tipo                  IS DISTINCT FROM OLD.tipo                  OR
            NEW.beneficiario_id       IS DISTINCT FROM OLD.beneficiario_id       OR
            NEW.role_id               IS DISTINCT FROM OLD.role_id               OR
            NEW.id_atom               IS DISTINCT FROM OLD.id_atom               OR
            NEW.justificacion_negocio IS DISTINCT FROM OLD.justificacion_negocio OR
            NEW.politica_ref          IS DISTINCT FROM OLD.politica_ref          OR
            NEW.solicitante_id        IS DISTINCT FROM OLD.solicitante_id        OR
            NEW.aprobador_id          IS DISTINCT FROM OLD.aprobador_id          OR
            NEW.aprobado_at           IS DISTINCT FROM OLD.aprobado_at           OR
            NEW.valid_from            IS DISTINCT FROM OLD.valid_from) THEN
            RAISE EXCEPTION
                '[bAuth][T-201] Intento de modificar campos de gobernanza inmutables. contrato_id=%, estado_actual=%',
                OLD.contrato_id, OLD.estado;
        END IF;
    END IF;
    -- Siempre incrementar version_number y actualizar updated_at en cualquier UPDATE
    NEW.version_number := OLD.version_number + 1;
    NEW.updated_at     := now();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_iac_protect_active
    BEFORE UPDATE ON bauth.idn_access_contract
    FOR EACH ROW EXECUTE FUNCTION bauth.fn_iac_protect_active();

COMMENT ON TABLE bauth.idn_access_contract IS
  '[T-201] [D01-B05] [ISO 27001 A.9.2.2] [NIST SP 800-53 AC-2] [PCI DSS 4.0 Req 7.2] [SOX §404] [ISO/IEC 24760-2:2025 §6]
   Registro de gobernanza formal — documenta quién aprobó un acceso, con qué justificación
   de negocio y hasta cuándo. Diferencia con privilege_atom_grant (T-170): el grant controla
   el acceso EN RUNTIME (bit en BitmaskBundle); este contrato documenta el PORQUÉ del acceso
   para auditoría IGA. Campos de gobernanza INMUTABLES una vez estado != BORRADOR
   (trigger trg_iac_protect_active). Relación con grants: FK inversa en T-170.contrato_id.';

-- ============================================================
-- MIGRACIÓN T-170: agregar FK contrato_id a privilege_atom_grant
-- Reemplaza el patrón anti-patrón grant_ids UUID[] de v1.0.0
-- La relación se navega desde T-170 hacia T-201, no al revés
-- ============================================================
ALTER TABLE bauth.privilege_atom_grant
    ADD COLUMN IF NOT EXISTS contrato_id UUID NULL
        REFERENCES bauth.idn_access_contract(contrato_id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_pag_contrato ON bauth.privilege_atom_grant(contrato_id)
    WHERE contrato_id IS NOT NULL;

COMMENT ON COLUMN bauth.privilege_atom_grant.contrato_id IS
    '[T-201 FK] Contrato de acceso que respalda este grant. NULL = grant sin contrato formal (legado o bootstrap). '
    'Para listar todos los grants de un contrato: SELECT * FROM privilege_atom_grant WHERE contrato_id = X;';
```

**Relación T-170 ↔ T-201 — navegación canónica:**

```sql
-- Listar todos los grants que respalda un contrato (JOIN eficiente, con índice)
SELECT pag.id, pag.user_id, pag.id_atom, pag.status, pag.valid_until
FROM bauth.privilege_atom_grant pag
WHERE pag.contrato_id = '<contrato_id>'
  AND pag.status = 'ACTIVE';

-- Encontrar el contrato que respalda un grant específico
SELECT iac.*
FROM bauth.idn_access_contract iac
JOIN bauth.privilege_atom_grant pag ON pag.contrato_id = iac.contrato_id
WHERE pag.id = '<grant_id>';

-- Contratos que vencen en los próximos 30 días (alerta de revisión)
SELECT beneficiario_id, justificacion_negocio, valid_until
FROM bauth.idn_access_contract
WHERE estado = 'ACTIVO'
  AND valid_until BETWEEN now() AND now() + INTERVAL '30 days';
```

### 12.3 T-203 · `bauth.idn_acceso_abac_policy` — ⚠️ DECISIÓN: DESCARTADA

**⚠️ DECISIÓN ARQUITECTÓNICA IRRENUNCIABLE — NO CREAR T-203**

T-203 `idn_acceso_abac_policy` fue propuesta en v1.0.0 de este informe y **descartada** al evaluarse contra el principio D-07 y la arquitectura de T-162.

**Razones del descarte:**

1. **Viola D-07:** T-203 definiría QUÉ PUEDE HACER un actor bajo condiciones ABAC → debe vivir en el árbol T-162, no en una tabla separada. Crear T-203 generaría una segunda fuente de verdad de autorización paralela al árbol, rompiendo la coherencia del modelo BitMask.

2. **`condition_expr JSONB` ya existe en T-162:** cada átomo puede llevar un JSON AST de condición compilado por AtomLang. El PDP evalúa `condition_expr` en runtime. No hay gap real — la infraestructura está disponible y se activa cuando los átomos se crean vía interfaz.

3. **Dispersión de datos:** T-203 replicaría lógica de autorización ya presente en el árbol. Toda condición que T-203 expresaría (`subject.department == X`, `resource.classification == Y`) puede expresarse como `condition_expr` en el átomo correspondiente, con mayor cohesión y sin JOIN adicional en tiempo de evaluación.

4. **Las condiciones temporales pertenecen a D04:** el ejemplo canónico de T-203 (`env.time BETWEEN '09:00' AND '18:00'`) es responsabilidad del dominio D04 (Temporal), que define sus propios átomos con `condition_expr` temporal. No es un caso genérico de ABAC en D01.

**Implementación correcta de B08:**
- Condiciones ABAC → `condition_expr JSONB` en los átomos de T-162 (compilado por AtomLang)
- Condiciones temporales → D04, con `condition_expr` temporal en sus átomos
- Riesgo adaptativo → T-180 `ses_risk_policy` (mecanismo ortogonal, no autorización)

**Rango T-203** queda libre en D01. No se asigna.

---

## 13. Estado de implementación

### 13.1 Tablas existentes en VPS (verificadas)

| Estado | T-code | Tabla | Versión |
|--------|--------|-------|---------|
| ✅ IMPLEMENTADA | T-162 | `idn_roles_template` | v2.0.0 |
| ✅ IMPLEMENTADA | T-170 | `privilege_atom_grant` | v2.0.0 |
| ✅ IMPLEMENTADA | T-170b | `privilege_atom_audit` | v2.0.0 (WORM particionada) |
| ✅ IMPLEMENTADA | T-171 | `privilege_resource_atom` | v2.0.0 |
| ✅ IMPLEMENTADA | T-172 | `privilege_delegation` | v2.0.0 |
| ✅ IMPLEMENTADA | T-173 | `privilege_override` | v2.0.0 |
| ✅ IMPLEMENTADA | T-176 | `privilege_assurance_audit` | v2.0.0 |
| ✅ IMPLEMENTADA | T-177 | `aud_certification_campaign` | v2.0.0 |
| ✅ IMPLEMENTADA | T-178 | `aud_certification_review` | v2.0.0 |
| ✅ IMPLEMENTADA | T-179 | `privilege_exception_record` | v2.0.0 |
| ✅ IMPLEMENTADA | T-180 | `ses_risk_policy` | v2.0.0 (B08 parcial) |
| ✅ IMPLEMENTADA | T-181 | `ses_session_log` | v2.0.0 (B06) |
| ✅ IMPLEMENTADA | — | `privilege_verb` | v2.0.0 |
| ✅ IMPLEMENTADA | — | `privilege_verb_conflict` | v2.0.0 |
| 🚫 DESCARTADA | T-200 | `idn_acceso_field_policy` | — · B04 se implementa con átomos en T-162 |
| ✅ IMPLEMENTADA | T-500 | `idn_registro_atributo_schema` | VPS 2026-07-29 · PIP para D01-B04 field-level access |
| ✅ IMPLEMENTADA | T-201 | `idn_access_contract` | VPS 2026-07-29 · trigger WORM + FK inversa en T-170 |
| 🚫 DESCARTADA | T-203 | `idn_acceso_abac_policy` | — · ABAC vive en `condition_expr` de T-162; temporales → D04 |

### 13.2 Bloques con referencia cruzada (compartidos)

- **B02 (roles):** S4 del DDL — tablas D00 (idn_roles_rol_hierarchical, etc.)
- **B06 (session):** S9 del DDL — tablas D08 (ses_session_log, ses_caep_event_log)
- **B07 (certification):** S10 del DDL — tablas D11 (aud_certification_campaign/review)
- **B09 (business_zone):** árbol `idn_roles_template` — compartido entre todos los dominios

---

## 14. Checklist de completitud

### 14.1 DDL (tablas)

- [x] `privilege_atom_grant` — tabla de grants ✅ (VPS)
- [x] `privilege_resource_atom` — PAP Kong ✅ (VPS)
- [x] `privilege_atom_audit` — WORM hash-chain particionada ✅ (VPS)
- [x] `privilege_delegation` — delegaciones ✅ (VPS)
- [x] `privilege_override` — overrides SoD ✅ (VPS)
- [x] `privilege_assurance_audit` — auditoría LoA ✅ (VPS)
- [x] `privilege_exception_record` — excepciones ✅ (VPS)
- [x] `privilege_verb` + `privilege_verb_conflict` ✅ (VPS)
- [x] B04 decisión arquitectónica establecida: **átomos en T-162**, NO T-200, NO T-500 ✅ CERRADO
- [x] B04 nodo raíz `skull.D01.fields` (depth=2, B04) ✅ EXISTE EN VPS
- [ ] B04 átomos `skull.D01.fields.<ns>.<key>.<verbo>` — ⏸ SUSPENDIDO (requiere interfaz AtomLang)
- [ ] B04 mappings en T-171 — ⏸ SUSPENDIDO (se crean junto con los átomos vía interfaz)
- [x] B05 decisión arquitectónica establecida: **T-201 es tabla separada** (registra QUÉ PASÓ/POR QUÉ — D-07) ✅ DECIDIDO
- [x] B05 DDL corregido: `grant_ids[]` eliminado → FK inversa `privilege_atom_grant.contrato_id` ✅ DECIDIDO
- [x] B05 `CONSTRAINT chk_iac_subject` agregado (role_id OR id_atom NOT NULL) ✅ DECIDIDO
- [x] B05 `version_number` + trigger WORM `trg_iac_protect_active` para ISO 27001 A.8.15 ✅ DECIDIDO
- [x] B05 CREATE T-201 `idn_access_contract` en VPS ✅ IMPLEMENTADA (migración 004)
- [x] B05 ALTER TABLE `privilege_atom_grant` ADD COLUMN `contrato_id` (FK a T-201) ✅ IMPLEMENTADA
- [ ] B05 átomos `skull.D01.contracts.*` — ⏸ pendientes de validación vía árbol de roles template
- [x] B08 decisión arquitectónica: **T-203 DESCARTADA** — ABAC vive en `condition_expr` de T-162; temporales → D04 ✅ CERRADO

### 14.2 Triggers

- [ ] Trigger: invalidar grants al archivar rol → `UPDATE privilege_atom_grant SET status='REVOKED'` cuando `idn_roles_rol_hierarchical` pasa a `ARCHIVED`
- [ ] Trigger: WORM en `privilege_atom_audit` ya implementado — verificar activo en VPS
- [ ] Trigger: recertificación vencida → marcar campaña `CLOSED_EXPIRED` si `due_date < now()` y `status = 'ACTIVE'`

### 14.3 Jobs automáticos

- [ ] Job: revisar grants con `valid_until < now()` y marcar `EXPIRED` (análogo a fn_job_reproofing_check)
- [ ] Job: alertar sobre revisiones de contrato próximas (`proxima_revision` en T-201 cuando exista)
- [ ] Job: cerrar campañas de recertificación vencidas

### 14.4 Catálogo de átomos D01 (especificación arquitectónica — implementación ⏸ SUSPENDIDO)

**Fuente de verdad en producción:** `idn_roles_template` T-162, campo `path`, depth=3 por átomo  
**Creación:** EXCLUSIVAMENTE vía interfaz AtomLang o compilador `atomc` — PROHIBIDO INSERT manual  
**Estado global:** Catálogo especificado ✅ · Implementación ⏸ suspendida hasta interfaz AtomLang L1→L3  
**Total estimado:** ~35 átomos distribuidos en 9 bloques

| Bloque | Path canónico | Verbos (átomos) | `condition_expr` notable | Notas |
|--------|--------------|-----------------|--------------------------|-------|
| **B01** `authorization` | `skull.D01.authorization.<verbo>` | `evaluate`, `grant`, `revoke`, `override` | `override`: requiere AAL3 (`{"aal": {"min": 3}}`) | Gobierno directo del PDP; `override` = privilegio elevado con doble aprobación |
| **B02** `roles` | `skull.D01.roles.<verbo>` | `create`, `read`, `configure`, `suspend`, `archive` | — | Gestión del ciclo de vida de roles (7 estados) |
| **B03** `zones` | `skull.D01.zones.<verbo>` | `register`, `configure`, `read` | — | Registro y configuración de zonas de aplicación |
| **B04** `fields` | `skull.D01.fields.<ns>.<attr_key>.<verbo>` | `read`, `write`, `mask`, `configure` | `write` en clasificación RESTRICTED: `{"attr_sensitivity": {"min": "RESTRICTED"}}` | Patrón por atributo EAV: `skull.D01.fields.core.national_id.read`; cada campo PII puede tener su propio átomo |
| **B05** `contracts` | `skull.D01.contracts.<verbo>` | `create`, `approve`, `revoke`, `review` | `approve`: SoD actor ≠ creador (`{"sod": {"not_creator": true}}`) | Gobernanza de T-201; `contrato_id` en T-170 vincula grant ↔ contrato |
| **B06** `session` | `skull.D01.session.<verbo>` | `read`, `terminate`, `extend` | `terminate`: requiere AAL2 mínimo (`{"aal": {"min": 2}}`) | Gestión de sesiones activas; `extend` = step-up RFC 9470 |
| **B07** `certification` | `skull.D01.certification.<verbo>` | `launch`, `certify`, `revoke`, `escalate` | — | Campañas IGA periódicas de recertificación de accesos |
| **B08** `dynamic_policy` | `skull.D01.dynamic_policy.<verbo>` | `configure`, `activate`, `evaluate`, `read` | `configure`: AAL3 + aprobación dual (`{"aal": {"min": 3}, "dual_approval": true}`) | Gestión de `condition_expr` en T-162; `evaluate` = test de condición ABAC en modo debug |
| **B09** `business_zone` | `skull.D01.business_zone.<verbo>` | `register`, `read` | — | Zonas de negocios raíz (depth=2 del árbol) |

**Nota B08 — T-203 descartada:** los átomos de `dynamic_policy` gestionan QUIÉN PUEDE modificar `condition_expr` en átomos existentes. No son la política ABAC en sí (esa vive en `condition_expr` de cada átomo), sino el meta-control de quién puede configurarla.

### 14.5 Seeds

- [ ] `privilege_verb` — seeds de verbos estándar (read, write, create, delete, configure, evaluate, approve, revoke, export, import)
- [ ] `privilege_verb_conflict` — seeds de conflictos SoD mínimos (approve↔execute, create↔audit, configure↔operate)
- [x] `~~idn_acceso_field_policy~~` — ELIMINADO (T-200 descartada; control de campo vía átomos T-162)

### 14.6 Criterio de aceptación global

| Nivel | Criterio | Estado |
|-------|----------|:------:|
| **DDL Core ✅** | B01/B02/B03/B06/B07/B09 satisfechos | ✅ |
| **DDL Cerrado** | T-200 DESCARTADO · T-201 ✅ VPS | ✅ |
| **ABAC Completo** | T-203 DESCARTADA · ABAC en `condition_expr` T-162 · temporales → D04 | ✅ |
| **Átomos D01** | 9 bloques × 3-5 átomos ≈ 35 átomos catalogados | ⏸ Catálogo ✅ · Impl. ⏸ vía árbol |
| **IAM Enterprise** | Ver §15 | ✅ 5/5 gaps cerrados arquitecturalmente |

---

## 15. Análisis IAM Enterprise — D01

### 15.1 Cobertura de pilares

D01 cubre principalmente **Pilar I — Authentication & Authorization Engine** y **Pilar II — IGA**:

| Pilar IAM Enterprise | Criterio relevante para D01 | Estado |
|---|---|:---:|
| **I AuthEngine** | PDP BitMask < 0.5ns | ✅ L3 |
| **I AuthEngine** | RBAC N3 + DAG herencia OR | ✅ L3 |
| **I AuthEngine** | SoD estático (verb_conflict) | ✅ L3 |
| **I AuthEngine** | SoD dinámico (override + exception) | ✅ L3 |
| **I AuthEngine** | ABAC contextual completo | ⏸ L2 — `condition_expr` en T-162 vía AtomLang; temporales → D04 |
| **I AuthEngine** | Field-level access control | ⏸ L1 — arquitectura cerrada, átomos vía árbol |
| **II IGA** | Recertificación IGA periódica | ✅ L3 |
| **II IGA** | Role lifecycle 7 estados | ✅ L3 |
| **II IGA** | Contratos de acceso formales | ⏸ L2 — T-201 ✅ VPS, átomos vía árbol |
| **III PAM** | Gestión de privilegios (ver D14) | → D14 |
| **VI Standards** | XACML 3.0 PAP/PDP/PEP/PIP | ✅ L3 |
| **VI Standards** | NIST SP 800-207 ZTA | ⚠️ L2 |

### 15.2 Gaps IAM Enterprise D01

#### GAP-D01-01 — Field-level Access Control `✅ CERRADO · Pilar I`

**Norma:** ISO 27001 A.9.4.1 · GDPR Art. 5(1)(c) · NIST SP 800-53 AC-3(9) · XACML 3.0 §4 + §5.2

**Decisión arquitectónica final (2026-07-30):** Control de acceso a nivel de campo = **átomos en T-162 exclusivamente**. Sin T-200, sin T-500 como mecanismo de acceso.

Los campos de identidad en bAuth son atributos EAV en `idn_identity_attribute` (T-157) con `attr_namespace.attr_key` (ej: `core.national_id`, `fiscal.nit`). Los átomos siguen el path `skull.D01.fields.<namespace>.<attr_key>.<verbo>` y se crean a través del constructor visual AtomLang (no por SQL directo).

**T-500 `idn_registro_atributo_schema`** tiene un propósito diferente (schema registry del modelo EAV — D98) y se actualiza en sincronía con el árbol de roles template, no como mecanismo independiente de control de acceso para B04.

**Por qué esta solución cumple las normas:**
- XACML 3.0 §4: reglas de autorización → átomos en T-162 ✅
- XACML 3.0 §5.2: obligations (LoA mínimo) → T-171, poblado vía interfaz ✅
- GDPR Art. 5(1)(c): minimización automatizada por PEP (Kong) con BitMask ✅
- A.65.02.01 D-07: QUÉ PUEDE HACERSE → árbol ✅

**Estado de implementación:** Arquitectura CERRADA · Nodo raíz B04 ✅ VPS · Átomos ⏸ SUSPENDIDO hasta interfaz AtomLang

#### GAP-D01-02 — Contratos de Acceso Formales `✅ CERRADO · Pilar II`

**Norma:** ISO 27001 A.9.2.2 · NIST SP 800-53 AC-2 · PCI DSS 4.0 Req 7.2 · SOX §404 · ISO/IEC 24760-2:2025 §6

**Decisión arquitectónica final (2026-07-30):** T-201 `idn_access_contract` es la solución correcta como tabla separada — registra QUÉ PASÓ/POR QUÉ (gobernanza IGA), no QUÉ PUEDE HACER (autorización). Principio D-07 aplicado: diferencia fundamental con GAP-D01-01 donde el campo va al árbol porque define autorización.

**DDL completo e implementado:**
- T-201 ✅ VPS (migración 004, 2026-07-29) con trigger WORM `trg_iac_protect_active` (ISO 27001 A.8.15)
- `privilege_atom_grant.contrato_id` ✅ VPS — FK inversa que navega T-170 → T-201 sin anti-patrón array
- `CONSTRAINT chk_iac_subject` ✅ — garantiza que todo contrato tiene sujeto (role_id OR id_atom)
- `version_number` + hash-chain ✅ — integridad documental de campos de gobernanza

**Átomos B05** (`skull.D01.contracts.*`): ⏸ pendientes de validación vía árbol de roles template. Cuando el árbol sea actualizable, los procesos propagarán los átomos `create`, `approve`, `revoke`, `review` a T-162 y sus obligations a T-171 de forma sincronizada.

**Estado:** DDL ✅ completo en VPS + canónico · Átomos ⏸ vía árbol roles template

#### GAP-D01-03 — ABAC Contextual Completo `✅ CERRADO · Pilar I`

**Norma:** NIST SP 800-162 (ABAC Guide) · XACML 3.0 §4 · NIST SP 800-207 §3.3

**Decisión arquitectónica final (2026-07-30):** T-203 `idn_acceso_abac_policy` **DESCARTADA**. Las condiciones ABAC no son una tabla separada — son `condition_expr JSONB` en el átomo correspondiente de T-162, compiladas por AtomLang y evaluadas por el PDP en runtime.

**Razonamiento D-07:** una regla ABAC define QUÉ PUEDE HACER un actor bajo ciertas condiciones → es autorización → vive en el árbol. T-203 hubiera creado una segunda fuente de verdad de autorización paralela al árbol, con duplicación de lógica y dispersión de datos.

**Condiciones temporales** (`env.time`, vigencia, ventanas horarias): pertenecen al **dominio D04 (Temporal)**, no a ABAC genérico en D01. D04 tiene sus propios átomos con `condition_expr` temporal.

**Cobertura real de B08:**
- ABAC sobre atributos → `condition_expr` en T-162 (activo cuando átomos se crean vía árbol)
- Riesgo adaptativo → T-180 `ses_risk_policy` (mecanismo ortogonal — reacciona a eventos, no define autorización)
- Condiciones temporales → D04

**Estado:** T-203 DESCARTADA · arquitectura cerrada · `condition_expr` T-162 + T-180 cubren B08 completamente

#### GAP-D01-04 — Átomos D01 en árbol `✅ CERRADO arquitectónicamente · Pilar I · L1`

**Norma:** SBOS arquitectura — árbol de políticas canónico · NIST SP 800-53 AC-3

**Decisión arquitectónica final (2026-07-30):** El catálogo completo de átomos para los 9 bloques de D01 ha sido especificado en §14.4. Esta especificación es el contrato que la interfaz AtomLang implementará cuando llegue a L3. La implementación (inserción real de átomos en T-162) queda **⏸ SUSPENDIDA** hasta que el árbol funcional sea editable.

**Principio central aplicado:** los átomos no se crean por INSERT SQL directo. El flujo es:
1. Interfaz visual AtomLang o compilador `atomc` → nodo en T-162 con `path`, `verb_id`, `effect`, `condition_expr`
2. Triggers/procesos propagan el cambio a tablas derivadas (T-171 obligations, cache BitMask)
3. El PDP evalúa en runtime mediante evaluación del BitMask precalculado

**Catálogo especificado (ver §14.4):**

| Bloque | Verbos principales | condition_expr clave |
|--------|-------------------|---------------------|
| B01 `authorization` | evaluate, grant, revoke, override | `override` → AAL3 |
| B02 `roles` | create, read, configure, suspend, archive | — |
| B03 `zones` | register, configure, read | — |
| B04 `fields` | read, write, mask, configure | `write` RESTRICTED → sensitivity check |
| B05 `contracts` | create, approve, revoke, review | `approve` → SoD actor ≠ creador |
| B06 `session` | read, terminate, extend | `terminate` → AAL2 mínimo |
| B07 `certification` | launch, certify, revoke, escalate | — |
| B08 `dynamic_policy` | configure, activate, evaluate, read | `configure` → AAL3 + aprobación dual |
| B09 `business_zone` | register, read | — |

**Estado:** Catálogo ✅ especificado en §14.4 · Implementación ⏸ SUSPENDIDO hasta interfaz AtomLang · ~35 átomos totales

#### GAP-D01-05 — Política de Zona Compuesta `✅ CERRADO · Pilar I`

**Norma:** NIST SP 800-207 §3.3 · XACML 3.0 §6

**Decisión arquitectónica final (2026-07-30):** T-202 `idn_acceso_zona_policy` **DESCARTADA**. Viola D-07 por el mismo razonamiento que T-203.

**Razonamiento:** La "política de zona compuesta" (recurso en zona A AND zona B) define QUÉ PUEDE HACERSE bajo ciertas condiciones de zona → es autorización → vive en el árbol T-162, no en una tabla separada.

**Cómo lo resuelve el modelo actual:**
- Un recurso que pertenece a múltiples zonas simplemente **requiere átomos de cada zona** en su evaluación.
- El PDP evalúa si el actor tiene todos los bits requeridos — el AND lógico entre zonas es el **AND nativo del BitMask**, no una tabla de intersección.
- No hay brecha real: el modelo BitMask ya cubre zona compuesta por diseño.

**Estado:** T-202 DESCARTADA · arquitectura BitMask cubre zona compuesta de forma nativa

### 15.3 Scorecard IAM Enterprise D01

| Gap | Prioridad | Acción | Estado |
|-----|-----------|--------|--------|
| GAP-D01-01 — Field-level access | 🟠 P1 | Arquitectura canónica: átomos en T-162 · T-500 NO aplica a B04 · nodo raíz B04 ✅ VPS · átomos ⏸ SUSPENDIDO (interfaz AtomLang) | ✅ CERRADO — arquitectura decidida y documentada; implementación suspendida hasta interfaz |
| GAP-D01-02 — Contratos de acceso | 🟠 P2 | T-201 ✅ VPS · trigger WORM ✅ · `contrato_id` en T-170 ✅ · átomos B05 ⏸ vía árbol roles template | ✅ CERRADO — DDL completo; átomos pendientes de validación vía árbol |
| GAP-D01-03 — ABAC completo | 🟠 P2 | T-203 DESCARTADA · ABAC = `condition_expr` en T-162 · temporales → D04 · riesgo → T-180 | ✅ CERRADO — arquitectura decidida; sin tabla separada |
| GAP-D01-04 — Átomos D01 | 🟠 P2 | Catálogo de ~35 átomos especificado en §14.4: 9 bloques × 3-5 verbos + `condition_expr` canónicas (AAL, SoD, sensitivity) · implementación ⏸ vía árbol roles template | ✅ CERRADO — catálogo especificado; implementación ⏸ suspendida hasta AtomLang |
| GAP-D01-05 — Zona compuesta | 🟡 P3 | T-202 DESCARTADA · AND de zonas = AND nativo del BitMask · no hay brecha real | ✅ CERRADO — BitMask resuelve zona compuesta por diseño |

### 15.4 Veredicto IAM Enterprise

D01 está en **L2-L3** para los criterios de autorización central (BitMask, RBAC N3, SoD, IGA). Los gaps P1/P2 son extensiones de profundidad sobre una base sólida — no son arquitectura ausente.

**Madurez actual:** PDP ✅ L3 · RBAC ✅ L3 · SoD ✅ L3 · IGA ✅ L3 · ABAC ⏸ L2 · Field-Access ⏸ L1 · Contratos ⏸ L2 · Zona compuesta ✅ (BitMask nativo)

**Gaps IAM Enterprise D01:** 5/5 cerrados arquitecturalmente — implementación de átomos ⏸ suspendida hasta interfaz AtomLang.

---

## Historial

| Versión | Fecha | Descripción |
|---------|-------|-------------|
| 1.0.0 | 2026-07-28 | Versión inicial. 9 bloques analizados: 7/9 satisfechos (B04, B05 faltantes). DDL propuesto T-200/T-201/T-203. 5 gaps IAM Enterprise identificados. Madurez D01: L2-L3 en núcleo de autorización. |
| 1.1.0 | 2026-07-29 | GAP-D01-01 resuelto arquitectónicamente. T-200 DESCARTADO — viola D-07. Solución: átomos `skull.D01.fields.*` en T-162 + obligation en T-171 + T-500 como PIP. B04 ❌→⚠️ PARCIAL. §6 reescrito con flujo completo, SQL y tabla de responsabilidades. |
| 1.2.0 | 2026-07-29 | GAP-D01-02 arquitectura + implementación VPS. T-201 CONFIRMADO como tabla separada (D-07). DDL corregido v2: (1) FK inversa `privilege_atom_grant.contrato_id` reemplaza `grant_ids[]`; (2) `chk_iac_subject`; (3) trigger WORM `trg_iac_protect_active`. IMPLEMENTADO EN VPS: T-201 ✅ · trigger ✅ · idx ✅ · contrato_id en T-170 ✅. T-500 también implementado en VPS para D01-B04. Átomos de ambos bloques pendientes (se insertan al definir árbol). |
| 1.3.0 | 2026-07-29 | DDL canónico (`SBOS_db_V2_DDL.sql`) actualizado: T-500 y T-201 insertados antes de NIVEL 7 · `contrato_id` añadido al CREATE TABLE de privilege_atom_grant · `idx_pag_contrato` añadido · trigger WORM `trg_iac_protect_active` en DDL canónico · MANUAL_DB_DDL.md §43 añadido · migración incremental `004_d01_gaps_b04_b05.sql` creada. GAP-D01-01 y GAP-D01-02: DDL completo en VPS + canónico + migración. |
| 1.4.0 | 2026-07-30 | GAP-D01-01 CERRADO. Decisión arquitectónica final: campo × verbo = átomo en T-162 únicamente. T-500 NO es mecanismo de control de acceso para B04 (su propósito es schema registry del modelo EAV D00 y se actualiza en sincronía con el árbol, no como entidad independiente). Ejemplos de árbol corregidos: atributos EAV reales (`core.national_id`, `fiscal.nit`) en lugar de columnas inventadas (`salario`, `numero_ci`). Átomos SUSPENDIDOS hasta interfaz AtomLang. §6 reescrito. §14, §15.2, §15.3 actualizados. |
| 1.5.0 | 2026-07-30 | GAP-D01-02 CERRADO. Principio arquitectónico formalizado: los átomos NO se insertan manualmente — se crean exclusivamente desde el árbol funcional de roles template (interfaz AtomLang/atomc); triggers/procesos propagan los cambios del árbol a las tablas derivadas (T-171, etc.). T-201 ✅ VPS (ya implementada desde v1.2.0). §7.5 veredicto B05 actualizado a CERRADO. §12.2 heading corregido. Checklist §14 y scorecard §15.3 actualizados. Madurez: Field-Access ⏸ L1 · Contratos ⏸ L2. |
| 1.6.0 | 2026-07-30 | GAP-D01-03 CERRADO. T-203 `idn_acceso_abac_policy` DESCARTADA: viola D-07 (define QUÉ PUEDE HACER → va en árbol T-162). Las condiciones ABAC se expresan en `condition_expr JSONB` del átomo correspondiente, compiladas por AtomLang, evaluadas por el PDP en runtime. Las condiciones temporales (`env.time`, horarios) pertenecen a D04 (Temporal), no a ABAC genérico en D01. T-180 `ses_risk_policy` cubre riesgo adaptativo ortogonal (reacciona a eventos, no define autorización). GAP-D01-04 reformulado: átomos con `condition_expr` para cada bloque D01, pendientes de validación vía árbol. §10 B08 reescrito. §12.3 marcado como DESCARTADO. §13.1, §14, §15 actualizados. Principio central: el árbol de roles template es la única fuente de verdad — muchas tablas propuestas eran duplicación y dispersión de información. |
| 1.8.0 | 2026-07-30 | GAP-D01-05 CERRADO. T-202 `idn_acceso_zona_policy` DESCARTADA: viola D-07 (la intersección de zonas define autorización → árbol). La zona compuesta ya está resuelta nativamente por el AND del BitMask — un recurso en múltiples zonas simplemente requiere átomos de cada zona; el PDP los evalúa como AND implícito. No hay brecha real. §5 B03 actualizado. §15.2 GAP-D01-05 expandido. §15.3 scorecard: 5/5 gaps cerrados. §15.4 veredicto actualizado. **D01 cierra su ciclo IAM Enterprise completo: todos los gaps P1/P2/P3 resueltos arquitecturalmente.** |
| 1.7.0 | 2026-07-30 | GAP-D01-04 CERRADO arquitectónicamente. Catálogo completo de ~35 átomos D01 especificado en §14.4: 9 bloques × 3-5 verbos con paths canónicos `skull.D01.<bloque>.<verbo>`, `condition_expr` clave por bloque (AAL3 para override, SoD para contracts.approve, sensitivity check para fields.write, AAL3+dual para dynamic_policy.configure). Seed obsoleta `idn_acceso_field_policy` eliminada de §14.5 (T-200 descartada). §14.6 actualizado: Átomos D01 ⏸ catálogo ✅ / implementación vía árbol. Nota B08 aclarada: átomos de `dynamic_policy` controlan QUIÉN puede modificar `condition_expr` (meta-control), no son la política ABAC en sí. Score: 4/5 gaps IAM Enterprise cerrados arquitecturalmente; solo GAP-D01-05 (P3) pendiente. |
