# INDICE-NAVEGACION — Carpeta REPARACIONBAUTH
## Mapa de navegación completo · bAuth Rediseño v3.0

**Versión:** 1.0.0 · **Fecha:** 2026-07-01
**Propósito:** Guía de navegación entre todos los documentos de trabajo del rediseño.
Todo lo necesario para reparar bAuth de forma profesional y robusta está en esta carpeta.

---

## REGLA DE USO

> Antes de escribir una sola línea de código o SQL, leer en el orden indicado.
> El orden no es sugerencia — es la secuencia lógica de comprensión.

---

## SECCIÓN 1 — LECTURA OBLIGATORIA ANTES DE CUALQUIER TRABAJO

### 1.1 Entrada al trabajo (leer primero)

| # | Documento | Propósito | Leer cuando |
|---|-----------|-----------|-------------|
| 1 | `BAUTH-COBERTURA-100PCT.md` | **PUNTO DE PARTIDA.** Matriz 100% que valida que el diseño es completo. Confirma qué campo va a qué átomo y tabla | SIEMPRE PRIMERO |
| 2 | `PLAN-ACCION-REDISEÑO.md` | Plan de 6 fases: qué hacer, en qué orden, qué aprobaciones se necesitan | Al iniciar sesión |
| 3 | `REGISTRO-ESTADO-REDISEÑO.md` | **REGISTRO CANÓNICO** del avance. Qué está hecho, qué está pendiente, qué está bloqueado | Al iniciar sesión |

### 1.2 DDL — Fuente de verdad de la base de datos (EXTERNOS, referenciar por ruta)

> Estos archivos son grandes. No copiar aquí — usar las rutas absolutas.

| Archivo | Ruta absoluta | Propósito |
|---------|--------------|-----------|
| `DDL_skSBOS_db.sql` | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/db/migrations/DDL_skSBOS_db.sql` | DDL canónico — toda la estructura de la BD |
| `MANUAL_DB_DDL.md` | `/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/db/migrations/MANUAL_DB_DDL.md` | Manual que explica la intención de cada tabla, constraint e invariante |
| `CLAUDE_BAUTH_SECURITY_STANDARDS.md` | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/humano/daemons/bauth/plandeaccion/bauth/CLAUDE_BAUTH_SECURITY_STANDARDS.md` | Estándares de seguridad obligatorios — vectores de ataque, controles NIST/OWASP |

### 1.3 Registro de estado global bAuth

| Archivo | Propósito |
|---------|-----------|
| `REGISTRO-ESTADO-BAUTH-PRINCIPAL.md` | Estado global del desarrollo bAuth (copia del registro maestro) |
| `REGISTRO-ESTADO-REDISEÑO.md` | **Registro específico del rediseño** — este es el que actualizar en REPARACIONBAUTH |

---

## SECCIÓN 2 — DISEÑO DEL REDISEÑO (producidos en esta sesión)

### 2.1 Cobertura y catálogos de átomos

| Documento | Contenido | Dependencia |
|-----------|-----------|------------|
| `BAUTH-COBERTURA-100PCT.md` | Matriz 156 campos × átomo/tabla. 82 campos UT + 74 campos RT. 100% verificado | BASE |
| `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` | 120 átomos CRUD D00 (30 campos × 4). Posiciones 5809-5928 | BAUTH-COBERTURA-100PCT |
| `BAUTH-CATALOGO-ATOMOS-D4-D12.md` | 188 átomos CRUD D4-D12 (47 campos × 4). Posiciones dentro de cada dominio | BAUTH-COBERTURA-100PCT |
| `BAUTH-DOMINIO-D13-BLOCKCHAIN.md` | 36 átomos D13 blockchain + firma legal ADSIB. Posiciones 5929-5964 | BAUTH-COBERTURA-100PCT |
| `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` | Diseño `idn_atributo`: EAV genérico, display_format, validation_policy, bglobal integration | BAUTH-CATALOGO-ATOMOS-D00-CRUD |

### 2.2 Arquitectura master

| Documento | Contenido |
|-----------|-----------|
| `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md` | **ARQUITECTURA MASTER v1.1.0.** Consolida todo el diseño atómico. 14 partes. |

