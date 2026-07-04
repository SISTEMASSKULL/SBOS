# SBOS-022-PGMIG — Plan de Migración de Versión Mayor de PostgreSQL
## Sección para insertar en SBOS-022 (Bounded Contexts)

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-022-PGMIG (sección nueva de SBOS-022)
**Versión:** 1.0
**Estado:** ACTIVO
**Clasificación:** Proceso Operacional — Migración de Infraestructura
**Complementa:** SBOS-022-BoundedContexts-v1_0.md (§nueva Plan de Migración PostgreSQL Mayor)
**Insertar en:** SBOS-022 como nueva sección §nueva

---

## Plan de Migración de Versión Mayor de PostgreSQL para el WAL EventBus de SBOS

### Por qué la migración de PostgreSQL es más compleja en SBOS

En un deployment convencional de PostgreSQL, una migración de versión mayor es una operación de infraestructura estándar: backup, pg_upgrade, verify, done. En SBOS, esta operación tiene un riesgo específico que no existe en otros sistemas.

**El riesgo único de SBOS:** los slots de replicación lógica (`pgoutput`) **no son migrados por `pg_upgrade`**. Después de una migración con `pg_upgrade`, los slots desaparecen. El bKernel no puede reconectarse al WAL hasta que los slots sean recreados manualmente. Si nadie sabe que esto debe hacerse, el sistema parece operar normalmente (PostgreSQL funciona, las apps responden) pero el EventBus está silenciosamente inoperativo.

### Versión actual y política de versiones

| Ítem | Valor |
|------|-------|
| **Versión actual en SBOS** | PostgreSQL 17 (declarada en ficha de postgresql en S01) |
| **Próxima migración prevista** | PostgreSQL 17 → 18 (cuando PG 18 sea estable) |
| **Versión mínima soportada** | PostgreSQL 15 (replicación lógica estable con pgoutput desde PG 15) |
| **Frecuencia de versiones mayores** | Cada ~1 año (política de PostgreSQL) |
| **Actualizaciones menores** | Automáticas via Patroni (17.1 → 17.2, etc.) — no requieren este proceso |

### Análisis de riesgos específicos de SBOS

#### Riesgo 1 — Slots de replicación lógica no migrados (CRÍTICO)

**Mecanismo:** `pg_upgrade` copia los archivos de datos de PostgreSQL de la versión anterior a la nueva. Los slots de replicación lógica son metadatos del sistema de replicación, no datos de usuario, y `pg_upgrade` no los migra en versiones con cambios de formato de WAL.

**Impacto sin mitigación:** el bKernel arranca post-migración, intenta conectarse al slot `bkernel_tryton`, recibe error "slot does not exist", y entra en loop de error. El EventBus cesa. Ningún dato se propaga entre bounded contexts.

**Mitigación:** recrear todos los slots inmediatamente post-migración (Paso 4 del proceso de migración).

**Verificación:** `SELECT count(*) FROM pg_replication_slots WHERE plugin='pgoutput'` debe devolver el mismo número que pre-migración.

#### Riesgo 2 — Cambios de protocolo WAL en nueva versión mayor

**Mecanismo:** el protocolo `pgoutput` (formato de los mensajes del WAL de replicación lógica) puede tener cambios entre versiones mayores de PostgreSQL. Si el bKernel usa una versión del protocolo que la nueva PG no soporta, la conexión se establece pero los mensajes son mal interpretados.

**Mitigación:** probar el bKernel en staging con la nueva versión de PostgreSQL antes de migrar producción. El criterio de go es que `bkernel_wal_lag_seconds` baje a < 500ms en staging con la nueva versión.

#### Riesgo 3 — Tiempo de pg_upgrade en bases de datos de SBOS

**Mecanismo:** `pg_upgrade --link` (modo hard-link, el más rápido) puede migrar incluso bases de datos grandes en pocos minutos. El modo estándar (copia) tarda proporcional al tamaño de los datos.

**Recomendación:** usar `pg_upgrade --link` para minimizar el tiempo de ventana de mantenimiento.

