# SBOS-026-SIM — Plan de Ejecución del Simulacro de Disaster Recovery
## Template de Registro Post-Simulacro · Ambiente Staging

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-026-SIM (sección complementaria de SBOS-026)
**Versión:** 1.0
**Complementa:** SBOS-026-BackupRestoreDR-v1_0.md (checklist operativo del simulacro DR semestral)
**Estado:** ACTIVO
**Clasificación:** Runbook Operacional — DR
**Depende de:** SBOS-026 (RK-011, RK-012), SBOS-024 (SLAs), SBOS-016 (orden de fases)

---

## PARTE 1 — Plan de Ejecución del Simulacro

### Propósito

Verificar que el proceso de restore documentado en SBOS-026 RK-012 permite recuperar el sistema completo dentro de los SLAs contractuales:

- **RTO PostgreSQL:** ≤ 15 minutos
- **RTO Sistema completo:** ≤ 60 minutos
- **RPO:** ≤ 15 minutos de datos (frecuencia de backup diferencial)

Este simulacro ejecuta el procedimiento real — no una simulación parcial. Al finalizar, el sistema debe estar operativo con datos consistentes.

### Alcance

| Incluido | Excluido |
|----------|----------|
| Destrucción y restore del dataserver (S01) | Servidores de aplicaciones (S04-S13) |
| Recreación de slots de replicación WAL | Backup del sistema operativo del host |
| Reinicio del daemon bKernel | Migración de datos entre servidores |
| Verificación de Keycloak post-restore | Escenarios de fallo de red |
| Medición de RTO real contra SLA | Pruebas de rendimiento |

### Participantes requeridos

| Rol | Responsabilidad durante el simulacro |
|-----|-------------------------------------|
| **SRE Lead (Ejecutor)** | Ejecuta todos los comandos. Comunica cada paso al observador. |
| **DevOps (Observador)** | Lleva el cronómetro oficial. Registra tiempos en la hoja de registro. No interviene salvo que el ejecutor quede bloqueado. |

**Quórum mínimo:** 2 personas. No ejecutar el simulacro con menos de 2 participantes.

### Pre-requisitos (verificar 30 minutos antes)

```bash
# 1. Confirmar que el último backup de staging está disponible y es reciente
pgbackrest --stanza=sbos info | grep "backup type"
# Esperado: debe haber al menos un backup diferencial de las últimas 24h

# 2. Confirmar que el WAL se está archivando
pgbackrest --stanza=sbos check
# Esperado: "check command end: completed successfully"

# 3. Confirmar credenciales activas
vault kv get secret/pgbackrest/minio | head -5
# Esperado: las credenciales no están expiradas

# 4. Confirmar que el IAM Installer está disponible
systemctl status iam-installer | grep "Active:"
# Esperado: active (running)

# 5. Anotar el estado inicial de staging
sudo -u postgres psql -c "SELECT count(*) FROM pg_replication_slots WHERE plugin='pgoutput';"
# Guardar este número como referencia post-restore
```

---

### Checklist de ejecución — 14 pasos

**Leyenda:** ✓ = completado con éxito · ✗ = fallido (registrar en desviaciones) · T = timestamp

---

#### FASE 0 — Estado inicial (T+00)

```
T inicio: ___________

[ ] Paso 1: Registrar estado pre-simulacro
    Versión PostgreSQL en staging:    ___________
    Número de BDs presentes:          ___________
    Número de slots de replicación:   ___________
    Último LSN en bkernel_db:

    sudo -u postgres psql -d bkernel_db \
      -c "SELECT lsn FROM checkpoint ORDER BY updated_at DESC LIMIT 1;"
    LSN registrado: ___________

    Conteo de registros en tryton_db.account_move (referencia):
    sudo -u postgres psql -d tryton_db -c "SELECT count(*) FROM account_move;"
    Conteo pre: ___________
```

#### FASE 1 — Destrucción controlada (T+05)

```
[ ] Paso 2: Detener daemons soberanos
    sudo systemctl stop bkernel biedata bcompass
    Verificar: systemctl is-active bkernel → "inactive"
    T detención daemons: ___________

[ ] Paso 3: Detener PostgreSQL
    sudo systemctl stop postgresql
    T detención PostgreSQL: ___________

[ ] Paso 4: Destruir datos (simular fallo catastrófico del disco)
    sudo rm -rf /var/lib/postgresql/17/main/*
    Verificar que el directorio está vacío:
    ls /var/lib/postgresql/17/main/ | wc -l → debe ser 0
    T destrucción: ___________

[ ] Paso 5: Confirmar que PostgreSQL no responde
    pg_isready -U postgres → debe devolver error/refused
    T confirmación de fallo: ___________

    ⏱ INICIO CRONÓMETRO RTO POSTGRESQL: ___________
```

