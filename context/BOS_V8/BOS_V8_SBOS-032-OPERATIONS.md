# SBOS-032-OPERATIONS
## Libro de Operaciones: SLOs, Alertas y Runbooks — Estándar HUMAN-DOC
### SKULL · SBOS · v1.0 · Abril 2026

---

## 1. Propósito y Marco SRE

La observabilidad sin umbrales es decoración. Este documento define tres cosas que convierten instrumentación en operación accionable: SLOs (umbrales numéricos), reglas Alertmanager (condiciones exactas), y runbooks (pasos para resolver los incidentes más frecuentes).

### Marco SRE adoptado (Google SRE Book + prácticas de industria 2025)

| Concepto | Definición | Ejemplo SBOS |
|---|---|---|
| **SLI** (Service Level Indicator) | Métrica específica y medible del comportamiento del sistema | Latencia P99, tasa errores 5xx, disponibilidad |
| **SLO** (Service Level Objective) | Umbral objetivo para un SLI — el mínimo aceptable para los usuarios | Latencia P99 < 50ms para PostgreSQL OLTP |
| **SLA** (Service Level Agreement) | Compromiso contractual con el cliente — siempre más conservador que SLO | 99.9% disponibilidad mensual del sistema completo |
| **Error Budget** | Margen de incumplimiento permitido: (100% - SLO%) × período | 99.9% = 43.8 min/mes de downtime permitido |
| **Burn Rate** | Velocidad de consumo del error budget. 1x = ritmo esperado. 60x = presupuesto agotado en 1 día | Si burn rate > 14.4x por 1h → alerta crítica |

Según las mejores prácticas SRE para Kubernetes, los SLOs deben enfocarse en user journeys (síntomas, no causas): alertar sobre latencia percibida por el usuario, no sobre CPU del pod. El error budget es el mecanismo que balancea innovación vs estabilidad — cuando se agota, se pausan deployments hasta restaurar la confiabilidad.

## 2. SLOs por Componente

### PostgreSQL — dataserver (criticidad máxima)

| SLI | SLO | Error Budget/mes |
|---|---|---|
| Disponibilidad | > 99.99% | 4.3 min |
| Latencia queries OLTP (P99) | < 50ms | — |
| Latencia queries reporting (P95) | < 5s | — |
| Lag replicación WAL (bKernel P99) | < 500ms | — |
| RTO (Recovery Time) | < 5 minutos | — |

### Keycloak — identityserver

| SLI | SLO | Error Budget/mes |
|---|---|---|
| Disponibilidad | > 99.99% | 4.3 min |
| Latencia autenticación (P99) | < 500ms | — |
| Latencia validación token (P95) | < 50ms | — |
| Tasa errores 5xx | < 0.1% | — |

### bKernel — daemon soberano

| SLI | SLO | Error Budget/mes |
|---|---|---|
| Disponibilidad daemon | > 99.95% | 21.9 min |
| Lag WAL → destino (P99) | < 500ms | — |
| Tamaño Dead Letter Queue | < 10 eventos | — |
| Throughput mínimo | > 1000 eventos/min | — |

### bSearch — búsqueda federada

| SLI | SLO | Error Budget/mes |
|---|---|---|
| Disponibilidad | > 99.9% | 43.8 min |
| Latencia búsqueda (P95) | < 200ms | — |
| Latencia búsqueda (P99) | < 500ms | — |
| Índice actualizado post-evento | < 2s | — |

### Kong API Gateway + Vault + Core UI

| Componente | Disponibilidad SLO | Métrica clave |
|---|---|---|
| Kong | > 99.9% | Latencia overhead P95 < 100ms |
| Vault (unsealed) | > 99.99% | Lectura secreto P95 < 100ms |
| Core UI | > 99.5% | Time to Interactive P95 < 5s |

## 3. SLAs hacia el Cliente

| Componente | SLA disponibilidad | RTO | RPO |
|---|---|---|---|
| Sistema completo | 99.9% mensual | 1 hora | 1 hora |
| Autenticación (KC) | 99.95% mensual | 30 min | 0 (sin pérdida datos) |
| Base de datos (PG) | 99.95% mensual | 15 min | 15 min (frecuencia backup) |
| Apps del stack | 99.5% mensual | 2 horas | 1 hora |

