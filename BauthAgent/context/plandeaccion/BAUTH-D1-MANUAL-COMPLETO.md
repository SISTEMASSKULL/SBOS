# BAUTH-D1-MANUAL-COMPLETO.md — Ecosistema Completo de Tablas de bAuth

**Versión:** 6.0 · **Fecha:** 2026-06-29 · **Estado:** ✅ PROYECTO COMPLETADO · **B45 CERRADO**
**Tablas totales:** 155 (organizadas en 12 dominios D1-D12 + schemas bglobal, bcalendar)
**Estructura:** 12 `ath_policy_d*` + 12 `ath_config_d*` + 12 `idn_role_d*` + 48 migradas del DDL antiguo + 57 nuevas
**Errores DDL:** 0 · **Idempotencia:** ×3 verificada (97 seeds, 2026-06-29, VPS 13.140.128.230)
**Seeds:** 97 idempotentes con datos reales
**DDL:** `BauthAgent/db/migrations/DDL_skSBOS_db.sql` (~5500 líneas, 18 secciones por dominio)
**VPS:** 13.140.128.230 · **DB test:** `bauth_test`
**Visión:** `SBOS-CONTEXT-PLANE-VISION.md` — `bos.GetContext()` como propuesta de valor central
**Inventario:** `BAUTH-INVENTARIO-TABLAS-DECISION.md` v7.0
**Context Plane:** `SBOS-049-CONTEXT-PLANE.md` · Reconcile loop extendido B45.D03 operativo (60s)
**Propósito:** Documento ÚNICO del ecosistema de tablas de bAuth. Cubre: arquitectura de 12 dominios,
**155 tablas** (48 migradas del DDL antiguo + 57 nuevas + 50 de dominio),
políticas y configuraciones separadas por dominio (`ath_policy_d*` + `ath_config_d*`),
templates de rol por dominio (`idn_role_d*` con 14 secciones JSONB v6.0 c/u),
guías de llenado (RolTemplate 14 secciones, UserTemplate 16 bloques),
matriz de 40 métodos de autenticación, combinaciones válidas y prohibidas (NIST SP 800-63B-4),
niveles de aseguramiento AAL1-3 + Step-Up RFC 9470,
procedimientos operativos, 42+ estándares de referencia, y 97 seeds poblados con datos reales.
Integración con el Context Plane del BOS vía Unix socket `/run/bos/bauth.sock` +
handler `bauth.context.evaluate` + reconcile loop extendido con eventos CAEP.
Sin este ecosistema no hay autenticación, no hay roles, no hay permisos, no hay facturación,
no hay acceso físico. **Si el ecosistema de tablas falla, el SBOS no funciona.**

---

## 0. PRINCIPIO FUNDAMENTAL — EL ROL COMO RECETA

**Un rol es una receta. Las políticas son ingredientes reutilizables. El token JWT es el plato cocinado.**

```
ROL "CAJERO"                              ROL "CHOFER"
══════════════                            ═══════════════
Datos base: nombre, tipo, nivel           Datos base: nombre, tipo, nivel
  + log_zone ("CAJA", "VENTAS")             + fis_access_zone ("ESTACIONAMIENTO","FLOTA")
  + log_permission (verbos: 1,2,4)          + cre_credential_policy (WebAuthn + PIN)
  + fin_limit ($5K/día)                    + d4_temporal (turnos 6-20h)
  + d4_temporal (lun-vie 8-18h)            + d6_geospatial (solo La Paz)
  + cre_credential_policy (TOTP)            + d7_network (VPN requerida)
  = CAJERO listo para usar                 = CHOFER listo para usar
       │                                          │
       └────────────────┬─────────────────────────┘
                        ▼
             BAUTH SYNC ENGINE (reconcile loop 60s)
                        │
             ┌──────────┴──────────┐
             ▼                     ▼
         KEYCLOAK               TRYTON
      Composite Roles      ir.model.access
      Auth Flows            Grupos, botones
      User Attributes       Menús
             │                     │
             └──────────┬──────────┘
                        ▼
               TOKEN DE AUTORIZACIÓN (JWT)
               claims: { roles, zones, verbs, limits, scope, ctx_id }
```

**Las políticas son ingredientes REUTILIZABLES.** La misma política `fin_limit` de $5K/día
puede asignarse al Cajero, al Vendedor y al Supervisor. Modificar la política una vez
afecta a todos los roles que la referencian. Sin editar cada RolTemplate.

**El RolTemplate JSONB REFERENCIA políticas, no las incrusta.**
Referencia por UUID o por código. Esto permite modificar políticas sin migrar datos.

---

## 1. ARQUITECTURA DEL D1 — 5 SUBSISTEMAS + MOTOR DE POLÍTICAS

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  SUBSISTEMA 1: MOTOR DE PRIVILEGIOS (privilege_)  11 tablas         │
│  1059 átomos × 6782 políticas × 12 dominios × 4 verbos              │
│  Evaluación BitMask: D8→D9→D1→D3→D2→D10→D4→D6→D7→D5→D12→D11      │
│  PolicyState: NoAplica(00) | Pendiente(01) | Aprobado(10)           │
│              | Rechazado(11) → CORTO CIRCUITO                       │
│                                                                      │
│       │                                                              │
│       ▼                                                              │
│  SUBSISTEMA 2: POLÍTICAS POR DOMINIO (tablas independientes)        │
│  ┌──────────┬──────────┬──────────┬──────────┬──────────┐          │
│  │D1 lógico │D2 físico │D3 financ │D4 tempor │D5 biomét │          │
│  │log_zone  │fis_acces │fin_limit │cal_sched │bio_templ │          │
│  │log_perm  │s_zone    │fin_approv│ule       │ate       │          │
│  ├──────────┼──────────┼──────────┼──────────┼──────────┤          │
│  │D6 geoesp │D7 red   │D8 contex │D9 creden │D10 deleg │          │
│  │global_co │idn_tenan│to        │cial      │dlg_delega│          │
│  │untry     │t_network │ses_conte│cre_policy│tion_log  │          │
│  ├──────────┴──────────┴──────────┴──────────┴──────────┤          │
│  │ D11 auditoría (aud_event + hash-chain)               │          │
│  │ D12 blockchain (blk_anchor + Besu QBFT — validez jurídica, │          │
│  │  EIP-725/735, Merkle anchoring, AuditAnchor.sol. Ver    │          │
│  │  BAUTH-D12-INFRAESTRUCTURA-BLOCKCHAIN.md para detalle)   │          │
│  └──────────────────────────────────────────────────────┘          │
│       │                                                              │
│       │ Cada política es REUTILIZABLE entre roles                   │
│       ▼                                                              │
│  SUBSISTEMA 3: ROLTEMPLATE (idn_role_template)  LA RECETA           │
│  ┌─────────────────────────────────────────────────────┐            │
│  │ Datos base: id, name, type, hierarchy_level, status │            │
│  │ policies: {                                         │            │
│  │   "logical_access": ["uuid-zona-1","uuid-zona-2"],  │            │
│  │   "financial_limits": ["uuid-limit-1"],              │            │
│  │   "credential_policy": "uuid-policy-mfa",            │            │
│  │   "temporal_schedule": "uuid-schedule-1",             │            │
│  │   ... (12 dominios)                                  │            │
│  │ }                                                    │            │
│  └─────────────────────────────────────────────────────┘            │
│       │                                                              │
│       ▼                                                              │
│  SUBSISTEMA 4: USERTEMPLATE (idn_user_template)                     │
│  Datos base + assigned_roles[]  (referencia RolTemplate por ID)     │
│  Credenciales personales (password hash, TOTP seed, WebAuthn key)   │
│                                                                      │
│       │                                                              │
│       ▼                                                              │
│  SUBSISTEMA 5: SINCRONIZACIÓN + TOKEN (sync engine)                 │
│  RolTemplate → KC (Composite Roles, Auth Flows)                     │
│  UserTemplate → KC (User, credenciales, atributos)                  │
│  RolTemplate → Tryton (ir.model.access, grupos, botones)            ││  Resultado: JWT con claims de autorización                          │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 2. INVENTARIO COMPLETO DE TABLAS — 38 tablas

### SUBSISTEMA 1 — Motor de Privilegios (privilege_)

| # | Tabla | Origen | Línea | Seed | Estado |
|---|-------|--------|-------|------|--------|
| 101 | `privilege_domain` | bos_privilege.bos_domain | 2073 | Sí (12 dominios D1-D12) | ⏳ En schema separado |
| 102 | `privilege_verb` | bos_privilege.bos_verb | 2111 | Sí (~50 verbos: 4 CRUD + 27 SAP + 15 extendidos + 4 ejecución) | ⏳ Ver §2.1 — Catálogo completo de verbos |
| 103 | `privilege_atom` | bos_privilege.bos_atom_catalog | 2122 | Sí (1059 átomos) | ⏳ Precargado |
| 104 | `privilege_atom_policy` | bos_privilege.bos_atom_policy | 2207 | Sí (6782 políticas) | ⏳ Precargado |
| 105 | `privilege_application` | bos_privilege.bos_application | 2086 | Sí (12 apps desde 31 fichas BosAgent) | ⏳ Inventariadas + gobierno §7.5 |
| 106 | `privilege_group` | bos_privilege.bos_group | 2100 | Sí (grupos base) | ⏳ |
| 107 | `privilege_role` | bos_privilege.bos_role | 2146 | No (datos por tenant) | ⏳ |
| 108 | `privilege_role_atom` | bos_privilege.bos_role_atom | 2163 | No (datos por tenant) | ⏳ |
| 109 | `privilege_atom_audit` | bos_privilege.bos_atom_audit | 2240 | No (WORM — solo INSERTs runtime) | ⏳ WORM particionado |

### SUBSISTEMA 2 — Catálogo de Roles (log_ + idn_)

| # | Tabla | Origen | Línea | Seed | Estado |
|---|-------|--------|-------|------|--------|
| 201 | `log_zone` | bos_zona_logica | 911 | Sí (zonas CAEB predefinidas) | ⏳ |
| 202 | `log_permission` | bos_permiso_logico | 940 | No (datos por tenant) | ⏳ |
| 203 | `idn_role_template` | bos_rol_template | 1272 | Sí (66 plantillas base — catálogo 368 roles) | ⏳ 16 bloques JSONB |
| 204 | `idn_role_closure` | bos_rol_closure | 1552 | No (calculado por trigger al insertar rol) | ⏳ Herencia DAG |
| 205 | `idn_role_template_history` | bos_rol_template_history | 1418 | No (WORM — solo INSERTs runtime) | ⏳ WORM SHA-256 |
| 206 | `idn_user_template` | bos_user_template | 1481 | No (datos por usuario) | ⏳ 16 bloques JSONB |
| 207 | `idn_user_template_history` | NUEVA | — | No (WORM — solo INSERTs runtime) | 🆕 Simetría con 205 |
| 208 | `idn_tier_policy` | bos_tier_policy | 1379 | Sí (4 tiers NIST 800-63B-4 predefinidos) | ⏳ |

### 2.2 — Relación Áreas ↔ Roles (1:N)

**Concepto:** Un Área Organizacional es una unidad funcional (Gerencia Financiera, Dirección de Personal...). Cada área agrupa roles exclusivos y compartidos. El mismo rol (Secretaria, Chofer, Mensajero) puede existir en MÚLTIPLES áreas. Relación 1:N → Área : Roles.

Las áreas se almacenan en `log_zone` como zonas funcionales. La asignación de roles a áreas se gestiona vía `log_permission` (área × verbo × rol × scope).

**29 áreas organizacionales definidas en `BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` §9:**

| Área | Nivel | Roles típicos |
|------|-------|--------------|
| AREA-DIR | N1 | CEO, EVP, Secretaria de Dirección, Chofer Ejecutivo |
| AREA-FIN | N2 | CFO, Director Financiero, Contador, Tesorero, Secretaria, Mensajero, Chofer |
| AREA-CONT | N3 | Jefe de Contabilidad, Contador, Auxiliar Contable, Encargado de Facturación |
| AREA-COM | N2 | CCO, Director Comercial, Gerente de Ventas, Vendedores, Secretaria, Chofer |
| AREA-VENT | N3 | Gerente de Ventas, Jefe de Ventas, Vendedores, Asistente, Chofer de Reparto |
| AREA-MKT | N2 | CMO, Director de Marketing, Diseñador, Community Manager, Analista de Datos |
| AREA-OPER | N2 | COO, Director de Operaciones, Gerente de Operaciones, Supervisor de Turno |
| AREA-LOG | N3 | Director de Logística, Jefe de Almacén, Despachador, Chofer de Reparto |
| AREA-IT | N2 | CTO, Director de IT, Gerente de TI, Jefe de Sistemas, Técnicos, Programadores |
| AREA-RRHH | N2 | CHRO, Director de RRHH, Gerente de RRHH, Reclutador, Capacitador, Secretaria |
| AREA-LEGAL | N2 | CLO, Director Legal, Abogados, Secretaria, Mensajero |
| AREA-COMP | N2 | Director de Compras, Gerente de Compras, Encargado de Compras |
| AREA-PROD | N2 | Gerente de Producción, Supervisor de Planta, Operarios, Técnico de Calidad |
| AREA-SEG | N2 | Director de Seguridad, Jefe de Seguridad, Vigilantes, Portero |
| AREA-ADM | N2 | Secretario General, Recepcionista, Telefonista, Auxiliares, Cadete |
| AREA-SERV | N4 | Personal de Limpieza, Jardinero, Cocinero, Ascensorista |
| AREA-TRANS | N3 | Jefe de Flota, Chofer Ejecutivo, Chofer de Reparto, Courier |

**Roles compartidos entre áreas:** Secretaria (13 áreas), Chofer (6), Mensajero (7), Auxiliar de Oficina (3), Cadete (2), Analista de Datos (3), Técnico de Sistemas (2).

**Seed:** 29 áreas → `log_zone`. Activación escalable por tamaño de empresa (Tienda: 1 área, PYME: 9, Corporación: 29).

---

### SUBSISTEMA 2b — Sistema de Menús (menu_) 🆕

| # | Tabla | Origen | Línea | Seed | Estado |
|---|-------|--------|-------|------|--------|
| 211 | `menu_item` | NUEVA | — | Sí (~50 ítems jerárquicos base) | 🆕 Pendiente agregar a DDL |
| 212 | `menu_context` | NUEVA | — | Sí (6 contextos estándar) | 🆕 Pendiente agregar a DDL |
| 213 | `menu_item_atom` | NUEVA | — | No (asignación por tenant) | 🆕 Puente menú↔privilege_atom |

