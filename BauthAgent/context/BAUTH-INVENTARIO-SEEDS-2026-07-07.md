# BAUTH — Inventario de Seeds · Clasificación y Acciones
**Versión:** 1.0 · **Fecha:** 2026-07-07 · **Autor:** bauth-developer
**Contexto:** Post bauth_76 v2.0 — biblioteca canónica de 9,874 nodos lista

---

## Resumen ejecutivo

Ahora que `bauth_76__cfg_policy_library_master.sql` es el seed canónico (9,874 nodos),
la cadena original de 21 archivos que construían `cfg_policy_library` es redundante.
Este inventario clasifica cada seed y propone acciones claras.

**Total seeds analizados: 90+**
- Archivar (redundantes): 21 archivos
- Mantener siempre: 52 archivos
- Pendiente HITL H14: 25 archivos

---

## 1. ARCHIVAR — Superseded por bauth_76

Estos archivos eran el pipeline de construcción de `cfg_policy_library`.
Ya no hacen falta para instalación fresca ni para operación.

### 1A. Archivos bauth_fw_* (pipeline framework_raw → cfg_policy_library)

| Archivo | Tamaño | Tabla que llena | Razón de archivo |
|---|---|---|---|
| `bauth_fw_01__authentication_framework.sql` | 127 KB | `framework_raw` | Fuente de 6,651 nodos → ya en bauth_76 |
| `bauth_fw_02__policies_framework.sql` | 29 KB | `framework_raw` | Fuente de 1,324 nodos → ya en bauth_76 |
| `bauth_fw_03__nist_rev4.sql` | 2.5 KB | `framework_raw` | source `nist_sp_800_63b_rev4` → ya en bauth_76 |
| `bauth_fw_04__fido2_ctap.sql` | 3.4 KB | `framework_raw` | source `fido2_ctap_2.2` → ya en bauth_76 |
| `bauth_fw_05__nist_pqc.sql` | 1.7 KB | `framework_raw` | source `nist_pqc_2025` → ya en bauth_76 |
| `bauth_fw_06__oauth_21.sql` | 2.4 KB | `framework_raw` | source `oauth_2_1` → ya en bauth_76 |
| `bauth_fw_07__zero_trust.sql` | 2.7 KB | `framework_raw` | source `zero_trust_nsa_2026` → ya en bauth_76 |
| `bauth_fw_08__iso_27001.sql` | 3.1 KB | `framework_raw` | source `iso_27001_2022` → ya en bauth_76 |
| `bauth_fw_09__industry.sql` | 4.5 KB | `framework_raw` | source `industry_enterprise` → ya en bauth_76 |
| `bauth_fw_10__d3_financiero.sql` | 3.3 KB | `framework_raw` | source `pci_dss_4_0_financial` → ya en bauth_76 |
| `bauth_fw_11__d4_temporal.sql` | 3.3 KB | `framework_raw` | source `time_based_access_d4` → ya en bauth_76 |
| `bauth_fw_12__d6_geo.sql` | 3.7 KB | `framework_raw` | source `geo_location_d6` → ya en bauth_76 |
| `bauth_fw_13__d10_delegacion.sql` | 3.9 KB | `framework_raw` | source `delegation_authority_d10` → ya en bauth_76 |
| `bauth_fw_14__cis_k8s.sql` | 3.8 KB | `framework_raw` | source `cis_kubernetes_1_8` → ya en bauth_76 |
| `bauth_fw_15__aws_iam.sql` | 3.7 KB | `framework_raw` | source `aws_iam_best_practices` → ya en bauth_76 |
| `bauth_fw_16__soc2.sql` | 3.0 KB | `framework_raw` | source `soc2_type_ii` → ya en bauth_76 |

**Nota:** La tabla `framework_raw` también puede archivarse una vez aprobada la
decisión H14 — es solo una staging table intermedia ya sin propósito.

### 1B. Archivos bauth_71..75 (inserción directa en cfg_policy_library)

