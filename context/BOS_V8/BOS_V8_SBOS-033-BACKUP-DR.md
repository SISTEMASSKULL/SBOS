# SBOS-033-BACKUP-DR
## Backup, Restore y Disaster Recovery — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Propósito

PostgreSQL = componente de mayor criticidad. Riesgo más silencioso: pérdida de datos sin proceso de recuperación probado. Backup no verificado = no backup.

**Riesgo específico SBOS:** bKernel usa slots de replicación lógica (pgoutput). Un restore estándar NO migra los slots. Sin slots, bKernel no conecta al WAL → sincronización cesa silenciosamente. Este documento incluye recreación de slots como paso obligatorio.

## 2. Topología de Backup

```
S01 dataserver (ORIGEN)
├── PostgreSQL 17 (wal_level=logical)
│   ├── keycloak_db, tryton_db, bkernel_db, biedata_db
│   ├── bcompass_db, orangehrm_db, saleor_db, [otras]
│   └── SLOTS REPLICACIÓN LÓGICA:
│       bkernel_tryton, bkernel_orangehrm, bkernel_saleor, ...
├── Patroni (HA) + PgBouncer (pool)

S14 opsserver (HERRAMIENTA)
└── pgBackRest → MinIO (S01)
    └── bucket: sbos-pgbackup/ (backup/ + archive/)
```

MinIO en mismo servidor (latencia restore). Producción con presupuesto: replicar bucket a segundo servidor.

## 3. RK-011 — Backup con pgBackRest

### Configuración pgBackRest → MinIO (S3-compatible)
```ini
[global]
repo1-type=s3
repo1-s3-endpoint=minio.dataserver.svc.cluster.local:9000
repo1-s3-bucket=sbos-pgbackup
repo1-retention-full=4       # 4 backups completos = 4 semanas
repo1-retention-diff=6       # 6 diferenciales
repo1-retention-archive=7    # 7 días WAL

[sbos]
pg1-path=/var/lib/postgresql/17/main
pg1-host=dataserver
```

### PostgreSQL archive_command
```ini
wal_level = logical
archive_mode = on
archive_command = 'pgbackrest --stanza=sbos archive-push %p'
archive_timeout = 60
max_replication_slots = 20
```

### Política de backups

| Tipo | Frecuencia | Hora | Retención |
|---|---|---|---|
| Full (completo) | Semanal (domingo) | 01:00 | 4 semanas |
| Diferencial | Diario (lun-sáb) | 01:00 | 6 días |
| WAL continuo | Continuo | archive_timeout 60s | 7 días |

### BDs incluidas con criticidad

| BD | Criticidad | Contenido |
|---|---|---|
| keycloak_db | MÁXIMA | Realms, usuarios, roles, SPIs |
| tryton_db | MÁXIMA | ERP, facturas, inventario, contabilidad |
| bkernel_db | ALTA | LSN checkpoints, audit_events, crossref |
| biedata_db | ALTA | Integraciones tributarias, comprobantes |
| orangehrm_db | ALTA | Empleados, contratos, estructura org |
| saleor_db | ALTA | Catálogo, órdenes, clientes e-commerce |
| bcompass_db | MEDIA | Estado rutas, historial ejecuciones |

Nota: bkernel_db contiene tabla checkpoint con último LSN. Sin ella, bKernel no puede determinar punto de reanudación.

Credenciales MinIO vía Vault. Rotación cada 90 días.

## 4. RK-012 — Restore Completo y PITR

### Escenario A — Restore completo (S01 destruido)

**Paso 1 (T+0→T+10):** Preparar nuevo S01 (Ubuntu 26.04 + PostgreSQL 17 + pgBackRest). Limpiar directorio datos.

**Paso 2 (T+10→T+20):** `pgbackrest --stanza=sbos restore`. Iniciar PostgreSQL. Verificar pg_isready.

**Paso 3 CRÍTICO (T+20→T+25):** Verificar y recrear slots de replicación lógica:
```sql
SELECT slot_name, plugin, active FROM pg_replication_slots;
-- Si faltan:
SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_orangehrm', 'pgoutput');
-- Un slot por BD que bKernel monitorea (ver bkernel.toml)
```

**Paso 4 (T+25→T+27):** Reiniciar bKernel. Verificar WAL lag < 500ms en Grafana.