---

## SECCIÓN 3 — SSOT: PLANTILLAS Y CONTRATOS (leer antes de implementar)

### 3.1 Plantillas (contratos de datos)

| Documento | Versión | Contenido | Bloques |
|-----------|:-------:|-----------|:-------:|
| `SBOS-ROLTEMPLATE-v5_0.md` | v6.0 | Contrato declarativo de rol. 14 bloques JSONB. | 14 |
| `SBOS-USERTEMPLATE-v5_0.md` | v6.0 | Contrato de identidad de usuario. 16 bloques JSONB. | 16 |
| `BAUTH-ROLTEMPLATE-SECCIONES.md` | v1 | Detalle de las 14 secciones del RolTemplate | 14 |
| `BAUTH-USERTEMPLATE-SECCIONES.md` | v1 | Detalle de las 16 secciones del UserTemplate | 16 |

> `BAUTH-ROLTEMPLATE-SECCIONES.md` y `BAUTH-USERTEMPLATE-SECCIONES.md` están en la carpeta padre:
> `../BAUTH-ROLTEMPLATE-SECCIONES.md` y `../BAUTH-USERTEMPLATE-SECCIONES.md`

### 3.2 Catálogo de roles

| Documento | Contenido |
|-----------|-----------|
| `BAUTH-CATALOGO-ROLES-EMPRESARIALES.md` | 368 roles, 66 plantillas, 7 tiers (SU/SYS/BIZ_N1-N5/EXT/M2M/VISITANTE), 21 sectores CAEB |
| `BAUTH-CADENAS-JERARQUIA.md` | 186 aristas DAG de herencia de roles. Closure table. BitMask OR inheritance |

### 3.3 Frameworks de autenticación (JSON)

| Documento | Versión | Contenido |
|-----------|:-------:|-----------|
| `Authentication_Framework_v3.json` | v3.0.0 | 27+1 grupos de autenticación, arquitectura completa |
| `Policies_Authentication_Framework_v4.json` | v4.0.0 | 18 métodos KC, políticas por tier y LoA |

---

## SECCIÓN 4 — DISEÑO DE DOMINIOS (DDL anterior y diseño de dominios)

### 4.1 DDL de dominios (trabajo anterior — referencia)

| Documento | Dominio | Contenido |
|-----------|:-------:|-----------|
| `BAUTH-DDL-DOMINIO-FISICO.md` | D4 | DDL previo de acceso físico — revisar antes de implementar D4 |
| `BAUTH-DDL-DOMINIO-FINANCIERO.md` | D7 | DDL previo financiero — revisar antes de implementar D7 |
| `DDL_framework_unified.sql` | Todos | DDL unificado de trabajo anterior — referencia para reutilizar |
| `BAUTH-D12-INFRAESTRUCTURA-BLOCKCHAIN.md` | D12/D13 | Infraestructura blockchain previa |
| `SBOS-MANUAL-BAUTH-D12-BLOCKCHAIN-WALLET-CONTROL.md` | D13 | Control de wallets — referencia para D13 |

### 4.2 Análisis de completitud

| Documento | Contenido |
|-----------|-----------|
| `BAUTH-COMPLETITUD-DOMINIOS-STANDARDS.md` | Verificación de completitud por dominio vs estándares internacionales |
| `BAUTH-GAP-ANALISIS-TABLAS-vs-TEMPLATE.md` | Análisis de gaps entre tablas DDL y campos de templates |
| `SBOS-BITMASK-ANALISIS-SAM128-Y-PLAN-CORREGIDO.md` | Análisis del BitMask SAM-128 y plan de corrección |

---

## SECCIÓN 5 — ARQUITECTURA Y SEGURIDAD

### 5.1 Arquitectura general

