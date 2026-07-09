# SEED-DEPENDENCIES.md — Dependencias del Seed idn_role_template
## B47.E04 · G4 del Manual v18.0 · 2026-06-29

**Propósito:** Documentar el orden topológico de ejecución de seeds, dependencias internas,
y procedimiento para agregar nuevos roles al catálogo.

---

## Orden Topológico de Ejecución

```
NIVEL 0 — Catálogos base (sin dependencias)
  seed_global_country.sql        →  bglobal.country
  seed_global_language.sql       →  bglobal.language
  seed_geo_timezone.sql          →  bglobal.timezone
  seed_privilege_domain.sql      →  bos_privilege.privilege_domain
  seed_privilege_verb.sql        →  bos_privilege.privilege_verb
  seed_privilege_group.sql       →  bos_privilege.privilege_group

NIVEL 1 — Átomos y aplicaciones
  seed_privilege_application.sql →  bos_privilege.privilege_application
  seed_privilege_atom.sql        →  bos_privilege.privilege_atom (FK→domain,verb,group)
  seed_privilege_atom_policy.sql →  bos_privilege.privilege_atom_policy (FK→atom)

NIVEL 2 — Configuraciones por dominio
  seed_ath_config_d1..d12.sql    →  bauth.ath_config_d1..d12
  seed_ath_policy_d1..d12.sql    →  bauth.ath_policy_d1..d12
  seed_ath_method.sql            →  bauth.ath_method
  seed_ath_auth_flow.sql         →  bauth.ath_auth_flow
  seed_ath_step_up_rule.sql      →  bauth.ath_step_up_rule

NIVEL 3 — Templates de rol por dominio
  seed_idn_role_d1..d12.sql      →  bauth.idn_role_d1..d12
  seed_idn_role_closure.sql      →  bauth.idn_role_closure

NIVEL 4 — Template maestro (depende de todos los d1..d12)
  seed_idn_role_template.sql     →  bauth.idn_role_template (DDL)
  seed_idn_role_template_data.sql →  bauth.idn_role_template (datos)
  seed_idn_role_template_merge.sql → Función merge_role_templates()

NIVEL 5 — Usuarios y organización
  seed_org_empresa.sql           →  bglobal.org_empresa
  seed_org_sucursal.sql          →  bglobal.org_sucursal
  seed_idn_user_template_v6.sql  →  bauth.idn_user_template
  seed_idn_tenant.sql            →  bauth.idn_tenant
  seed_test_users.sql            →  bauth.idn_user_template (test data)
```

---

## Dependencias del Seed Principal (seed_idn_role_template_data.sql)

### Tablas requeridas antes del seed:

| Tabla | Propósito | Sin ella... |
|-------|-----------|------------|
| `idn_role_d1..d12` | Templates por dominio | merge_role_templates() falla |
| `ath_method` | Métodos de autenticación | No se pueden asignar métodos al rol |
| `privilege_atom` | Catálogo de átomos | No se puede calcular RolBitMask |
| `fin_sod_rule` | Reglas SoD | No se validan conflictos |
| `ath_policy_d1..d12` | Políticas operativas | Evaluación incompleta |

### Subconsultas internas:

1. `merge_role_templates()` consulta cada `idn_role_d{n}` por `role_code`
2. `compute_rol_bitmask()` consulta `privilege_role_atom` para calcular la máscara
3. `validate_merge_no_conflicts()` consulta `fin_sod_rule` para verificar conflictos

---

## Procedimiento para Agregar Nuevos Roles

1. Identificar el dominio principal del rol
2. Agregar entrada en `idn_role_d{n}` correspondiente con `config JSONB`
3. Ejecutar `seed_idn_role_d{n}.sql` para el dominio
4. Ejecutar `merge_role_templates()` para generar el rol combinado
5. Insertar en `idn_role_template` con el JSONB resultante
6. Verificar con `bauth.role.template.validate <role_code>`

---

## Diagrama de Dependencias Simplificado

```
privilege_domain ──→ privilege_atom ──→ privilege_role_atom ──→ rol_bitmask
       │                    │
       └─→ privilege_group ─┘
                    │
ath_method ──→ ath_auth_flow ──→ idn_role_d{n} ──→ merge_role_templates()
                                                         │
                                              idn_role_template (JSONB final)
```

*SEED-DEPENDENCIES.md v1.0 · 2026-06-29*