**Referencia:** `BAUTH-090-MENU-SYSTEM-SPEC.md` v2.0. El menú usa `privilege_atom.atom_code` (INTEGER, label encoding) para evaluar visibilidad vía BitMask. La función `fn_resolve_menu` retorna solo los ítems que el usuario puede ver.

---

### 2.4 — Datos de Selección para Templates (NUEVOS seeds) 🆕

| # | Seed | Registros | Fuente | Usado en |
|---|------|-----------|--------|----------|
| N01 | `seed_account_type` | 4 | SCIM 2.0 RFC 7643 | UserTemplate.block1 |
| N02 | `seed_gender` | 4 | ISO/IEC 5218 + RGPD | UserTemplate.block2 |
| N03 | `seed_marital_status` | 7 | Normativa civil LATAM | UserTemplate.block2 |
| N04 | `seed_id_document_type` | ~12 | Normativa migratoria LATAM | UserTemplate.block2 |
| N05 | `seed_employment_type` | 7 | OIT + legislación laboral | UserTemplate.block3 |

---

### SUBSISTEMA 3 — Identidad Organizacional (idn_)

| # | Tabla | Origen | Línea | Seed | Estado |
|---|-------|--------|-------|------|--------|
| 301 | `idn_tenant` | bos_tenant | — | No (datos por tenant) | ✅ YA REPARADO |
| 302 | `idn_empresa` | bos_empresa | 1046 | No (datos por tenant) | ⏳ |
| 303 | `idn_sucursal` | bos_sucursal | 1117 | No (datos por tenant) | ⏳ |
| 304 | `idn_pos` | bos_pos_logico | 1170 | No (datos por tenant) | ⏳ SIN Bolivia |
| 305 | `idn_tenant_config` | bos_tenant_config | — | No (datos por tenant) | ✅ YA REPARADO |

### SUBSISTEMA 4 — Autenticación (ath_ + cre_)

| # | Tabla | Origen | Línea | Seed | Estado |
|---|-------|--------|-------|------|--------|
| 401 | `ath_method` | bos_auth_method | 2282 | Sí (18 métodos predefinidos) | ⏳ |
| 402 | `ath_policy` | bos_auth_policy | 2309 | Sí (políticas base por LoA) | ⏳ |
| 403 | `ath_config` | bos_auth_config | 2327 | Sí (configuración base) | ⏳ |
| 404 | `cre_credential_policy` | bos_credential_policy | 978 | No (datos por tenant/rol) | ⏳ |
| 405 | `cre_credential_rotation_log` | bos_credential_rotation_log | 1014 | No (WORM — solo INSERTs runtime) | ⏳ |
| 406 | `cre_password_history` | bos_password_history | 1649 | No (WORM — solo INSERTs runtime) | ⏳ |
| 407 | `cre_mfa_enrollments` | bos_mfa_enrollments | 1690 | No (datos por usuario) | ⏳ |
| 408 | `cre_biometric_templates` | bos_biometric_templates | 1611 | No (datos por usuario) | ⏳ |

### SUBSISTEMA 5 — Trazabilidad (aud_ + ses_ + dlg_)

| # | Tabla | Origen | Línea | Seed | Estado |
|---|-------|--------|-------|------|--------|
| 501 | `aud_event` | bos_audit_events | 1722 | No (WORM particionado — solo INSERTs runtime) | ⏳ |
| 502 | `aud_access_reviews` | bos_access_reviews | 1964 | No (datos por tenant) | ⏳ |
| 503 | `aud_ghost_accounts` | bos_ghost_accounts | 1991 | No (datos por tenant) | ⏳ |
| 504 | `aud_superuser_contexts` | bos_superuser_contexts | 1938 | No (WORM — solo INSERTs runtime) | ⏳ |
| 505 | `ses_context` | bos_context_sessions | 1819 | No (datos por sesión) | ⏳ ctx_id |
| 506 | `ses_context_switches` | bos_context_switches | 1874 | No (datos por sesión) | ⏳ |
| 507 | `ses_sync_log` | bos_sync_log | 1896 | No (WORM — solo INSERTs runtime) | ⏳ KC+Tryton |
| 508 | `dlg_delegation_log` | bos_delegation_log | 1570 | No (WORM — solo INSERTs runtime) | ⏳ D10 |

---

### 2.1 — Investigación de Verbos: privilege_verb más allá del CRUD

**El catálogo actual del bauth (código Rust `bitmask/catalog.rs`) define 4 verbos Fast-Path:**
`nuevo`(1), `editar`(2), `eliminar`(3), `ver`(4). Estos son label encoding usados por el motor
BitMask para evaluación <0.5ns. Pero Tryton maneja una colección mucho más rica de acciones.

**Tryton tiene 5 niveles de access rights** (fuente: Tryton 7.6 oficial):

| Nivel | Tabla | Verbos/Acciones | Descripción |
|-------|-------|----------------|-------------|
| **Modelo** | `ir.model.access` | `create`, `read`, `write`, `delete` | Permisos CRUD por modelo × grupo |
| **Acción** | `ir.action.groups` | `execute` (implícito) | Acceso a wizards, reports, menús. Verifica `read` en el modelo subyacente |
| **Campo** | `ir.model.field.access` | `read`, `write` | Control de acceso a nivel de campo por grupo |
| **Botón** | `ir.model.button` | `click` (implícito) + rules | Botones en vistas. `read` en modelo SIEMPRE requerido. `write` si no hay grupo |
| **Registro** | `ir.rule.group` | `read`, `write`, `create`, `delete` (domain-based) | Filtrado de registros por dominio. Global/default/group |

**Acciones de negocio Tryton (ir.model.button + workflow):**

| Verbo | Tipo | Ejemplo Tryton | Cómo se sincroniza |
|-------|------|---------------|-------------------|
| `create` | CRUD base | Crear factura | → `privilege_verb.verb_code=1` (nuevo) |
| `read` | CRUD base | Ver lista de clientes | → `privilege_verb.verb_code=4` (ver) |
| `write` | CRUD base | Editar dirección | → `privilege_verb.verb_code=2` (editar) |
| `delete` | CRUD base | Eliminar borrador | → `privilege_verb.verb_code=3` (eliminar) |
| `approve` | Workflow | Aprobar factura para envío al SIN | → RolTemplate.policies.logical_access.{permission}.overrides |
| `cancel` | Workflow | Cancelar factura emitida | → `ir.model.button` groups |
| `validate` | Workflow | Validar número de factura (SIN secuencial) | → `ir.model.button` + `ir.rule` domain |
| `post` | Workflow | Contabilizar asiento en mayor | → `ir.model.button` groups |
| `reconcile` | Workflow | Conciliar pago con factura | → `ir.model.button` groups |
| `draft` | Workflow | Volver a borrador | → `ir.model.button` groups |
| `submit` | Workflow | Enviar a aprobación | → `ir.model.button` groups |
| `reject` | Workflow | Rechazar aprobación | → `ir.model.button` groups |
| `close` | Workflow | Cerrar período/gestión | → `ir.model.button` groups |
| `reopen` | Workflow | Reabrir gestión cerrada | → `ir.model.button` groups |
| `duplicate` | UI | Duplicar registro | → `ir.model.button` groups |
| `export` | UI | Exportar a CSV/PDF | → `ir.action.groups` |
| `print` | UI | Imprimir reporte | → `ir.action.groups` |
| `email` | UI | Enviar por correo | → `ir.model.button` groups |
| `execute` | Wizard | Ejecutar wizard (ej: cierre masivo) | → `ir.action.groups` |

**Catálogo completo de verbos empresariales — Investigación de fuentes reales:**

### Fuente 1: SAP Authorization Objects (ACTVT — 31 códigos estándar + extendidos)

SAP define el catálogo más completo de la industria. Cada código es independiente (no jerárquico):

| Código | Verbo (EN) | Verbo (ES) | Aplica a SBOS |
|--------|-----------|-----------|---------------|
| 01 | **Create** | Crear / Nuevo | ✅ BitMask 1 |
| 02 | **Change** | Modificar / Editar | ✅ BitMask 2 |
| 03 | **Display** | Mostrar / Ver | ✅ BitMask 4 |
| 04 | **Print** | Imprimir | ✅ Tryton ir.actions.report |
| 05 | **Lock** | Bloquear | ✅ |
| 06 | **Delete** | Eliminar | ✅ BitMask 3 |
| 07 | **Unlock** | Desbloquear | ✅ |
| 08 | **Display Change Documents** | Ver historial de cambios | ✅ |
| 09 | **Check** | Verificar / Validar | ✅ |
| 10 | **Post** | Contabilizar / Registrar | ✅ Tryton account.move |
| 11 | **Release** | Liberar / Publicar | ✅ |
| 12 | **Undo Release** | Deshacer liberación | ✅ |
| 13 | **Complete Technically** | Completar técnicamente | ✅ |
| 14 | **Complete** | Completar / Finalizar | ✅ |
| 15 | **Reverse** | Reversar / Anular | ✅ |
| 16 | **Execute** | Ejecutar (programa/reporte) | ✅ Tryton ir.action |
| 17 | **Approve** | Aprobar | ✅ Tryton ir.model.button |
| 18 | **Reject** | Rechazar | ✅ Tryton ir.model.button |
| 19 | **Block** | Bloquear (vendor/customer) | ✅ |
| 20 | **Unblock** | Desbloquear | ✅ |
| 21 | **Archive** | Archivar | ✅ |
| 22 | **Copy** | Copiar | ✅ |
| 23 | **Save** | Guardar | ✅ |
| 24 | **Submit** | Enviar a aprobación | ✅ |
| 25 | **Transfer** | Transferir | ✅ |
| 26 | **Close** | Cerrar (período/objeto) | ✅ |
| 27 | **Display Totals** | Ver totales (reporting) | ✅ |
| 28 | **Display Line Items** | Ver partidas individuales | ✅ |
| 29 | **Display Saved Data** | Ver extractos guardados | ✅ |
| 30 | **Maintain Settlement Rule** | Mantener regla de liquidación | ✅ |
| 31 | **Maintain Settlement Parameters** | Mantener parámetros de liquidación | ✅ |

### Fuente 2: Odoo ORM (ir.model.access + ir.model.button)

| Permiso | Descripción |
|---------|-------------|
| `perm_create` | Crear registros |
| `perm_read` | Leer registros |
| `perm_write` | Modificar registros |
| `perm_unlink` | Eliminar registros |
| `ir.model.button` | Botones de acción (approve, confirm, cancel, etc. — N ilimitados) |
| `ir.actions` | Wizards, reportes, menús |
| `ir.rule` | Filtros de dominio por registro |

### Fuente 3: Microsoft Dynamics 365 (8 privilegios + 5 niveles de acceso)

| Privilegio | Descripción | Equivalente SBOS |
|-----------|-------------|-----------------|
| **Create** | Crear nuevo registro | BitMask 1 |
| **Read** | Ver contenido de registro | BitMask 4 |
| **Write** | Modificar registro existente | BitMask 2 |
| **Delete** | Eliminar permanentemente | BitMask 3 |
| **Append** | Asociar registro hijo a padre | Tryton relation |
| **Append To** | Ser el padre de una asociación | Tryton relation |
| **Assign** | Cambiar propietario del registro | Tryton write |
| **Share** | Compartir acceso con otro usuario | Tryton ir.rule |

**5 niveles de acceso (scoping):** None, Basic (User), Local (Business Unit), Deep (Parent:Child), Global (Organization).
Esto equivale al `scope` del RolTemplate: PERSONAL, BRANCH, COMPANY, GLOBAL.

### Fuente 4: ServiceNow (5 operaciones ACL)

| Operación | Descripción |
|-----------|-------------|
| **Create** | Insertar nuevos registros |
| **Read** | Ver registros y campos |
| **Write** | Modificar registros existentes |
| **Delete** | Eliminar registros |
| **Execute** | Ejecutar scripts, UI actions, script includes |

### Fuente 5: Oracle NetSuite (4 niveles de permiso)

| Permiso | Descripción |
|---------|-------------|
| **View** (1) | Solo lectura |
| **Create** (2) | Crear + Ver |
| **Edit** (3) | Modificar + Crear + Ver |
| **Full** (4) | Eliminar + Modificar + Crear + Ver (jerárquico) |

### Fuente 6: AWS IAM — Service-Last Verbs

AWS IAM tiene ~10,000+ acciones únicas (`iam:CreateRole`, `s3:GetObject`, `ec2:StartInstances`).
Patrón: `{service}:{CRUD_Verb}{Resource}`. Los verbos base son siempre CRUD.

---

### 2.1b — Investigación de Grupos Funcionales (privilege_group + privilege_application)

**El catálogo de grupos define cómo se organizan los permisos DENTRO de cada aplicación.**
Cada aplicación tiene sus propios grupos funcionales. Los grupos heredan permisos vía `implied_ids`.

#### Fuente 1: Odoo — 12 categorías estándar + jerarquía de grupos

| Categoría (ir.module.category) | Grupos típicos |
|-------------------------------|----------------|
| **Sales** | User (propio), Manager (propio + todos) |
| **Accounting** | Accountant, Accountant Manager, Advisor |
| **Inventory** | User, Manager |
| **Human Resources** | Employee, Officer, Manager |
| **Project** | User, Manager |
| **Purchases** | User, Manager |
| **Manufacturing** | User, Manager |
| **Contacts** | User, Manager |
| **Technical** | Settings, Technical Features |
| **Administration** | Access Rights, Settings, Translations |
| **Hidden** | Multi-Company, Portal, Public |

**Jerarquía de grupos Odoo (implied_ids):**
```
base.group_user (Empleado — base, todos lo heredan)
  ├── sale.group_sale_user → sale.group_sale_manager
  ├── account.group_account_user → account.group_account_manager
  ├── stock.group_stock_user → stock.group_stock_manager
  └── hr.group_hr_user → hr.group_hr_manager → hr.group_hr_officer
```

#### Fuente 2: Tryton — Grupos por módulo funcional