Ventanas mantenimiento: martes/jueves 22:00-02:00 hora local cliente. Emergencia P0: cualquier hora con notificación previa.

## 4. Reglas Alertmanager — Configuración Completa

### Grupo Crítico (respuesta < 15 min, 24/7)

```yaml
groups:
  - name: sbos.critical
    rules:
      - alert: PostgreSQLDown
        expr: up{job="postgresql"} == 0
        for: 30s
        labels: { severity: critical, runbook: RK-001 }
      - alert: KeycloakDown
        expr: up{job="keycloak"} == 0
        for: 60s
        labels: { severity: critical, runbook: RK-002 }
      - alert: bKernelDown
        expr: up{job="bkernel"} == 0
        for: 60s
        labels: { severity: critical, runbook: RK-003 }
      - alert: WALReplicationLagCritical
        expr: bkernel_wal_lag_seconds > 30
        for: 60s
        labels: { severity: critical, runbook: RK-004 }
      - alert: TLSCertificateExpiringSoon
        expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 7
        for: 1h
        labels: { severity: critical, runbook: RK-006 }
      - alert: VaultSealed
        expr: vault_core_unsealed == 0
        for: 30s
        labels: { severity: critical, runbook: RK-010 }
```

### Grupo Alto (respuesta < 1 hora, horario laboral)

```yaml
  - name: sbos.high
    rules:
      - alert: AIServerUnavailable
        expr: up{job="ollama"} == 0
        for: 5m
        labels: { severity: high }
      - alert: bSearchLatencyHigh
        expr: histogram_quantile(0.95, bsearch_query_duration_seconds_bucket) > 0.5
        for: 5m
        labels: { severity: high, runbook: RK-003 }
      - alert: DiskUsageHigh
        expr: (node_filesystem_size_bytes - node_filesystem_free_bytes) / node_filesystem_size_bytes * 100 > 85
        for: 5m
        labels: { severity: high, runbook: RK-005 }
      - alert: PodCrashLoopBackOff
        expr: kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1
        for: 5m
        labels: { severity: high, runbook: RK-007 }
```

### Grupo Medio (respuesta < 4 horas)

```yaml
  - name: sbos.medium
    rules:
      - alert: MemoryUsageHigh
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 90
        for: 5m
        labels: { severity: medium }
```

Enrutamiento: critical → #sbos-alerts-critical (24/7), high → #sbos-alerts-high (horario laboral), medium → #sbos-alerts-all.

## 5. Criterios de Halt del Rollout Canary

| Condición | Umbral | Observación | Acción |
|---|---|---|---|
| Incidente P0 en canary | 1 incidente | Inmediato | Halt + rollback automático |
| Incidentes P1 en canary | 2 incidentes | < 4 horas | Halt + revisión equipo |
| Degradación latencia P95 | > 50% vs versión anterior | > 15 min | Hold automático |
| Error rate endpoints críticos | > 1% | > 5 min | Hold automático |
| Health check fallando | 3 fallos consecutivos | — | Rollback inmediato |
| Memoria > 150% límite | — | > 10 min | Hold automático |

### Etapas del rollout

```
Etapa 0 — Pre-deploy: make validate ✓ + make test-all ✓ + firma Ed25519 ✓
Etapa 1 — Canary 10% (15 min): error rate <1%, latencia P95 <150%, health 200
Etapa 2 — Canary 50% (30 min): + throughput bKernel estable ±10%
Etapa 3 — Full deploy 100% + 15 min observación post-deploy
Rollback en cualquier etapa: < 30 segundos
```

## 6. Dashboard Grafana Operacional

| Panel | Métrica | Tipo | Criticidad |
|---|---|---|---|
| Estado general | Semáforo todos SLOs | Stat R/Y/G | Vista de un vistazo |
| PostgreSQL uptime | up{job="postgresql"} | Gauge 24h | Máxima |
| KC autenticaciones/min | keycloak_logins_total | Time series 2h | Si cae a 0 = nadie entra |
| bKernel lag WAL | bkernel_wal_lag_seconds | Gauge 30s/500ms | Sistema nervioso |
| bKernel DLQ size | bkernel_dlq_size | Stat | Eventos perdidos |
| Disco % por servidor | node_filesystem_used | Bar chart | Disco lleno = destrucción |
| RAM % por servidor | node_memory_MemAvailable | Bar chart | OOM kills silenciosos |
| Pods no-Running | kube_pod_status_phase | Stat | CrashLoop/Pending |
| bSearch latencia P95 | histogram_quantile(0.95) | Gauge 200ms | Visible al usuario |
| Error Budget restante | Cálculo SLO mensual | Gauge % | Margen del mes |

