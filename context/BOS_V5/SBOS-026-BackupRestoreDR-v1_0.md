# SBOS-026 — Guía de Backup, Restore y Disaster Recovery
## Runbooks RK-011, RK-012, RK-013 — Continuidad operacional de PostgreSQL en SBOS

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-026
**Versión:** 1.0
**Estado:** ACTIVO
**Complemento operativo:** SBOS-026-SIM-Simulacro-DR-v1_0.md (Plan de Simulacro DR — checklist operativo de 14 pasos para ejecución del simulacro semestral)
**Documento nuevo** — no reemplaza a ningún documento anterior
**Clasificación:** Especificación Operacional — Backup, Restore y DR
**Complementa:** SBOS-024 (SLOs y Runbooks), SBOS-010 (bKernel y WAL), SBOS-016 (Servidores)

---

## Tabla de Contenidos

1. [Por qué este documento existe](#1-por-qué-este-documento-existe)
2. [Topología de backup en SBOS](#2-topología-de-backup-en-sbos)
3. [RK-011 — Backup con pgBackRest](#3-rk-011--backup-con-pgbackrest)
4. [RK-012 — Restore completo y PITR](#4-rk-012--restore-completo-y-pitr)
5. [RK-013 — Simulacro semestral de DR](#5-rk-013--simulacro-semestral-de-dr)
6. [Tabla de RTO/RPO por escenario](#6-tabla-de-rtorpo-por-escenario)
7. [Alertas de backup en Alertmanager](#7-alertas-de-backup-en-alertmanager)
8. [Registro de cambios](#8-registro-de-cambios)

---

## 1. Por qué este documento existe

PostgreSQL es el componente de mayor criticidad del stack SBOS. Si PostgreSQL no está disponible, el sistema completo está inoperativo: las aplicaciones no pueden leer ni escribir datos, el bKernel no tiene WAL que procesar, y Keycloak pierde su base de datos de identidad.

Pero el riesgo más silencioso no es la indisponibilidad — es **la pérdida de datos sin proceso de recuperación probado**. Una base de datos con backup no verificado es equivalente a no tener backup.

Este documento define tres cosas que convierten el backup en recuperación operacional real:

1. **RK-011** — cómo se realiza el backup de PostgreSQL con pgBackRest hacia MinIO, incluyendo los artefactos específicos de SBOS que deben preservarse.
2. **RK-012** — cómo se restaura el sistema completo desde cero, incluyendo los slots de replicación lógica del bKernel y la verificación de la cadena de sincronización.
3. **RK-013** — cómo se ejecuta y registra un simulacro de DR semestral con evidencia verificable.

### Riesgo específico de SBOS que no existe en deployments convencionales de PostgreSQL

El bKernel usa **slots de replicación lógica** (`pgoutput`) para leer el WAL de cada base de datos del stack. Estos slots tienen nombre y estado persistente en PostgreSQL. Un restore estándar de PostgreSQL con `pg_dump` o `pgbackrest restore` **no migra los slots de replicación lógica** — deben ser recreados manualmente post-restore.

Si el restore no incluye la recreación de los slots, el sistema parece operativo (PostgreSQL responde, las apps funcionan) pero el bKernel no puede conectarse al WAL: **la sincronización de datos entre aplicaciones cesa silenciosamente**.

Este documento incluye la verificación explícita de los slots como paso obligatorio de cualquier restore.

---

## 2. Topología de backup en SBOS

```
S01 · dataserver (ORIGEN)
├── PostgreSQL 17 (WAL level=logical)
│   ├── keycloak_db         ← identidad de todos los tenants
│   ├── tryton_db           ← ERP, fuente de verdad de negocio
│   ├── bkernel_db          ← estado del daemon + LSN checkpoints
│   ├── biedata_db         ← integraciones tributarias
│   ├── bcompass_db         ← rutas y estado de bCompass
│   ├── orangehrm_db        ← RRHH
│   ├── saleor_db           ← e-commerce
│   └── [otras BDs del stack]
│
│   SLOTS DE REPLICACIÓN LÓGICA (críticos):
│   ├── bkernel_tryton       → bKernel monitorea tryton_db
│   ├── bkernel_orangehrm    → bKernel monitorea orangehrm_db
│   ├── bkernel_saleor       → bKernel monitorea saleor_db
│   └── [un slot por BD monitoreada]
│
├── Patroni               ← gestión de HA de PostgreSQL
└── PgBouncer             ← pool de conexiones (todas las apps pasan por aquí)

S14 · opsserver (HERRAMIENTA)
└── pgBackRest            ← cliente de backup instalado en S14

S01 · dataserver (DESTINO)
└── MinIO                 ← object storage, repo de backups
    └── bucket: sbos-pgbackup/
        ├── backup/       ← archivos de backup
        └── archive/      ← WAL archivado continuamente
```

**Decisión de diseño:** MinIO como destino de backup vive en el mismo servidor que PostgreSQL (S01). Esto facilita la latencia de restore pero no protege ante fallo catastrófico del servidor físico. Para instalaciones de producción con presupuesto, se recomienda replicar el bucket MinIO a un segundo servidor o servicio externo. Para modo nodo único, este diseño cumple el SLA de RPO 15 minutos del contrato.

---

## 3. RK-011 — Backup con pgBackRest

**Activación:** Automático via cron. Verificación manual mensual.
**Responsable:** SRE Lead
**Impacto si falla:** Sin capacidad de restore ante fallo de PostgreSQL.

### 3.1 Instalación y configuración de pgBackRest

```bash
# En S14 (opsserver) — instalar pgBackRest
sudo apt install pgbackrest

# Crear directorio de configuración
sudo mkdir -p /etc/pgbackrest
sudo mkdir -p /var/log/pgbackrest
```

Archivo de configuración `/etc/pgbackrest/pgbackrest.conf`:

```ini
[global]
# Repositorio MinIO en S01 (dataserver)
repo1-type=s3
repo1-path=/sbos-pgbackup
repo1-s3-endpoint=minio.dataserver.svc.cluster.local:9000
repo1-s3-region=us-east-1
repo1-s3-bucket=sbos-pgbackup
repo1-s3-key=<MINIO_ACCESS_KEY>         # obtener de Vault: secret/pgbackrest/minio
repo1-s3-key-secret=<MINIO_SECRET_KEY>  # obtener de Vault: secret/pgbackrest/minio
repo1-s3-uri-style=path
repo1-s3-verify-tls=n                   # MinIO interno sin cert público

# Configuración de retención
repo1-retention-full=4          # 4 backups completos = 4 semanas
repo1-retention-diff=6          # 6 backups diferenciales
repo1-retention-archive=7       # 7 días de WAL archivado

# Logging
log-level-console=info
log-level-file=detail
log-path=/var/log/pgbackrest

[sbos]
# Stanza: nombre lógico de la instancia PostgreSQL
pg1-path=/var/lib/postgresql/17/main
pg1-host=dataserver              # S01 dataserver
pg1-port=5432
pg1-user=pgbackrest              # rol de replicación dedicado
```

Configurar `archive_command` en PostgreSQL (`postgresql.conf` en S01):

```ini
# En /etc/postgresql/17/main/postgresql.conf
wal_level = logical
archive_mode = on
archive_command = 'pgbackrest --stanza=sbos archive-push %p'
archive_timeout = 60        # archivar WAL cada 60 segundos como máximo
max_replication_slots = 20  # suficiente para todos los slots de bKernel
```

Inicializar la stanza:

```bash
# Ejecutar desde S14 (opsserver)
sudo -u postgres pgbackrest --stanza=sbos stanza-create
sudo -u postgres pgbackrest --stanza=sbos check
```

### 3.2 Política de backups

| Tipo | Frecuencia | Hora | Retención |
|------|-----------|------|-----------|
| Full (completo) | Semanal (domingo) | 01:00 hora local | 4 semanas |
| Diferencial | Diario (lun–sáb) | 01:00 hora local | 6 días |
| WAL continuo | Continuo | archive_timeout: 60s | 7 días |

Crontab en S14 (`/etc/cron.d/pgbackrest`):

```cron
# Backup completo — domingos 01:00
0 1 * * 0 postgres pgbackrest --stanza=sbos --type=full backup

# Backup diferencial — lunes a sábado 01:00
0 1 * * 1-6 postgres pgbackrest --stanza=sbos --type=diff backup
```

### 3.3 Bases de datos incluidas en el backup

pgBackRest hace backup de toda la instancia PostgreSQL, incluyendo:

| Base de datos | Criticidad | Contenido |
|--------------|-----------|-----------|
| `keycloak_db` | MÁXIMA | Realms, usuarios, roles, SPIs — sin esto nadie puede autenticarse |
| `tryton_db` | MÁXIMA | ERP, facturas, inventario, contabilidad |
| `bkernel_db` | ALTA | LSN checkpoints, audit_events, processed_events, crossref |
| `biedata_db` | ALTA | Resultados de integraciones tributarias, comprobantes |
| `bcompass_db` | MEDIA | Estado de rutas, historial de ejecuciones |
| `orangehrm_db` | ALTA | Empleados, contratos, estructura organizacional |
| `saleor_db` | ALTA | Catálogo, órdenes, clientes de e-commerce |

> **Nota crítica:** `bkernel_db` debe estar incluida en el backup. Esta base de datos contiene la tabla `checkpoint` con el último LSN procesado por el bKernel. Si se restaura PostgreSQL sin restaurar `bkernel_db`, el bKernel arranca desde un LSN incorrecto o no puede determinar su punto de reanudación.

### 3.4 Verificación post-backup

```bash
# Verificar estado del repositorio de backup
pgbackrest --stanza=sbos info

# Salida esperada:
# stanza: sbos
#     status: ok
#     backup type: full
#     backup: 20260303-010000F
#     timestamp start/stop: 2026-03-03 01:00:00 / 2026-03-03 01:23:14
#     database size: X.XGB, backup size: X.XGB

# Verificar que el WAL se está archivando correctamente
pgbackrest --stanza=sbos check

# Si el check falla: revisar que archive_command funciona en PostgreSQL
sudo -u postgres psql -c "SELECT pg_switch_wal();"
# Verificar que el WAL aparece en MinIO
```

### 3.5 Credenciales — gestión via Vault

Las credenciales de MinIO para pgBackRest se obtienen de Vault:

```bash
# Obtener credenciales desde Vault (S02 gatewayserver)
vault kv get secret/pgbackrest/minio

# Las credenciales deben rotarse cada 90 días
# Proceso: generar nuevas en MinIO → actualizar en Vault → recargar pgbackrest.conf
```

---

## 4. RK-012 — Restore completo y PITR

**Activación:** Fallo catastrófico de S01 dataserver O corrupción de datos detectada.
**Responsable:** SRE Lead
**Impacto durante restore:** Sistema completo inoperativo.
**SLA de RTO:** 15 minutos para PostgreSQL, 1 hora para sistema completo.

### 4.1 Escenario A — Restore completo (S01 destruido)

Este escenario cubre la pérdida total del servidor S01 (dataserver): fallo de disco, corrupción irreparable, o migración a nuevo hardware.

**Paso 1 — Preparar el nuevo servidor PostgreSQL (T+0 a T+10)**

```bash
# En el nuevo S01 (Ubuntu 24.04 limpio)
sudo apt install postgresql-17 pgbackrest

# Detener PostgreSQL temporalmente
sudo systemctl stop postgresql

# Limpiar el directorio de datos (está vacío en servidor nuevo)
sudo rm -rf /var/lib/postgresql/17/main/*
```

**Paso 2 — Restore desde pgBackRest (T+10 a T+20)**

```bash
# Restore del backup más reciente
sudo -u postgres pgbackrest --stanza=sbos restore

# Para restore a un punto específico en el tiempo (PITR):
# sudo -u postgres pgbackrest --stanza=sbos restore \
#   --target="2026-03-03 14:30:00" \
#   --target-action=promote

# Iniciar PostgreSQL post-restore
sudo systemctl start postgresql

# Verificar que PostgreSQL está operativo
sudo -u postgres pg_isready
# Esperado: /var/run/postgresql:5432 - accepting connections
```

**Paso 3 — CRÍTICO: Verificar y recrear slots de replicación lógica (T+20 a T+25)**

```bash
# Verificar qué slots existen post-restore
sudo -u postgres psql -c "SELECT slot_name, plugin, active, restart_lsn FROM pg_replication_slots;"

# pgBackRest NO migra los slots de replicación lógica.
# Si la lista está vacía o incompleta, recrear los slots:

sudo -u postgres psql << 'EOF'
-- Recrear slots para cada BD que el bKernel monitorea
SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_orangehrm', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_saleor', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_espocrm', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_zammad', 'pgoutput');
-- Agregar un slot por cada BD de aplicación que el bKernel monitorea
-- Ver /etc/bos/blibs/bkernel/bkernel.toml para la lista completa
EOF
```

**Paso 4 — Reiniciar el bKernel (T+25 a T+27)**

```bash
# El bKernel lee el LSN desde bkernel_db.checkpoint al arrancar
# Si bkernel_db fue restaurada correctamente, retoma desde el último LSN conocido
sudo systemctl start bkernel
sudo systemctl status bkernel

# Verificar que el bKernel está procesando correctamente
# En Grafana: métrica bkernel_wal_lag_seconds debe bajar a < 500ms en ~2 minutos
```

**Paso 5 — Verificar Keycloak (T+27 a T+30)**

```bash
# Keycloak depende de keycloak_db. Si fue restaurada, Keycloak debe funcionar.
# Reiniciar Keycloak para que reestablezca la conexión
kubectl rollout restart deployment/keycloak -n keycloak

# Verificar que el realm principal responde
curl -s https://bos.<cliente>.com/realms/master/.well-known/openid-configuration \
  | python3 -m json.tool | head -5
# Esperado: JSON con issuer, authorization_endpoint, etc.
```

**Paso 6 — Verificar aplicaciones críticas (T+30 a T+45)**

```bash
# Verificar Kong
curl -s http://kong:8001/status | python3 -m json.tool

# Verificar que el bKernel está sincronizando — confirmar que el lag bajó
kubectl exec -n monitoring prometheus-0 -- \
  promtool query instant 'bkernel_wal_lag_seconds'
# Esperado: valor < 0.5

# Verificar que Tryton responde
curl -s https://bos.<cliente>.com/tryton/health
```

### 4.2 Script de validación post-restore

```bash
#!/bin/bash
# /usr/local/bin/sbos-restore-validate.sh
# Ejecutar después de cualquier restore para confirmar integridad

echo "=== SBOS RESTORE VALIDATION ==="
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

PASS=0
FAIL=0

check() {
  local name=$1
  local cmd=$2
  if eval "$cmd" &>/dev/null; then
    echo "✅ PASS: $name"
    ((PASS++))
  else
    echo "❌ FAIL: $name"
    ((FAIL++))
  fi
}

# 1. PostgreSQL acepta conexiones
check "PostgreSQL operativo" "pg_isready -U postgres"

# 2. Slots de replicación existen
check "Slots de replicación presentes" \
  "psql -U postgres -c \"SELECT count(*) FROM pg_replication_slots WHERE plugin='pgoutput'\" | grep -E '[1-9][0-9]*'"

# 3. bkernel_db tiene registros de checkpoint
check "bkernel_db checkpoint presente" \
  "psql -U postgres -d bkernel_db -c \"SELECT count(*) FROM checkpoint\" | grep -E '[1-9][0-9]*'"

# 4. keycloak_db tiene realms
check "Realms de Keycloak presentes" \
  "psql -U postgres -d keycloak_db -c \"SELECT count(*) FROM realm\" | grep -E '[1-9][0-9]*'"

# 5. bKernel daemon activo
check "bKernel daemon activo" "systemctl is-active bkernel"

# 6. Keycloak responde OIDC
check "Keycloak OIDC operativo" \
  "curl -sf https://bos.localhost/realms/master/.well-known/openid-configuration"

# 7. Tryton responde
check "Tryton operativo" "curl -sf https://bos.localhost/tryton/health"

echo ""
echo "=== RESULTADO: $PASS pasaron, $FAIL fallaron ==="
if [ $FAIL -gt 0 ]; then
  echo "⚠️  RESTORE INCOMPLETO — revisar los items fallidos antes de notificar al cliente"
  exit 1
else
  echo "✅ RESTORE EXITOSO — sistema operativo"
  exit 0
fi
```

### 4.3 Point-In-Time Recovery (PITR)

Usar cuando se necesita recuperar a un momento específico antes de un evento de corrupción de datos:

```bash
# Identificar el timestamp objetivo (momento justo antes de la corrupción)
# Consultar los logs de Loki para identificar cuándo ocurrió el evento problemático

# Restore a timestamp específico
sudo -u postgres pgbackrest --stanza=sbos restore \
  --target="2026-03-03 14:29:59" \
  --target-action=promote \
  --target-exclusive=y

# Después del PITR, los slots de replicación deben recrearse igual que en 4.1 Paso 3
# El bKernel debe verificar la consistencia de bkernel_db.checkpoint con el nuevo LSN
```

---

## 5. RK-013 — Simulacro semestral de DR

**Frecuencia:** Cada 6 meses (marzo y septiembre)
**Ambiente:** STAGING únicamente — NUNCA en producción
**Participantes:** SRE Lead (ejecutor) + DevOps (observador con cronómetro)
**Duración estimada:** 90 minutos

### 5.1 Checklist de ejecución

```
PRE-SIMULACRO (30 minutos antes):
□ Confirmar que el último backup de staging está disponible en MinIO
□ Confirmar credenciales pgBackRest activas (pgbackrest --stanza=sbos check)
□ Confirmar que el IAM Installer está disponible para reinstalar
□ Notificar al equipo que staging estará inactivo durante el simulacro
□ Inicializar hoja de registro con fecha y participantes

FASE 1 — ESTADO INICIAL (T+00):
□ Registrar: versión de PostgreSQL en staging: _______
□ Registrar: número de BDs presentes: _______
□ Registrar: número de slots de replicación activos: _______
□ Registrar: último LSN de bkernel_db.checkpoint: _______
□ Tomar snapshot de referencia: pg_dumpall --schema-only > /tmp/schema_pre.sql
□ INICIO CRONÓMETRO OFICIAL

FASE 2 — DESTRUCCIÓN CONTROLADA (T+05):
□ Detener bKernel: sudo systemctl stop bkernel
□ Detener PostgreSQL: sudo systemctl stop postgresql
□ Simular fallo catastrófico: sudo rm -rf /var/lib/postgresql/17/main/*
□ Verificar que pg_isready falla: pg_isready devuelve error
□ Registrar T destrucción: _______

FASE 3 — RESTORE POSTGRESQL (T+10):
□ Inicio cronómetro RTO PostgreSQL
□ Ejecutar: sudo -u postgres pgbackrest --stanza=sbos restore
□ Iniciar PostgreSQL: sudo systemctl start postgresql
□ Verificar: pg_isready devuelve "accepting connections"
□ FIN cronómetro RTO PostgreSQL
□ REGISTRAR RTO PostgreSQL: _______ (SLA objetivo: 15 minutos)
□ RESULTADO RTO PostgreSQL: PASS (≤15 min) / FAIL (>15 min)

FASE 4 — RECREAR SLOTS Y REINICIAR bKERNEL (T+15 a T+25):
□ Verificar slots: SELECT slot_name FROM pg_replication_slots WHERE plugin='pgoutput'
□ Cantidad de slots post-restore: _______ (esperado: mismo que pre-restore)
□ Si faltan slots: recrear con el script del RK-012 Paso 3
□ Reiniciar bKernel: sudo systemctl start bkernel
□ Verificar bKernel activo: systemctl is-active bkernel → "active"
□ Esperar 2 minutos y verificar lag WAL en Grafana < 500ms

FASE 5 — VERIFICAR KEYCLOAK Y APPS (T+25 a T+50):
□ Reiniciar Keycloak: kubectl rollout restart deployment/keycloak -n keycloak
□ Verificar OIDC: curl al endpoint .well-known/openid-configuration
□ Verificar login de prueba: admin del realm master
□ Verificar Tryton responde
□ Ejecutar script de validación: /usr/local/bin/sbos-restore-validate.sh
□ Resultado validación: _______ PASS de 7 checks

FASE 6 — MEDICIÓN FINAL (T+50 a T+60):
□ FIN cronómetro RTO sistema completo
□ REGISTRAR RTO sistema: _______ (SLA objetivo: 60 minutos)
□ RESULTADO RTO sistema: PASS (≤60 min) / FAIL (>60 min)
□ Cero pérdida de datos: comparar conteo de registros pre/post
```

### 5.2 Template de registro post-simulacro

```
═══════════════════════════════════════════════════════════
REGISTRO DE SIMULACRO DR — SBOS
═══════════════════════════════════════════════════════════
Fecha: ___________   Ambiente: staging
Ejecutor: ___________   Observador: ___________

TIEMPOS:
┌─────────────────────────────┬─────────┬─────────┬─────────┐
│ Fase                        │ Objetivo│ Real    │ Resultado│
├─────────────────────────────┼─────────┼─────────┼─────────┤
│ RTO PostgreSQL              │ 15 min  │         │ PASS/FAIL│
│ RTO Sistema completo        │ 60 min  │         │ PASS/FAIL│
│ Slots replicación recreados │ —       │         │ PASS/FAIL│
│ bKernel lag < 500ms         │ < 500ms │         │ PASS/FAIL│
│ Keycloak OIDC operativo     │ —       │         │ PASS/FAIL│
│ Script validación (7 checks)│ 7/7     │ ___/7   │ PASS/FAIL│
└─────────────────────────────┴─────────┴─────────┴─────────┘

DECISIÓN SOBRE SLA:
□ SLAs CONFIRMADOS — RTO PostgreSQL 15 min y sistema 60 min son alcanzables
□ SLA REQUIERE AJUSTE — RTO real fue _______, ajustar SLA a _______ en SBOS-024

DESVIACIONES DEL PROCEDIMIENTO:
___________________________________________________________

ACCIONES CORRECTIVAS IDENTIFICADAS:
1. ___________________________________________________________
2. ___________________________________________________________

PRÓXIMA FECHA DE SIMULACRO: ___________

Firma ejecutor: ___________   Firma observador: ___________
═══════════════════════════════════════════════════════════
```

---

## 6. Tabla de RTO/RPO por escenario

| Escenario | Descripción | RTO Objetivo | RPO Objetivo | Runbook | Intervención manual |
|-----------|-------------|-------------|-------------|---------|-------------------|
| **E-01** | Fallo S01 dataserver completo | 15 min (PostgreSQL) / 60 min (sistema) | 15 min (frecuencia backup diferencial) | RK-012 completo | Sí — recrear slots de replicación |
| **E-02** | Corrupción parcial de tabla | 30 min | Depende del timestamp de corrupción | RK-012 PITR | Sí — identificar timestamp pre-corrupción |
| **E-03** | bKernel pierde sincronización (crash) | < 5 min (automático) | 0 (retoma desde LSN checkpointado) | RK-003 (SBOS-024) | No — systemd lo reinicia automáticamente |
| **E-04** | Slot de replicación invalidado | 15 min | 0 (no hay pérdida de datos, solo gap de sincronización) | RK-012 Paso 3 | Sí — recrear slot y reiniciar bKernel |
| **E-05** | IAM Installer pierde .sbos_state.json | 30 min | 0 (el estado se reconstruye desde las fichas) | RK-008 (SBOS-024) | No — el IAM Installer lo reconstruye |

---

## 7. Alertas de backup en Alertmanager

Agregar las siguientes reglas al `prometheus-rules.yml` del monitorserver:

```yaml
# SBOS-026 — Alertas de backup y continuidad de negocio
- name: sbos.backup
  rules:

    - alert: pgBackRestBackupFailed
      expr: pgbackrest_backup_error == 1
      for: 0m
      labels:
        severity: critical
        team: skull-ops
        runbook: RK-011
      annotations:
        summary: "pgBackRest backup falló en stanza {{ $labels.stanza }}"
        description: >
          El backup de PostgreSQL no completó exitosamente.
          Sin backup válido, el sistema no puede recuperarse ante un fallo.
          Verificar logs: /var/log/pgbackrest/sbos-backup.log

    - alert: pgBackRestBackupStale
      expr: (time() - pgbackrest_backup_timestamp_last_full) > 86400 * 8
      for: 1h
      labels:
        severity: high
        team: skull-ops
        runbook: RK-011
      annotations:
        summary: "pgBackRest sin backup completo en más de 8 días"
        description: >
          El último backup completo tiene más de 8 días de antigüedad.
          El backup semanal puede haber fallado silenciosamente.

    - alert: WALSlotReplicationLag
      expr: pg_replication_slots_pg_wal_lsn_diff > 1073741824
      for: 10m
      labels:
        severity: high
        team: skull-ops
        runbook: RK-012
      annotations:
        summary: "Slot WAL del bKernel acumula > 1GB sin consumir"
        description: >
          El slot de replicación lógica del bKernel tiene > 1GB de WAL acumulado.
          Si PostgreSQL aplica max_slot_wal_keep_size, el slot puede invalidarse.
          Verificar que el bKernel está activo y procesando.
```

---

## 8. Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---------|-------|-------|-------------|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial — RK-011, RK-012, RK-013, alertas de backup |

---

*SKULL · SBOS · SBOS-026-BACKUP-RESTORE-DR · v1.0 · Marzo 2026*
*Complementa: SBOS-024 (Runbooks RK-001 a RK-010), SBOS-010 (bKernel y WAL LSN), SBOS-016 (topología S01/S14)*