#### Riesgo 4 — Compatibilidad de pgBackRest con la nueva versión

**Verificación obligatoria:** antes de migrar, confirmar que la versión instalada de pgBackRest soporta la nueva versión de PostgreSQL. pgBackRest tiene una tabla de compatibilidad de versiones en su documentación oficial.

```bash
# Verificar compatibilidad de pgBackRest con la nueva versión objetivo
pgbackrest version
# Comparar con la matriz de compatibilidad de pgBackRest para PG-{nueva-versión}
```

---

### Proceso de migración en 4 pasos con criterios go/no-go

#### Paso 1 — Validación obligatoria en staging (NO saltar)

**Duración estimada:** 4-8 horas
**Quién ejecuta:** DBA + Arquitecto Lead

```bash
# En el servidor staging (réplica de producción)

# 1.1 Instalar la nueva versión de PostgreSQL junto a la actual
sudo apt install postgresql-18    # o la versión objetivo

# 1.2 Ejecutar pg_upgrade en staging
sudo systemctl stop postgresql@17
sudo -u postgres pg_upgrade \
  --old-datadir=/var/lib/postgresql/17/main \
  --new-datadir=/var/lib/postgresql/18/main \
  --old-bindir=/usr/lib/postgresql/17/bin \
  --new-bindir=/usr/lib/postgresql/18/bin \
  --link                    # Modo hard-link: migración rápida
  --check                   # Primero solo verificar, sin migrar

# Si --check pasa sin errores: ejecutar sin --check
sudo -u postgres pg_upgrade \
  --old-datadir=/var/lib/postgresql/17/main \
  --new-datadir=/var/lib/postgresql/18/main \
  --old-bindir=/usr/lib/postgresql/17/bin \
  --new-bindir=/usr/lib/postgresql/18/bin \
  --link

# 1.3 Iniciar PostgreSQL 18 en staging
sudo systemctl start postgresql@18

# 1.4 PASO CRÍTICO: Recrear los slots de replicación lógica
sudo -u postgres psql -c "
SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_orangehrm', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_saleor', 'pgoutput');
-- Recrear todos los slots (ver /etc/bos/blibs/bkernel/bkernel.toml para la lista completa)
"

# 1.5 Reiniciar el bKernel en staging
sudo systemctl restart bkernel
sleep 120    # Esperar 2 minutos

# 1.6 Verificar que el bKernel está procesando correctamente
sudo journalctl -u bkernel -n 20 | grep -i "lag\|error\|slot"
# Verificar en Grafana: bkernel_wal_lag_seconds < 500ms

# 1.7 Ejecutar la suite de tests de integración
cd iam-installer && make test-integration
```

**Criterio GO para Paso 1:**
- `bkernel_wal_lag_seconds < 0.5` sostenido por > 5 minutos en staging
- Tests de integración: todos pasan
- Ningún error en logs de bKernel relacionado con slots o protocolo WAL

**Si NO-GO:** detener el proceso. Investigar el fallo antes de proceder a producción.

---

#### Paso 2 — Backup completo pre-migración en producción

**Ejecutar inmediatamente antes de la ventana de mantenimiento:**

```bash
# Desde S14 (opsserver) — backup completo de producción
pgbackrest --stanza=sbos --type=full backup \
  --log-level-console=detail

# Verificar que el backup completó exitosamente
pgbackrest --stanza=sbos info | grep "backup type: full"

# NO proceder si el backup no completó exitosamente
```

**Criterio GO para Paso 2:** `pgbackrest info` muestra backup completo con timestamp < 30 minutos antes de iniciar la ventana de mantenimiento.

---

#### Paso 3 — pg_upgrade en producción con ventana de mantenimiento

**Comunicación previa:** notificar al cliente la ventana de mantenimiento con al menos 48 horas de antelación.

**Duración estimada de la ventana:** 30-90 minutos (según tamaño de las BDs).

