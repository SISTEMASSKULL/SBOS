# BAUTH — Memoria de Contexto: Dominio D00
**Sesión:** 2026-06-30 · **Tema:** Diseño e implementación de D00 — Identidad Organizacional

---

## CONTEXTO GENERAL

Se está trabajando en `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` para insertar el **Dominio D00 —
Identidad Organizacional** antes de D1. Es un dominio que NO alinea con normas internacionales
de autenticación — es exclusivamente para estandarización interna (SBOS-MODEL-D00).

**Documento a modificar:**
`context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/BAUTH-ARQUITECTURA-ATOMICA-FINAL.md`

**VPS de prueba:** `root@13.140.128.230` · clave: `12345678ubuntu`
**PostgreSQL:** pod `sbos-data/postgresql-0` vía `KUBECONFIG=/etc/kubernetes/admin.conf kubectl exec`

---

## CONCEPTO CENTRAL (CORREGIDO Y VALIDADO)

### ctx_id
```
ctx_id = interno.tenant.bdomain.bsubdomain
```
- `interno` = switch booleano en `idn_tenant.is_internal` (true=skull/interno, false=externo)
- `tenant` = UUID del tenant
- `bdomain` = UUID de la empresa/persona/etc (tabla `org_empresa`)
- `bsubdomain` = UUID de la sucursal/oficina/etc (tabla `org_sucursal`)
- BOS es el propietario del Context Plane — él crea el ctx_id

### Modelo de bDomain y bSubDomain
- **bDomain** = la "empresa" — tipos: empresa, persona, hogar, desarrollador, m2m, edificio, ...
- **bSubDomain** = la "sucursal" — tipos: sucursal, dependiente, familiar, oficina, ...
- Cada tipo tiene atributos propios: nombre, nit, email, telefono, ci, direccion, etc.
- El atributo `nombre` para tipo=empresa → "DEPO srl"; para tipo=persona → "Juan Pérez"

### Modelo de átomo para D00
```
EMPRESA no es un verbo/átomo — es un VALOR del átomo D00.org.bdomain.type
```

| Átomo (D.A.M.V)           | Tipo  | Valor/Validación          |
|---------------------------|-------|---------------------------|
| `D00.org.bdomain.type`    | REGLA | ENUM: empresa/persona/hogar/desarrollador/m2m/... |
| `D00.org.bdomain.nombre`  | REGLA | TEXT (2-128 chars)        |
| `D00.org.bdomain.nit`     | REGLA | TEXT (^\d{8,12}$)         |
| `D00.org.bdomain.email`   | REGLA | TEXT (email format)       |
| `D00.org.bdomain.telefono`| REGLA | TEXT (7-15 digits)        |
| `D00.org.bdomain.ci`      | REGLA | TEXT (carnet de identidad)|
| `D00.org.bsubdomain.type` | REGLA | ENUM: sucursal/dependiente/familiar/oficina/... |
| `D00.org.bsubdomain.nombre`| REGLA| TEXT (2-128 chars)       |
| `D00.org.tenant.type`     | REGLA | ENUM: interno/externo     |

---

## ESTADO REAL DE LA BASE DE DATOS (verificado 2026-06-30)

### Tablas existentes relevantes

| Tabla | Estado | Nota |
|-------|--------|------|
| `bauth.idn_tenant` | 1 registro (skull) | **Falta columna `is_internal boolean`** |
| `bauth.privilege_domain` | 12 registros (D1-D12) | **D00 no existe. CHECK: domain_code >= 1** |
| `bauth.privilege_application` | 12 apps (Tryton...PostgreSQL) | **Falta app `org` (app_code=13)** |
| `bauth.privilege_group` | 48 registros | **Faltan grupos: Tenant, bDomain, bSubDomain, Pos** |
| `bauth.privilege_verb` | 50 verbos (CRUD) | **Faltan: type, nombre, nit, email, telefono, ci, direccion** |
| `bauth.privilege_atom` | 5,808 átomos (D1-D12) | **0 átomos de D00** |
| `bauth.idn_tenant_domain` | 0 registros | Vacía |

### tenant_type_enum actual
`STANDARD`, `REGULATED`, `HIGH_SENSITIVITY` — NO captura interno/externo.
**La distinción interno/externo va en columna boolean separada `is_internal`.**

### Tenant existente
```
tenant_slug=skull | tenant_name="Sistemas SKULL" | tenant_type=HIGH_SENSITIVITY | status=ACTIVE
```
**Falta seed del tenant externo.**

---

## ESTRUCTURA DE D00 EN LA BD (patrón igual a D1-D12)

Los otros dominios siguen este patrón exacto:
- `atom_name` = `"Aplicación · Grupo · Dominio · Verbo"`
- `atom_slug` = `"app_slug.g{group_code}.d{domain_code}.verb_slug"`

### Paso 1 — `idn_tenant`: agregar columna
```sql
ALTER TABLE bauth.idn_tenant ADD COLUMN is_internal boolean NOT NULL DEFAULT true;
-- skull es interno, el tenant externo que se creará tendrá is_internal=false
```

### Paso 2 — `privilege_domain`: modificar CHECK e insertar D00
```sql
ALTER TABLE bauth.privilege_domain DROP CONSTRAINT ck_domain_code;
ALTER TABLE bauth.privilege_domain ADD CONSTRAINT ck_domain_code CHECK (domain_code >= 0 AND domain_code <= 15);
INSERT INTO bauth.privilege_domain VALUES
  (0, 'Identidad Organizacional', false,
   'Tipos y atributos de tenant, bDomain, bSubDomain y pos. Pre-condición estructural del ctx_id.');
```

