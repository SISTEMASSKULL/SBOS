# SBOS-024 — Libro de Operaciones: SLOs, Alertas y Runbooks
## Umbrales, criterios de halt y procedimientos de respuesta operacional

**SKULL · SBOS — Sovereign Business Operating System**
**v1.0 · Marzo 2026**

---

**Código:** SBOS-024
**Versión:** 1.0
**Estado:** ACTIVO — Complementos en archivos separados
**Complemento:** SBOS-018-DEPLOY-FeatureFlags-v1_0.md (contiene §7.3 Feature Flags por tenant y §12 RK-014: Blue/Green de daemons soberanos — complemento disponible en archivo separado)
**Documento nuevo** — no reemplaza a ningún documento anterior
**Clasificación:** Especificación Operacional — Observabilidad y Runbooks

---

## 1. Por qué este documento existe

La observabilidad sin umbrales es decoración. Prometheus puede recopilar diez mil métricas por segundo, Grafana puede dibujar dashboards impresionantes, y Alertmanager puede enrutar notificaciones a cualquier canal — pero si nadie definió cuándo una métrica es "demasiado alta" o cuándo el sistema está "degradado", todas esas herramientas no producen ninguna acción.

Este documento define tres cosas que convierten la instrumentación en operación accionable:

1. **SLOs** — los umbrales numéricos que separan "el sistema está bien" de "hay que actuar"
2. **Reglas de Alertmanager** — las condiciones exactas que disparan notificaciones, listas para copiar al archivo de configuración
3. **Runbooks** — los pasos exactos para resolver los diez incidentes más frecuentes

### Conceptos SRE usados en este documento

El SBOS adopta la terminología del libro *Site Reliability Engineering* de Google para definir sus compromisos de servicio:

- **SLI (Service Level Indicator):** una métrica específica y medible del comportamiento del sistema (latencia P95, tasa de errores, disponibilidad)
- **SLO (Service Level Objective):** el umbral objetivo para un SLI (latencia P95 < 200ms)
- **SLA (Service Level Agreement):** el compromiso contractual con el cliente, siempre más conservador que el SLO
- **Error Budget:** el margen de incumplimiento permitido (si el SLO es 99.9% de disponibilidad, el error budget es 43.8 min/mes de downtime)
- **Burn Rate:** qué tan rápido se consume el error budget. Un burn rate de 1x consume el budget exactamente al ritmo esperado. Un burn rate de 60x lo consume en un día.

---

## 2. SLOs por componente

### PostgreSQL — dataserver

PostgreSQL es la base de datos de toda la Capa 1 del SBOS. Si PostgreSQL no está disponible, el sistema completo está inoperativo. Tiene la criticidad más alta del stack.

| SLI | SLO | Error Budget mensual |
|---|---|---|
| Disponibilidad | > 99.99% | 4.3 minutos/mes |
| Latencia de queries OLTP (P99) | < 50ms | — |
| Latencia de queries de reporting (P95) | < 5s | — |
| Lag de replicación WAL (bKernel) | < 500ms (P99) | — |
| Tiempo de recuperación ante fallo (RTO) | < 5 minutos | — |

### Keycloak — identityserver

Keycloak es el proveedor de identidad. Sin él, ningún usuario puede autenticarse en ninguna aplicación del sistema.

| SLI | SLO | Error Budget mensual |
|---|---|---|
| Disponibilidad | > 99.99% | 4.3 minutos/mes |
| Latencia de autenticación (P99) | < 500ms | — |
| Latencia de validación de token (P95) | < 50ms | — |
| Tasa de errores 5xx | < 0.1% | — |

### bKernel — daemon soberano

El bKernel es el sistema nervioso del SBOS. Si se detiene, la sincronización de datos entre aplicaciones cesa.

| SLI | SLO | Error Budget mensual |
|---|---|---|
| Disponibilidad del daemon | > 99.95% | 21.9 minutos/mes |
| Lag WAL → destino (P99) | < 500ms | — |
| Tamaño de Dead Letter Queue | < 10 eventos | — |
| Throughput mínimo | > 1000 eventos/min | — |

### SBOS Data RAG — búsqueda federada

| SLI | SLO | Error Budget mensual |
|---|---|---|
| Disponibilidad | > 99.9% | 43.8 minutos/mes |
| Latencia de búsqueda (P95) | < 200ms | — |
| Latencia de búsqueda (P99) | < 500ms | — |
| Índice de Typesense actualizado | < 2s post-evento bKernel | — |

### Kong API Gateway

Kong es el punto de entrada de todas las peticiones externas. Actúa como WAF, balanceador y proxy de autenticación.

| SLI | SLO | Error Budget mensual |
|---|---|---|
| Disponibilidad | > 99.9% | 43.8 minutos/mes |
| Latencia overhead del gateway (P95) | < 100ms adicionales | — |
| Tasa de errores 5xx | < 0.5% | — |

### Core UI — frontend del IAM Installer

| SLI | SLO | Error Budget mensual |
|---|---|---|
| Disponibilidad | > 99.5% | 3.6 horas/mes |
| Tiempo de carga inicial (P95) | < 3s | — |
| Time to Interactive (P95) | < 5s | — |