| Módulo | Grupos |
|--------|--------|
| **account** | Accountant, Accountant Manager, Financial Advisor |
| **stock** | Stock User, Stock Manager |
| **sale** | Sale User, Sale Manager |
| **purchase** | Purchase User, Purchase Manager |
| **timesheet** | Timesheet User, Timesheet Manager |
| **project** | Project User, Project Manager |
| **admin** | Administrator |

#### Fuente 3: SAP — Grupos de actividad por módulo

SAP no usa "grupos" como Odoo/Tryton. Usa **Activity Groups** (ACTVT) combinados con
**Authorization Objects** por módulo (FI, CO, MM, SD, PP, HR...). Cada módulo tiene
docenas de authorization objects, cada uno con sus propios ACTVT codes.

#### Aplicación al SBOS — Catálogo de Aplicaciones y Grupos

**Aplicaciones base SBOS (privilege_application) — Inventario real desde BosAgent `servers/`:**

| app_code | app_name | app_slug | Ficha (servers/) | Grupos funcionales |
|----------|----------|----------|-----------------|-------------------|
| 1 | **Tryton** | tryton | S01/tryton | account, stock, sale, purchase, timesheet, project, admin, point_of_sale, calendar, marketing |
| 2 | **Keycloak** | keycloak | S03/keycloak | realm_admin, client_admin, user_admin, identity_provider, auditor |
| 3 | **Kong** | kong | S02/kong | admin, developer, consumer, monitor |
| 4 | **Vault** | vault | S02/vault | admin, operator, auditor, app_role |
| 5 | **Cal.com** | calcom | S06/calcom | calendar_admin, calendar_user, schedule_viewer |
| 6 | **Mattermost** | mattermost | S06/mattermost | channel_admin, user, auditor |
| 7 | **Novu** | novu | S06/novu | workflow_admin, subscriber_manager, viewer |
| 8 | **Grafana** | grafana | S12/grafana | editor, viewer, admin |
| 9 | **Prometheus** | prometheus | S12/prometheus | admin, operator, viewer |
| 10 | **Besu QBFT** | besu | S02/besu-qbft | validator, rpc_user, auditor |
| 11 | **MinIO** | minio | S01/minio | admin, readwrite, readonly |
| 12 | **PostgreSQL** | postgresql | S01/postgresql | superuser, readwrite, readonly, replicator |

**Las 19 fichas restantes son INFRAESTRUCTURA** (sin permisos de usuario): bos-preflight, sbos-bootstrap-*, sbos-bkernel, certbot, nginx, oauth2-proxy, kyverno, linkerd, ferretdb, sbos-notifier, alertmanager, alloy, redis.

**Gobierno de aplicaciones:** Al instalar una ficha vía `bosctl ficha install`, BOS registra
automáticamente la app en `privilege_application`. Al desinstalar, verifica que no haya usuarios
activos ni movimiento reciente (90 días). Si hay usuarios → bloqueo. Si hay historial → notificación
con preaviso de 30 días. Si está inactiva → desinstalación limpia. Ver BAUTH-SEED-PLAN.md §7.5.

**Seed propuesto para `privilege_group`:** 12 aplicaciones × ~3 grupos promedio = ~40 grupos.

---

Tras analizar 6 sistemas de producción reales (SAP, Odoo, Tryton, Dynamics 365, ServiceNow, NetSuite),
el catálogo canónico de verbos para `privilege_verb` se consolida en **4 categorías**:

| Categoría | Códigos | Cantidad | Evaluación |
|-----------|---------|----------|------------|
| **CRUD Base** | 1-4 (create, read, update, delete) | 4 | Fast-Path BitMask <0.5ns |
| **Acciones de Negocio** | 5-31 (SAP ACTVT: approve, reject, post, reverse, submit, close...) | 27 | Tryton ir.model.button |
| **Acciones Extendidas** | 32-46 (Odoo extra + Dynamics: append, assign, share, duplicate, export...) | 15 | Tryton ir.action |
| **Ejecución** | 47-50 (execute, schedule, delegate, impersonate) | 4 | ServiceNow + bauth interno |
| **TOTAL** | | **~50 verbos** | |

**Principio:** `privilege_verb` almacena TODOS los verbos en UNA tabla. El `verb_code` 1-4
es Fast-Path. El resto se usa en las capas de sincronización. Nuevos verbos = INSERT, sin ALTER TABLE.

---

### 2.3 — El ÁTOMO y la POLÍTICA: La unidad mínima de permiso

**Átomo (privilege_atom) = combinación de 4 elementos base:**

```
átomo = app_code × group_code × domain_code × verb_code

Ejemplo concreto — átomo #1059:
  app_code:    1 (Tryton)
  group_code:  1 (account — grupo funcional Contabilidad)
  domain_code: 3 (D3 Financiero)
  verb_code:   1 (create)
  ────────────────────────────────────────────
  Significado: "Crear factura en el módulo de Contabilidad de Tryton"
  atom_slug:   "tryton.account.factura.create"
  atom_position: 3 → Fast-Path BitMask <0.5ns
```

**El átomo es el QUÉ. La política es el CÓMO.**

Cada átomo (P03) tiene 1+N políticas (P04) que definen las reglas de evaluación:

```
privilege_atom_policy para átomo #1059:
  ├── Política SoD:      { "type":"SoD", "rule":"creator_neq_approver" }
  ├── Política Límite:   { "type":"FinancialLimit", "max_amount":50000, "period":"daily" }
  ├── Política Dual:     { "type":"DualApproval", "required":true, "amount_threshold":10000 }
  ├── Política Evidencia:{ "type":"Evidence", "required":true, "doc_types":["FACTURA"] }
  ├── Política SIN:      { "type":"SINNotification", "required":true }
  └── Política Auditoría:{ "type":"Audit", "level":"full", "retention_days":2555, "hash_chain":true }
```

**Evaluación del motor BitMask:**
```
¿Puede el usuario X ejecutar el átomo #1059?
  ├── D8 Contexto:   ¿ctx_id válido? → OK
  ├── D9 Credenciales: ¿autenticado con AAL2+? → OK
  ├── D1 Lógico:     ¿tiene el rol el verbo "create" sobre "factura"? → OK (Fast-Path)
  ├── D3 Financiero: ¿monto ≤ 50000? ¿no es el mismo que creó? (SoD) → Policy-Path
  ├── D4 Temporal:   ¿está en horario laboral? → Policy-Path
  └── D11 Auditoría:  registrar evento WORM con hash-chain → Siempre
```

**Dependencias para construir átomos y políticas:**

```
P01 (dominios) ──┐
P02 (verbos) ────┤
P05 (apps) ──────┼──→ P03 (átomos = combinaciones válidas)
P06 (grupos) ────┘         │
                            └──→ P04 (políticas = reglas por átomo)
```

**Máximo teórico vs real:**
- Combinaciones posibles: 12 apps × 40 grupos × 12 dominios × 4 verbos = **23,040**
- Combinaciones válidas reales: **~1,059** (solo las que tienen sentido de negocio)
- Políticas totales: **~6,782** (cada átomo tiene 1+N políticas)

---

## 3. PLAN DE PROCESAMIENTO ORDENADO

```
FASE A — Identidad Organizacional (3 tablas · ~2h)
  idn_empresa, idn_sucursal, idn_pos
  Sin esto no hay tenant completo. Es la base de todo.

FASE B — Catálogo Lógico (2 tablas · ~1h)
  log_zone, log_permission
  Define el vocabulario de zonas y permisos.

FASE C — Templates de Roles y Usuarios (7 tablas · ~3h)
  idn_role_template, idn_role_closure, idn_role_template_history
  idn_user_template, idn_tier_policy
  log_zone_application_map → log_zone_app

FASE D — Motor de Privilegios (9 tablas · ~4h)
  Migrar bos_privilege.* → bauth.privilege_*
  Con 1059 átomos y 6782 políticas existentes.

FASE E — Autenticación y Credenciales (8 tablas · ~3h)
  ath_method, ath_policy, ath_config
  cre_credential_policy, cre_rotation_log, cre_password_history
  cre_mfa_enrollments, cre_biometric_templates

FASE F — Trazabilidad y Auditoría (8 tablas · ~3h)
  aud_event + particiones, aud_access_reviews, aud_ghost_accounts
  aud_superuser_contexts, ses_context, ses_context_switches
  ses_sync_log, dlg_delegation_log

TOTAL: ~37 tablas · ~16 horas de trabajo
```

---

## 4. INTERFACES A DESARROLLAR

### 4.1 — Pantallas del D1

| Interfaz | Tablas que consulta | Tablas que escribe |
|----------|-------------------|-------------------|
| **Gestión de Roles** | idn_role_template, idn_role_closure, privilege_atom, log_zone | idn_role_template, idn_role_template_history |
| **Asignación de Permisos** | log_zone, log_permission, privilege_verb | log_permission |
| **Catálogo de Zonas** | log_zone | log_zone |
| **Usuarios** | idn_user_template, idn_role_template, cre_mfa_enrollments | idn_user_template |
| **Autenticación** | ath_method, ath_policy, cre_credential_policy | — (lectura) |
| **Auditoría** | aud_event, ses_context, dlg_delegation_log | — (lectura, WORM) |
| **Sincronización KC** | idn_role_template, idn_user_template | ses_sync_log (trigger) |
| **Empresa/Sucursal/POS** | idn_empresa, idn_sucursal, idn_pos | idn_empresa, idn_sucursal, idn_pos |

### 4.2 — Orden de desarrollo de interfaces

```
1. Gestión de Empresa/Sucursal/POS  (FASE A — sin esto no hay tenant)
2. Catálogo de Zonas                 (FASE B — vocabulario base)
3. Gestión de Roles                  (FASE C — 368 roles, herencia, JSONB)
4. Asignación de Permisos            (FASE C — zona × verbo × rol)
5. Usuarios                          (FASE C — templates + credenciales)
6. Autenticación                     (FASE E — métodos, políticas)
7. Auditoría y Trazabilidad          (FASE F — WORM, ctx_id)
8. Sincronización KC+Tryton          (FASE F — reconcile loop)
```

---

## 5. REGLAS DE DISEÑO APLICADAS A TODO EL D1

| # | Regla | Fundamento |
|---|-------|------------|
| R1 | UUIDv7 PK en toda tabla | RFC 9562 |
| R2 | Columnas en inglés, snake_case | ISO SQL standard |
| R3 | ENUM types, nunca CHECK IN | Type-safe, reutilizable |
| R4 | COMMENT ON con [RFC/ISO] en cada columna | Documentación normativa |
| R5 | ctx_id en toda tabla Nivel 1+ | SBOS-049 |
| R6 | created_at + updated_at en toda tabla | ISO 27001 A.8.15 |
| R7 | JSONB para campos variables | Extensibilidad sin ALTER TABLE |
| R8 | Jerarquía con parent_id + closure table | Herencia H-RBAC |
| R9 | Hash-chain SHA-256 en tablas WORM | PCI DSS 10.3.2 |
| R10 | Particiones por mes en tablas de alto volumen | PostgreSQL 18 |

---

*Documento v3.0 — 2026-06-23. Este es EL documento para retomar el desarrollo de bAuth.
Cada tabla listada aquí debe ser procesada, cada interfaz desarrollada en el orden indicado.
Si D1 funciona, el SBOS funciona.*

## 6. GUÍA DE LLENADO — ROLTEMPLATE (16 BLOQUES JSONB — 12 DOMINIOS)

### 1.1 — Bloque 1: Identidad (`role.identity`)

| Campo | Quién lo llena | Cuándo | Regla de validación |
|-------|---------------|--------|-------------------|
| `id` | Sistema | Al crear | Inmutable. Formato: `{SIGLA}-{3_DIGITOS}` |
| `parent_id` | Arquitecto RBAC | Al crear | Debe existir en idn_role_template. NULL = raíz |
| `type_id` | Arquitecto RBAC | Al crear | TYPE-OPERATIVO, TYPE-SUPERVISOR, TYPE-GERENCIA-MEDIA, TYPE-DIRECCION, TYPE-ADMIN-SISTEMA, TYPE-SERVICIO, TYPE-AUDITORIA |
| `hierarchy_level` | Sistema | Automático | 1=C-Level, 2=Gerencia, 3=Supervisor, 4=Operativo, 5=Soporte. Derivado del parent |
| `path_ids[]` | Sistema | Automático | Solo lectura. Cadena de ancestros calculada |
| `version` | Sistema | Automático | SemVer. MAJOR al cambiar permisos |
| `status` | Arquitecto RBAC | Manual | DRAFT→REVIEW→ACTIVE→DEPRECATED→ARCHIVED |
| `name` | Arquitecto RBAC | Al crear | Obligatorio en es + en. pt opcional |
| `description` | Arquitecto RBAC | Al crear | Obligatorio: qué hace, alcance, límites |
| `metadata` | Arquitecto RBAC | Al crear | Datos organizacionales |

**Ejemplo de llenado:**

```json
{
  "id": "VEN-VEN-001",
  "parent_id": "VEN-BASE-001",
  "type_id": "TYPE-OPERATIVO",
  "hierarchy_level": 4,
  "status": "ACTIVE",
  "name": {"es": "Vendedor Junior", "en": "Junior Sales Representative"},
  "description": {
    "es": "Ejecuta ventas al por menor en sucursal asignada. No puede aprobar descuentos >10%. No puede modificar precios de lista.",
    "en": "Executes retail sales at assigned branch. Cannot approve discounts >10%. Cannot modify list prices."
  },
  "metadata": {"sector_caeb": "COMERCIO", "reporta_a": "SUPERVISOR-VENTAS"}
}
```

### 1.0 — ACLARACIÓN: Dónde se modifican las políticas

**Pregunta clave:** ¿La política se modifica en la tabla de políticas, en el RolTemplate,
o en el UserTemplate?

**Respuesta (investigación Google Cloud IAM + NIST RBAC):** En los 3 niveles, con herencia
en cascada y una regla de hierro.

