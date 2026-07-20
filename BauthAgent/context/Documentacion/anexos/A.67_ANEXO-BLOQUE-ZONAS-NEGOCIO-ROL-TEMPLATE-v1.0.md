# A.67 — Bloque Zona de Negocios del RolTemplate
**Versión:** 1.1.0 · **Fecha:** 2026-07-20
**Bloque canónico:** `Zona de Negocios` · presente en **todos los dominios D01–D13 y D98/D99**
**Fuente normativa:** NGAC INCITS 565-2020 · SABSA SCF · ISO/IEC 27001:2022 A.5.15 · NIST SP 800-207 · XACML 3.0

---

## 1. Propósito

Este anexo define el bloque **Zona de Negocios** del árbol RolTemplate de bAuth.

**Zona de Negocios** es el contenedor estándar internacional para el registro de aplicaciones
dentro de un dominio de control. Está presente en **todos los dominios** del árbol RolTemplate
(D01–D13, D98, D99). Su función: declarar qué aplicaciones operan en el perímetro de ese
dominio y definir los átomos de privilegio que bAuth controla sobre ellas.

**Regla absoluta:** el bloque Zona de Negocios **solo acepta estructuras de aplicaciones**.
No acepta áreas de negocio, departamentos, categorías temáticas ni ningún otro tipo de nodo
que no sea la declaración de una aplicación concreta con su bloque Z0 de identidad.

---

## 2. Base normativa — por qué "Zona de Negocios"

El término **Business Zone** (Zona de Negocios) tiene origen en los principales marcos
normativos de seguridad empresarial:

| Estándar | Término | Definición relevante |
|----------|---------|----------------------|
| **NGAC INCITS 565-2020 §4** | Policy Class (PC) | Contenedor de nodos OA que define el perímetro de una política. Una zona = un PC. La membresía es un edge estructural, no una propiedad. |
| **SABSA SCF (Sherwood Applied Business Security Architecture)** | Business Zone | Agrupación de activos de negocio bajo un conjunto común de controles de seguridad. Cada zona tiene su propia política. |
| **ISO/IEC 27001:2022 A.5.15** | Access Control — Segregación | Las zonas de negocio son unidades de segregación de acceso. Un activo pertenece a una zona, y la zona define quién accede. |
| **NIST SP 800-207 §3.3** | Enterprise Resource Zone | En Zero Trust, los recursos se agrupan en zonas según sensibilidad. El motor de políticas (PDP) opera por zona. |
| **XACML 3.0 §5.2** | PolicySet con Target | Cada zona es un PolicySet con un Target que delimita su alcance. Solo políticas compatibles con ese target son válidas dentro. |
| **NIST SP 800-162** | Object Attribute (OA) | En ABAC, los recursos tienen atributos de entorno que los ubican en una zona. |

**Conclusión:** en todos los marcos mencionados, la zona de negocios es el contenedor de
política que agrupa **recursos concretos** (aplicaciones, sistemas, servicios) bajo un
perímetro de control. No agrupa categorías abstractas de negocio.

---

## 3. Regla global — todos los dominios tienen Zona de Negocios

**Todo dominio del árbol RolTemplate** (D01 a D13, D98, D99) contiene exactamente **un**
bloque `Zona de Negocios`. Este bloque está presente aunque el dominio no tenga aplicaciones
registradas aún — en ese caso el bloque existe vacío, listo para recibir configuraciones.

| Dominio | Bloque | Prefijo de zona esperado |
|---------|--------|--------------------------|
| D01 · ACCESO LÓGICO | `B6 · Zona de Negocios` | `zona_logical_*` |
| D02 · ACCESO FÍSICO | `Zona de Negocios` | `zona_fisica_*` |
| D03 · FINANCIERO | `Zona de Negocios` | `zona_financial_*` |
| D04 · TEMPORAL | `Zona de Negocios` | `zona_temporal_*` |
| D05 · BIOMÉTRICO | `Zona de Negocios` | `zona_biometric_*` |
| D06 · GEOESPACIAL | `Zona de Negocios` | `zona_geo_*` |
| D07 · RED | `Zona de Negocios` | `zona_network_*` |
| D08 · CONTEXTO | `Zona de Negocios` | `zona_context_*` |
| D09 · CREDENCIALES | `Zona de Negocios` | `zona_credential_*` |
| D10 · DELEGACIÓN | `Zona de Negocios` | `zona_delegation_*` |
| D11 · AUDITORÍA | `Zona de Negocios` | `zona_audit_*` |
| D12 · BLOCKCHAIN | `Zona de Negocios` | `zona_blockchain_*` |
| D13 · FIRMA DIGITAL EXTERNA | `Zona de Negocios` | `zona_signature_*` |
| D98 · DIAGNÓSTICO | `Zona de Negocios` | `zona_diag_*` |
| D99 · ADMINISTRATIVO | `Zona de Negocios` | `zona_admin_*` |

**Nota:** el prefijo de zona es una convención de nomenclatura que identifica el dominio
al que pertenece la aplicación. Una misma aplicación puede aparecer en múltiples dominios
si actúa sobre recursos de esos dominios (ej.: Tryton en D01 para acceso a menús,
y en D03 para acceso financiero).