```bash
# T-00: Inicio de ventana de mantenimiento
# Notificar en el Core UI: "Sistema en mantenimiento — X minutos"

# T+05: Detener todas las apps del stack (via IAM Installer)
sudo systemctl stop iam-installer
kubectl scale --replicas=0 deployment --all -n erpserver
kubectl scale --replicas=0 deployment --all -n identityserver
# ... detener todos los workloads que escriben en PostgreSQL

# T+10: Detener los daemons soberanos
sudo systemctl stop bkernel biedata bcompass

# T+15: Detener PostgreSQL (Patroni gestionará el failover)
sudo patronictl pause
sudo systemctl stop postgresql@17

# T+20: Ejecutar pg_upgrade
sudo -u postgres pg_upgrade \
  --old-datadir=/var/lib/postgresql/17/main \
  --new-datadir=/var/lib/postgresql/18/main \
  --old-bindir=/usr/lib/postgresql/17/bin \
  --new-bindir=/usr/lib/postgresql/18/bin \
  --link

# T+35: Iniciar PostgreSQL 18
sudo systemctl start postgresql@18
sudo -u postgres pg_isready

# T+40: Actualizar Patroni para usar PostgreSQL 18
# (ver documentación de Patroni para upgrade procedure)
sudo patronictl resume
```

---

#### Paso 4 — Recrear slots y verificar el bKernel

```bash
# T+45: CRÍTICO — Recrear todos los slots de replicación lógica
sudo -u postgres psql << 'EOF'
-- Slots del bKernel (uno por BD monitoreada)
SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_orangehrm', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_saleor', 'pgoutput');
SELECT pg_create_logical_replication_slot('bkernel_espocrm', 'pgoutput');
-- Agregar todos los slots de /etc/bos/blibs/bkernel/bkernel.toml
EOF

# T+50: Reiniciar daemons soberanos y apps
sudo systemctl start bkernel biedata bcompass
kubectl scale --replicas=1 deployment --all -n erpserver
# ... restaurar todos los workloads

# T+55: Verificar que el bKernel está procesando
sudo journalctl -u bkernel -n 30 | grep -i "lag\|slot\|error"
# bkernel_wal_lag_seconds debe bajar a < 500ms en Grafana

# T+60: Ejecutar script de validación completo
/usr/local/bin/sbos-restore-validate.sh

# T+65: Fin de ventana de mantenimiento — notificar al cliente
```

**Criterio GO para Paso 4 (declarar migración exitosa):**
- `bkernel_wal_lag_seconds < 0.5` por > 5 minutos consecutivos
- `SELECT count(*) FROM pg_replication_slots WHERE plugin='pgoutput'` = mismo número que pre-migración
- Script de validación: 7/7 checks pasan
- Ningún error en logs de bKernel, biedata, bCompass

---

### Política de versiones de PostgreSQL en SBOS

| Ítem | Política |
|------|---------|
| **Versión mínima soportada** | PostgreSQL 15 — primera versión con replicación lógica `pgoutput` completamente estable para el uso del bKernel |
| **Actualizaciones patch** | Automáticas via Patroni (ej: 17.1 → 17.2). Sin ventana de mantenimiento requerida. |
| **Actualizaciones de versión mayor** | Requieren este proceso completo de 4 pasos. Ventana de mantenimiento requerida. RFC en SBOS-025. |
| **Versión declarada en fichas** | La ficha `postgresql` en S01 declara la versión específica. El IAM Installer valida que la versión instalada coincide con la declarada en la ficha. |
| **Soporte de versiones antiguas** | SKULL soporta la versión actual y la inmediatamente anterior. PostgreSQL 15 es EOL en 2027 — migrar a 17 antes de esa fecha. |

---

*SKULL · SBOS · SBOS-022-PGMIG · v1.0 · Marzo 2026*
*Insertar en SBOS-022-BoundedContexts como nueva sección de Infraestructura Compartida*
*Complementa: SBOS-010 (slots de replicación), SBOS-016 (S01 dataserver + Patroni), SBOS-026 (backup pre-migración)*