## 7. Runbooks Operacionales

### RK-001 — PostgreSQL Inaccesible (CRITICAL)
**Impacto:** Sistema completo inoperativo. **Diagnóstico:** kubectl get pods → logs → pg_isready → PV/PVC → recursos nodo. **Resolución:** Caso A: OOM → aumentar memory limit + rollout restart. Caso B: disco lleno → RK-005 primero. Caso C: nodo NotReady → drain + reprogramar. Caso D: max_connections → verificar pg_stat_activity + aumentar. **Cierre:** pg_isready = "accepting connections" + alerta resuelta.

### RK-002 — Keycloak Inaccesible (CRITICAL)
**Impacto:** Ningún usuario puede autenticarse (sesiones activas funcionan 5 min). **Diagnóstico:** pods → logs → well-known endpoint → Infinispan cache. **Resolución:** Caso A: PG caída → RK-001 primero + restart KC. Caso B: OOM → aumentar limits. Caso C: daemon standalone → systemctl restart. **Cierre:** well-known retorna 200.

### RK-003 — bKernel Caído (CRITICAL)
**Impacto:** Sincronización datos detenida. Índices bSearch/Qdrant dejan de actualizarse. **Diagnóstico:** systemctl status → journalctl → conexión PG → conexión Redis. **Resolución:** Caso A: detenido → systemctl start. Caso B: config error → verificar bkernel.toml + restaurar desde Release Server. Caso C: DLQ con backlog → XLEN + XRANGE + procesar o limpiar con documentación. **Cierre:** active (running) + WAL lag < 500ms.

### RK-004 — Lag WAL Elevado (CRITICAL)
**Impacto:** Datos no se propagan entre apps con latencia esperada. **Diagnóstico:** lag actual → throughput → consumer groups con lag → recursos servidor. **Resolución:** Caso A: consumer lento → restart servicio consumidor. Caso B: CPU saturado → verificar operación masiva. Caso C: PG I/O saturado → verificar queries lentas pg_stat_activity. **Cierre:** lag < 500ms.

### RK-005 — Disco Lleno (HIGH)
**Impacto:** PG puede corromper datos, logs dejan de escribirse. **Diagnóstico:** df -h → du -sh logs/docker → tablas PG grandes. **Resolución:** Caso A: logs → vacuum-time 7d. Caso B: imágenes → docker system prune. Caso C: PG → VACUUM ANALYZE + limpiar event_entity >90 días. Caso D: emergencia >90% → expandir PVC si StorageClass lo permite. **Cierre:** disco < 80%.

### RK-006 — Certificado TLS Expirando (CRITICAL < 7 días)
**Impacto:** Browsers bloquean acceso HTTPS. **Diagnóstico:** kubectl get certificates → cert-manager logs → ClusterIssuer. **Resolución:** cert-manager no renueva → verificar issuer → forzar renovación manual con kubectl delete certificate + recrear. **Cierre:** certificado renovado + alerta resuelta.

---

## Trazabilidad

| Sección | Extraída de | Secciones originales |
|---|---|---|
| §1 Marco SRE | SBOS-024 v1.0 + investigación web | §1 (conceptos SRE) + Google SRE Book + prácticas industria 2025 |
| §2 SLOs | SBOS-024 v1.0 | §2 completo (7 componentes con SLIs, SLOs, error budgets) |
| §3 SLAs | SBOS-024 v1.0 | §3 (tabla SLA + RTO/RPO + ventanas mantenimiento) |
| §4 Alertmanager | SBOS-024 v1.0 | §4 completo (YAML reglas critical/high/medium + routing) |
| §5 Canary halt | SBOS-024 v1.0 | §5 (tabla criterios + 4 etapas rollout + tiempo rollback) |
| §6 Dashboard | SBOS-024 v1.0 | §6 (10 paneles Grafana con métricas y criticidad) |
| §7 Runbooks | SBOS-024 v1.0 | §7-§12 (RK-001 a RK-006 con diagnóstico, resolución, cierre) |