---

## 4. Estructura válida — qué acepta el bloque Zona de Negocios

El bloque Zona de Negocios **solo acepta nodos de tipo `politica`** que representen
aplicaciones. Cada nodo `politica` es una **zona-app**: una aplicación concreta registrada
en `bauth.privilege_application`.

### 4.1 Estructura obligatoria de una zona-app

```
zona_{dominio}_{app_code}             ← TipoNodo.politica  — una zona por app
  ├── Z0 · Identidad                  ← TipoNodo.bloque    — OBLIGATORIO
  │     ├── app_code                  ← atributo           — clave PK en privilege_application
  │     ├── vendor                    ← atributo           — nombre comercial
  │     ├── slug_prefix               ← atributo           — prefijo de átomos de esta app
  │     ├── dominio                   ← atributo           — dominio al que pertenece esta zona
  │     ├── registro                  ← atributo           — referencia a la tabla de registro
  │     ├── app_type                  ← enumerado          — tipo de aplicación
  │     ├── loa_required              ← enumerado          — AAL1/AAL2/AAL3
  │     ├── sod_enforced              ← atributo           — true/false
  │     └── clasificacion             ← atributo           — INTERNAL/CONFIDENTIAL/SECRET
  └── {niveles de acceso según dominio}  ← definidos por el dominio (ver §5)
```

### 4.2 Lo que NO acepta el bloque

El motor de validación de bAuth **rechaza** cualquier nodo hijo del bloque Zona de Negocios
que no cumpla:

| Condición de rechazo | Razón |
|----------------------|-------|
| Nodo sin `Z0 · Identidad` | Toda zona-app debe declarar su identidad antes de sus políticas |
| Nodo sin `app_code` en Z0 | Sin `app_code` no hay referencia a `privilege_application` |
| Nodo de tipo `dominio`, `bloque`, `evaluacion` como hijo directo | Solo `politica` (zona-app) es hijo directo del bloque |
| Áreas de negocio como `zona_ventas`, `zona_clientes`, `zona_rrhh` | Las zonas identifican **aplicaciones**, no departamentos |
| Zonas de dominio distinto al bloque contenedor | `zona_financial_*` no puede estar en B6 (D01) |

---

## 5. Jerarquía canónica por dominio

### 5.1 D01 · ACCESO LÓGICO — niveles de acceso Tryton/ERP

El dominio lógico usa los **5 niveles de acceso oficiales de Tryton** (nomenclatura universal
en sistemas ERP/CRM):

```
D01 · ACCESO LÓGICO
  └── B6 · Zona de Negocios
        └── zona_logical_{app_code}        ← TipoNodo.politica
              ├── Z0 · Identidad
              ├── model        → ir.model.access       — CRUD por modelo
              ├── actions      → ir.action              — menús y acciones visibles
              ├── field        → ir.model.field.access  — acceso a campos
              ├── button       → ir.model.button        — botones de formulario
              └── record_rule  → ir.rule                — filtros de dominio sobre registros
```