```
BASE POLICY (tabla de dominio)
    │  fin_limit: daily = $10,000
    │  Creado por: Compliance Officer
    │  Es el molde original. Todos los roles que la referencian parten de aquí.
    │
    ▼
ROLE OVERRIDE (RolTemplate JSONB)
    │  policies.financial_limits[0] = {
    │    "policy_id": "uuid-limit-base",
    │    "overrides": { "daily": 5000 }
    │  }
    │  Creado por: Admin RBAC al asignar la política al rol
    │  Regla: SOLO puede ser MÁS RESTRICTIVO (5000 ≤ 10000 ✅)
    │
    ▼
USER OVERRIDE (UserTemplate JSONB)
    │  assigned_roles[0].policy_overrides = {
    │    "uuid-limit-base": { "daily": 3000 }
    │  }
    │  Creado por: Admin Tenant para un usuario específico
    │  Regla: SOLO puede ser MÁS RESTRICTIVO (3000 ≤ 5000 ✅)
    │
    ▼
BAUTH EVALUATION ENGINE
    │  Evalúa: ¿hay user override? → usa ese.
    │          ¿hay role override? → usa ese.
    │          Si no → usa base policy.
    │  Resultado final: daily limit de María = $3,000
```

**Regla de hierro (NIST 800-53 AC-6 Least Privilege):**
> Un override NUNCA puede otorgar MÁS permisos que el nivel superior.
> Solo puede ser IGUAL o MÁS RESTRICTIVO. Violar esto = escalamiento de privilegios.

**Ejemplo concreto:**
1. Base `fin_limit`: "Cajero puede aprobar hasta $10,000/día"
2. Rol "Cajero Sucursal Pequeña" → override: "máximo $5,000/día" (más restrictivo ✅)
3. Usuario "María" (Cajero Sucursal Pequeña) → override: "máximo $3,000/día" (más restrictivo ✅)
4. Si María intenta aprobar $6,000 → RECHAZADO (su límite es $3,000)
5. Si María intenta cambiar su override a $15,000 → RECHAZADO (viola regla de hierro)

**Fuentes:** Google Cloud IAM Conditions (CEL-based attribute evaluation, 2024), NIST SP 800-53 AC-6 (Least Privilege), NIST SP 800-162 (ABAC Guide), SailPoint IdentityNow Policy Override Model.

---

### 1.2 — MODELO DE RECETA: El RolTemplate REFERENCIA políticas, no las incrusta

**Principio:** Cada dominio (D1-D12) tiene sus propias tablas de políticas. El RolTemplate
solo guarda REFERENCIAS (UUIDs) a esas políticas. Así, una misma política se reutiliza
en múltiples roles.

```json
{
  "role": {
    "id": "ROL-CAJERO",
    "name": {"es": "Cajero"},
    "type_id": "TYPE-OPERATIVO",
    "hierarchy_level": 4,
    "status": "ACTIVE"
  },
  "policies": {
    "logical_access": {
      "zones": [
        {"zone_id": "uuid-zona-caja", "overrides": {}},
        {"zone_id": "uuid-zona-ventas", "overrides": {}}
      ],
      "permissions": [
        {"permission_id": "uuid-perm-1", "overrides": {"max_records": 500}},
        {"permission_id": "uuid-perm-2", "overrides": {}}
      ]
    },
    "financial_limits": {
      "limits": [
        {
          "policy_id": "uuid-limit-base-cajero",
          "overrides": {
            "daily": 5000,
            "monthly": 50000
          }
        }
      ]
    },
    "temporal_schedule": {
      "schedule_id": "uuid-horario-oficina",
      "overrides": {
        "allow_overtime": false
      }
    },
    "credential_policy": {
      "policy_id": "uuid-policy-totp-obligatorio",
      "overrides": {
        "min_aal": "AAL2"
      }
    },
    "physical_access": {
      "zones": [
        {"zone_id": "uuid-zona-sucursal", "overrides": {"max_security_zone": 3}}
      ]
    },
    "audit": {
      "level": "basic"
    }
  }
}
```

**Cada política se compone de `policy_id` (referencia) + `overrides` (ajustes del rol).**
El motor bauth evalúa: `effective = base_policy ⊕ role_overrides ⊕ user_overrides`
donde ⊕ = merge con regla de hierro (solo más restrictivo).

**Ventaja:** El Cajero A (sucursal grande) tiene `daily: 5000`. El Cajero B (sucursal
pequeña) referencia la MISMA `uuid-limit-base-cajero` pero con `daily: 2000`.
Si Compliance cambia la base de $10K a $8K, ambos heredan el cambio automáticamente.
Pero si solo quieren ajustar el Cajero B, editan el `overrides` de ESE rol.
Sin tocar la base, sin tocar otros roles.

### 1.3 — Bloque 2: Acceso Lógico (`policies.logical_access`)

Cada entrada es `{id, overrides}`. El `id` referencia la política base. `overrides` almacena
los ajustes específicos de este rol. Si `overrides` está vacío `{}`, se usa la política tal cual.

```json
{
  "zones": [
    {"zone_id": "uuid-zona-caja", "overrides": {}},
    {"zone_id": "uuid-zona-ventas", "overrides": {}}
  ],
  "permissions": [
    {
      "permission_id": "uuid-perm-cajero-base",
      "overrides": {
        "max_records": 500,
        "requires_step_up": false,
        "data_classification": "INTERNAL"
      }
    }
  ],
  "scope": "COMPANY"
}
```

| Campo | Estructura | Ejemplo |
|-------|-----------|---------|
| `zones[].zone_id` | UUID → `log_zone` | `"uuid-zona-caja"` |
| `zones[].overrides` | JSONB (ajustes del rol) | `{}` (sin cambios) |
| `permissions[].permission_id` | UUID → `log_permission` | `"uuid-perm-cajero-base"` |
| `permissions[].overrides` | JSONB (ajustes del rol) | `{"max_records": 500}` |
| `scope` | Enum directo | GLOBAL, COMPANY, BRANCH, PERSONAL |

### 1.4 — Bloque 3: Acceso Físico (`policies.physical_access`)

```json
{
  "zones": [
    {
      "zone_id": "uuid-zona-sucursal",
      "overrides": {
        "max_security_zone": 3,
        "requires_escort": false
      }
    }
  ]
}
```

### 1.5 — Bloque 4: Límites Financieros (`policies.financial_limits`)

```json
{
  "limits": [
    {
      "policy_id": "uuid-limit-base-cajero",
      "overrides": {
        "daily": 5000,
        "monthly": 50000,
        "per_operation": 2000,
        "requires_dual_approval": false,
        "max_approval_amount": 50000
      }
    }
  ]
}
```

### 1.5b — Bloque 5: Horario (`role.temporal_schedule`)

| Campo | Quién lo llena | Ejemplo |
|-------|---------------|---------|
| `schedule_id` | Operaciones | UUID de cal_schedule |
| `allow_overtime` | Operaciones | true — puede trabajar fuera de horario |
| `requires_approval_outside` | Operaciones | true — fuera de horario → step-up MFA |

### 1.6 — MAPEO COMPLETO A LOS 12 DOMINIOS DE SOBERANÍA (D1-D12)

Cada bloque del RolTemplate materializa UN dominio de soberanía. Los bloques transversales
(identity, compliance, sync_metadata, bitmask) aplican a todos los dominios.

| # | Bloque JSONB | Dominio | Cómo se representa | Investigación |
|---|-------------|---------|-------------------|---------------|
| 1 | `identity` | D1 Lógico (base) | id, parent_id, type_id, hierarchy_level, status, name, description, metadata | ANSI INCITS 359-2004 |
| 2 | `logical_access` | **D1 Lógico** | zones[], verbs[], scope, max_records, requires_step_up, data_classification, applications[], menu_items[], reports[] | NIST RBAC Nivel 3, NIST 800-53 AC-3 |
| 3 | `physical_access` | **D2 Físico** | site_ids[], zone_ids[], max_security_zone, requires_escort, allowed_schedules[] | IEC 60839-11-5 (OSDP), BS 5979, NIST 800-53 PE |
| 4 | `financial_limits` | **D3 Financiero** | limits[{transaction_type, max_amount, period}], requires_dual_approval, max_approval_amount | ISO 20022, COSO, SOX §404, NIST 800-53 AC-5 |
| 5 | `temporal_schedule` | **D4 Temporal** | schedule_id, allow_overtime, requires_approval_outside, grace_period_minutes | RFC 5545 (iCalendar), GTRBAC (IEEE TKDE 2005), NIST 800-53 AC-2 |
| 6 | `geospatial` | **D6 Geoespacial** | allowed_countries[], max_distance_km, geo_fence_radius_m, viaje_imposible_kmh (900) | NIST SP 800-53 PE-3, Google BeyondCorp location trust tiers |
| 7 | `network` | **D7 Red** | allowed_cidrs[], vpn_required, mtls_required, device_trust_level, allowed_protocols[], blocked_ports[] | NIST SP 800-207 ZTA, Google BeyondCorp device trust |
| 8 | `session_context` | **D8 Contexto** | ctx_id_scope, session_ttl_max, reauth_timeout, context_switching_allowed | SBOS-049, W3C Trace Context, NIST 800-63B-4 §7 |
| 9 | `credential_policy` | **D9 Credenciales** | required_methods[], min_aal, rotation_days, complexity, recovery_methods[], mfa_required | NIST SP 800-63B-4 §4-5, FIDO2 WebAuthn W3C |
| 10 | `biometric` | **D5 Biométrico** | required_types[], liveness_required, far_threshold, frr_threshold, enrollment_mandatory | ISO/IEC 19794, NIST SP 800-63B-4 §5.2.3, FIDO Biometric Certification |
| 11 | `delegation` | **D10 Delegación** | can_delegate, allowed_target_roles[], max_duration_hours, requires_approval, auto_revoke | NIST 800-53 AC-5, ISO 27001 A.8.2 |
| 12 | `audit` | **D11 Auditoría** | audit_level (basic/full), retention_days, events_to_log[], hash_chain_required | ISO 27001 A.8.15, PCI DSS 10.3.2, NIST AU-2/AU-3 |
| 13 | `blockchain` | **D12 Blockchain** | merkle_anchoring_required, anchor_frequency, smart_contract_address, besu_qbft_enabled | NIST IR 8202, EIP-725/735 |
| 14 | `compliance` | **Transversal** | iso_controls[], nist_controls[], pci_controls[], gdpr_articles[], sox_sections[] | Aplica a todos los dominios |
| 15 | `sync_metadata` | **Transversal** | kc_realm, kc_composite_role, tryton_group, tryton_ir_model_access, tryton_buttons[] | SCIM 2.0 RFC 7643/7644 |
| 16 | `bitmask` | **Transversal** | computed_bitmask, effective_domains[], effective_bits | Solo lectura. Calculado por el motor |

### 1.7 — DOMINIOS FALTANTES EN EL DISEÑO ORIGINAL (AHORA COMPLETOS)

**D4 Temporal, D7 Red, D8 Contexto** no tenían representación explícita en el RolTemplate original.
Se agregaron bloques específicos basados en investigación profesional.

### 1.8 — INVESTIGACIÓN DESTACADA: Network Access (D7) en formato JSONB

```json
{
  "network": {
    "allowed_cidrs": ["10.0.1.0/24", "10.0.2.0/24"],
    "vpn_required": false,
    "mtls_required": true,
    "device_trust_level": "MEDIUM",
    "device_trust_requirements": {
      "os_patched": true,
      "encryption_enabled": true,
      "firewall_enabled": true,
      "screen_lock_enabled": true
    },
    "allowed_protocols": ["HTTPS", "WSS"],
    "blocked_ports": [22, 3389],
    "geolocation_required": false
  }
}
```
Referencia: Google BeyondCorp (2014-2024), NIST SP 800-207 Zero Trust Architecture.

### 1.9 — UserTemplate History (NUEVO — completa la simetría)

**Problema:** `idn_role_template_history` YA existe. `idn_user_template_history` NO existe aún.
**Solución:** Agregar la tabla siguiendo el patrón Identity→Version→Audit (US8782070, SailPoint US20230117846).

```sql
CREATE TABLE bauth.idn_user_template_history (
    history_id       UUID PRIMARY KEY DEFAULT uuidv7(),
    user_template_id UUID NOT NULL REFERENCES idn_user_template(template_id) ON DELETE CASCADE,
    version          TEXT NOT NULL,
    changed_by       UUID NOT NULL,
    change_type      user_template_change_enum NOT NULL,
    old_values       JSONB,
    new_values       JSONB NOT NULL,
    change_reason    TEXT,
    prev_hash        TEXT,
    entry_hash       TEXT NOT NULL,
    ctx_id           TEXT NOT NULL,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_uth_template ON idn_user_template_history(user_template_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_uth_hash     ON idn_user_template_history(prev_hash);

-- REVOKE: WORM — solo INSERT, nunca UPDATE ni DELETE
REVOKE UPDATE, DELETE ON idn_user_template_history FROM PUBLIC;
```

**Simetría completada:**
- `idn_role_template_history` ✅ (ya existe en DDL antigua, línea 1418)
- `idn_user_template_history` 🆕 (NUEVA — fase C)

Ambos siguen el mismo patrón: hash-chain SHA-256, WORM, ctx_id, versionado semántico.

---

## 7. GUÍA DE LLENADO — USERTEMPLATE (16 BLOQUES JSONB)

### 2.0 — Overrides a nivel de usuario (mismo patrón)

```json
{
  "user": {
    "id": 1001,
    "uuid": "550e8400-...",
    "username": "maria.garcia",
    "status": "ACTIVE"
  },
  "assigned_roles": [
    {
      "role_id": "ROL-CAJERO",
      "valid_from": "2026-01-01",
      "policy_overrides": {
        "uuid-limit-base-cajero": {
          "daily": 3000
        }
      }
    }
  ],
  "credentials": {
    "password_hash": "$argon2id$...",
    "totp_seed": "JBSWY3DPEHPK3PXP",
    "webauthn_keys": ["uuid-key-1"]
  }
}
```

**Regla:** `user_overrides ≤ role_overrides ≤ base_policy`. Siempre más restrictivo.

### 2.1 — Diferencias clave con RolTemplate

| Dimensión | RolTemplate | UserTemplate |
|-----------|------------|-------------|
| **Pregunta** | ¿Qué PUEDE HACER este tipo de rol? | ¿Quién ES este usuario? |
| **Asignación** | Uno → muchos usuarios | Un usuario → uno |
| **Permisos** | Los define | Los hereda del RolTemplate |
| **Credenciales** | Define política (qué se requiere) | Almacena datos reales (hash, device_id) |
| **Biometría** | Define política de enrollment | Almacena hash biométrico del individuo |
| **Sincroniza en KC** | Composite Roles, Auth Flows | User record, credenciales, atributos |
| **Sincroniza en Tryton** | Grupos, ir.model.access | res.user, company.employee |