**Paso 5 (T+27→T+30):** Reiniciar Keycloak. Verificar OIDC endpoint.

**Paso 6 (T+30→T+45):** Verificar Kong, Tryton, apps críticas.

### Script validación post-restore (7 checks)
```bash
sbos-restore-validate.sh:
✅ PostgreSQL operativo (pg_isready)
✅ Slots replicación presentes (pgoutput)
✅ bkernel_db checkpoint presente
✅ Realms Keycloak presentes
✅ bKernel daemon activo
✅ Keycloak OIDC operativo
✅ Tryton operativo
→ 7/7 PASS = RESTORE EXITOSO
→ <7 PASS = RESTORE INCOMPLETO — revisar antes de notificar cliente
```

### PITR (Point-In-Time Recovery)
```bash
pgbackrest --stanza=sbos restore \
  --target="2026-03-03 14:29:59" \
  --target-action=promote \
  --target-exclusive=y
# Post-PITR: recrear slots igual que Paso 3
```

## 5. RK-013 — Simulacro Semestral DR

Frecuencia: cada 6 meses (marzo/septiembre). Ambiente: STAGING únicamente. Duración: 90 min.

### 6 Fases del simulacro

```
FASE 1 — ESTADO INICIAL: Registrar versión PG, BDs, slots, último LSN. INICIO CRONÓMETRO.
FASE 2 — DESTRUCCIÓN: Stop bKernel → stop PG → rm -rf data/*. Verificar pg_isready falla.
FASE 3 — RESTORE PG: pgbackrest restore → start PG → pg_isready OK. REGISTRAR RTO PG (objetivo: 15 min).
FASE 4 — SLOTS + BKERNEL: Verificar/recrear slots → start bKernel → WAL lag < 500ms.
FASE 5 — KEYCLOAK + APPS: Restart KC → OIDC OK → login prueba → Tryton → script validación 7/7.
FASE 6 — MEDICIÓN: FIN CRONÓMETRO. RTO sistema (objetivo: 60 min). Comparar registros pre/post.
```

### Template registro post-simulacro
```
Fecha: ___  Ejecutor: ___  Observador: ___
RTO PostgreSQL:    ___ min (objetivo 15) → PASS/FAIL
RTO Sistema:       ___ min (objetivo 60) → PASS/FAIL
Slots recreados:   PASS/FAIL
bKernel lag <500ms: PASS/FAIL
Script validación: ___/7 PASS
DECISIÓN SLA: □ CONFIRMADOS  □ REQUIERE AJUSTE → nuevo RTO: ___
Acciones correctivas: ___
Próximo simulacro: ___
```

## 6. RTO/RPO por Escenario

| Escenario | Descripción | RTO | RPO | Runbook | Manual |
|---|---|---|---|---|---|
| E-01 | Fallo S01 completo | 15m PG / 60m sistema | 15 min | RK-012 | Sí (slots) |
| E-02 | Corrupción parcial tabla | 30 min | Depende timestamp | RK-012 PITR | Sí (timestamp) |
| E-03 | bKernel crash | < 5 min (auto) | 0 (retoma desde LSN) | RK-003 | No (systemd) |
| E-04 | Slot invalidado | 15 min | 0 (gap sync, no pérdida) | RK-012 §3 | Sí (recrear) |
| E-05 | IAM Installer pierde estado | 30 min | 0 (reconstruye) | RK-008 | No (auto) |

## 7. Alertas Backup en Alertmanager

```yaml
- name: sbos.backup
  rules:
    - alert: pgBackRestBackupFailed
      expr: pgbackrest_backup_error == 1
      labels: { severity: critical, runbook: RK-011 }
    - alert: pgBackRestBackupStale
      expr: (time() - pgbackrest_backup_timestamp_last_full) > 86400 * 8
      labels: { severity: high, runbook: RK-011 }
    - alert: WALSlotReplicationLag
      expr: pg_replication_slots_pg_wal_lsn_diff > 1073741824
      for: 10m
      labels: { severity: high, runbook: RK-012 }
```

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1-2 | SBOS-026 v1.0 | §1-§2 (propósito, riesgo slots, topología con diagrama) |
| §3 RK-011 | SBOS-026 v1.0 | §3 completo (pgBackRest config, política, BDs, verificación, Vault) |
| §4 RK-012 | SBOS-026 v1.0 | §4 completo (6 pasos restore, script validación 7 checks, PITR) |
| §5 RK-013 | SBOS-026 v1.0 | §5 completo (6 fases simulacro, template registro) |
| §6 RTO/RPO | SBOS-026 v1.0 | §6 (tabla 5 escenarios) |
| §7 Alertas | SBOS-026 v1.0 | §7 (YAML 3 reglas: failed, stale, slot lag) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-033-BACKUP-DR