| Archivo | Tamaño | Tabla que llena | Razón de archivo |
|---|---|---|---|
| `bauth_71__lib_d3_financiero.sql` | 22 KB | `cfg_policy_library` | source `d3_financial_ext` (10 nodos) → ya en bauth_76 |
| `bauth_72__lib_d4_temporal.sql` | 18 KB | `cfg_policy_library` | source `d4_temporal_ext` (8 nodos) → ya en bauth_76 |
| `bauth_73__lib_d6_geoespacial.sql` | 20 KB | `cfg_policy_library` | source `d6_geospatial_ext` (8 nodos) → ya en bauth_76 |
| `bauth_74__lib_d10_delegacion.sql` | 19 KB | `cfg_policy_library` | source `d10_delegation_ext` (8 nodos) → ya en bauth_76 |
| `bauth_75__lib_d12_blockchain.sql` | 20 KB | `cfg_policy_library` | source `d12_blockchain_ext` (8 nodos) → ya en bauth_76 |

**Acción propuesta:** Mover los 21 archivos a `DDLs/seeds/_obsoletos/`. No eliminar
del repositorio hasta que el Revisor confirme que bauth_76 cubre todo.

---

## 2. PENDIENTE HITL H14 — No descartar aún

Estos archivos corresponden a las tablas `ath_config_dN` y `ath_policy_dN`.
La decisión de deprecar estas tablas está pendiente (HITL H14). Hasta que se tome,
estos seeds **deben mantenerse intactos**.

### 2A. ath_config_dN (SELECT dinámico desde cfg_policy_library)