---

---

# ENRIQUECIMIENTO V8 — SBOS-032-OPERATIONS

## V5 — Enriquecimiento desde BOS_V5_SBOS-024-Operations-v1_0

### V5 §1 — Expansión del Marco SRE con Política de Error Budget

La política de Error Budget determina cuándo el equipo puede hacer deployments vs. cuándo debe estabilizar:

| Burn Rate | Ventana | Acción |
|---|---|---|
| < 1x (ritmo normal) | continua | Deployments sin restricción |
| 1x - 2x | 12 horas | Alertar al equipo on-call |
| 2x - 10x | 6 horas | Pausar deployments no críticos |
| 10x - 60x | 1 hora | Congelar todos los cambios |
| > 60x | 30 min | Rollback inmediato + war room |

**Cálculo automático:** Prometheus calcula burn_rate diaria y la compara con el error budget restante. Si el consumo en 1 hora supera 14.4x (2% del budget mensual en 1 hora), se dispara alerta crítica.

### V5 §2 — Expansión de Reglas Alertmanager (Configuración Completa)

**Reglas adicionales del grupo Critical:**

```yaml
    - alert: ImagePullBackOff
      expr: kube_pod_container_status_waiting_reason{reason="ImagePullBackOff"} == 1
      for: 5m
      labels: { severity: critical, runbook: RK-009 }
    - alert: PersistentVolumeFault
      expr: kube_persistentvolume_status_phase{phase="Failed"} == 1
      for: 2m
      labels: { severity: critical, runbook: RK-013 }
    - alert: ClusterNodeNotReady
      expr: kube_node_status_condition{condition="Ready", status="true"} == 0
      for: 3m
      labels: { severity: critical, runbook: RK-008 }
```

**Reglas adicionales del grupo High:**

```yaml
    - alert: CoreDumpDetected
      expr: node_boot_time_seconds{device="..."}  # correlación con crashes
      for: 2m
      labels: { severity: high, runbook: RK-011 }
    - alert: PodPending
      expr: kube_pod_status_phase{phase="Pending"} > 0
      for: 10m
      labels: { severity: high, runbook: RK-012 }
    - alert: HighCPUUsage
      expr: (100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 90
      for: 10m
      labels: { severity: high }
```

**Routing completo Alertmanager:**

```yaml
route:
  receiver: 'default'
  group_wait: 10s
  group_interval: 2m
  repeat_interval: 4h
  routes:
    - match: { severity: critical }
      receiver: 'pagerduty-critical'
      repeat_interval: 15m
    - match: { severity: high }
      receiver: 'rocketchat-high'
      repeat_interval: 30m
    - match: { severity: medium }
      receiver: 'rocketchat-medium'
      repeat_interval: 2h

receivers:
  - name: 'pagerduty-critical'
    pagerduty_configs:
      - routing_key: '<pd-key>'
        severity: critical
        description: 'SBOS CRITICAL: {{ .GroupLabels.alertname }}'
  - name: 'rocketchat-high'
    rocketchat_configs:
      - alias: 'SBOS-Monitor'
        channel: '#sbos-alerts-high'
        message_color: 'warning'
  - name: 'rocketchat-medium'
    rocketchat_configs:
      - alias: 'SBOS-Monitor'
        channel: '#sbos-alerts-all'
        message_color: 'info'
```

### V5 §3 — Runbooks Expandidos (RK-007 a RK-014)

**RK-007 — Pod CrashLoopBackOff (HIGH)**
**Impacto:** Servicio no disponible. **Diagnóstico:** `kubectl describe pod` → Events → logs del contenedor → resource limits → Liveness/Readiness probes. **Resolución:** Caso A: OOM → aumentar `memory_limit`. Caso B: Liveness probe mal configurada → corregir `periodSeconds` o `initialDelaySeconds`. Caso C: Config error → verificar ConfigMap montado. Caso D: Dependencia caída → verificar servicio upstream. **Cierre:** Pod Running 5/5 + readiness probe OK.