### Vault — gestión de secretos

| SLI | SLO | Error Budget mensual |
|---|---|---|
| Disponibilidad (unsealed) | > 99.99% | 4.3 minutos/mes |
| Latencia de lectura de secreto (P95) | < 100ms | — |

---

## 3. SLAs hacia el cliente

Los SLAs son los compromisos contractuales de SKULL hacia sus clientes. Son siempre más conservadores que los SLOs internos para preservar el error budget.

| Componente | SLA de disponibilidad | RTO | RPO |
|---|---|---|---|
| Sistema completo (todos los servicios) | 99.9% mensual | 1 hora | 1 hora |
| Autenticación (Keycloak) | 99.95% mensual | 30 minutos | 0 (sin pérdida de datos) |
| Base de datos (PostgreSQL) | 99.95% mensual | 15 minutos | 15 minutos (frecuencia de backup) |
| Aplicaciones del stack (Tryton, OrangeHRM, etc.) | 99.5% mensual | 2 horas | 1 hora |

**RTO (Recovery Time Objective):** tiempo máximo para restaurar el servicio después de un fallo.
**RPO (Recovery Point Objective):** máxima pérdida de datos aceptable (qué tan atrás se puede volver con los backups disponibles).

### Ventanas de mantenimiento

Las actualizaciones del sistema se ejecutan en ventanas de mantenimiento pre-acordadas:
- **Ventana estándar:** martes y jueves, 22:00 - 02:00 hora local del cliente
- **Ventana de emergencia (P0):** cualquier hora, notificación al cliente antes de iniciar

---

## 4. Reglas de Alertmanager — configuración completa

Las siguientes reglas están listas para copiarse al archivo `prometheus-rules.yml` del cluster. Usar el namespace `sbos` para todas las reglas.