### 2.2 — Bloques que requieren intervención humana

| Bloque | Quién lo llena | Cuándo |
|--------|---------------|--------|
| `identity` | RRHH / Admin Tenant | Al crear usuario (nombre, username, external_id) |
| `profile` | RRHH | Datos personales, contacto, dirección |
| `employment` | RRHH | Cargo, empresa, sucursal, fecha ingreso |
| `credentials` | Usuario + Sistema | Password (hash), TOTP (seed), WebAuthn (public key) |
| `devices` | Sistema | Dispositivos registrados, fingerprint |
| `assigned_roles[]` | Admin Tenant | Roles asignados al usuario |
| `preferences` | Usuario | Idioma, tema, notificaciones |

---

## 8. MATRIZ DE MÉTODOS DE AUTENTICACIÓN — CATÁLOGO COMPLETO 2026

### 8.0 — bauth como Administrador de Herramientas de Autenticación

**bauth NO implementa los métodos de autenticación. bauth ADMINISTRA las herramientas que los implementan.**

```
┌──────────────────────────────────────────────────────────────────────┐
│                    BAUTH — ADMINISTRADOR DE AUTENTICACIÓN             │
│                                                                      │
│  RolTemplate.credential_policy define QUÉ métodos requiere el rol.   │
│  bauth emite el UserTemplate a la HERRAMIENTA CORRECTA según método. │
│  La herramienta devuelve un TOKEN. bauth lo valida y propaga.        │
│                                                                      │
│  ┌─────────────────────────────────────────────────────────────┐    │
│  │ HERRAMIENTA 1: KEYCLOAK 26.6.2 (base)                       │    │
│  │ OIDC · SAML · WebAuthn/FIDO2 · TOTP/HOTP · Social · CIBA   │    │
│  │ Password · OTP · Recovery · Device · Client Credentials     │    │
│  │ 16 de 26 métodos cubiertos                                  │    │
│  └─────────────────────────────────────────────────────────────┘    │
│       │                                                              │
│  ┌────┴────────────────────────────────────────────────────────┐    │
│  │ HERRAMIENTA 2: FREERADIUS + PostgreSQL (red)                 │    │
│  │ RADIUS · EAP-TLS · EAP-TTLS · PEAP · MAC-based              │    │
│  │ 5 métodos de acceso a red                                    │    │
│  └─────────────────────────────────────────────────────────────┘    │
│       │                                                              │
│  ┌────┴────────────────────────────────────────────────────────┐    │
│  │ HERRAMIENTA 3: FREEIPA (LDAP + Kerberos + PKI)              │    │
│  │ Kerberos · LDAP · PKI/X.509 · Smart Card                    │    │
│  │ 4 métodos de directorio empresarial                          │    │
│  └─────────────────────────────────────────────────────────────┘    │
│       │                                                              │
│  ┌────┴────────────────────────────────────────────────────────┐    │
│  │ HERRAMIENTA 4: BAUTH BLOCKCHAIN (Besu QBFT)                 │    │
│  │ Ethereum EIP-725/735 · Merkle anchoring · AuditAnchor.sol   │    │
│  │ 1 método criptográfico descentralizado                       │    │
│  └─────────────────────────────────────────────────────────────┘    │
│                                                                      │
│  Todas usan PostgreSQL 18.4 como backend.                            │
│  Todas son open source (MIT, Apache 2.0, GPL).                       │
│  bauth unifica: un solo RolTemplate → tokens de múltiples fuentes.   │
└──────────────────────────────────────────────────────────────────────┘
```

### 8.1 — Autenticación con Dispositivos Físicos y Biométricos (WebAuthn/FIDO2)

#### 8.1.1 — Resumen Ejecutivo

**WebAuthn (W3C Level 2) + FIDO2** es el estándar de autenticación fuerte que reemplaza
contraseñas con criptografía de clave pública. El usuario se autentica con su cuerpo
(huella, rostro, PIN) sobre un dispositivo físico que **nunca revela su clave privada.**
El servidor solo conoce la clave pública. Compromiso del servidor = cero riesgo para el usuario.

**bAuth adopta WebAuthn/FIDO2 como método primario de autenticación fuerte en el ecosistema
SBOS porque:**

1. **Phishing-proof:** el navegador valida el origen (rpId). Un sitio falso no obtiene firma.
2. **Biometría local:** la huella/rostro NUNCA sale del dispositivo. El chip seguro (TEE/Secure
   Enclave/Titan M) firma un desafío criptográfico y Keycloak solo verifica la firma.
3. **Sin password:** elimina el vector de ataque #1 (credenciales robadas/phishing).
4. **Hardware-bound opcional:** Passkeys device-bound (YubiKey, smart card) para AAL3.
5. **Multi-dispositivo:** Passkeys synced (Apple/Google account) para AAL2 con comodidad.

---

#### 8.1.2 — Dispositivos Soportados

| Dispositivo | Tipo de Autenticador | LoA | Clave | NFC | ¿Cómo se usa en SBOS? |
|------------|---------------------|-----|-------|-----|----------------------|
| **Celular Android** (sensor de huella) | Platform | AAL2 | Synced | ✅ Sí | Empleado desbloquea app SBOS con su huella. Passkey sincronizada en su cuenta Google |
| **Celular Android** (reconocimiento facial 2D) | Platform | AAL2 | Synced | ✅ Sí | Cliente accede al portal desde su celular. Face Unlock |
| **iPhone** (Touch ID) | Platform | AAL2 | Synced | ✅ Sí | Gerente aprueba factura con huella en app SBOS. Passkey en iCloud Keychain |
| **iPhone** (Face ID — TrueDepth 3D) | Platform | AAL2+ | Synced | ✅ Sí | CFO autoriza transferencia >$50K con su rostro. FAR ~1/1,000,000 |
| **Laptop Windows Hello** (huella) | Platform | AAL2 | Synced | ❌ No | Empleado en oficina. Windows Hello desbloquea acceso a SBOS web |
| **Laptop Windows Hello** (reconocimiento facial IR) | Platform | AAL2 | Synced | ❌ No | Similar a huella. Cámara IR para anti-spoofing |
| **YubiKey Bio** (huella en la llave) | Cross-Platform | AAL3 | Device-Bound | ✅ Sí | Admin Plataforma. Huella verificada DENTRO de la llave. Clave nunca sale |
| **YubiKey 5 NFC** (toque NFC, sin biometría) | Cross-Platform | AAL2+ | Device-Bound | ✅ Sí | Operador financiero. Toque + PIN. Sin huella. Clave en HW |
| **Chapa electrónica FIDO2** (OSDP + WebAuthn) | Cross-Platform | AAL2 | Device-Bound | ✅ Sí | Puerta de bóveda. Presenta YubiKey al lector OSDP. Abre si el token es válido |
| **Tarjeta inteligente NFC** (X.509 + FIDO2) | Cross-Platform | AAL3 | Device-Bound | ✅ Sí | Compliance Officer. DNI electrónico o PIV card. Certificado en chip |

**Notas:**
- **Platform:** el autenticador está integrado en el dispositivo (celular, laptop). La clave puede sincronizarse (synced) vía cuenta Apple/Google.
- **Cross-Platform:** autenticador externo (YubiKey, tarjeta). La clave NUNCA sale del HW (device-bound). Requiere transporte NFC o USB.
- **AAL3** solo se alcanza con device-bound + user verification (PIN o bio en el propio HW).

---

#### 8.1.3 — Cómo Funciona Internamente (Flujo Criptográfico Completo)

**La biometría NUNCA sale del dispositivo. El chip seguro firma un desafío. Keycloak solo ve la clave pública.**

```
╔══════════════════════════════════════════════════════════════════════╗
║              FLUJO WEBATHN/FIDO2 — REGISTRO (Attestation)            ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  USUARIO                      NAVEGADOR                 KEYCLOAK     ║
║  ───────                      ─────────                ────────     ║
║  1. "Quiero registrarme"                                         │  ║
║     ─────────────────────────────────────────────────────────────▶  ║
║  2.                                                    ┌─────────┐ ║
║     Recibe: challenge (32 bytes random),                │ Genera  │ ║
║     rpId="sbos.skull.bo", user.id,                      │ desafío │ ║
║     pubKeyCredParams=[ES256, RS256]                     └─────────┘ ║
║     ◀─────────────────────────────────────────────────────────────  ║
║  3. ┌──────────────────┐                                          │ ║
║     │ CHIP SEGURO      │                                          │ ║
║     │ (TEE/Secure      │                                          │ ║
║     │  Enclave/Titan M)│                                          │ ║
║     │                  │                                          │ ║
║     │ a) Pide huella   │                                          │ ║
║     │    o PIN al      │                                          │ ║
║     │    usuario       │                                          │ ║
║     │ b) Genera par    │                                          │ ║
║     │    de claves     │                                          │ ║
║     │    (ES256)       │                                          │ ║
║     │ c) Guarda clave  │                                          │ ║
║     │    PRIVADA       │                                          │ ║
║     │    (nunca sale)  │                                          │ ║
║     │ d) Firma         │                                          │ ║
║     │    challenge     │                                          │ ║
║     │    con la privada│                                          │ ║
║     └──────────────────┘                                          │ ║
║  4. Envía: credential_id, clave PÚBLICA,                           │ ║
║     firma del challenge, attestation (opcional)                    │ ║
║     ─────────────────────────────────────────────────────────────▶  ║
║  5.                                                    ┌─────────┐ ║
║     Verifica:                                           │ Keycloak│ ║
║     - firma del challenge con clave pública             │ Almacena│ ║
║     - rpId coincide                                     │ clave   │ ║
║     - attestation (si AAL3) contra FIDO MDS3            │ PÚBLICA │ ║
║     ✅ REGISTRO COMPLETO                                │ + cred  │ ║
║                                                        └─────────┘ ║
╚══════════════════════════════════════════════════════════════════════╝

╔══════════════════════════════════════════════════════════════════════╗
║           FLUJO WEBATHN/FIDO2 — AUTENTICACIÓN (Assertion)           ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  USUARIO                      NAVEGADOR                 KEYCLOAK     ║
║  ───────                      ─────────                ────────     ║
║  1. "Quiero entrar"                                               │  ║
║     ─────────────────────────────────────────────────────────────▶  ║
║  2.                                                    ┌─────────┐ ║
║     Recibe: challenge (32 bytes random),                │ Genera  │ ║
║     credential_id (cuál clave usar)                     │ desafío │ ║
║     ◀─────────────────────────────────────────────────────────────  ║
║  3. ┌──────────────────┐                                          │ ║
║     │ CHIP SEGURO      │                                          │ ║
║     │                  │                                          │ ║
║     │ a) Pide huella   │                                          │ ║
║     │    o PIN         │                                          │ ║
║     │ b) Recupera      │                                          │ ║
║     │    clave PRIVADA │                                          │ ║
║     │    (del registro)│                                          │ ║
║     │ c) Firma         │                                          │ ║
║     │    challenge     │                                          │ ║
║     │    con la privada│                                          │ ║
║     └──────────────────┘                                          │ ║
║  4. Envía: credential_id, firma del challenge,                      │ ║
║     userHandle                                                     │ ║
║     ─────────────────────────────────────────────────────────────▶  ║
║  5.                                                    ┌─────────┐ ║
║     Verifica:                                           │ Keycloak│ ║
║     - Busca clave PÚBLICA por credential_id             │ (solo   │ ║
║     - Verifica firma contra clave pública               │ clave   │ ║
║     - Verifica rpId                                    │ PUBLICA)│ ║
║     - Verifica userHandle coincide con userId          │         │ ║
║     ✅ TOKEN EMITIDO                                   └─────────┘ ║
║                                                                      ║
║  ⚠️ LA BIOMETRÍA NUNCA SALE DEL DISPOSITIVO.                        ║
║  ⚠️ KEYCLOAK NUNCA VE LA HUELLA, EL ROSTRO NI LA CLAVE PRIVADA.     ║
║  ⚠️ SOLO VE: credential_id + firma criptográfica + clave pública.   ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

#### 8.1.4 — Matriz de Decisión: Qué Dispositivo para Cada Caso SBOS

| Caso de Uso SBOS | Dispositivo Recomendado | Método del Catálogo | LoA | Flow de Keycloak |
|-----------------|------------------------|-------------------|-----|-----------------|
| **Empleado interno** (oficina) | Laptop con Windows Hello (huella/rostro IR) | #4 WebAuthn Passwordless | AAL2 | `sbos-webauthn-passwordless` |
| **Empleado interno** (móvil) | Celular con huella (Android/iPhone Touch ID) | #4 WebAuthn Passwordless | AAL2 | `sbos-webauthn-passwordless` |
| **Operador financiero** (POS/caja) | YubiKey 5 NFC (toque + PIN) | #5 WebAuthn 2FA | AAL2 | `sbos-webauthn-2fa` |
| **Operador financiero** (>$10K) | YubiKey Bio (huella + toque) + TOTP | #5 + #2 TOTP (step-up) | AAL2+ | `sbos-webauthn-2fa` → step-up TOTP |
| **Gerente / Director** (aprobaciones) | iPhone Face ID 3D o YubiKey Bio | #4 WebAuthn Passwordless | AAL2 | `sbos-webauthn-passwordless` |
| **Cliente externo** (web) | Passkey synced (Apple/Google) | #6 Passkey Synced | AAL2 | `sbos-webauthn-passwordless` |
| **Cliente externo** (app móvil) | Face ID / Huella del celular | #6 Passkey Synced | AAL2 | `sbos-webauthn-passwordless` |
| **SU / Compliance** (AAL3) | YubiKey Bio (device-bound) o PIV card | #7 Passkey Device-Bound + PIN | AAL3 | `sbos-passkey-aal3` |
| **Admin Plataforma (N1)** | YubiKey 5 NFC + PIN + TOTP | #5 + #2 TOTP | AAL3 | `sbos-passkey-aal3` |
| **Daemon / Service Account** | X.509 mTLS (certificado en Vault) | #8 mTLS | M2M | Client Credentials + mTLS (fuera de WebAuthn) |

---

#### 8.1.5 — Pasos de Implementación en Keycloak 26.6.2

**Pre-requisitos:** Keycloak 26.6.2 operativo, `kcadm.sh` configurado.
Variables de entorno:

```bash
export KEYCLOAK_URL="https://auth.sbos.local:8443"
export REALM="tenant-skull"
export ADMIN_USER="admin"
export ADMIN_PASS=$(vault read -field=password secret/bauth/keycloak/admin)
```

---

**Paso 1 — Verificar realm existente y autenticar**

```bash
# Autenticar kcadm.sh contra el admin de Keycloak
kcadm.sh config credentials \
  --server "$KEYCLOAK_URL" \
  --realm master \
  --user "$ADMIN_USER" \
  --password "$ADMIN_PASS"