## V5 — Enriquecimiento desde BOS_V5_SBOS-026-BackupRestoreDR-v1_0

### V5 §1 — Instalación y Configuración Detallada de pgBackRest

**Instalación en opsserver:**
```bash
# Ubuntu 26.04
sudo apt install -y pgbackrest
# Verificar instalación
pgbackrest version
# Configurar stanza
sudo mkdir -p /etc/pgbackrest
sudo nano /etc/pgbackrest/pgbackrest.conf
# Verificar configuración
pgbackrest check --stanza=sbos
```

**Verificación de cada componente del backup:**
```
1. pgBackRest instalado y configurado → pgbackrest version
2. Stanza sbos configurada → pgbackrest check
3. MinIO endpoint reachable → curl http://minio.dataserver:9000
4. Permisos bucket sbos-pgbackup → mc ls sbos-pgbackup/
5. WAL archiving activo → pg_stat_archiver
6. Archive command no falla → pg_stat_archiver.failed_count = 0
7. Backup completo programable → sudo pgbackrest --stanza=sbos --type=full backup
```

### V5 §2 — Procedimiento Detallado de Restore (PITR)

**Restore a un punto en el tiempo específico:**
```bash
# 1. Identificar timestamp objetivo
# 2. Detener la base de datos
sudo systemctl stop postgresql

# 3. Limpiar el directorio de datos actual
sudo rm -rf /var/lib/postgresql/17/main/*

# 4. Ejecutar PITR restore
sudo pgbackrest --stanza=sbos restore \
  --target="2026-03-03 14:29:59.123456-04" \
  --target-action=promote \
  --target-exclusive=y \
  --type=time

# 5. Iniciar PostgreSQL
sudo systemctl start postgresql

# 6. Verificar que la BD está en el estado correcto
sudo -u postgres psql -c "SELECT pg_is_in_recovery();"
# Respuesta esperada: "f" (no en recovery, promovido correctamente)

# 7. Verificar datos
sudo -u postgres psql -d tryton_db -c "SELECT count(*) FROM account_invoice;"
```

**Restore a una transacción específica (target-xid):**
```bash
sudo pgbackrest --stanza=sbos restore \
  --target-xid=12345678 \
  --target-action=promote
```

**Restore a un punto nominal:**
```bash
sudo pgbackrest --stanza=sbos restore \
  --target-name="before_schema_change" \
  --target-action=promote
```

### V5 §3 — Simulacro DR Expandido (14 pasos)

El simulacro de V6 (6 fases) se expande con pasos detallados y 7 criterios de éxito:

**Ejecución del simulacro (14 pasos):**
```
PRE-SIMULACRO (día anterior):
  1. Designar ejecutor y observador
  2. Configurar cronómetro (inicia en FASE 1)
  3. Registrar versión PostgreSQL, BDs, slots, último LSN
  4. Preparar template de registro

FASE SIMULACRO (90 min):
  5. INICIO: stop bKernel → stop PostgreSQL → rm -rf data/*
  6. Verificar: pg_isready falla (confirmar destrucción)
  7. pgbackrest restore
  8. Iniciar PostgreSQL
  9. pg_isready OK → REGISTRAR RTO PG
  10. Verificar slots de replicación (recrear si faltan)
  11. Iniciar bKernel (systemctl start bkernel)
  12. Verificar WAL lag < 500ms
  13. Iniciar Keycloak → OIDC OK → login prueba
  14. Ejecutar script validación 7/7

POST-SIMULACRO:
  COMPLETAR template de registro
  FIRMAR DECISIÓN SLA
  Archivar en DOCUMENTO-IMPLEMENTACION.md
```

**Criterios de éxito del simulacro (7 checks):**
```
1. RTO PostgreSQL ≤ 15 min
2. RTO Sistema ≤ 60 min
3. Recreación de slots exitosa (sin errores)
4. bKernel operativo con lag WAL < 500ms
5. Keycloak operativo (well-known 200)
6. Login de prueba exitoso en Tryton
7. Sin data loss detectado (RPO confirmado)
```