**Fuente niveles:** [Tryton Server — Access Rights](https://docs.tryton.org/projects/server/en/latest/topics/access_rights.html)
> *"There are 5 levels of access rights: Model, Actions, Field, Button and Record Rule."*

### 5.2 D02 · ACCESO FÍSICO — recursos de hardware

```
D02 · ACCESO FÍSICO
  └── Zona de Negocios
        └── zona_fisica_{app_code}
              ├── Z0 · Identidad
              ├── device_access   — acceso a dispositivos físicos (lectores, puertas)
              ├── location_rule   — restricción por ubicación física
              └── schedule_rule   — restricción por horario de acceso físico
```

### 5.3 D03 · FINANCIERO — módulos financieros

```
D03 · FINANCIERO
  └── Zona de Negocios
        └── zona_financial_{app_code}
              ├── Z0 · Identidad
              ├── model        — CRUD contable (account, invoice, payment)
              ├── actions      — menús financieros
              ├── field        — campos sensibles (importes, cuentas bancarias)
              ├── button       — validar/confirmar/pagar
              └── record_rule  — filtros por empresa/diario/periodo contable
```

> **Nota:** los módulos financieros de Tryton ERP (`account`, `account_invoice`,
> `account_payment`) pertenecen a D03, **no a D01**. Aunque son parte del mismo sistema
> Tryton, su dominio de control es financiero.

### 5.4 Otros dominios (D04–D13, D98, D99)

Cada dominio define sus propios niveles de acceso según la naturaleza de sus recursos.
El bloque `Zona de Negocios` es siempre el contenedor; los niveles internos varían:

| Dominio | Niveles típicos internos |
|---------|--------------------------|
| D04 · TEMPORAL | `time_window`, `calendar_rule`, `expiry_policy` |
| D05 · BIOMÉTRICO | `biometric_method`, `liveness_check`, `fallback_policy` |
| D06 · GEOESPACIAL | `geofence`, `country_rule`, `ip_region_rule` |
| D07 · RED | `network_segment`, `protocol_rule`, `port_policy` |
| D08 · CONTEXTO | `device_trust`, `risk_score_rule`, `session_context` |
| D09 · CREDENCIALES | `credential_type`, `rotation_policy`, `revocation_rule` |
| D10 · DELEGACIÓN | `delegate_scope`, `delegation_depth`, `consent_rule` |
| D11 · AUDITORÍA | `audit_level`, `retention_rule`, `alert_rule` |
| D12 · BLOCKCHAIN | `chain_id`, `smart_contract_rule`, `tx_policy` |
| D13 · FIRMA DIGITAL | `signature_method`, `certificate_authority`, `validity_rule` |
| D98 · DIAGNÓSTICO | `diag_scope`, `introspection_rule` |
| D99 · ADMINISTRATIVO | `admin_scope`, `emergency_rule`, `break_glass_policy` |

---

## 6. Slug de átomo

El slug identifica unívocamente cada átomo en todo el árbol:

```
{dominio_code}.{app_slug}.{modulo}.{verbo}
```

Ejemplos:
```
D01 · tryton_erp  · sale         · read    → D01.tryton.sale.read
D01 · orange_crm  · lead         · create  → D01.orange_crm.lead.create
D03 · tryton_erp  · account      · confirm → D03.tryton.account.confirm
D06 · bsearch     · geofence     · enforce → D06.bsearch.geofence.enforce
D07 · bnotify     · network_seg  · allow   → D07.bnotify.network_seg.allow
```

---

## 7. Aplicaciones registradas en D01 B6 (v1.0)

| Zona | app_code | Vendor | Módulos iniciales | LOA |
|------|----------|--------|-------------------|-----|
| zona_logical_tryton | tryton_erp | Tryton ERP (open source) | sale, party, stock | AAL2 |
| zona_logical_orange_crm | orange_crm | OrangeCRM / SuiteCRM | lead, opportunity, contact | AAL2 |
| zona_logical_orange_hrm | orange_hrm | OrangeHRM | employee, leave | AAL2 |
| zona_logical_bsearch | bsearch | SKULL SBOS bSearch | index | AAL1 |
| zona_logical_bnotify | bnotify | SKULL SBOS bNotify | notification | AAL1 |

> Para registrar una nueva aplicación: agregar `zona_logical_{app_code}` con su Z0 e
> insertar en `bauth.privilege_application` el registro correspondiente.

---

## 8. Bloque Z0 · Identidad — campos obligatorios

| Campo | Tipo | Descripción | Obligatorio |
|-------|------|-------------|:-----------:|
| `app_code` | atributo | Clave PK en `bauth.privilege_application` | ✅ |
| `vendor` | atributo | Nombre comercial de la aplicación | ✅ |
| `slug_prefix` | atributo | Prefijo de todos los átomos de esta app | ✅ |
| `dominio` | atributo | Dominio al que pertenece esta zona | ✅ |
| `registro` | atributo | Referencia a la tabla de registro | ✅ |
| `app_type` | enumerado | ERP / CRM / RRHH / FINANCIERO / PORTAL / COMUNICACIONES / SOBERANO / EXTERNO | ✅ |
| `loa_required` | enumerado | AAL1 / AAL2 / AAL3 | ✅ |
| `sod_enforced` | atributo | `true` o `false` | ✅ |
| `clasificacion` | atributo | INTERNAL / CONFIDENTIAL / SECRET / TOP_SECRET | ✅ |

---

## 9. Normas aplicables

| Estándar | Aplica a |
|----------|----------|
| NGAC INCITS 565-2020 §4 | Zona = Policy Class (PC) — nodo raíz de perímetro |
| SABSA SCF | Business Zone — agrupación de activos bajo política común |
| ISO/IEC 27001:2022 A.5.15 | Segregación de acceso por zona de negocio |
| NIST SP 800-207 §3.3 | Enterprise Resource Zone (Zero Trust) |
| XACML 3.0 §5.2 | PolicySet con Target — solo políticas compatibles son válidas |
| NIST SP 800-162 | ABAC — Object Attribute ubica recurso en zona |
| NIST AC-3 | Aplicación del control de acceso |
| NIST AC-6(10) | Privilegio mínimo: campo y botón como granularidad mínima |
| ISO 27001 A.8.3 | Restricción de acceso a información |
| RGPD Art. 5 | Masking obligatorio en módulos con PII (field-level) |

---

## 10. Historial

| Versión | Fecha | Cambio |
|---------|-------|--------|
| 1.0.0 | 2026-07-20 | Creación — arquitectura inicial: Zona=App, jerarquía Tryton, 5 apps D01 |
| 1.1.0 | 2026-07-20 | **Corrección de nombre**: bloque pasa a llamarse `Zona de Negocios` (Business Zone — NGAC/SABSA/ISO 27001). Formalización de regla global: todos los dominios D01–D13/D98/D99 tienen un bloque Zona de Negocios. Regla de validación estructural: solo acepta nodos `politica` de aplicación con Z0 de identidad. Tabla de prefijos por dominio. Niveles internos por dominio (D02–D13). |