```yaml
# prometheus-rules.yml
# SBOS-024 — Reglas de alertas operacionales
# Versión: 1.0 — Marzo 2026

groups:
  # ──────────────────────────────────────────────────────────────────
  # GRUPO CRÍTICO — Notificación inmediata 24/7
  # Tiempo de respuesta objetivo: < 15 minutos
  # ──────────────────────────────────────────────────────────────────
  - name: sbos.critical
    rules:

      - alert: PostgreSQLDown
        expr: up{job="postgresql"} == 0
        for: 30s
        labels:
          severity: critical
          team: skull-ops
          runbook: RK-001
        annotations:
          summary: "PostgreSQL inaccesible en {{ $labels.instance }}"
          description: >
            PostgreSQL lleva más de 30 segundos sin responder.
            El sistema completo está degradado. Ver runbook RK-001.

      - alert: KeycloakDown
        expr: up{job="keycloak"} == 0
        for: 60s
        labels:
          severity: critical
          team: skull-ops
          runbook: RK-002
        annotations:
          summary: "Keycloak inaccesible — usuarios sin autenticación"
          description: >
            Keycloak lleva más de 60 segundos sin responder.
            Ningún usuario puede autenticarse. Ver runbook RK-002.

      - alert: bKernelDown
        expr: up{job="bkernel"} == 0
        for: 60s
        labels:
          severity: critical
          team: skull-ops
          runbook: RK-003
        annotations:
          summary: "bKernel caído — sincronización de datos detenida"
          description: >
            El daemon bKernel no responde. La sincronización
            de datos entre aplicaciones está detenida. Ver runbook RK-003.

      - alert: WALReplicationLagCritical
        expr: bkernel_wal_lag_seconds > 30
        for: 60s
        labels:
          severity: critical
          team: skull-ops
          runbook: RK-004
        annotations:
          summary: "Lag de replicación WAL crítico: {{ $value }}s"
          description: >
            El bKernel tiene un lag de {{ $value }} segundos en la
            replicación WAL. Los datos de las aplicaciones no están
            sincronizados. Ver runbook RK-004.

      - alert: TLSCertificateExpiringSoon
        expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 7
        for: 1h
        labels:
          severity: critical
          team: skull-ops
          runbook: RK-006
        annotations:
          summary: "Certificado TLS expira en {{ $value | humanizeDuration }}"
          description: >
            El certificado TLS de {{ $labels.instance }} expira en menos de
            7 días. Si no se renueva, el sistema dejará de funcionar.
            Ver runbook RK-006.

      - alert: VaultSealed
        expr: vault_core_unsealed == 0
        for: 30s
        labels:
          severity: critical
          team: skull-ops
          runbook: RK-010
        annotations:
          summary: "Vault sellado — secretos inaccesibles"
          description: >
            Vault está en estado sellado. Ningún servicio puede
            obtener secretos. El sistema está degradado. Ver runbook RK-010.

  # ──────────────────────────────────────────────────────────────────
  # GRUPO ALTO — Notificación en horario laboral
  # Tiempo de respuesta objetivo: < 1 hora
  # ──────────────────────────────────────────────────────────────────
  - name: sbos.high
    rules:

      - alert: AIServerUnavailable
        expr: up{job="ollama"} == 0
        for: 5m
        labels:
          severity: high
          team: skull-ops
        annotations:
          summary: "aiserver Ollama no disponible"
          description: >
            El servidor de IA (Ollama) lleva más de 5 minutos sin responder.
            Las funcionalidades de IA del SBOS no están disponibles.

      - alert: SBOS Data RAGLatencyHigh
        expr: histogram_quantile(0.95, bsearch_query_duration_seconds_bucket) > 0.5
        for: 5m
        labels:
          severity: high
          team: skull-ops
          runbook: RK-003
        annotations:
          summary: "SBOS Data RAG latencia P95 elevada: {{ $value }}s"
          description: >
            La latencia P95 de SBOS Data RAG lleva 5 minutos por encima de 500ms.
            Las búsquedas están degradadas.

      - alert: DiskUsageHigh
        expr: (node_filesystem_size_bytes - node_filesystem_free_bytes)
              / node_filesystem_size_bytes * 100 > 85
        for: 5m
        labels:
          severity: high
          team: skull-ops
          runbook: RK-005
        annotations:
          summary: "Disco > 85% en {{ $labels.instance }}"
          description: >
            El servidor {{ $labels.instance }} tiene el disco al {{ $value }}%.
            Si llega al 100% el servidor puede quedar inestable. Ver runbook RK-005.

      - alert: PodCrashLoopBackOff
        expr: kube_pod_container_status_waiting_reason{reason="CrashLoopBackOff"} == 1
        for: 5m
        labels:
          severity: high
          team: skull-ops
          runbook: RK-007
        annotations:
          summary: "Pod en CrashLoopBackOff: {{ $labels.pod }}"
          description: >
            El pod {{ $labels.pod }} en el namespace {{ $labels.namespace }}
            está en CrashLoopBackOff. Ver runbook RK-007.

  # ──────────────────────────────────────────────────────────────────
  # GRUPO MEDIO — Canal de monitoreo
  # Tiempo de respuesta objetivo: < 4 horas
  # ──────────────────────────────────────────────────────────────────
  - name: sbos.medium
    rules:

      - alert: MemoryUsageHigh
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)
              / node_memory_MemTotal_bytes * 100 > 90
        for: 5m
        labels:
          severity: medium
          team: skull-ops
        annotations:
          summary: "RAM > 90% en {{ $labels.instance }}"
          description: >
            El servidor {{ $labels.instance }} tiene la RAM al {{ $value }}%.

      - alert: bKernelDLQNotEmpty
        expr: bkernel_dlq_size > 10
        for: 10m
        labels:
          severity: medium
          team: skull-ops
        annotations:
          summary: "bKernel DLQ con {{ $value }} eventos pendientes"
          description: >
            La Dead Letter Queue del bKernel tiene {{ $value }} eventos
            que no pudieron ser procesados. Revisar logs del bKernel.

      - alert: TLSCertificateExpiring30Days
        expr: (probe_ssl_earliest_cert_expiry - time()) / 86400 < 30
        for: 1h
        labels:
          severity: medium
          team: skull-ops
          runbook: RK-006
        annotations:
          summary: "Certificado TLS expira en {{ $value }} días"
          description: >
            El certificado TLS de {{ $labels.instance }} expira en
            menos de 30 días. Ver runbook RK-006.

      - alert: ConfigDriftDetected
        expr: sbos_installer_drift_count > 0
        for: 15m
        labels:
          severity: medium
          team: skull-ops
          runbook: RK-009
        annotations:
          summary: "Drift de configuración detectado: {{ $value }} fichas"
          description: >
            El IAM Installer detectó drift en {{ $value }} fichas.
            El estado real del sistema difiere del estado deseado.
            Ver runbook RK-009.
```

### Configuración del enrutamiento en Alertmanager

```yaml
# alertmanager.yml
route:
  group_by: ['alertname', 'severity']
  group_wait:      30s
  group_interval:  5m
  repeat_interval: 4h
  receiver: 'default'

  routes:
    - match:
        severity: critical
      receiver: 'critical-24x7'
      repeat_interval: 1h

    - match:
        severity: high
      receiver: 'high-business-hours'
      repeat_interval: 4h

    - match:
        severity: medium
      receiver: 'medium-slack'
      repeat_interval: 8h

receivers:
  - name: 'critical-24x7'
    pagerduty_configs:
      - service_key: '<PAGERDUTY_KEY>'
    slack_configs:
      - api_url: '<SLACK_WEBHOOK>'
        channel: '#sbos-alerts-critical'
        title: '🚨 CRÍTICO: {{ .GroupLabels.alertname }}'

  - name: 'high-business-hours'
    slack_configs:
      - api_url: '<SLACK_WEBHOOK>'
        channel: '#sbos-alerts-high'
        title: '⚠️ ALTO: {{ .GroupLabels.alertname }}'

  - name: 'medium-slack'
    slack_configs:
      - api_url: '<SLACK_WEBHOOK>'
        channel: '#sbos-alerts-medium'
        title: 'ℹ️ MEDIO: {{ .GroupLabels.alertname }}'

  - name: 'default'
    slack_configs:
      - api_url: '<SLACK_WEBHOOK>'
        channel: '#sbos-alerts-all'
```

---

## 5. Criterios de halt del rollout canary