| Documento | Contenido |
|-----------|-----------|
| `BAUTH-ARQUITECTURA-FRAMEWORK.md` | bAuth como orquestador central — patrón Helidon/Duende |
| `BAUTH-CONTRATO-SYMBIOSIS.md` | Simbiosis trilateral bAuth-KC-Tryton. Contratos de integración |
| `SBOS-008-ROLFRAMEWORK-v1_0.md` | 5 SPIs Java 21. 5 capas Tryton. Role Framework v2.0 |
| `BAUTH-CONTEXT-PLANE-B16.md` | Context Plane: ctx_id 6 capas, W3C Trace, OTel Baggage |
| `BAUTH-CRUD-ROLES-USUARIOS.md` | Diseño CRUD de roles y usuarios con árbol jerárquico |

### 5.2 Seguridad

| Documento | Contenido |
|-----------|-----------|
| `SBOS-054-NETWORK-SECURITY.md` | NRS-01 a NRS-10. SAN-01 a SAN-12. Seguridad de red |
| `SBOS-BAUTH-DIGITAL-SIGNATURE-ENGINES.md` | Doble motor de firmas: Vault Ed25519 (interno) + ADSIB RSA-SHA256 (externo) |
| `SBOS-BAUTH-USER-REGISTRATION-CREDENTIAL-LIFECYCLE.md` | IAL1-3, credenciales aleatorias (diceware), auto-gestión, recuperación |
| `SBOS-BAUTH-ACCESS-REVOCATION-REMOVAL.md` | Revocación < 30s, offboarding, privilege creep detection |

### 5.3 ADRs (decisiones arquitectónicas irreversibles)

| ADR | Tema |
|-----|------|
| `adrs/ADR-001-Rust-Java-Stack.md` | Stack Rust 1.85+ MUSL + Java 21 SPIs |
| `adrs/ADR-002-Interface-Dual-ADR-020.md` | Interface Dual WS-RPC + JSON-RPC 2.0 |
| `adrs/ADR-003-BitMask-64-DAG.md` | BitMask 64-bit 2 capas + DAG herencia OR |
| `adrs/ADR-004-bAuth-Framework-No-Monolito.md` | Arquitectura modular, anti-monolito |
| `adrs/ADR-005-Argon2id-Hash-Algorithm.md` | Argon2id para hash de contraseñas (NIST SP 800-63B) |
| `adrs/ADR-006-Dual-Digital-Signature-Engine.md` | Doble motor firma: interno + externo |
| `adrs/ADR-007-Keycloak-3-Realms-Per-Tenant.md` | 3 realms por tenant en Keycloak |
| `adrs/ADR-008-Symbiosis-bAuth-KC-Tryton.md` | Simbiosis bAuth-KC-Tryton |
| `adrs/ADR-009-BitMask-Dual-Label-OneHot.md` | Label + OneHot en BitMask dual |
| `adrs/ADR-010-DEPRECACION-TRYTON.md` | Estado de Tryton en el stack |
| `adrs/ADR-D12-Blockchain-Dominio-12.md` | D12/D13 Blockchain domain |

---

## SECCIÓN 6 — BASE DE DATOS: ESQUEMAS Y TABLAS DE REFERENCIA

### 6.1 Conexión a la VPS

```bash
# Conexión a PostgreSQL en VPS
ssh root@13.140.128.230
export KUBECONFIG=/etc/kubernetes/admin.conf
kubectl exec -it $(kubectl get pod -l app=postgresql -n default -o name | head -1) -- \
  psql -U postgres -d SBOS_db
```

### 6.2 Esquemas en SBOS_db

| Schema | Propósito | Tablas principales |
|--------|-----------|-------------------|
| `bauth` | **Schema principal bAuth** — 180+ tablas. Toda la lógica de identidad y privilegios | privilege_atom, privilege_domain, privilege_application, idn_tenant, idn_user_template, idn_role_template, bitmask_bundle, audit_event, cfg_policy_library |
| `bglobal` | Catálogos globales — datos de referencia internacional | global_country (196), global_language (125), geo_timezone (319), global_currency (143) |
| `bcalendar` | Horarios y calendarios | cal_schedule |
| `public` | Tablas del sistema PostgreSQL | — |

### 6.3 Tablas críticas del rediseño (bauth schema)

