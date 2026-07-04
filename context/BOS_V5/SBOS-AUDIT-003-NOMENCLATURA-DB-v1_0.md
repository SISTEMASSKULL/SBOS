# SBOS-AUDIT-003
## Informe: Nomenclatura "biedata" y Gap de Catálogo de Bases de Datos
### Auditoría de Coherencia + Plan de Acción

### SKULL · SBOS — Sovereign Business Operating System
### Marzo 2026

---

## PARTE 1 — HALLAZGO: "biedata" no existe

### El problema

El daemon 3 del SBOS tiene un nombre definido y un servicio systemd:

```
Nombre del daemon:  biedata
Servicio systemd:   biedata.service
Nombre conceptual:  SBOS Data Integration
```

Sin embargo, **35 documentos del proyecto** usan el nombre "biedata" o "biedata" que NO es el nombre oficial. Este nombre nunca fue definido como estándar — es un nombre de trabajo que quedó residual en la documentación.

### Magnitud del problema

| Término | Archivos afectados | Ocurrencias totales |
|---------|:---------:|:----:|
| `biedata` (incorrecto) | 35 | ~250 |
| `biedata.service` (incorrecto) | 5 | ~8 |
| `biedata_db` (incorrecto) | 4 | ~6 |
| `biedata_slot` (incorrecto) | 3 | ~4 |
| `SBOS-011-INEXDATA` (nombre de archivo) | 1 | nombre del archivo mismo |

### Documentos más afectados

| Documento | Refs a "biedata" | Impacto |
|-----------|:-----------------:|---------|
| SBOS-011-INEXDATA-v3_0.md | 56 | El documento del propio daemon usa el nombre incorrecto |
| SBOS-011-Tributario-SIAT-AFIP-SAT.md | 25 | Complemento tributario |
| SBOS-002-ARCH-v4_0.md | 21 | Documento fundacional de arquitectura |
| SBOS-018-Standards-v1_0.md | 13 | Estándares |
| SBOS-016-Servers-v1_0.md | 11 | Mapa de servidores |
| SBOS-014-bCompass-v4_0.md | 10 | AI Tools |
| SBOS-004-K8S-v4_0.md | 10 | Infraestructura |
| SBOS-017-Roadmap-v2_0.md | 9 | Roadmap |
| SBOS-001-OKR-Strategic-v1_0.md | 8 | OKRs |

### Corrección requerida

En TODOS los documentos:
- `biedata` → `biedata` (cuando se refiere al daemon)
- `SBOS Data Integration` → se mantiene (es el nombre conceptual largo, correcto)
- `biedata.service` → `biedata.service`
- `biedata_db` → `biedata_db`
- `biedata_slot` → `biedata_slot`
- Archivo `SBOS-011-INEXDATA-v3_0.md` → renombrar a `SBOS-011-BIEDATA-v4_0.md`

---

## PARTE 2 — HALLAZGO: No existe catálogo de bases de datos

### El problema

El SBOS opera con 30+ bases de datos PostgreSQL (más MySQL para 3 apps legacy). Sin embargo, **no existe un documento que catalogue de forma centralizada**:

1. Qué bases de datos se crean
2. Qué tablas propias crea cada daemon
3. Qué usuarios PostgreSQL se crean y con qué permisos
4. Qué replication slots se configuran para WAL CDC
5. Qué extensions de PostgreSQL requiere cada app

La información está **dispersa** en 30 documentos diferentes. Un desarrollador que necesita entender el esquema de datos del SBOS tendría que leer 30 documentos para armarlo.

### BDs identificadas en el proyecto (31 bases de datos)

```
BASES DE DATOS DE APLICACIONES (una por app):
  tryton_db          → ERP core, fuente de verdad de negocio
  orangehrm_db       → RRHH (nota: MySQL, sincronizado vía SymmetricDS)
  saleor_db          → E-commerce
  espocrm_db         → CRM
  keycloak_db        → Identidad y acceso
  kong_db            → API Gateway
  grafana_db         → Dashboards
  zabbix_db          → Monitoreo infraestructura
  gitlab_db          → SCM y CI/CD
  paperless_db       → DMS/OCR
  docuseal_db        → Firma digital
  nextcloud_db       → Archivos colaborativos
  onlyoffice_db      → Ofimática
  roundcube_db       → Webmail
  postfixadmin_db    → Administración de correo
  langfuse_db        → Observabilidad de LLM
  health_db          → GNU Health (si está instalado)
  pgadmin_db         → Admin de PostgreSQL
  mail_db            → Buzones de correo

BASES DE DATOS DE DAEMONS SOBERANOS:
  bkernel_db         → Estado del bKernel: DLQ, entity_crossref, checkpoints LSN
  biedata_db         → Auditoría de biedata: jobs, audit_log, circuit breaker state
  bcompass_db        → Estado de bCompass: routes, analysis cache, feedback
  bauth_db           → Sincronización bAuth: sync_log, drift_history, delegations
  bsearch_db         → (nota: bSearch usa Typesense + Qdrant, no PostgreSQL propio)
  bhnexus_db         → (nota: bhnexus usa cache en memoria, no PostgreSQL propio)

BASE DE DATOS DEL SISTEMA:
  sbos_state_db      → Estado del IAM Installer (o archivo .sbos_state.json)
```