El rollout canary distribuye una nueva versión a un porcentaje pequeño del tráfico antes de expandirla al 100%. Estos criterios definen cuándo el rollout debe detenerse automáticamente.

### Criterios de halt automático

| Condición | Umbral | Tiempo de observación | Acción |
|---|---|---|---|
| Incidente P0 en el segmento canary | 1 incidente | Inmediato | Halt total + rollback automático |
| Incidentes P1 en el segmento canary | 2 incidentes | < 4 horas | Halt + revisión del equipo antes de continuar |
| Degradación de latencia P95 | > 50% respecto a la versión anterior | > 15 minutos sostenidos | Hold automático — no rollback, pero no avance |
| Error rate en endpoints críticos | > 1% | > 5 minutos | Hold automático |
| Health check fallando | 3 fallos consecutivos | — | Rollback inmediato |
| Uso de memoria | > 150% del límite definido en la ficha | > 10 minutos | Hold automático |

### Etapas del rollout y sus criterios de avance

```
ETAPA 0 — Pre-deploy (validación)
  □ make validate — debe pasar al 100%
  □ make test-all — todos los tests en verde
  □ Firma Ed25519 verificada
  → Si todo OK: continuar a Etapa 1

ETAPA 1 — Canary 10% (duración: 15 minutos)
  Métricas observadas:
  □ Error rate < 1%
  □ Latencia P95 < 150% de la versión actual
  □ Health check: 100% de respuestas 200
  □ Cero incidentes P0 o P1
  → Si todas OK: continuar a Etapa 2
  → Si cualquiera falla: halt + rollback automático (< 30s)

ETAPA 2 — Canary 50% (duración: 30 minutos)
  Mismas métricas que Etapa 1
  + □ Throughput del bKernel estable (±10% respecto a baseline)
  → Si todas OK: continuar a Etapa 3
  → Si cualquiera falla: halt + rollback automático (< 30s)

ETAPA 3 — Full deploy 100%
  □ Rollout completo
  □ Health check de todas las réplicas: 200
  □ 15 minutos de observación post-deploy
  □ IAM Installer emite installer.ficha.updated
```

### Tiempo objetivo de rollback

El rollback de una versión fallida debe completarse en **menos de 30 segundos** desde la detección del criterio de halt. Este es el objetivo de diseño del `rollout_controller` del IAM Installer (ver SBOS-022 CU-04).

---

## 6. Dashboard de Grafana recomendado

El dashboard principal del SBOS debe tener los siguientes paneles visibles en una sola pantalla (sin scroll) para el operador de turno:

| Panel | Métrica | Tipo de visualización | Por qué es crítico |
|---|---|---|---|
| Estado general del sistema | Semáforo de todos los SLOs | Stat con color rojo/amarillo/verde | Vista de un vistazo del estado del sistema |
| PostgreSQL — disponibilidad | `up{job="postgresql"}` | Gauge — % uptime últimas 24h | La base de datos es la criticidad máxima |
| Keycloak — autenticaciones/min | `keycloak_logins_total` | Time series — últimas 2h | Caída a cero = nadie puede entrar |
| bKernel — lag WAL | `bkernel_wal_lag_seconds` | Gauge con umbrales 30s/500ms | El nervioso del sistema |
| bKernel — DLQ size | `bkernel_dlq_size` | Stat — número actual | Eventos perdidos en espera |
| Disco — % uso por servidor | `node_filesystem_used_bytes` | Bar chart por servidor | El disco lleno destruye el sistema |
| RAM — % uso por servidor | `node_memory_MemAvailable_bytes` | Bar chart por servidor | OOM kills son silenciosos |
| Pods en estado no-Running | `kube_pod_status_phase` | Stat — cuenta de pods problemáticos | CrashLoopBackOff o Pending bloqueantes |
| SBOS Data RAG — latencia P95 | `histogram_quantile(0.95, ...)` | Gauge con umbral 200ms | La búsqueda es visible para el usuario final |
| Alertas activas | Alertmanager API | Alert list por severidad | Resumen de todo lo que está fuera de SLO |
| Error Budget restante (mes actual) | Cálculo de SLO mensual | Gauge — % restante | Cuánto margen queda para el mes |

---

## 7. RK-001 — PostgreSQL inaccesible

**Alerta que lo dispara:** `PostgreSQLDown` (severity: critical)
**Impacto:** Sistema completo inoperativo. Ninguna aplicación puede leer ni escribir datos.

### Diagnóstico

```bash
# 1. Verificar el pod de PostgreSQL
kubectl get pods -n postgresql
kubectl describe pod <postgresql-pod> -n postgresql

# 2. Verificar los logs del pod
kubectl logs <postgresql-pod> -n postgresql --tail=100

# 3. Verificar si el pod existe pero no responde
kubectl exec -n postgresql <postgresql-pod> -- pg_isready -U postgres

# 4. Verificar el estado del PersistentVolume
kubectl get pv | grep postgresql
kubectl get pvc -n postgresql

# 5. Verificar recursos del nodo (disco y RAM)
kubectl describe node <dataserver-node>
```

### Resolución