#### FASE 2 — Restore PostgreSQL (T+10 a T+25)

```
[ ] Paso 6: Ejecutar restore con pgBackRest
    sudo -u postgres pgbackrest --stanza=sbos restore
    (Este comando puede tardar 5-15 minutos según el tamaño de la BD)
    T inicio restore: ___________
    T fin restore:    ___________

[ ] Paso 7: Iniciar PostgreSQL
    sudo systemctl start postgresql
    sudo -u postgres pg_isready
    T PostgreSQL operativo: ___________

    ⏱ FIN CRONÓMETRO RTO POSTGRESQL: ___________
    RTO PostgreSQL medido: ___________ (objetivo: ≤ 15 min)
    RESULTADO: PASS [ ]  FAIL [ ]
```

#### FASE 3 — Slots de replicación (T+25 a T+30)

```
[ ] Paso 8: Verificar slots de replicación post-restore
    sudo -u postgres psql -c \
      "SELECT slot_name, plugin FROM pg_replication_slots WHERE plugin='pgoutput';"
    Número de slots post-restore: ___________
    Número de slots pre-restore (de Paso 1): ___________
    ¿Son iguales? SÍ [ ]  NO [ ]

    Si NO son iguales — recrear los slots faltantes:
    sudo -u postgres psql << 'EOF'
    SELECT pg_create_logical_replication_slot('bkernel_tryton', 'pgoutput');
    SELECT pg_create_logical_replication_slot('bkernel_orangehrm', 'pgoutput');
    SELECT pg_create_logical_replication_slot('bkernel_saleor', 'pgoutput');
    -- agregar los que falten según /etc/bos/blibs/bkernel/bkernel.toml
    EOF
    T slots verificados/recreados: ___________
```

#### FASE 4 — Daemons soberanos (T+30 a T+40)

```
[ ] Paso 9: Reiniciar bKernel
    sudo systemctl start bkernel
    sudo systemctl status bkernel | grep "Active:"
    Esperado: "active (running)"
    T bKernel activo: ___________

[ ] Paso 10: Verificar que el bKernel retomó desde el LSN correcto
    sudo journalctl -u bkernel -n 20 | grep "LSN\|checkpoint\|resuming"
    (Debe mostrar que arrancó desde el LSN checkpointado en bkernel_db)
    ¿El log muestra reanudación desde LSN? SÍ [ ]  NO [ ]

[ ] Paso 11: Esperar 2 minutos y verificar lag WAL
    sleep 120
    # En Grafana: panel "bKernel WAL lag"
    # O via Prometheus:
    curl -s http://prometheus:9090/api/v1/query \
      --data 'query=bkernel_wal_lag_seconds' | python3 -m json.tool
    Lag medido: ___________s (objetivo: < 0.5s)
    RESULTADO: PASS [ ]  FAIL [ ]

[ ] Paso 12: Reiniciar SBOS Data Integration y SBOS AI Tools
    sudo systemctl start biedata bcompass
    systemctl is-active biedata bcompass
    Esperado: "active active"
    T daemons activos: ___________
```

#### FASE 5 — Keycloak y aplicaciones (T+40 a T+55)

```
[ ] Paso 13: Reiniciar Keycloak y verificar
    kubectl rollout restart deployment/keycloak -n keycloak
    kubectl rollout status deployment/keycloak -n keycloak
    (Esperar a que el rollout complete)

    Verificar OIDC:
    curl -sf https://bos.staging.local/realms/master/.well-known/openid-configuration \
      | python3 -m json.tool | head -5
    ¿Keycloak responde? SÍ [ ]  NO [ ]
    T Keycloak operativo: ___________

[ ] Paso 14: Ejecutar script de validación
    /usr/local/bin/sbos-restore-validate.sh
    Resultado: ___ / 7 checks PASS
    Todos PASS: SÍ [ ]  NO [ ]

    ⏱ FIN CRONÓMETRO RTO SISTEMA COMPLETO
    T fin: ___________
    RTO Sistema medido: ___________ (objetivo: ≤ 60 min)
    RESULTADO: PASS [ ]  FAIL [ ]
```

---

### Criterios de éxito del simulacro