### V5 §4 — Data Breach Notification (Requisito Normativo)

**Marco regulatorio para notificación de brechas:**
- Bolivia: Ley de Protección de Datos Personales (anteproyecto AGETIC) — requiere notificación a autoridad en < 72 horas
- Argentina: Ley 25.326 — notificación a la AAIP en < 48 horas
- México: LFPDPPP — notificación al propietario de los datos en < 72 horas
- Colombia: Ley 1581 — notificación a la SIC en < 72 horas
- España/EU: GDPR — notificación a la AEPD en < 72 horas

**Derechos ARCO:** Todo titular de datos puede ejercer Acceso, Rectificación, Cancelación y Oposición. bKernel y SmartORC exponen endpoints para gestionar solicitudes ARCO.

---

## Smart* — Enriquecimiento desde Subproyectos SBOS

### SmartVault — SBOS-VAULT-009-OPERACION

**Política de backup de bvault_db (en clúster Patroni de SBOS):**
| Tipo | Frecuencia | Retención |
|---|---|---|
| Full backup | Semanal (domingos 00:00 UTC) | 4 semanas |
| Incremental | Diario (02:00 UTC) | 7 días |
| WAL archiving (PITR) | Continuo | 7 días |

**Procedimiento de restauración de bvault:**
1. Failover de nodo: Patroni detecta caída y promueve réplica en < 30s automáticamente
2. Corrupción de datos: PITR con pgBackRest — restaurar bvault_db al punto anterior al error
3. Pérdida total del dataserver: Restaurar desde backup full + WAL al nuevo nodo

**Backup de archivos en Nextcloud:**
| Tipo | Frecuencia | Retención |
|---|---|---|
| Backup del almacenamiento | Diario | 30 días (snapshot + rsync) |
| Archivos de cold archive | Sin backup adicional | Indefinido |

**Integridad de activos:** bvault detecta pérdida de archivos en el job de verificación de integridad. Si se restaura el archivo correcto desde backup de Nextcloud, el SHA-256 debe coincidir con `vault_assets.file_hash` para que el activo vuelva a `integrity_ok = true`.

### SmartReport — SBOS-REPORT-009-OPERACION

**Backup de smartreport_db:** pgBackRest del ecosistema SBOS (automático). RTO < 2 horas, RPO < 5 minutos.

**Backup del árbol de plantillas (3 niveles):**
- Nivel 1 — Git: archivos `.jrxml` fuente (los `.jasper` son regenerables)
- Nivel 2 — rsync diario del árbol completo (> `.jrxml` + `.jasper` + `_sub/`). Retención: 90 días
- Nivel 3 — Snapshot del PVC via Velero (restauración point-in-time)

**Política de retención del log (GAP-09 resuelto con pg_partman):**
| Etapa | Duración | Acceso |
|---|---|---|
| HOT | 0-36 meses | Via API de auditoría |
| COLD | 37-60 meses | Query directa a `ejecucion_archivo.log_YYYY_MM` |
| DROP | > 60 meses | Eliminado |

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-033-BACKUP-DR.md` | Documento completo (198 líneas) |
| V5 Backup/DR | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-026-BackupRestoreDR-v1_0.md` | §1 Instalación pgBackRest, §2 Verificación componentes, §3 PITR detallado (target-time, target-xid, target-name), §4 Restore validation script |
| V5 DR Simulacro | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-026-SIM-Simulacro-DR-v1_0.md` | §1 14-step execution checklist, §2 Template registro, §3 Criterios de éxito 7 checks |
| V5 Data Breach | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-023-DataBreachNotification.md` | Marco regulatorio Bolivia/Argentina/México/Colombia/España, Derechos ARCO |
| SmartVault Operación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Vault Flow/context/SBOS-VAULT-009-OPERACION.md` | Backup bvault_db, restauración 3 escenarios, backup Nextcloud, integridad de activos |
| SmartReport Operación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Report/context/SBOS-REPORT-009-OPERACION.md` | Backup plantillas 3 niveles, pg_partman retención 3 etapas |

---

_SKULL · SBOS · SBOS-033-BACKUP-DR · V8 (V6+V5+Smart*) · Mayo 2026_