| Archivo | Tamaño | Comportamiento | Estado |
|---|---|---|---|
| `bauth_16__ath_config_d1.sql` | 669 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_17__ath_config_d2.sql` | 669 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_18__ath_config_d3.sql` | 669 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_19__ath_config_d4.sql` | 669 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_20__ath_config_d5.sql` | 23 KB | Hardcoded (biometría ISO/IEC 19794) | Tiene datos propios · KEEP |
| `bauth_21__ath_config_d6.sql` | 669 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_22__ath_config_d7.sql` | 669 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_23__ath_config_d8.sql` | 1.7 KB | Datos propios (sesión/contexto) | Tiene datos propios · KEEP |
| `bauth_24__ath_config_d9.sql` | 1.7 KB | Datos propios (token) | Tiene datos propios · KEEP |
| `bauth_25__ath_config_d10.sql` | 676 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_26__ath_config_d11.sql` | 676 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |
| `bauth_27__ath_config_d12.sql` | 676 B | SELECT dinámico de cfg_policy_library | Depende de bauth_76 primero |

**Observación:** Los pequeños (669 B) son apenas `SELECT … FROM cfg_policy_library LIMIT 20`.
Si H14 se aprueba (deprecar ath_config_dN), estos 9 archivos desaparecen.
Si H14 se rechaza, quedan pero **deben ejecutarse después de bauth_76**.

### 2B. ath_policy_dN (datos hardcodeados propios)

| Archivo | Tamaño | Políticas hardcodeadas | Estado |
|---|---|---|---|
| `bauth_28__ath_policy_d1.sql` | 2.0 KB | 4 políticas SCOPE/DATA_CLASS/MAX_RECORDS | Datos propios · KEEP |
| `bauth_29__ath_policy_d2.sql` | 1.9 KB | Políticas físico-biométricas | Datos propios · KEEP |
| `bauth_30__ath_policy_d3.sql` | 3.5 KB | 5+ políticas PCI DSS / SIN Bolivia | Datos propios · KEEP |
| `bauth_31__ath_policy_d4.sql` | 1.5 KB | Políticas temporales | Datos propios · KEEP |
| `bauth_32__ath_policy_d5.sql` | 19 KB | 10 políticas biométricas ISO/GDPR | Datos propios · KEEP |
| `bauth_33__ath_policy_d6.sql` | 1.9 KB | Políticas geoespaciales | Datos propios · KEEP |
| `bauth_34__ath_policy_d7.sql` | 2.0 KB | Políticas de métodos de auth | Datos propios · KEEP |
| `bauth_35__ath_policy_d8.sql` | 1.3 KB | Políticas de sesión | Datos propios · KEEP |
| `bauth_36__ath_policy_d9.sql` | 5.3 KB | Políticas de token | Datos propios · KEEP |
| `bauth_37__ath_policy_d10.sql` | 1.2 KB | Políticas de delegación | Datos propios · KEEP |
| `bauth_38__ath_policy_d11.sql` | 1.2 KB | Políticas administrativas | Datos propios · KEEP |
| `bauth_39__ath_policy_d12.sql` | 1.9 KB | Políticas de blockchain | Datos propios · KEEP |

### 2C. Sync seed (bauth_43 en seeds/)

| Archivo | Tamaño | Qué hace | Estado |
|---|---|---|---|
| `bauth_43__framework_sync.sql` | 12 KB | SELECT cfg_policy_library → INSERT ath_policy_dN (LIB-%) | Pendiente H14 |

---

## 3. MANTENER SIEMPRE — Datos propios, tablas distintas

### 3A. Datos de referencia estructurales (siempre necesarios)

| Archivo | Tabla | Contenido |
|---|---|---|
| `bauth_01__cfg_key_translation.sql` | cfg_key_translation | Traducciones de claves |
| `bauth_02__privilege_domain.sql` | privilege_domain | 12 dominios BitMask |
| `bauth_03__privilege_verb.sql` | privilege_verb | Verbos CRUD |
| `bauth_04__privilege_application.sql` | privilege_application | Aplicaciones del sistema |
| `bauth_05__privilege_group.sql` | privilege_group | Grupos de privilegios |
| `bauth_06__privilege_atom.sql` | privilege_atom | Átomos de permisos |
| `bauth_07__privilege_atom_policy.sql` | privilege_atom_policy | Políticas de átomos |
| `bauth_08__privilege_role.sql` | privilege_role | Roles base |
| `bauth_09__privilege_role_atom.sql` | privilege_role_atom | Asignaciones rol-átomo |
| `bauth_10__idn_tenant.sql` | idn_tenant | Tenant inicial (SBOS_DEFAULT) |
| `bauth_11__idn_tier_policy.sql` | idn_tier_policy | Políticas de tiers SU/SYS/BIZ/EXT |
| `bauth_12__log_zone.sql` | log_zone | Zonas de auditoría |
| `bauth_13__geo_trust_tier.sql` | geo_trust_tier | Niveles de confianza geográfica |
| `bauth_14__ath_method.sql` | ath_method | 18 métodos de autenticación |
| `bauth_15__ath_federation_protocol.sql` | ath_federation_protocol | OIDC, SAML, SCIM, etc. |

### 3B. Flujos y reglas de autenticación

| Archivo | Tabla | Contenido |
|---|---|---|
| `bauth_40__ath_auth_flow.sql` | ath_auth_flow | 8 flujos (AAL1/2/3, Step-Up, etc.) |
| `bauth_41__ath_step_up_rule.sql` | ath_step_up_rule | Reglas RFC 9470 |
| `bauth_42__validation_rules.sql` | cfg_validation_rule | 58 reglas de validación NIST/ISO |
| `bauth_67__ath_credential_policy.sql` | ath_credential_policy | Política de credenciales |

### 3C. Datos financieros / SoD

| Archivo | Tabla | Contenido |
|---|---|---|
| `bauth_44__fin_transaction_type.sql` | fin_transaction_type | Tipos de transacción |
| `bauth_45__fin_sod_rule.sql` | fin_sod_rule | Reglas SoD financiero |
| `bauth_46__fin_limit.sql` | fin_limit | Límites financieros |
| `bauth_47__fin_decision_matrix.sql` | fin_decision_matrix | Matriz de decisión |

### 3D. Roles y plantillas de identidad

| Archivo | Tabla | Contenido |
|---|---|---|
| `bauth_48__idn_role_template.sql` | idn_role_template | 66 plantillas base de roles |
| `bauth_49__idn_role_template_data.sql` | idn_role_template_data | Datos de plantillas |
| `bauth_50..61__idn_role_dN.sql` | idn_role_dN | Roles por dominio D1-D12 |
| `bauth_62__idn_role_closure.sql` | idn_role_closure | Closure table DAG herencia |
| `bauth_68__idn_user_template.sql` | idn_user_template | Plantillas de usuario |

### 3E. Organización y configuración de dispositivos

| Archivo | Tabla | Contenido |
|---|---|---|
| `bauth_63__org_empresa.sql` | org_empresa | Empresa por defecto |
| `bauth_64__org_sucursal.sql` | org_sucursal | Sucursal por defecto |
| `bauth_65__mobile_app_config.sql` | mobile_app_config | Config de apps móviles |
| `bauth_66__zone_application_map.sql` | zone_application_map | Mapeo zona-aplicación |

### 3F. Auditoría y compliance

| Archivo | Tabla | Contenido |
|---|---|---|
| `bauth_69__aud_compliance_map.sql` | aud_compliance_map | Mapeo ISO 27001 / NIST |
| `bauth_70__compliance_qa.sql` | compliance_qa | Preguntas de compliance |

### 3G. Datos globales y calendario

| Archivo | Tabla | Contenido |
|---|---|---|
| `bglobal_01__global_country.sql` | global_country | 246 países |
| `bglobal_02__global_language.sql` | global_language | Idiomas |
| `bglobal_03__geo_timezone.sql` | geo_timezone | Zonas horarias |
| `bglobal_04__menu_context.sql` | menu_context | Menú contextual del sistema |
| `bcalendar_01__cal_calendar.sql` | cal_calendar | Calendarios |
| `bcalendar_02__cal_schedule.sql` | cal_schedule | Horarios |
| `bcalendar_03__cal_holiday_complete.sql` | cal_holiday | Feriados Bolivia |

### 3H. EL seed canónico de la biblioteca

| Archivo | Tamaño | Contenido |
|---|---|---|
| `bauth_76__cfg_policy_library_master.sql` | **13 MB** | **9,874 nodos — árbol ltree completo — fuente de instalación** |

---

## 4. Orden de ejecución correcto (instalación fresca)

```
PASO 1 — Estructura (tablas vacías):
  sbos_00__esquema_base.sql
  bauth_01..15 (referencia estructural)