**RK-008 — Nodo K8s No Ready (CRITICAL)**
**Impacto:** Capacidad del cluster reducida, pods no reprogramables. **Diagnóstico:** `kubectl describe node` → Conditions → kubelet logs → disco/CPU/memoria. **Resolución:** Caso A: kubelet stopped → `systemctl restart kubelet`. Caso B: disk pressure → RK-005 + `kubectl cordon`. Caso C: network plugin caído → `kubectl get pods -n kube-system` verificar Calico. **Cierre:** `kubectl wait --for=condition=Ready node/<name>`.

**RK-009 — ImagePullBackOff (CRITICAL)**
**Impacto:** Pod no puede arrancar. **Diagnóstico:** `kubectl describe pod` última condición → ImagePullBackOff → ErrImagePull. **Resolución:** Caso A: imagen no existe → verificar tag. Caso B: registry caído → `curl <registry>/v2/`. Caso C: credenciales registry inválidas → renovar Vault. Caso D: rate limit registry → usar mirror. **Cierre:** Pod corriendo con la imagen correcta.

**RK-010 — Vault Sellado (CRITICAL)**
**Impacto:** Ningún servicio puede leer secretos = sistema detenido. **Diagnóstico:** `vault status` → `vault operator seal-status` → logs Vault. **Resolución:** Obtener al menos 3 de 5 unseal keys del offline storage. `vault operator unseal <key>`. Repetir 3 veces. Verificar: `vault status` → Sealed: false. **Cierre:** Vault unsealed + alerta resuelta.

**RK-011 — Core Dump en Daemon Soberano (HIGH)**
**Impacto:** Daemon caído (bkernel, biedata, bcompass). **Diagnóstico:** Verificar core dump en `/var/lib/systemd/coredump/`. Extraer backtrace con `gdb`. **Resolución:** Caso A: bug conocido → aplicar hotfix de Release Server. Caso B: OOM killer → aumentar memory_limit en service. Caso C: race condition → restart + escalar a equipo de desarrollo. **Cierre:** daemon active (running) + core dump analizado.

**RK-012 — Pod Pending sin Node Assign (HIGH)**
**Impacto:** Servicio no arranca. **Diagnóstico:** `kubectl describe pod` → Events → node selector/affinity → resource requests vs node capacity. **Resolución:** Caso A: recursos insuficientes → escalar nodo o reducir requests. Caso B: taints/tolerations → `kubectl describe nodes \| grep Taints`. Caso C: PVC pending → RK-013. **Cierre:** Pod Running.

**RK-013 — PersistentVolume Fault (CRITICAL)**
**Impacto:** Pérdida potencial de datos. **Diagnóstico:** `kubectl get pv` → Status → `kubectl describe pv`. **Resolución:** Caso A: disco desconectado → verificar iSCSI/NFS. Caso B: StorageClass dinámico caído → verificar provisioner. Caso C: recuperar desde snapshot Velero. **Cierre:** PV Status = Bound.

**RK-014 — Blue/Green Deployment Failure (HIGH)**
**Impacto:** Rollout trabado. **Diagnóstico:** Verificar estado del green stack vs blue. **Resolución:** Caso A: green health checks fallan → abortar + mantener blue. Caso B: tráfico no cambia → verificar Service selector. Caso C: base de datos incompatible → migración backward-compatible no respetada. **Cierre:** Rollout confirmado + monitoreo 15 min.

---

## V5 §4 — Criterios de Canary Rollout Expandidos

### Etapa 0 — Pre-deploy checks
```
[✓] make validate       → sin errores
[✓] make test-all       → 100% tests pasan (unit + integration + contract)
[✓] make lint           → sin warnings
[✓] Firma Ed25519       → artefacto firmado + SBOM generado
[✓] Vulnerability scan  → sin CVEs HIGH/CRITICAL
```

### Etapa 1 — Canary 10% (15 min)
```
Monitoreo continuo:
[✓] Error rate endpoints críticos < 1%
[✓] Latencia P95 < 150% de la versión anterior
[✓] Health check: 200 OK
[✓] No incidentes P0/P1
```

### Etapa 2 — Canary 50% (30 min)
```
[✓] + Throughput bKernel estable ±10%
[✓] + WAL replication lag < 500ms
[✓] + KC auth rate sin degradación
```