| Tabla | Propósito | Relevante para |
|-------|-----------|---------------|
| `bauth.privilege_domain` | 13 dominios (0-12, más D13 a crear) | F1.02-F1.03 |
| `bauth.privilege_application` | Apps por dominio (app_code) | F1.04 |
| `bauth.privilege_group` | Grupos dentro de cada app | F1.05 |
| `bauth.privilege_verb` | Verbos (1=C, 2=R, 3=U, 4=D + semánticos) | F1.06 |
| `bauth.privilege_atom` | **Tabla central** — todos los átomos CRUD 1-5964 | F1.07, F2.01-F2.10, F3.03 |
| `bauth.idn_tenant` | Tenants del sistema (`is_internal` a agregar) | F1.01 |
| `bauth.idn_user_template` | Actores: HUMAN/SERVICE/DEVICE/BOT | FASE 5 |
| `bauth.idn_role_template` | Plantillas de rol con 14 bloques JSONB | FASE 5 |
| `bauth.bitmask_bundle` | Cache BitMask computado (BIGINT[]) | F2.10 |
| `bauth.audit_event` | Registro de auditoría append-only | solo lectura |
| `bauth.cfg_policy_library` | 9,142 filas — referencia normativa inmutable | solo lectura |
| **`bauth.idn_atributo`** | **NUEVA** — tabla EAV genérica extensible (crear en F1.08) | FASE 1 |
| `bauth.ath_policy_d4` | Política acceso físico D4 | FASE 2 |
| `bauth.ath_policy_d5` | Política dispositivos D5 | FASE 2 |
| `bauth.ath_policy_d6` | Política geoespacial D6 | FASE 2 |
| `bauth.ath_policy_d7` | Política financiera D7 | FASE 2 |
| `bauth.ath_policy_d8` | Política temporal D8 | FASE 2 |
| `bauth.ath_policy_d9` | Política red D9 | FASE 2 |
| `bauth.ath_policy_d10` | Política auditoría D10 | FASE 2 |
| `bauth.ath_policy_d11` | Política biométrica D11 | FASE 2 |
| `bauth.ath_policy_d12` | Política delegación/compliance D12 | FASE 2 |

### 6.4 Tablas bglobal de referencia (solo lectura — NO modificar)

| Tabla | Registros | Columnas clave | Usada por |
|-------|:---------:|----------------|-----------|
| `bglobal.global_country` | 196 | `iso_alpha2`, `iso_alpha3`, `itu_calling_code`, `name_es` | display_format COUNTRY_CODE, ID_XX, TAX_XX |
| `bglobal.global_language` | 125 | `locale` (BCP 47), `name_es`, `iso_639_1` | display_format LOCALE_BCP47 |
| `bglobal.geo_timezone` | 319 | `timezone_id` (IANA), `utc_offset`, `country_iso` | display_format TIMEZONE_IANA |
| `bglobal.global_currency` | 143 | `currency_code` (ISO 4217), `symbol`, `name_es` | display_format MONEY |

### 6.5 Consultas de verificación clave

```sql
-- Ver dominios existentes
SELECT domain_code, domain_name, is_normative FROM bauth.privilege_domain ORDER BY domain_code;

-- Contar átomos por dominio
SELECT domain_code, COUNT(*) as atomos
FROM bauth.privilege_atom
GROUP BY domain_code ORDER BY domain_code;

-- Ver átomos D00 (si ya existen)
SELECT atom_code, verb_code, group_code, pos
FROM bauth.privilege_atom
WHERE domain_code = 0 ORDER BY pos;

-- Verificar catálogos bglobal
SELECT COUNT(*) FROM bglobal.global_country;
SELECT COUNT(*) FROM bglobal.global_language;
SELECT COUNT(*) FROM bglobal.geo_timezone;

-- Ver política de auditoría (referencia inmutable)
SELECT domain_code, policy_key, standard_ref
FROM bauth.cfg_policy_library
WHERE domain_code = 0
LIMIT 20;

-- Ver estructura de idn_atributo (después de crear)
\d bauth.idn_atributo

-- Verificar tablas existentes en bauth schema
SELECT tablename FROM pg_tables WHERE schemaname = 'bauth' ORDER BY tablename;
```