# Verificar que el realm del tenant existe
kcadm.sh get "realms/$REALM" 2>/dev/null \
  && echo "[OK] Realm $REALM existe" \
  || { echo "[ERROR] Realm $REALM no encontrado — crear primero con bosctl"; exit 1; }
```

---

**Paso 2 — Configurar WebAuthn Policy en el realm**

```bash
echo "[$(date -Iseconds)] Configurando WebAuthn Policy para realm $REALM..."

kcadm.sh update "realms/$REALM" \
  -s 'webAuthnPolicyRpEntityName=sbos.skull.bo' \
  -s 'webAuthnPolicyRpId=skull.sbos.bo' \
  -s 'webAuthnPolicyAttestationConveyancePreference=direct' \
  -s 'webAuthnPolicyAuthenticatorAttachment=platform' \
  -s 'webAuthnPolicyRequireResidentKey=required' \
  -s 'webAuthnPolicyUserVerificationRequirement=required' \
  -s 'webAuthnPolicySignatureAlgorithms[ES256]' \
  -s 'webAuthnPolicySignatureAlgorithms[RS256]' \
  -s 'webAuthnPolicyAcceptableAaguids=[]' 2>&1 \
  && echo "[OK] WebAuthn Policy configurada (platform)" \
  || { echo "[ERROR] Fallo al configurar WebAuthn Policy"; exit 2; }
```

**Nota sobre `authenticatorAttachment`:**
- `platform` = biométrico integrado (celular, laptop). Usado por empleados y clientes.
- `cross-platform` = YubiKey/NFC externo. Se configura como flow SEPARADO para SU/Compliance.
- Para el flow `sbos-passkey-aal3` se usa `cross-platform` con `acceptableAaguids`
  poblados con los AAGUIDs de YubiKey 5 Bio, YubiKey 5 NFC y PIV cards homologadas.

---

**Paso 3 — Crear flow `sbos-webauthn-passwordless` (AAL2 sin password)**

```bash
FLOW_ALIAS="sbos-webauthn-passwordless"

# Verificar si ya existe (idempotencia)
if kcadm.sh get "authentication/flows/$FLOW_ALIAS" 2>/dev/null; then
  echo "[$(date -Iseconds)] Flow $FLOW_ALIAS ya existe — verificando..."
else
  echo "[$(date -Iseconds)] Creando flow $FLOW_ALIAS..."

  # Crear flow de nivel superior
  FLOW_ID=$(kcadm.sh create authentication/flows \
    -s alias="$FLOW_ALIAS" \
    -s providerId="basic-flow" \
    -s topLevel=true \
    -s builtIn=false \
    -i 2>&1)

  # Agregar ejecución: WebAuthn Passwordless Authenticator (REQUIRED)
  kcadm.sh create "authentication/flows/$FLOW_ALIAS/executions/execution" \
    -s provider="webauthn-passwordless-authenticator" \
    -s requirement="REQUIRED" 2>&1

  echo "[OK] Flow $FLOW_ALIAS creado (ID: $FLOW_ID)"
fi
```

---

**Paso 4 — Crear flow `sbos-webauthn-2fa` (AAL2 con password + segundo factor)**

```bash
FLOW_ALIAS="sbos-webauthn-2fa"

if kcadm.sh get "authentication/flows/$FLOW_ALIAS" 2>/dev/null; then
  echo "[$(date -Iseconds)] Flow $FLOW_ALIAS ya existe — verificando..."
else
  echo "[$(date -Iseconds)] Creando flow $FLOW_ALIAS..."

  FLOW_ID=$(kcadm.sh create authentication/flows \
    -s alias="$FLOW_ALIAS" \
    -s providerId="basic-flow" \
    -s topLevel=true \
    -s builtIn=false \
    -i 2>&1)

  # Sub-flow: Username Password Form (REQUIRED)
  SUB_FLOW_ID=$(kcadm.sh create "authentication/flows/$FLOW_ALIAS/executions/flow" \
    -s alias="sbos-webauthn-2fa-forms" \
    -s type="basic-flow" \
    -i 2>&1)

  kcadm.sh create "authentication/flows/$FLOW_ALIAS/executions/execution" \
    -s provider="auth-username-password-form" \
    -s requirement="REQUIRED" 2>&1

  # Ejecución: WebAuthn Authenticator (REQUIRED)
  kcadm.sh create "authentication/flows/$FLOW_ALIAS/executions/execution" \
    -s provider="webauthn-authenticator" \
    -s requirement="REQUIRED" 2>&1

  echo "[OK] Flow $FLOW_ALIAS creado (ID: $FLOW_ID)"
fi
```

---

**Paso 5 — Crear flow `sbos-passkey-aal3` (AAL3 device-bound para SU/Compliance)**

```bash
FLOW_ALIAS="sbos-passkey-aal3"

if kcadm.sh get "authentication/flows/$FLOW_ALIAS" 2>/dev/null; then
  echo "[$(date -Iseconds)] Flow $FLOW_ALIAS ya existe — verificando..."
else
  echo "[$(date -Iseconds)] Creando flow $FLOW_ALIAS..."

  FLOW_ID=$(kcadm.sh create authentication/flows \
    -s alias="$FLOW_ALIAS" \
    -s providerId="basic-flow" \
    -s topLevel=true \
    -s builtIn=false \
    -i 2>&1)

  # WebAuthn Passwordless con política AAL3 estricta
  EXEC_ID=$(kcadm.sh create "authentication/flows/$FLOW_ALIAS/executions/execution" \
    -s provider="webauthn-passwordless-authenticator" \
    -s requirement="REQUIRED" \
    -i 2>&1)

  # Configurar requerimientos AAL3: solo HW conocido, user verification obligatorio
  kcadm.sh update "authentication/flows/$FLOW_ALIAS/executions" \
    -s 'config.webAuthnPolicyAuthenticatorAttachment=cross-platform' \
    -s 'config.webAuthnPolicyRequireResidentKey=required' \
    -s 'config.webAuthnPolicyUserVerificationRequirement=required' \
    -s 'config.webAuthnPolicyAttestationConveyancePreference=direct' \
    2>&1

  echo "[OK] Flow $FLOW_ALIAS creado (ID: $FLOW_ID)"
fi
```

---

**Paso 6 — Asignar flows a bindings del realm**

```bash
echo "[$(date -Iseconds)] Asignando flows a bindings del realm $REALM..."

# Browser flow: por defecto passwordless para usuarios internos
kcadm.sh update "realms/$REALM" \
  -s 'browserFlow=sbos-webauthn-passwordless' 2>&1

# Direct grant: 2FA para APIs y resource owner password credentials
kcadm.sh update "realms/$REALM" \
  -s 'directGrantFlow=sbos-webauthn-2fa' 2>&1

echo "[OK] Flows asignados al realm"
```

---

**Paso 7 — Habilitar Required Actions para registro de dispositivos**

```bash
echo "[$(date -Iseconds)] Habilitando required actions WebAuthn..."

# Registrar autenticador (con huella o PIN)
kcadm.sh update "realms/$REALM" \
  -s 'requiredActions+=["webauthn-register"]' 2>&1

# Registrar autenticador passwordless (sin password, solo biométrico)
kcadm.sh update "realms/$REALM" \
  -s 'requiredActions+=["webauthn-register-passwordless"]' 2>&1