| Criterio | Objetivo | Resultado | Estado |
|----------|---------|-----------|--------|
| RTO PostgreSQL | ≤ 15 min | | PASS / FAIL |
| RTO Sistema completo | ≤ 60 min | | PASS / FAIL |
| Slots de replicación correctos | = pre-restore | | PASS / FAIL |
| bKernel lag < 500ms | < 500ms | | PASS / FAIL |
| Keycloak OIDC operativo | HTTP 200 | | PASS / FAIL |
| Script validación 7 checks | 7 / 7 | | PASS / FAIL |
| Cero pérdida de datos (conteo) | = pre-restore | | PASS / FAIL |

**Criterio de simulacro EXITOSO:** todos los 7 criterios en estado PASS.

---

## PARTE 2 — Template de Registro Post-Simulacro

```
╔══════════════════════════════════════════════════════════════════╗
║         REGISTRO OFICIAL DE SIMULACRO DR — SBOS               ║
╠══════════════════════════════════════════════════════════════════╣
║ Fecha:          _______________   Número simulacro: DR-____     ║
║ Ambiente:       staging                                         ║
║ Ejecutor:       _______________   Firma: ___________________    ║
║ Observador:     _______________   Firma: ___________________    ║
╠══════════════════════════════════════════════════════════════════╣
║                         TIEMPOS                                 ║
╠═══════════════════════════════╦═════════╦═════════╦════════════╣
║ Fase                          ║Objetivo ║  Real   ║  Estado    ║
╠═══════════════════════════════╬═════════╬═════════╬════════════╣
║ RTO PostgreSQL                ║ 15 min  ║         ║ PASS/FAIL  ║
║ RTO Sistema completo          ║ 60 min  ║         ║ PASS/FAIL  ║
║ Slots replicación correctos   ║ = pre   ║         ║ PASS/FAIL  ║
║ bKernel lag                   ║ <500ms  ║         ║ PASS/FAIL  ║
║ Keycloak OIDC operativo       ║ HTTP200 ║         ║ PASS/FAIL  ║
║ Script validación (7 checks)  ║  7/7    ║   /7    ║ PASS/FAIL  ║
║ Cero pérdida de datos         ║ 0 diff  ║         ║ PASS/FAIL  ║
╠═══════════════════════════════╩═════════╩═════════╩════════════╣
║                    DECISIÓN SOBRE SLAs                          ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ [ ] SLAs CONFIRMADOS                                            ║
║     RTO PostgreSQL 15 min y sistema 60 min son alcanzables.     ║
║     Los SLAs de SBOS-024 §3 se mantienen sin cambios.          ║
║                                                                  ║
║ [ ] SLA REQUIERE AJUSTE                                         ║
║     RTO real PostgreSQL fue: _______                            ║
║     RTO real sistema fue:    _______                            ║
║     SLA ajustado propuesto:  _______                            ║
║     Motivo del ajuste: _____________________________            ║
║     Aprobar ajuste en próxima reunión ARB: Fecha ___            ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║                  DESVIACIONES DEL PROCEDIMIENTO                 ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ 1. ____________________________________________________________  ║
║ 2. ____________________________________________________________  ║
║ 3. ____________________________________________________________  ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║              ACCIONES CORRECTIVAS IDENTIFICADAS                 ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ Acción 1: _____________________ Responsable: ______ Fecha: ____ ║
║ Acción 2: _____________________ Responsable: ______ Fecha: ____ ║
║ Acción 3: _____________________ Responsable: ______ Fecha: ____ ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║                     EVIDENCIA ADJUNTA                           ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ [ ] Output de pgbackrest --stanza=sbos info (post-restore)     ║
║ [ ] Output de pg_replication_slots query (post-restore)         ║
║ [ ] Output de /usr/local/bin/sbos-restore-validate.sh          ║
║ [ ] Captura del panel "bKernel WAL lag" de Grafana              ║
║ [ ] Log de bKernel mostrando reanudación desde LSN              ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║                    PRÓXIMA FECHA DE SIMULACRO                   ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ Fecha próximo simulacro: _______________                        ║
║ (Frecuencia: semestral — marzo y septiembre)                    ║
║ Responsable de agendar: _______________                         ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Historial de simulacros

| # | Fecha | RTO PG | RTO Sistema | Resultado | Ajuste SLA |
|---|-------|--------|-------------|-----------|-----------|
| DR-001 | | | | | |
| DR-002 | | | | | |
| DR-003 | | | | | |

---

*SKULL · SBOS · SBOS-026-SIM · v1.0 · Marzo 2026*
*Runbook RK-013 — complementa SBOS-026 (RK-011, RK-012)*