### Paso 3 — `privilege_application`: nueva app org
```sql
INSERT INTO bauth.privilege_application (app_code, app_name, app_slug, tenant_id, active)
VALUES (13, 'Org', 'org', '019f1333-2475-7fa2-b0d5-3e26d0f90308', true);
```

### Paso 4 — `privilege_group`: grupos de org
```sql
INSERT INTO bauth.privilege_group VALUES
  (1, 13, 'Tenant'),
  (2, 13, 'bDomain'),
  (3, 13, 'bSubDomain'),
  (4, 13, 'Punto de Acceso');
```

### Paso 5 — `privilege_verb`: verbos de identidad
```sql
INSERT INTO bauth.privilege_verb VALUES
  (51, 'type',      'tipo'),
  (52, 'nombre',    'nombre'),
  (53, 'nit',       'nit'),
  (54, 'email',     'email'),
  (55, 'telefono',  'telefono'),
  (56, 'ci',        'ci'),
  (57, 'direccion', 'direccion');
```

### Paso 6 — `privilege_atom`: átomos D00 (pos=5809+)
```
"Org · Tenant     · Identidad Org · type"       org.g1.d0.tipo      pos=5809
"Org · bDomain    · Identidad Org · type"        org.g2.d0.tipo      pos=5810
"Org · bDomain    · Identidad Org · nombre"      org.g2.d0.nombre    pos=5811
"Org · bDomain    · Identidad Org · nit"         org.g2.d0.nit       pos=5812
"Org · bDomain    · Identidad Org · email"       org.g2.d0.email     pos=5813
"Org · bDomain    · Identidad Org · telefono"    org.g2.d0.telefono  pos=5814
"Org · bDomain    · Identidad Org · ci"          org.g2.d0.ci        pos=5815
"Org · bDomain    · Identidad Org · direccion"   org.g2.d0.direccion pos=5816
"Org · bSubDomain · Identidad Org · type"        org.g3.d0.tipo      pos=5817
"Org · bSubDomain · Identidad Org · nombre"      org.g3.d0.nombre    pos=5818
"Org · bSubDomain · Identidad Org · direccion"   org.g3.d0.direccion pos=5819
"Org · Pos        · Identidad Org · type"        org.g4.d0.tipo      pos=5820
"Org · Pos        · Identidad Org · nombre"      org.g4.d0.nombre    pos=5821
```

---

## VIABILIDAD

**SÍ es viable.** Un solo obstáculo técnico: el CHECK constraint de `privilege_domain`
bloquea `domain_code=0`. Se resuelve con `ALTER TABLE` antes del INSERT.

Los demás cambios son solo INSERTs en tablas de catálogo — no tocan lógica existente.
Los 5,808 átomos actuales (D1-D12) no se modifican.

---

## DOCUMENTO A REESCRIBIR

En `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md`, la sección D00 (líneas ~1034-1092) está
**INCORRECTA** y debe reemplazarse. El error fue:
- Usaba `EMPRESA` como si fuera el verbo del átomo → INCORRECTO
- Usaba tipo IDENTIDAD para `nombre`, `email` → INCORRECTO (son REGLA)

La sección correcta debe mostrar los átomos tal como están arriba:
`D00.org.bdomain.type` con valor ENUM, `D00.org.bdomain.nombre` como REGLA TEXT, etc.

---

## ✅ COMPLETADO

- Sección D00 reescrita en `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` (2026-06-30)
  - Tipo corregido: IDENTIDAD → REGLA para todos los átomos
  - Verbos correctos: `type`, `nombre`, `nit`, `email` (no EMPRESA/PERSONA)
  - Grupo `actor` añadido con 7 verbos: type, employee_type, gender, marital_status, id_doc_type, locale, timezone
  - SQL de 6 pasos embebido en el documento
  - 20 átomos totales: pos 5809-5828

## PRÓXIMOS PASOS

1. ~~Reescribir sección D00 en `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md`~~ ✅ HECHO
2. Crear archivo de migration SQL físico en `BauthAgent/db/migrations/`
3. Agregar seed del tenant externo en `BauthAgent/db/migrations/seeds/`
4. Actualizar REGISTRO-ESTADO.md con tarea D00 completada

---

## COMANDOS DE ACCESO RÁPIDO

```bash
# Entrar a la VPS
ssh root@13.140.128.230  # clave: 12345678ubuntu

# Conectar a PostgreSQL
KUBECONFIG=/etc/kubernetes/admin.conf kubectl exec -n sbos-data postgresql-0 -- \
  psql -U postgres -d SBOS_db -c "SELECT * FROM bauth.privilege_domain ORDER BY domain_code;"

# Ver átomos D1 (referencia de patrón)
KUBECONFIG=/etc/kubernetes/admin.conf kubectl exec -n sbos-data postgresql-0 -- \
  psql -U postgres -d SBOS_db -c \
  "SELECT app_code, group_code, domain_code, verb_code, atom_name, atom_slug FROM bauth.privilege_atom WHERE domain_code=1 LIMIT 10;"

# Documento principal
/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/BAUTH-ARQUITECTURA-ATOMICA-FINAL.md
```