echo "[OK] Required Actions habilitadas"
echo "[$(date -Iseconds)] Configuración WebAuthn/FIDO2 completada para realm $REALM"
```

**Resultado esperado:**
- Empleado hace primer login → se le pide registrar huella/rostro → queda enrolado
- Siguientes logins → solo huella/rostro. Sin password. Token emitido.
- SU/Compliance → requiere YubiKey física con PIN → AAL3

---

#### 8.1.6 — Referencias Normativas

| Estándar | Versión | Aplicación en SBOS |
|----------|---------|-------------------|
| **FIDO2** | 2.0 (2024) | Client to Authenticator Protocol (CTAP2) + WebAuthn |
| **WebAuthn** | Level 2 (W3C, 2023) | API de navegador para crear/verificar credenciales |
| **NIST SP 800-63B-4** | Rev.4 (2024) | AAL2/AAL3 requirements, passkey classification |
| **FIDO MDS3** | 3.0 (2024) | Metadata Service: valida autenticidad de dispositivos (AAGUID) |
| **Keycloak 26.6** | WebAuthn SPI | Implementación de referencia de WebAuthn en IdP open source |
| **ISO/IEC 19794** | Multi-part | Biometric data interchange formats (huella, rostro, iris) |
| **SBOS-050 P9** | — | Comunicación entre daemons vía Unix socket, no HTTP |
| **ADR-020** | — | Interface Dual: JSON-RPC 2.0 + WebSocket RPC |

---

### 8.2 — Los 26 Métodos de Autenticación (Catálogo Completo 2026)

| # | Método | Tipo | Herramienta | LoA | ¿Cuándo? | ¿Cuándo NO? |
|---|--------|------|------------|-----|---------|------------|
| 1 | **Password** | Memorized Secret | Keycloak (credential store) | AAL1 | Empleados internos, validado contra HIBP | Solo para AAL2+. Siempre combinado |
| 2 | **TOTP** | Time-based OTP | Keycloak (OTP policy) | AAL2 | Acceso diario. Google Auth, FreeOTP, Aegis | AAL3 (no es hardware) |
| 3 | **HOTP** | HMAC-based OTP | Keycloak (OTP policy) | AAL2 | Áreas sin señal (bóvedas, sótanos) | Más débil que TOTP (sin time window) |
| 4 | **WebAuthn Passwordless** | FIDO2 Level 2 | Keycloak (WebAuthn flow) | AAL2 | Touch ID, Windows Hello, YubiKey Bio | Requiere HW compatible |
| 5 | **WebAuthn 2FA** | FIDO2 + PIN | Keycloak (WebAuthn flow) | AAL2 | Segundo factor para operadores | — |
| 6 | **Passkey (Synced)** | FIDO2 Multi-device | Keycloak 26.6 (passkey support) | AAL2 | Apple/Google account sync, múltiples dispositivos | **NO para AAL3** (clave exportable) |
| 7 | **Passkey (Device-Bound)** | FIDO2 HW Level 3 | Keycloak 26.6 (passkey support) | AAL3 | SU, Compliance. YubiKey 5, SoloKey, smart card | Solo HW dedicado |
| 8 | **X.509 mTLS** | Mutual TLS | FreeIPA (Dogtag PKI) | AAL2 | M2M: daemons, service accounts, Unix socket | No para usuarios humanos |
| 9 | **Kerberos** | Ticket (RFC 4120) | FreeIPA (krb5) | AAL2 | Redes corporativas AD, Windows Integrated Auth | Solo si existe AD/FreeIPA |
| 10 | **SAML 2.0** | XML SSO Federation | Keycloak (SAML IdP/SP) | AAL2 | Enterprise B2B, gobierno, healthcare legacy | Migrar a OIDC cuando posible |
| 11 | **OIDC Social Brokering** | Federated Identity | Keycloak (Identity Brokering) | AAL1 | Clientes externos. Google, FB, Apple, GitHub | No para empleados internos |
| 12 | **CIBA** | Backchannel (RFC 8628) | Keycloak (CIBA grant) | AAL2 | App banking: autenticar desde dispositivo separado | No para web frontend |
| 13 | **Device Auth** | OAuth 2.0 Device Grant | Keycloak (Device Flow) | AAL1 | TVs, impresoras, IoT sin navegador | No para usuarios interactivos |
| 14 | **RADIUS** | Network Access (RFC 2865) | FreeRADIUS + PostgreSQL | AAL2 | Wi-Fi corporativo, VPN, switches | No para web apps |
| 15 | **EAP-TLS** | Certificate-based WiFi | FreeRADIUS + FreeIPA (PKI) | AAL3 | WiFi empresarial con certificados por dispositivo | Requiere PKI |
| 16 | **EAP-TTLS/PEAP** | Tunneled WiFi Auth | FreeRADIUS + PostgreSQL | AAL2 | WiFi con credenciales internas | — |
| 17 | **MAC-based Auth** | MAC Address Bypass | FreeRADIUS + PostgreSQL | AAL1 | Impresoras, cámaras IP, IoT sin agente | Solo para dispositivos conocidos |
| 18 | **LDAP Bind** | Directory Auth (RFC 4511) | FreeIPA (389 DS) | AAL1 | Apps legacy que solo hablan LDAP | Migrar a OIDC cuando posible |
| 19 | **PKI Smart Card** | X.509 Certificate | FreeIPA (Dogtag PKI) | AAL3 | Tarjetas inteligentes, DNI electrónico, CAC militar | Requiere lector HW |
| 20 | **Blockchain Identity** | EIP-725/735 | bauth + Besu QBFT | AAL3 | AuditAnchor.sol: Merkle anchoring de identidad. Ver BAUTH-D12 | Solo para eventos auditables |
| 21 | **Conditional OTP** | Risk-based Step-Up | Keycloak (Auth SPI) | AAL2 | Step-up condicional: solo si riesgo elevado | No como método primario |
| 22 | **Recovery Codes** | Backup (RFC 6238) | Keycloak (Recovery Codes) | AAL1 | Recuperación de cuenta. Un solo uso | No como método primario |
| 23 | **Email OTP** | Magic Link / Code | Keycloak (Email OTP) | AAL1 | Verificación inicial, recuperación | No para transacciones sensibles |
| 24 | **Client Credentials** | OAuth 2.0 M2M | Keycloak (Client Creds) | M2M | Service accounts, daemons, API keys | No para humanos |
| 25 | **Token Exchange** | OAuth 2.0 (RFC 8693) | Keycloak (Token Exchange) | M2M | Impersonación controlada entre servicios | Requiere cadena de confianza |
| 26 | **DPoP** | Proof-of-Possession (RFC 9449) | Keycloak 26.6 | AAL2+ | Binding token a cliente específico. Anti-robo de token | Requiere cliente que soporte DPoP |

### 8.3 — Herramientas Open Source con PostgreSQL para métodos faltantes

| Herramienta | Licencia | Backend PostgreSQL | Métodos que aporta | ¿Por qué no Keycloak solo? |
|------------|----------|-------------------|-------------------|--------------------------|
| **Keycloak 26.6.2** | Apache 2.0 | ✅ Sí | 16 métodos (OIDC, SAML, WebAuthn, TOTP, CIBA, Device, Social, Token Exchange...) | Base. Pero no cubre RADIUS, LDAP nativo, Kerberos, PKI completa, EAP-TLS |
| **FreeRADIUS 3.2** | GPLv2 | ✅ Sí (módulo rlm_sql) | RADIUS, EAP-TLS, EAP-TTLS, PEAP, MAC-based | Keycloak no habla RADIUS nativo. WiFi empresarial, VPNs y switches lo requieren |
| **FreeIPA 4.12** | GPLv3 | ❌ (389 DS interno, pero interoperable vía LDAP → PostgreSQL sync) | Kerberos, LDAP, PKI (Dogtag), Smart Card | Keycloak consume Kerberos vía User Storage SPI pero no lo genera. FreeIPA lo GENERA |
| **bauth Blockchain** | MIT | ✅ Sí (PostgreSQL + Besu QBFT) | EIP-725/735 identity anchoring, AuditAnchor.sol, Merkle proofs | Único. Ninguna otra herramienta ancla identidad en blockchain con validez jurídica |
| **Kanidm** | MPL-2.0 | ❌ (SQLite, migrando a PostgreSQL) | OAuth2/OIDC, WebAuthn, LDAP, RADIUS (futuro) | Alternativa ligera a FreeIPA. En evolución activa (2025) |
| **Authentik** | MIT | ✅ Sí | OAuth2/OIDC, SAML, LDAP, Proxy Auth, RADIUS outpost | "Pegamento" de protocolos. Puede traducir entre protocolos. Complementa a Keycloak |

### 8.4 — Combinaciones VÁLIDAS por Nivel de Seguridad (AAL1→AAL3→M2M)

| Combinación | AAL | Herramienta | Ejemplo SBOS |
|------------|-----|------------|-------------|
| Password solo | AAL1 | Keycloak | Cliente ve catálogo online |
| Password + TOTP | AAL2 | Keycloak | Cajero inicia sesión en POS |
| Password + WebAuthn (YubiKey) | AAL2 | Keycloak | Supervisor revisa reportes financieros |
| WebAuthn Passwordless (Touch ID) | AAL2 | Keycloak | Gerente accede desde su laptop |
| EAP-TLS (certificado × dispositivo) | AAL2 | FreeRADIUS + FreeIPA | Empleado conecta al WiFi corporativo |
| Password + TOTP + WebAuthn | AAL2+ | Keycloak | Step-up: Contador aprueba factura >$10K |
| Password + Kerberos Ticket | AAL2 | FreeIPA + Keycloak | Empleado en red AD accede a app interna |
| Passkey Device-Bound + PIN | AAL3 | Keycloak | SU activa break-glass |
| PKI Smart Card + PIN | AAL3 | FreeIPA | Oficial de cumplimiento firma documento SIN |
| EAP-TLS + Passkey Device-Bound | AAL3 | FreeRADIUS + Keycloak | Acceso físico + lógico a bóveda |
| X.509 mTLS solo | M2M | FreeIPA (PKI) | bAuth → bKernel vía Unix socket |
| Client Credentials + DPoP | M2M | Keycloak | Kong → bAuth con token anti-robo |
| Blockchain Identity (EIP-725) | AAL3 | bauth + Besu QBFT | Anclaje de evento crítico en blockchain |

### 8.5 — Combinaciones PROHIBIDAS (NIST SP 800-63B-4)

| Combinación | Razón |
|------------|-------|
| Password + SMS OTP para AAL2+ | SMS deprecado (SIM swapping, SS7 attacks). Migrar a TOTP app |
| Biometría como único factor | NIST: biométrico es "activation factor", no autenticación independiente |
| 2× OTP del mismo dispositivo | Mismo factor = no es MFA real |
| Password + Security Questions | No son un factor de autenticación (NIST SP 800-63B §5.1.1) |
| Passkey synced para AAL3 | Clave exportable viola requisito de HW no-exportable |
| Token sin DPoP en redes no confiables | RFC 9449: token bearer sin proof-of-possession = vulnerable a robo |

### 8.6 — MÉTODOS BIOMÉTRICOS (D5 — Dominio Biométrico)

Además de los 26 métodos de autenticación, existen **15 modalidades biométricas** que se
utilizan como factor de verificación (NIST: "activation factor"), no como autenticación
independiente. El biométrico siempre debe estar vinculado a un dispositivo físico.

| # | Biométrico | Sensor | Dispositivo típico | FAR | Aplicación SBOS |
|---|-----------|--------|-------------------|-----|-----------------|
| B1 | **Huella digital** | Capacitivo / Ultrasónico | Celular (Touch ID, Android), lector OSDP | ~1/50,000 | Cajero desbloquea POS con su huella |
| B2 | **Reconocimiento facial 3D** | IR dot-projector (TrueDepth) | iPhone/iPad con Face ID | ~1/1,000,000 | Gerente aprueba factura >$50K desde su iPad |
| B3 | **Reconocimiento facial 2D** | Cámara RGB | Celular Android, laptop | ~1/10,000 | Cliente verifica identidad en portal (menos seguro) |
| B4 | **Iris** | Cámara NIR | Samsung Galaxy, lectores dedicados | ~1/1,200,000 | Acceso a data center (Zone 5) |
| B5 | **Retina** | Escáner retinal | Equipo médico/militar | ~1/10,000,000 | Instalaciones de máxima seguridad |
| B6 | **Voz** | Micrófono | Celular, call center | ~1/5,000 | Verificación telefónica con cliente. ⚠️ Deepfake voice risk 2026 |
| B7 | **Palma venosa** | Infrarrojo | Lector Fujitsu/Panasonic | ~1/1,000,000 | Bóveda bancaria. Sin contacto, requiere flujo sanguíneo |
| B8 | **Geometría de mano** | Cámara + guías | Lector dedicado | ~1/500 | Control de acceso físico (obsoleto vs palma venosa) |
| B9 | **ADN** | Muestra biológica | Laboratorio | ~1/10^18 | Forense únicamente. No es tiempo real |
| B10 | **Firma manuscrita** | Tableta digitalizadora | POS, courier | Variable | Recepción de paquetería, delivery |
| B11 | **Dinámica de tecleo** | Teclado | Cualquier dispositivo | ~1/500 | Detección continua: ¿sigue siendo Juan el que escribe? |
| B12 | **Análisis de marcha** | Cámara / acelerómetro | CCTV, celular | Variable | Vigilancia. Detecta si alguien camina distinto (lesión, estrés) |
| B13 | **Patrón de voz + labios** | Cámara + micrófono | Celular | Alto | Liveness anti-deepfake: ve la boca moverse MIENTRAS habla |
| B14 | **Ángulo y agarre del teléfono** | Giroscopio + acelerómetro | Celular | Bajo | Auth continua: ¿sigue María sosteniendo el teléfono? |
| B15 | **Pulso cardíaco (PPG)** | Sensor óptico | Smartwatch, pulsera | Medio | Auth continua para entornos industriales |

### 8.7 — AUTENTICACIÓN POR NIVEL DE RESPONSABILIDAD DEL ROL

**Principio:** Un Gerente General NO usa password. Un Cajero SÍ usa password + TOTP.
El método de autenticación debe ser **proporcional a la responsabilidad y al contexto de uso.**

| # | Tier | Ejemplo | Método recomendado | ¿Por qué? |
|---|------|---------|-------------------|-----------|
| **SU** | Superusuario | SU SBOS | Passkey Device-Bound (YubiKey) + PIN + Huella | Máxima seguridad. Solo 1 activo. Break-glass |
| **N1** | Plataforma | Admin Plataforma, Admin Seguridad | Passkey Device-Bound + TOTP + Facial 3D | Administran todo el ecosistema. AAL3 obligatorio |
| **N2** | Dirección | CFO, COO, Director IT | WebAuthn Passwordless (Face ID / Touch ID) + PIN | No recuerdan passwords. Su celular es su llave |
| **N2** | Gerencia | Gerente Regional, Gerente Financiero | Face ID + PIN en su dispositivo. Step-up facial para aprobaciones >$10K | Combina comodidad con seguridad escalonada |
| **N3** | Supervisión | Supervisor Ventas, Jefe Caja | Password + TOTP + Huella (opcional) | Operación diaria. TOTP en su celular |
| **N4** | Operativo | Cajero, Vendedor, Contador | Password + TOTP | AAL2 estándar. Suficiente para operaciones diarias |
| **N4** | Operativo (POS físico) | Cajero en caja registradora | Huella digital (lector OSDP Biometric) | Sin password. La huella desbloquea la caja. Rápido, seguro |
| **N5** | Soporte | Soporte IT, Atención Cliente | Password + TOTP | Igual que operativo |
| **EXT_N0** | Cliente externo | Cliente portal web | Social Login (Google/Apple) o Passkey synced | Sin fricción. El cliente no quiere crear otra cuenta |
| **EXT_N0** | Cliente app móvil | App SBOS Móvil | Face ID / Huella del celular | Abre la app con su cara. Cero passwords |
| **M2M** | Service Account | kong-admin, vault-agent | Client Credentials + mTLS + DPoP | Sin intervención humana. Rotación automática |
| **VISITOR** | Visitante | Auditor externo, consultor | Email OTP + TOTP temporal | Acceso limitado. Expira automáticamente |

### 8.8 — MATRIZ DE MÉTODOS POR CONTEXTO DE USO

| Contexto | Método ideal | ¿Por qué? |
|----------|-------------|-----------|
| **Escritorio en oficina** | Password + TOTP o WebAuthn | Dispositivo confiable en red corporativa |
| **Celular en movimiento** | Face ID / Huella | Sin teclado. El biométrico del dispositivo es suficiente |
| **POS / Caja registradora** | Huella digital (OSDP) | Rápido. El cajero no debe teclear. La huella abre la caja |
| **Bóveda / Data center** | Palma venosa o Iris + Passkey | Zone 5. Sin contacto. Requiere prueba de vida |
| **Remoto / Home office** | WebAuthn Passwordless o Passkey + TOTP | Mayor riesgo. Step-up si IP es desconocida |
| **Cliente externo web** | Social Login o Passkey synced | El cliente abandona si le piden crear cuenta con password |
| **Cliente externo app** | Face ID / Huella del celular | Sin fricción. Abre y usa |
| **API / M2M** | Client Credentials + mTLS | Sin humano. Criptográfico puro |
| **Emergencia / Break-glass** | Passkey Device-Bound + PIN | SU. Tiempo limitado. Auditoría post-evento obligatoria |

---

## 9. CUÁNDO USAR CADA NIVEL DE ASEGURAMIENTO (LoA)

### 9.1 — AAL1: Autenticación Básica

| Cuándo | Ejemplo SBOS | Método típico |
|--------|-------------|---------------|
| Usuario consulta información pública | Cliente ve productos en portal | Password o Social Login |
| No hay datos personales expuestos | Visitante consulta horarios | Sin autenticación o Password |
| Riesgo bajo de suplantación | Empleado ve su propio perfil | Password |

### 9.2 — AAL2: Autenticación Alta

| Cuándo | Ejemplo SBOS | Método típico |
|--------|-------------|---------------|
| **TODOS los empleados internos** | Cajero, vendedor, contador | Password + TOTP |
| Acceso a datos personales de terceros | RRHH ve expedientes | Password + WebAuthn |
| Operaciones financieras ≤ límite diario | Vendedor emite factura ≤ $5K | Password + TOTP |
| Acceso a configuración del sistema | Admin Tenant modifica roles | Password + WebAuthn (YubiKey) |

### 9.3 — AAL3: Autenticación Muy Alta

| Cuándo | Ejemplo SBOS | Método típico |
|--------|-------------|---------------|
| **Superusuario (SU)** | Break-glass, DR | Passkey device-bound (YubiKey) + PIN |
| **Admin Plataforma (N1)** | Crear tenant, modificar infraestructura | WebAuthn hardware + TOTP |
| Operaciones financieras > límite superior | Transferencia > $100K | Password + WebAuthn + TOTP (3 factores) |
| Acceso a datos RESTRICTED | Expedientes médicos, secretos industriales | Passkey device-bound + PIN |
| Modificación de políticas de seguridad | Cambiar credential_policy de un rol | WebAuthn hardware + TOTP |

### 9.4 — Step-Up (RFC 9470): Elevación Temporal

| Trigger | De → A | Duración | Ejemplo |
|---------|--------|---------|---------|
| Operación excede límite | AAL2 → AAL3 | Duración de la operación | Cajero necesita aprobar factura >$10K |
| Acceso fuera de horario | AAL2 → AAL2+WebAuthn | Hasta fin de sesión | Gerente accede domingo 10PM |
| Acceso desde IP desconocida | AAL2 → AAL2+TOTP adicional | 15 minutos | Empleado viaja y accede desde otra ciudad |
| Break-glass SU | AAL2 → AAL3 | Máximo 4 horas | Emergencia: base de datos caída |

---

## 10. PROCEDIMIENTOS OPERATIVOS

### 10.1 — Onboarding de un nuevo Tenant

```
PASO 1: Crear tenant (idn_tenant + idn_tenant_config)
  → Quién: Admin Plataforma (S002)
  → Tiempo: ~2 min

PASO 2: Seleccionar sector CAEB
  → El sistema carga las zonas predefinidas para ese sector
  → Ej: COMERCIO → VENTAS, CAJA, INVENTARIO, CONTABILIDAD, RRHH
  → Tiempo: ~1 min

PASO 3: Desplegar roles del catálogo
  → El sistema clona las 66 plantillas base adaptadas al sector
  → Cada zona recibe sus roles predefinidos
  → Tiempo: ~2 min (automático)

PASO 4: Crear empresa (idn_empresa)
  → Quién: Admin Tenant (S008)
  → Datos: NIT, razón social, dirección, contactos
  → Tiempo: ~2 min

PASO 5: Crear sucursales (idn_sucursal)
  → Al menos 1 sucursal por empresa
  → Tiempo: ~1 min por sucursal