**Caso A — Pod crasheado, logs indican OOM (Out of Memory):**
```bash
# Verificar si fue un OOM kill
kubectl describe pod <postgresql-pod> -n postgresql | grep -i oom
# Si fue OOM: aumentar el memory limit en la ficha de PostgreSQL
# y hacer kubectl rollout restart
kubectl rollout restart deployment/postgresql -n postgresql
```

**Caso B — Pod crasheado, logs indican disco lleno:**
```bash
# Ver runbook RK-005 primero para liberar espacio
# Luego reanudar PostgreSQL
kubectl rollout restart deployment/postgresql -n postgresql
```

**Caso C — Pod en Pending (nodo no disponible):**
```bash
# Verificar el estado del nodo dataserver
kubectl get nodes
# Si el nodo está NotReady: ver runbook RK-007
# Evacuar pods del nodo y reprogramarlos
kubectl drain <dataserver-node> --ignore-daemonsets --delete-emptydir-data
```

**Caso D — PostgreSQL responde pero conexiones rechazadas (max_connections):**
```bash
# Verificar conexiones activas
kubectl exec -n postgresql <postgresql-pod> -- \
  psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Si está al límite: aumentar max_connections en postgresql.conf
# (requiere reinicio de PostgreSQL)
kubectl exec -n postgresql <postgresql-pod> -- \
  psql -U postgres -c "SHOW max_connections;"
```

**Criterio de cierre:** `pg_isready` retorna "accepting connections" y la alerta `PostgreSQLDown` se resuelve en Alertmanager.

---

## 8. RK-002 — Keycloak inaccesible

**Alerta que lo dispara:** `KeycloakDown` (severity: critical)
**Impacto:** Ningún usuario puede autenticarse. Las sesiones activas siguen funcionando hasta que el JWT expira (5 minutos).

### Diagnóstico

```bash
# 1. Verificar el pod de Keycloak
kubectl get pods -n keycloak
kubectl logs <keycloak-pod> -n keycloak --tail=100

# 2. Verificar si Keycloak responde pero devuelve errores
curl -s https://bos.acme.com/realms/master/.well-known/openid-configuration \
  | head -20

# 3. Verificar la conexión de Keycloak a PostgreSQL
# (Keycloak no puede arrancar sin su base de datos)
kubectl logs <keycloak-pod> -n keycloak | grep -i "database"

# 4. Verificar el estado del Infinispan cache (cluster de sesiones)
kubectl exec -n keycloak <keycloak-pod> -- \
  /opt/keycloak/bin/kcadm.sh get serverinfo --server http://localhost:8080
```

### Resolución

**Caso A — Keycloak no puede conectar a PostgreSQL:**
```bash
# Primero resolver el problema de PostgreSQL (RK-001)
# Luego reiniciar Keycloak para que reintente la conexión
kubectl rollout restart deployment/keycloak -n keycloak
```

**Caso B — Keycloak responde con error 503 (memoria insuficiente):**
```bash
kubectl describe pod <keycloak-pod> -n keycloak | grep -i memory
# Si hay OOM: aumentar memory limit y reiniciar
kubectl set resources deployment/keycloak -n keycloak \
  --limits=memory=2Gi --requests=memory=1Gi
kubectl rollout restart deployment/keycloak -n keycloak
```

**Caso C — Keycloak en modo standalone caído (no K8s):**
```bash
# Si Keycloak corre como daemon en identityserver
sudo systemctl status keycloak
sudo systemctl restart keycloak
sudo journalctl -u keycloak -n 100
```

**Criterio de cierre:** El endpoint `/realms/master/.well-known/openid-configuration` retorna HTTP 200 y la alerta se resuelve.

---

## 9. RK-003 — bKernel caído

**Alerta que lo dispara:** `bKernelDown` (severity: critical)
**Impacto:** La sincronización de datos entre aplicaciones está detenida. Los datos de una app no se propagan a las demás. Los índices de SBOS Data RAG y Qdrant dejan de actualizarse.

### Diagnóstico

```bash
# bKernel es un daemon soberano del host (fuera de K8s)
# Se ejecuta como systemd service en cada servidor

# 1. Verificar el estado del daemon
sudo systemctl status bkernel

# 2. Ver los últimos logs
sudo journalctl -u bkernel -n 200

# 3. Verificar la conexión a PostgreSQL (bKernel lee el WAL)
# Los logs mostrarán errores de conexión si PostgreSQL está caído

# 4. Verificar la conexión a Redis (bKernel escribe en Redis Streams)
redis-cli -h redis.sbos.svc.cluster.local ping
```

### Resolución

**Caso A — bKernel detenido sin error evidente:**
```bash
sudo systemctl start bkernel
sudo systemctl status bkernel
# Verificar que el lag WAL vuelve a bajar en Grafana
```

**Caso B — bKernel crasheando por error de configuración:**
```bash
# Verificar la configuración
sudo cat /etc/bos/blibs/bkernel/bkernel.toml
# Verificar que los parámetros de conexión a PostgreSQL son correctos
# Restaurar la configuración desde el Release Server si hay duda
sudo systemctl restart bkernel
```