### Etapa 3 — Full deploy 100% (15 min observación post-deploy)
```
[✓] Gradiente de error rate normal
[✓] Todos los SLOs en verde
[✓] Alertmanager sin alertas del nuevo deployment
```

**Rollback:** `bosctl rollback <version>` en < 30 segundos. El IAM Installer restaura los manifests de la versión anterior y verifica health checks.

---

## V5 §5 — Dashboard Expandido (PrometheusRules)

Adicionales al dashboard base de V6:

```yaml
# PrometheusRules para alertas compuestas
- alert: ErrorBudgetBurningTooFast
  expr: |
    (
      1 - (
        sum(rate(http_requests_total{status_code=~"5.."}[1h]))
        / sum(rate(http_requests_total[1h]))
      )
    ) < 0.999
  for: 5m
  labels: { severity: critical }
  annotations:
    summary: "Error Budget burning too fast"

- alert: NoNewDataFromPostgreSQL
  expr: rate(pg_stat_database_xact_commit[5m]) < 0.1
  for: 5m
  labels: { severity: critical }
```

---

## Smart* — Enriquecimiento desde Subproyectos SBOS

### SmartVault — SBOS-VAULT-009-OPERACION

**SLA y disponibilidad de bvault:**
| Métrica | Valor |
|---|---|
| SLA objetivo | 99.5% mensual |
| Horario de operación | 24/7 |
| Ventana de mantenimiento | Domingos 01:00-03:00 UTC |
| RTO | < 4 horas |
| RPO | < 1 hora (pgBackRest PITR desde réplica) |

**Volumen por segmento de organización:**
| Segmento | Activos/día | Aprobaciones/día | Usuarios concurrentes |
|---|---|---|---|
| PYME (10-50 emp.) | 5-20 | 3-15 | 2-5 |
| Mediana (50-200 emp.) | 20-80 | 15-60 | 5-20 |
| Grande (200-1000 emp.) | 80-300 | 60-250 | 20-80 |
| Multi-empresa/Holding | 300-1000 | 250-800 | 80-200 |

**Rendimiento objetivo (p95):**
| Operación | Tiempo objetivo |
|---|---|
| Búsqueda de activos | < 2s (hasta 50,000 activos) |
| Carga de detalle de activo | < 1s |
| Descarga de activo | < 5s |
| Inicio de flujo de aprobación | < 3s |
| Firma de aprobación con Vault | < 8s |
| Ingreso de activo (hasta 10MB) | < 15s |
| Generación de expediente completo | < 30s (asíncrono) |

**Límites operativos de bvault:**
| Límite | Valor |
|---|---|
| Tamaño máximo de archivo | 50 MB por activo (configurable) |
| Máximo de firmantes por flujo | 20 |
| TTL máximo de delivery_token | 30 días |
| Intentos de verificación en Ventanilla | 5 máximos antes de bloqueo |
| Retención de vault_integrity_log | 730 días (2 años) |
| Retención de vault_delivery_log | 1825 días (5 años) |

**Monitoreo — Métricas críticas de negocio para dashboard Grafana:**
| Métrica | Alerta |
|---|---|
| `bvault_flows_active` | Alerta si > N (configurable) |
| `bvault_steps_overdue` | Alerta inmediata |
| `bvault_integrity_failures_total` | Alerta inmediata si > 0 |
| `bvault_deliveries_pending` | Alerta si TTL expira en < 24h |
| `bvault_vault_errors_total` | Alerta si > 3 en 5 minutos |
| `bvault_api_latency_p95` | Alerta si > 2000ms |
| `bvault_storage_errors_total` | Alerta si > 0 |

### SmartORC — BOSORC-009-OPERACION

**Disponibilidad de SmartORC:**
| Componente | Target |
|---|---|
| SmartORC API (escritura) | 99.5% mensual |
| SmartORC API (lectura) | 99.9% mensual |
| Job de prioridad | 99% de ejecuciones en intervalo |
| Notificaciones Centrifugo | 99% (degradación elegante) |

**Volúmenes de referencia:**
| Métrica | Tenant mediano | Tenant grande |
|---|---|---|
| Documentos ingresados/día | 50-200 | 500-2000 |
| Documentos activos simultáneos | 500-2000 | 5000-20000 |
| Transferencias de custodia/día | 100-400 | 1000-4000 |
| Usuarios activos simultáneos | 10-50 | 100-500 |