PASO 2 — Biblioteca de políticas (fuente de verdad):
  bauth_76__cfg_policy_library_master.sql  ← PRIMERO, todo lo demás depende de aquí

PASO 3 — Datos de autenticación:
  bauth_40 (auth_flow) · bauth_41 (step_up_rule) · bauth_42 (validation_rules)
  bauth_67 (credential_policy)

PASO 4 — Roles e identidad:
  bauth_48..62 (idn_role_template + idn_role_dN + closure)
  bauth_68 (idn_user_template)

PASO 5 — Datos financieros / SoD:
  bauth_44..47 (fin_*)

PASO 6 — Organización:
  bauth_63..66 (org + mobile + zone)

PASO 7 — Auditoría:
  bauth_69..70

PASO 8 — Sincronización ath (si H14 no fue aprobado):
  bauth_16..27 (ath_config_dN — requieren bauth_76 ya cargado)
  bauth_28..39 (ath_policy_dN — datos hardcodeados)
  bauth_43    (framework_sync — LIB-% entries desde cfg_policy_library)

PASO 9 — Datos globales y calendario:
  bglobal_01..04 · bcalendar_01..03
```

---

## 5. Propuesta de acción inmediata

| Acción | Archivos | Comando |
|---|---|---|
| **Mover a `_obsoletos/`** | `bauth_fw_01..16` + `bauth_71..75` (21 archivos) | `mkdir -p _obsoletos && mv bauth_fw_*.sql bauth_71..75 _obsoletos/` |
| **Sin tocar — esperar H14** | `bauth_16..27` + `bauth_28..39` + `bauth_43` (25 archivos) | — |
| **Mantener activos** | Todo lo demás (~52 archivos) | — |

**HITL requerido antes de mover a _obsoletos/:**
- Confirmar que bauth_76 cubre al 100% lo que cubrían los bauth_fw_* y bauth_71..75
- El Revisor debe verificar las fuentes en bauth_76 vs los archivos candidatos a archivar