**Caso C — DLQ con muchos eventos bloqueados (bKernel levanta pero hay backlog):**
```bash
# Ver el tamaño de la DLQ en Redis
redis-cli XLEN bkernel:dlq

# Procesar los eventos de la DLQ manualmente (con cuidado — pueden tener errores por razón)
redis-cli XRANGE bkernel:dlq - + COUNT 10

# Si los eventos son procesables: el bKernel los reintentará automáticamente al levantarse
# Si son errores permanentes: limpiar la DLQ con documentación del motivo
redis-cli DEL bkernel:dlq  # SOLO si se confirmó que los eventos son irrecuperables
```

**Criterio de cierre:** `systemctl status bkernel` muestra `active (running)`, la métrica `bkernel_wal_lag_seconds` vuelve a valores normales (< 500ms) y la alerta se resuelve.

---

## 10. RK-004 — bKernel lag de replicación elevado

**Alerta que lo dispara:** `WALReplicationLagCritical` (severity: critical)
**Impacto:** Los datos escritos en PostgreSQL no se están propagando a las otras aplicaciones con la latencia esperada. El sistema está sincronizando con retraso.

### Diagnóstico

```bash
# 1. Ver el lag actual en tiempo real
redis-cli GET bkernel:metrics:wal_lag

# 2. Ver el throughput del bKernel
redis-cli GET bkernel:metrics:events_per_minute

# 3. Verificar si hay un consumer lento bloqueando el Redis Stream
redis-cli XINFO GROUPS bkernel:main_stream
# Buscar consumer groups con lag alto

# 4. Verificar los recursos del servidor donde corre bKernel
top -p $(pgrep bkernel)
```

### Resolución

**Caso A — Consumer lento en un servicio destino:**
```bash
# Identificar el consumer group con lag
redis-cli XINFO GROUPS bkernel:main_stream
# Si un consumer group específico tiene lag alto,
# reiniciar el servicio consumidor correspondiente
kubectl rollout restart deployment/<servicio-lento> -n <namespace>
```

**Caso B — bKernel con CPU saturado (muchos eventos en ráfaga):**
```bash
# Verificar si hay una operación masiva en curso (migración de datos, importación)
kubectl top pod -A | sort -k4 -rn | head -20
# Si hay una operación masiva esperada: esperar a que termine
# Si es inesperado: investigar qué aplicación está generando el volumen
```

**Caso C — PostgreSQL con I/O saturado:**
```bash
# Verificar el I/O del dataserver
iostat -x 5 3
# Si el disco está saturado: ver si hay una query lenta bloqueando el WAL
kubectl exec -n postgresql <postgresql-pod> -- \
  psql -U postgres -c "SELECT pid, query, state, wait_event FROM pg_stat_activity WHERE state != 'idle';"
```

**Criterio de cierre:** La métrica `bkernel_wal_lag_seconds` vuelve a < 500ms y la alerta se resuelve.

---

## 11. RK-005 — Disco lleno en cualquier servidor

**Alerta que lo dispara:** `DiskUsageHigh` (severity: high, umbral > 85%)
**Impacto:** Si el disco llega al 100%, el servidor puede quedar inestable, PostgreSQL puede corromper datos, y los logs dejan de escribirse.

### Diagnóstico

```bash
# 1. Identificar qué está consumiendo el espacio
df -h
du -sh /var/log/* | sort -rh | head -20
du -sh /var/lib/docker/* | sort -rh | head -20

# En el dataserver (PostgreSQL):
du -sh /var/lib/postgresql/data/
# Verificar tablas grandes
kubectl exec -n postgresql <postgresql-pod> -- \
  psql -U postgres -c "
    SELECT schemaname, tablename,
           pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
    FROM pg_tables
    ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC
    LIMIT 10;"
```

### Resolución

**Caso A — Logs de sistema crecidos:**
```bash
# Limpiar logs viejos (con precaución — preservar los últimos 7 días)
sudo journalctl --vacuum-time=7d
sudo find /var/log -name "*.gz" -mtime +7 -delete
```

**Caso B — Imágenes Docker sin usar:**
```bash
docker system prune -f
docker image prune -a -f --filter "until=168h"
```

**Caso C — Tablas PostgreSQL con datos históricos crecidos:**
```bash
# VACUUM y ANALYZE para recuperar espacio de filas eliminadas
kubectl exec -n postgresql <postgresql-pod> -- \
  psql -U postgres -c "VACUUM ANALYZE;"
# Si la tabla de eventos de Keycloak es grande:
kubectl exec -n postgresql <postgresql-pod> -- \
  psql -U postgres -c "DELETE FROM event_entity WHERE time < extract(epoch from now() - interval '90 days') * 1000;"
```

**Caso D — Disco en el dataserver > 90% (emergencia):**
```bash
# Expansión de volumen en el PVC (si el StorageClass lo permite)
kubectl edit pvc postgresql-data -n postgresql
# Cambiar spec.resources.requests.storage a un valor mayor
# El volumen se expande sin reiniciar el pod si el StorageClass tiene allowVolumeExpansion: true
```

**Criterio de cierre:** El uso del disco baja por debajo del 80% y la alerta se resuelve.

---

## 12. RK-006 — Certificado TLS expirado o próximo a expirar