---

## SECCIÓN 7 — CÓDIGO RUST: MÓDULOS A MODIFICAR

### 7.1 Rutas del código fuente

```
/opt/skull/orquestador/proyectos/desarrollo/sbos/BauthAgent/src/
├── main.rs                              ← entry point (≤50 líneas)
├── domain/
│   ├── mod.rs                           ← módulo principal domain
│   ├── roltemplate_validator.rs         ← MODIFICAR: validar 14 bloques
│   ├── usertemplate_validator.rs        ← MODIFICAR: validar 16 bloques
│   └── [NUEVO] atributo_extensible.rs   ← CREAR: CRUD idn_atributo
├── server/
│   ├── handlers/
│   │   ├── mod.rs                       ← MODIFICAR: rutas CRUD D00
│   │   ├── role_lifecycle.rs            ← REVISAR: átomos D00 CRUD
│   │   └── [NUEVO] atributo.rs          ← CREAR: handlers idn_atributo
└── sync/
    └── role_sync.rs                     ← MODIFICAR: sync D4-D12 KC
```

### 7.2 Compilación y despliegue

```bash
# En máquina local — compilar MUSL
cargo build --release --target x86_64-unknown-linux-musl

# Copiar a VPS
scp target/x86_64-unknown-linux-musl/release/bauth root@13.140.128.230:/opt/bauth/bin/

# En VPS — reiniciar servicio
ssh root@13.140.128.230 "systemctl restart bauth.service && journalctl -u bauth.service -n 50"
```

---

## SECCIÓN 8 — ORDEN DE LECTURA RECOMENDADO POR ROL DE TRABAJO

### Si vas a escribir el SQL de la migración 003:

1. `BAUTH-COBERTURA-100PCT.md` → entender qué tablas y átomos crear
2. `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md` → estructura exacta de 120 átomos
3. `BAUTH-D00-ATRIBUTO-EXTENSIBLE-v1.0.md` → DDL de idn_atributo
4. DDL canónico (ruta externa) → verificar tablas existentes
5. MANUAL_DB_DDL.md (ruta externa) → entender invariantes
6. `DDL_framework_unified.sql` → SQL previo como referencia

### Si vas a escribir código Rust:

1. `BAUTH-COBERTURA-100PCT.md`
2. `SBOS-ROLTEMPLATE-v5_0.md` + `SBOS-USERTEMPLATE-v5_0.md`
3. `BAUTH-ARQUITECTURA-ATOMICA-FINAL.md §Arquitectura modular`
4. `BAUTH-ARQUITECTURA-FRAMEWORK.md`
5. `adrs/ADR-003-BitMask-64-DAG.md`
6. `BAUTH-CATALOGO-ATOMOS-D00-CRUD.md`

### Si vas a hacer validación en VPS:

1. `REGISTRO-ESTADO-REDISEÑO.md` → ver qué tests corresponden a la fase actual
2. `BAUTH-COBERTURA-100PCT.md` → criterios de éxito
3. Consultas SQL de §6.5 de este documento

---

## SECCIÓN 9 — ADVERTENCIAS CRÍTICAS

```
⚠️  TODO DDL REQUIERE APROBACIÓN HUMANA ANTES DE APLICAR
⚠️  NO USAR DROP TABLE SIN HABER MIGRADO LOS DATOS PRIMERO
⚠️  LOS CATÁLOGOS bglobal.* SON SOLO LECTURA — NO MODIFICAR
⚠️  LOS ÁTOMOS SE INSERTAN EN ORDEN — las posiciones son secuenciales
⚠️  audit_event ES APPEND-ONLY — NUNCA DELETE o UPDATE en esa tabla
⚠️  cfg_policy_library ES INMUTABLE EN RUNTIME — solo se actualiza con releases
⚠️  COMPILAR LOCAL, NUNCA EN VPS — flujo: cargo build → scp → systemctl restart
⚠️  ESPAÑOL OBLIGATORIO en código, comentarios, commits y comunicación
```

---

*Generado: 2026-07-01 · Versión: 1.0.0 · Carpeta: REPARACIONBAUTH*