### Tablas propias de los daemons (dispersas en la documentación)

```
bkernel_db:
  bkernel_dlq              → Dead Letter Queue (SBOS-010-001)
  bkernel_state            → Checkpoints LSN (SBOS-010)
  bkernel_entity_crossref  → Mapeo de IDs entre apps (SBOS-010)

biedata_db:
  biedata_audit_log        → Log de ejecución de cajas (SBOS-011-001)
  biedata_dlq              → Dead Letter Queue de biedata
  biedata_circuit_state    → Estado de circuit breakers (SBOS-011-001)

bauth_db:
  bauth_sync_log           → Log de sincronización KC↔Tryton (SBOS-008-001)
  bauth_drift_history      → Historial de correcciones de drift (SBOS-008-001)
  bauth_delegations        → Delegaciones temporales activas (SBOS-008-001)

bcompass_db:
  bcompass_routes           → Rutas de inteligencia activas (SBOS-014)
  bcompass_feedback         → Feedback de usuarios para fine-tuning (SBOS-014-001)
```

### Replication Slots WAL (dispersos)

```
PostgreSQL:
  bkernel_slot      → bkernel escucha cambios de TODAS las apps
  biedata_slot      → biedata escucha eventos para triggers de integración
  bcompass_slot     → bCompass escucha eventos para análisis
```

### Lo que se necesita: SBOS-040-DATABASE-CATALOG

Un documento nuevo que centralice:
- Catálogo de las 31 BDs con owner, propósito, y app asociada
- Tablas propias de cada daemon con DDL completo
- Usuarios PostgreSQL con permisos (GRANT/REVOKE)
- Replication slots con tabla de quién escucha qué
- Extensions requeridas (pg_replication_origin, pgcrypto, etc.)
- Política de backup por BD (frecuencia, retención, PITR)

---

## PARTE 3 — PLAN DE ACCIÓN

### Acción 1: Reemplazar "biedata" → "biedata" en TODO el proyecto

**35 archivos afectados.** La corrección es mecánica (sed) pero debe verificarse manualmente en cada documento para no romper contextos.

```
Reglas de reemplazo:
  "biedata"           → "biedata"  (nombre del daemon)
  "biedata.service"   → "biedata.service"
  "biedata_db"        → "biedata_db"
  "biedata_slot"      → "biedata_slot"
  "SBOS-011-INEXDATA"  → "SBOS-011-BIEDATA"  (nombre del archivo)

Preservar sin cambio:
  "SBOS Data Integration"  → se mantiene (nombre conceptual largo)
```

### Acción 2: Crear SBOS-040-DATABASE-CATALOG

Nuevo documento que contenga:

```
§1  Catálogo de BDs (tabla: nombre, owner, app, servidor, tamaño estimado)
§2  Usuarios PostgreSQL (tabla: usuario, BD, permisos, propósito)
§3  Tablas propias de daemons (DDL completo por daemon)
§4  Replication Slots WAL (quién escucha qué, configuración)
§5  Extensions requeridas por app
§6  Política de backup y retención por BD
§7  Diagrama ER de las tablas propias de daemons
```

### Acción 3: Actualizar SBOS-000 INDEX

Agregar SBOS-040 al mapa de documentos y a las rutas de lectura relevantes.

### Orden de ejecución

```
PASO 1: Reemplazar biedata → biedata en los 35 archivos
PASO 2: Renombrar SBOS-011-INEXDATA → SBOS-011-BIEDATA
PASO 3: Crear SBOS-040-DATABASE-CATALOG
PASO 4: Actualizar SBOS-000 INDEX
PASO 5: Verificación final (grep de residuos)
```

**Estimación: 1-2 sesiones de trabajo.**

---

*SKULL · SBOS · SBOS-AUDIT-003 · Marzo 2026*