**Alerta que lo dispara:** `TLSCertificateExpiring30Days` (medium) o `TLSCertificateExpiringSoon` (critical, < 7 días)
**Impacto:** Si el certificado expira, todos los clientes HTTPS recibirán error de seguridad. Los browsers bloquean el acceso.

### Diagnóstico

```bash
# 1. Identificar el certificado afectado
kubectl get certificates -A
kubectl describe certificate <cert-name> -n <namespace>

# 2. Verificar el estado del cert-manager
kubectl get pods -n cert-manager
kubectl logs -n cert-manager deployment/cert-manager | tail -50

# 3. Verificar si el emisor (ClusterIssuer) está disponible
kubectl get clusterissuer
kubectl describe clusterissuer letsencrypt-prod
```

### Resolución

**Caso A — cert-manager no está renovando automáticamente:**
```bash
# Forzar la renovación del certificado
kubectl annotate certificate <cert-name> -n <namespace> \
  cert-manager.io/issuer-kind=ClusterIssuer --overwrite
# O eliminar el certificado para que cert-manager lo recree
kubectl delete certificate <cert-name> -n <namespace>
# cert-manager lo recreará automáticamente
```

**Caso B — Certificado expirado en producción (emergencia):**
```bash
# Renovación manual de emergencia
kubectl delete secret <tls-secret-name> -n <namespace>
# cert-manager detecta el secret eliminado y emite uno nuevo
# Si no hay cert-manager: renovar con certbot manualmente
certbot renew --cert-name <domain> --force-renewal
```

**Criterio de cierre:** El certificado tiene fecha de expiración > 30 días y la alerta se resuelve.

---

## 13. RK-007 — Pod en CrashLoopBackOff

**Alerta que lo dispara:** `PodCrashLoopBackOff` (severity: high)
**Impacto:** Un servicio del sistema está caído y K8s no puede levantarlo. El servicio específico está inoperativo.

### Diagnóstico

```bash
# 1. Identificar el pod y su estado
kubectl get pods -A | grep CrashLoopBackOff
kubectl describe pod <pod-name> -n <namespace>

# 2. Ver los logs del crash
kubectl logs <pod-name> -n <namespace> --previous
# --previous muestra los logs del contenedor anterior antes del crash

# 3. Verificar los eventos del pod
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>

# 4. Verificar si es un problema de recursos
kubectl top pod <pod-name> -n <namespace>
```

### Causas frecuentes y resolución

**Causa A — Error de configuración (variable de entorno faltante o incorrecta):**
```bash
# Ver las variables de entorno del pod
kubectl exec <pod-name> -n <namespace> -- env | sort
# Comparar con la configuración esperada en la ficha
# Corregir el ConfigMap o Secret correspondiente
kubectl rollout restart deployment/<deployment> -n <namespace>
```

**Causa B — Secreto de Vault no disponible (Vault sellado):**
```bash
# Si el pod depende de un secreto de Vault y Vault está sellado:
# Ver runbook RK-010 para dessellar Vault primero
# Luego reiniciar el pod
kubectl rollout restart deployment/<deployment> -n <namespace>
```

**Causa C — Límites de recursos insuficientes:**
```bash
# Ver si el OOM killer está terminando el proceso
kubectl describe pod <pod-name> -n <namespace> | grep -i oom
# Si hay OOM: aumentar el memory limit en la ficha del servicio
# Hacer el PR correspondiente en el repositorio de fichas
```

**Criterio de cierre:** El pod está en estado `Running` y el health check pasa. La alerta se resuelve.

---

## 14. RK-008 — Rollback de versión del IAM Installer

**Activación:** Criterios de halt del rollout canary (§5) o solicitud manual del equipo.
**Impacto:** La versión nueva del sistema está produciendo errores. Se revierte a la versión anterior.

### Procedimiento

```bash
# 1. Confirmar que el rollback es necesario (verificar los criterios de §5)
make status  # Ver la versión instalada y el estado de salud

# 2. Identificar la versión anterior disponible
make history FICHA=<nombre-de-la-ficha>
# Lista las últimas N versiones instaladas con sus timestamps

# 3. Ejecutar el rollback
make rollback FICHA=<nombre-de-la-ficha> VERSION=<version-anterior>
# El IAM Installer ejecuta CU-04 (ver SBOS-022 §6)
# Objetivo: < 30 segundos para completar el rollback

# 4. Verificar que el rollback fue exitoso
make health FICHA=<nombre-de-la-ficha>
# Debe mostrar: HEALTHY, versión anterior activa

# 5. Documentar el incidente
# Crear issue en GitHub con:
# - La versión que falló
# - El criterio de halt que se activó
# - Los logs relevantes
# - La decisión de rollback con timestamp
```

**Criterio de cierre:** `make health` muestra HEALTHY para la ficha afectada, el health check pasa, y las métricas vuelven a los valores anteriores al deploy.

---

## 15. RK-009 — Drift de configuración detectado

**Alerta que lo dispara:** `ConfigDriftDetected` (severity: medium)
**Impacto:** El estado real del sistema difiere del estado deseado declarado en las fichas. Puede indicar un cambio manual no autorizado o un fallo en el proceso de reconciliación.

### Diagnóstico