**6 KPIs de SmartORC (A-F):**
- **KPI A — SLA por Funcionario:** Tiempo promedio de permanencia por funcionario. Benchmarks: < 4h excelente, 4-12h normal, > 24h alerta.
- **KPI B — Índice de Redirección Correcta:** % de documentos sin reasignación posterior. Umbral de alerta: < 65%.
- **KPI C — Eficiencia Resolutiva:** % de documentos vencidos que fueron resueltos. > 90% excelente, < 60% crítica.
- **KPI D — Tiempo de Primer Contacto:** Horas desde ingreso hasta primera acción. < 2h para ROJO: excelente.
- **KPI E — Tasa de Escalamiento:** % de documentos escalados sobre activos totales.
- **KPI F — Tasa de Despacho a Tiempo:** % de despachos programados ejecutados en ventana de ±30 min.

**Test de carga del job de prioridad:**
- Precondición: 10,000 documentos activos (60% VERDE, 30% AMARILLO, 10% ROJO)
- Criterios: job completa en < 30s, UPDATEs ≤ 20% del total, CPU PG < 60%

### SmartReport — SBOS-REPORT-009-OPERACION

**Disponibilidad:** 99.5% mensual. Ventana de mantenimiento: Domingos 2:00-6:00 AM.

**Rendimiento de SmartReport (p95):**
| Operación | Objetivo |
|---|---|
| Preview reporte estándar (1-5 páginas) | < 5s |
| Preview reporte complejo (50+ páginas) | < 20s |
| Consulta de catálogo (con caché) | < 100ms |
| Subida y compilación de plantilla | < 30s |

**Caché del catálogo:** Clave: `catalog:{tenant_id}:{app_id}:{empresa_id}:{sucursal_id}:{rol}`. TTL: 5 minutos (configurable `CATALOG_CACHE_TTL=300`).

**Política de retención del log de ejecución con pg_partman (3 etapas):**
| Etapa | Duración | Ubicación |
|---|---|---|
| HOT | 0-36 meses | `ejecucion.log` (accesible via API) |
| COLD | 37-60 meses | `ejecucion_archivo.log_YYYY_MM` (query directa) |
| DROP | > 60 meses | Eliminado |

**Monitoreo de SmartReport:**
| Métrica | Alerta |
|---|---|
| `smartreport_executions_error_rate` | > 5% en 5 min |
| `smartreport_execution_duration_p95` | > 30s |
| `smartreport_templates_integrity_alerts` | > 0 |
| `smartreport_paperless_queue_depth` | > 100 jobs |
| `smartreport_catalog_cache_hit_rate` | < 80% |

---

## Fuentes de Enriquecimiento V8

| Fuente | Archivo | Secciones utilizadas |
|---|---|---|
| V6 original | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V6_SBOS-032-OPERATIONS.md` | Documento completo (224 líneas) |
| V5 Operations | `/opt/skull/orquestador/proyectos/desarrollo/context/sbos/Procesar/BOS_V5_SBOS-024-Operations-v1_0.md` | §1 Error Budget policy, §4 Alertmanager completo con routing, §5-§14 Runbooks RK-007 a RK-014, §5 Canary expandido, §6 Dashboard expandido |
| SmartVault Operación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Vault Flow/context/SBOS-VAULT-009-OPERACION.md` | SLA 99.5%, volumen por segmento, rendimiento p95, límites operativos, métricas de negocio Grafana |
| SmartORC Operación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart ORC/context/BOSORC-009-OPERACION.md` | Disponibilidad ORC, volúmenes de referencia, 6 KPIs (A-F), test de carga job prioridad |
| SmartReport Operación | `/opt/skull/orquestador/proyectos/desarrollo/sbos/subproyectos/SBOS Smart Report/context/SBOS-REPORT-009-OPERACION.md` | SLA 99.5%, rendimiento p95, caché catálogo, pg_partman retención 3-etapas, monitoreo |

---

_SKULL · SBOS · SBOS-032-OPERATIONS · V8 (V6+V5+Smart*) · Mayo 2026_