PASO 6: Crear POS (idn_pos)
  → Registrar terminales SIN (CUFD, CUIS, CAFC)
  → Tiempo: ~3 min por terminal

PASO 7: Crear usuarios
  → Asignar RolTemplate a cada empleado
  → El usuario hereda zonas, verbos, scope del rol
  → Tiempo: ~1 min por usuario

TOTAL: <10 minutos para un tenant operativo con roles y usuarios.
```

### 10.2 — Ciclo de vida de un Rol

```
DRAFT → REVIEW → ACTIVE → DEPRECATED → ARCHIVED
  │        │         │           │           │
  │        │         │           │           └── 8 años retención (SIN)
  │        │         │           └── No asignable a nuevos usuarios
  │        │         └── Sincronizado en KC + Tryton. Operativo
  │        └── Pendiente aprobación del ARB
  └── En diseño. No sincronizado. Visible solo en bAuth
```

---

## 11. ESTÁNDARES DE REFERENCIA POR OPERACIÓN

| Operación | Estándar | Sección |
|-----------|----------|---------|
| Crear rol | NIST RBAC Nivel 3, ANSI INCITS 359-2004 | §4 Role Hierarchy |
| Asignar permisos | NIST 800-53 AC-3 Access Enforcement | §AC-3 |
| Separación de deberes | NIST 800-53 AC-5 SoD | §AC-5 |
| Autenticar usuario | NIST SP 800-63B-4 AAL1-3 | §4-5 |
| Step-Up | RFC 9470 | §3 |
| Sincronizar KC | OIDC Core 1.0, SCIM 2.0 RFC 7643/7644 | — |
| Sincronizar Tryton | JSON-RPC 2.0 sobre Unix socket | SBOS-050 P9 |
| Auditar acceso | ISO 27001 A.8.15, PCI DSS 10.3.2 | — |
| Proteger datos | GDPR Art.32, PCI DSS 4.0 Req 3-4 | — |
| Verificar identidad | NIST SP 800-63A IAL1-3 | — |

---

*Documento actualizado 2026-06-24. Este manual cubre el 100% de las operaciones del ecosistema bAuth (12 dominios).*

---

## 12. ESTADO DE LA BASE DE DATOS — Junio 2026

### 12.1 Estado Final del Proyecto

**Fecha:** 2026-06-25 · **VPS:** 13.140.128.230 · **DB test:** `bauth_test`

| Métrica | Valor |
|---------|:---:|
| Tablas totales | **177** (160 bauth + 8 bglobal + 9 bcalendar) |
| Errores DDL | **0** |
| Seeds idempotentes | **57** (×3 ejecuciones, mismo resultado) |
| Tablas migradas del DDL antiguo | **46** |
| Tablas nuevas creadas (FASE 1) | **15** |
| Reparaciones aplicadas | **15** |
| Fases completadas | **5 de 5** |
| Dominios cubiertos D1-D12 | **12 de 12** |

### 12.2 Lotes de migración

| Lote | Fecha | Dominios | Tablas |
|------|-------|---------|:---:|
| Lote 0.1 | 2026-06-24 | D1(3) + D3(2) + D8(3) | 7 |
| Lote 0.2 | 2026-06-24 | D9(14) | 14 |
| Lote 0.3 | 2026-06-24 | D10(1) + D11(7) + D13(1) | 9 |
| Lote 0.4 | 2026-06-24 | D12(5) + User(3) + Org(3) + Sec(3) + Red(2) | 16 |
| **Total** | | | **46** |

### 12.3 Distribución por dominio

| Dominio | Tablas | Estado |
|---------|:---:|:---:|
| D1 Lógico | 15 | ✅ Completo |
| D2 Físico | 7 | ✅ Completo |
| D3 Financiero | 9 | ✅ Completo |
| D4 Temporal | 8 | ✅ Completo |
| D5 Biométrico | — | Cubierto por D2 + D9 |
| D6 Geoespacial | 2 | ✅ Catálogos globales |
| D7 Red | 2 | ✅ Completo |
| D8 Contexto | 3 | ✅ Completo |
| D9 Credenciales | 19 | ✅ Completo |
| D10 Delegación | 1 | ✅ Completo |
| D11 Auditoría | 8 | ✅ Completo |
| D12 Blockchain | 5 | ✅ Completo |
| D13 Sync | 1 | ✅ Completo |
| USER | 3 | ✅ Completo |
| ORG | 3 | ✅ Completo |
| SEC | 3 | ✅ Completo |
| TENANT | 7 | ✅ Completo |
| GLOBAL | 5 | ✅ Completo |
| **TOTAL** | **91** | |

### 12.4 Tablas nuevas creadas hoy

| Tabla | Dominio | Origen |
|-------|---------|--------|
| `zone_application_map` | D1 | Migrada de `bos_zone_application_map` |
| `idn_role_closure` | D1 | Migrada de `bos_rol_closure` |
| `fin_sod_rule` | D3 | Migrada de `bos_sod_conflict_matrix` |
| `fin_decision_matrix` | D3 | Migrada de `bos_financial_decision_matrix` |
| `ses_context` | D8 | Migrada de `bos_context_sessions` |
| `ses_context_switch` | D8 | Migrada de `bos_context_switches` |
| `ses_superuser_context` | D8 | Migrada de `bos_superuser_contexts` |
| `ath_credential_policy` | D9 | Migrada de `bos_credential_policy` |
| `ath_password_history` | D9 | Migrada de `bos_password_history` |
| `ath_password_screening` | D9 | Migrada de `bos_password_screening_log` |
| `ath_mfa_enrollment` | D9 | Migrada de `bos_mfa_enrollments` |
| `ath_recovery_method` | D9 | Migrada de `bos_recovery_method` |
| `ath_recovery_challenge` | D9 | Migrada de `bos_recovery_challenge` |
| `ath_binding` | D9 | Migrada de `bos_authenticator_binding` |
| `ath_revocation` | D9 | Migrada de `bos_authenticator_revocation` |
| `ath_login_attempt` | D9 | Migrada de `bos_login_attempt` |
| `ath_consent` | D9 | Migrada de `bos_user_consent` |
| `ath_rotation_log` | D9 | Migrada de `bos_credential_rotation_log` |
| `ath_token_delivery` | D9 | Migrada de `bos_token_delivery_log` |
| `ath_enrollment_log` | D9 | Migrada de `bos_auth_method_enrollment_log` |
| `ath_federation_protocol` | D9 | Migrada de `bos_federation_protocol` |
| `dlg_delegation` | D10 | Migrada de `bos_delegation_log` |
| `aud_event` | D11 | Migrada de `bos_audit_events` |
| `aud_review` | D11 | Migrada de `bos_access_reviews` |
| `aud_ghost_account` | D11 | Migrada de `bos_ghost_accounts` |
| `aud_policy_change` | D11 | Migrada de `bos_policy_audit` |
| `aud_policy_version` | D11 | Migrada de `bos_policy_history` |
| `aud_compliance_map` | D11 | Migrada de `bos_compliance_map` |
| `sync_log` | D13 | Migrada de `bos_sync_log` |
| `blk_anchor` | D12 | Migrada de `bos_blockchain_anchor_log` |
| `blk_merkle_batch` | D12 | Migrada de `bos_merkle_batch` |
| `blk_merkle_leaf` | D12 | Migrada de `bos_merkle_leaf` |
| `blk_account` | D12 | Migrada de `bos_onchain_account` |
| `blk_reconciliation` | D12 | Migrada de `bos_anchor_reconciliation_log` |
| `idn_user_template` | USER | Migrada de `bos_user_template` |
| `idn_user_role` | USER | Migrada de `bos_user_role_assignment` |
| `org_empresa` | ORG | Migrada de `bos_empresa` |
| `org_sucursal` | ORG | Migrada de `bos_sucursal` |
| `org_pos_logico` | ORG | Migrada de `bos_pos_logico` |
| `sec_key_inventory` | SEC | Migrada de `bos_key_inventory` |
| `sec_key_rotation` | SEC | Migrada de `bos_key_rotation_log` |
| `sec_key_recovery` | SEC | Migrada de `bos_key_recovery_log` |
| `net_device` | D7 | Migrada de `bos_device_registry` |
| `global_config` | GLOBAL | Migrada de `bos_global_config` en `bglobal` |

### 12.5 Reparaciones aplicadas

| # | Problema | Solución |
|---|----------|------|
| 1 | `ath__policy` duplicado y corrupto | Eliminada entrada corrupta, preservada la de línea 2339 |
| 2 | `ath__config` duplicado y corrupto | Eliminada entrada corrupta, preservada la de línea 2309 |
| 3 | `bos_crypto_algorithm` sin cerrar | Agregadas CHECK constraints y `);` |
| 4 | `bos_rol_template_history` sin cerrar | Agregados `prev_hash`, `entry_hash` y `);` |
| 5 | `idn_role_template.parent_id` FK roto | Corregido: `REFERENCES bauth.idn_role_template(id) ON DELETE SET NULL` |
| 6 | `bos_permiso_logico.verbo_id` FK roto | Corregido: `REFERENCES bauth.privilege_verb(verb_code)` |
| 7 | INSERTs huérfanos `idn_tier_policy` en DDL | Movidos a `seed_idn_tier_policy.sql` (R5: Cero INSERTs en DDL) |

### 12.6 Fases Completadas

| Fase | Estado | Resultado |
|------|:---:|------|
| **FASE 0** — Migración DDL | ✅ | 46 tablas migradas, 0 errores |
| **FASE 1** — 15 tablas visión | ✅ | user_client_device, ctx_transfer_log, idp_*, emergency, visitor, mobile_app_config, attestation, push, cert_pin, token_refresh |
| **FASE 2** — Clasificación + Menú | ✅ | domain_classification 32 métodos, menú→bglobal, 3 ALTERs |
| **FASE 3** — Seeds | ✅ | 57 seeds idempotentes (12 políticas/d, 12 configs/d, 12 roles/d, 16 protocolos, org, app_config) |
| **FASE 4** — Idempotencia ×3 | ✅ | 3 ejecuciones, mismo resultado, 0 errores, 177 tablas |

### 12.7 Estado de la Migración — Junio 2026 ✅ COMPLETADA

La migración de 48 tablas del DDL antiguo + creación de 57 tablas nuevas está **completada**:

**✅ COMPLETADO (B45 + B46):**
- ✅ 12 `ath_policy_d*` — Políticas operativas por dominio D1-D12 (75 políticas con seeds)
- ✅ 12 `ath_config_d*` — Configuraciones por dominio D1-D12 (78 configs con seeds)
- ✅ 12 `idn_role_d*` — Templates de rol por dominio (42 roles con seeds)
- ✅ 17 tablas complementarias — auth_flow, step_up, zone_*, fis_*, cal_*, net_ztna, ses_risk, ses_caep, sod_*, conflict_interest (con seeds)
- ✅ Migración Lotes 0.1-0.4 — 48 tablas del DDL antiguo normalizadas (UUIDv7, inglés, ctx_id)
- ✅ Seeds `ath_credential_policy` (8 políticas) + `ath_federation_protocol` (16 protocolos)
- ✅ Seeds `org_empresa` + `org_sucursal` bootstrap + `aud_compliance_map` (34 controles)
- ✅ Menú movido de `bauth` a `bglobal`
- ✅ DDL organizado en 18 secciones por dominio
- ✅ Idempotencia ×3 verificada en VPS (97 seeds, 0 errores, 2026-06-29)
- ✅ Reconcile loop extendido (B45.D03): drift políticas + revalidación contextos + invalidación sesiones + eventos CAEP

---

## 13. INTEGRACIÓN CON EL CONTEXT PLANE DEL BOS (SBOS-049)

### 13.1 Arquitectura de Integración

bAuth es el motor de resolución del Context Plane del SBOS. El flujo completo:

```
BOS (IAM Installer)                bAuth (Identity Control Plane)
─────────────────────              ─────────────────────────────────
Crea ctx_id (UUIDv7)      ──→     Almacena en ses_context
Propaga vía OTel Baggage  ──→     Evalúa 12 dominios en <5ms
Solicita contexto          ──→     bauth.context.evaluate(ctx_id)
Recibe DomainResult        ←──     Retorna trust_level + permisos + JWT
```

### 13.2 Handlers del Context Plane (implementados)

| Handler | Método JSON-RPC | Propósito |
|---------|----------------|-----------|
| `CtxCreateHandler` | `bauth.ctx.create` | Crear nuevo ctx_id con 6 capas (tenant, empresa, sucursal, pos, user, traceparent) |
| `CtxValidateHandler` | `bauth.ctx.validate` | Validar ctx_id activo contra Redis + PostgreSQL |
| `CtxPromoteHandler` | `bauth.ctx.promote` | Elevar LoA del contexto (Step-Up RFC 9470) |
| `CtxInvalidateHandler` | `bauth.ctx.invalidate` | Invalidar ctx_id (logout, timeout, compromiso) |
| `CtxPropagateHandler` | `bauth.ctx.propagate` | Propagar ctx_id entre dispositivos |
| `ContextEvaluateHandler` | `bauth.context.evaluate` | Evaluación completa de 12 dominios con cortocircuito |

### 13.3 Reconcile Loop Extendido (60s)

El reconcile loop de `sync/mod.rs` ahora es el corazón del Context Plane runtime:

1. **Drift de políticas:** Compara `cfg_policy_library` vs `ath_policy_d1..d12`. Si hay delta → INSERT en `sync_log`.
2. **Revalidación de contextos:** Detecta sesiones activas cuyo RolBitMask cambió → invalida y fuerza re-login.
3. **Invalidación de sesiones:** Marca `EXPIRED` en `ses_context` para sesiones vencidas. Auditado en `aud_event`.
4. **Eventos CAEP:** Emite `session-revoked` y `assurance-level-change` según OpenID CAEP 1.0.

### 13.4 Unix Socket — Interface Dual (ADR-020)

Toda comunicación BOS↔bAuth ocurre sobre `/run/bos/bauth.sock` (0660, grupo `bosagent`):
- **Vía 1 (WebSocket RPC):** `bauthctl` CLI + Core UI Flutter
- **Vía 2 (JSON-RPC 2.0):** biedata, bkernel, agentes IA, Kong PEP

HTTP vetado entre daemons (SBOS-050 P9). Solo Unix socket + WebSocket.