```bash
# 1. Identificar qué fichas tienen drift
make drift-report
# Muestra una tabla con:
# - Ficha afectada
# - Tipo de drift (configuración, imagen, secreto, rol Keycloak)
# - Diferencia entre estado deseado y real

# 2. Ejemplo de salida:
# FICHA               TIPO          DESEADO          REAL
# sp-tryton-base      image         7.0.1            7.0.0
# sp-keycloak-roles   role_attr     bos_perm_ui=127  bos_perm_ui=63
```

### Resolución

**Caso A — Drift por actualización manual no autorizada:**
```bash
# El reconciler del IAM Installer revertirá el drift automáticamente
# en el siguiente ciclo (cada 15 minutos)
# Para forzar la reconciliación inmediata:
make reconcile FICHA=<nombre-de-la-ficha>

# Identificar quién hizo el cambio manual (auditoría):
# En Keycloak: Admin Console → Events → Admin Events
# En K8s: kubectl get events -A | grep -i "modified"
```

**Caso B — Drift por fallo en el proceso de instalación anterior:**
```bash
# El IAM Installer no completó correctamente la última instalación
# Forzar una reinstalación completa desde el estado deseado:
make repair FICHA=<nombre-de-la-ficha>
# Equivale a ejecutar CU-03 (ver SBOS-022)
```

**Criterio de cierre:** `make drift-report` no muestra fichas con drift. La alerta `ConfigDriftDetected` se resuelve.

---

## 16. RK-010 — Vault sellado

**Alerta que lo dispara:** `VaultSealed` (severity: critical)
**Impacto:** Ningún servicio puede obtener secretos de Vault. Los servicios que dependen de secretos dinámicos (credenciales de base de datos, claves de API) quedan inoperativos cuando sus leases expiran.

### Por qué Vault se sella

Vault se sella automáticamente cuando:
- El proceso de Vault es reiniciado (por el SO, por K8s, por fallo de nodo)
- Se detecta una condición de seguridad crítica (memoria corrupta, acceso no autorizado)
- El operador lo selló manualmente (`vault operator seal`)

### Diagnóstico

```bash
# 1. Verificar el estado de Vault
kubectl exec -n vault <vault-pod> -- vault status
# Muestra: Sealed = true/false, Threshold, Shares, Progress

# 2. Verificar cuándo se selló
kubectl logs -n vault <vault-pod> | grep -i "sealed"
```

### Resolución — Unseal de Vault

**IMPORTANTE:** El proceso de unseal requiere las Unseal Keys del cliente. SKULL no almacena estas claves — son responsabilidad del cliente. Las claves se entregan al cliente en el proceso de onboarding y deben almacenarse de forma segura (caja fuerte física, gestor de secretos fuera de Vault).

```bash
# El unseal requiere N de M claves (threshold configurado al instalar)
# Si threshold = 3 de 5: se necesitan 3 operadores con sus claves

# Operador 1:
kubectl exec -n vault <vault-pod> -- vault operator unseal <KEY_1>

# Operador 2:
kubectl exec -n vault <vault-pod> -- vault operator unseal <KEY_2>

# Operador 3:
kubectl exec -n vault <vault-pod> -- vault operator unseal <KEY_3>

# Verificar que el unseal fue exitoso:
kubectl exec -n vault <vault-pod> -- vault status
# Sealed = false
```

**Si no se tienen las Unseal Keys:**
- Escalar inmediatamente al fundador / arquitecto de SKULL
- Revisar el proceso de onboarding para verificar dónde se almacenaron las claves
- No intentar recrear Vault — los secretos serían perdidos

**Caso especial — Vault con Auto-Unseal via AWS KMS o Azure Key Vault:**
```bash
# Si el cliente configuró auto-unseal, Vault se desella automáticamente
# Si no se desella solo: verificar la conectividad al proveedor de KMS
kubectl logs -n vault <vault-pod> | grep -i "auto-unseal"
```

**Criterio de cierre:** `vault status` muestra `Sealed = false` y la alerta `VaultSealed` se resuelve. Verificar que los servicios que tenían secretos expirados se recuperan correctamente (pueden necesitar reinicio).

---

## 17. RK-014 — Blue/Green de Daemons Soberanos

> **Nota:** El contenido completo del runbook RK-014 (actualización Blue/Green de bKernel, SBOS Data Integration y SBOS AI Tools sin interrupción de servicio) se encuentra en **SBOS-018-DEPLOY-FeatureFlags-v1_0.md §12**. Incluye: procedimiento de warm-up del binario nuevo, ventana de observación, swap atómico de PID, rollback con binario `.prev` y criterios de abort. Ver también §7.3 de ese mismo documento para Feature Flags por tenant.

---

## 18. Registro de cambios

| Versión | Fecha | Autor | Descripción |
|---|---|---|---|
| 1.0 | Marzo 2026 | SKULL Team | Documento inicial — SLOs, SLAs, reglas Alertmanager, criterios de halt canary, dashboard Grafana, runbooks RK-001 a RK-010 |

---

*SKULL · SBOS · SBOS-024-OPERATIONS · v1.0 · Marzo 2026*
*Complementa: SBOS-003 (stack de observabilidad), SBOS-005 (rollout canary), SBOS-016 (monitorserver)*
