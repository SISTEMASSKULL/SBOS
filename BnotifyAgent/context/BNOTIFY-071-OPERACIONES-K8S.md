---
codigo: BNOTIFY-071
version: 1.0.0
estado: BORRADOR
gate: G0
depende_de: [BNOTIFY-000]
doctrina_que_ejerce: [D1, D14, D15]
criterio_implementado: >
  El daemon bNotify se reinicia automáticamente tras un kill -9 gracias a systemd.
  El dashboard Grafana "bNotify Overview" muestra las 6 métricas core en tiempo real.
  Un backup de la base de datos bnotify se completa sin errores y el restore
  en staging reproduce los datos. Verificado con verificar_afirmacion.sh en VPS.
---

# BNOTIFY-071 — Operaciones K8s y Host
## Despliegue, observabilidad, runbooks, respaldos y secretos

**Versión:** 1.0.0 · **Gate:** G0 · **Estado:** BORRADOR
**Referencia:** BNOTIFY-000 §4.8 · BNOTIFY-006 (stack: Ubuntu 24.04, systemd, K8s 1.32.x, Helm 3.16.x)

---

## 1. Topología de despliegue

```
Host físico / VPS (Ubuntu 24.04 LTS)
├── systemd daemon: bnotify.service     (Puerto 9450-9453, socket /run/bos/bnotify.sock)
│
└── Kubernetes (K8s 1.32.x)
    └── Namespaces:
        ├── infra/           PostgreSQL, Redis, NATS, Vault, Kong
        ├── identity/        Keycloak
        └── bns-messaging/   bRocket (StatefulSet), MongoDB, Jitsi, MinIO
```

bNotify corre como **systemd daemon en el host** (no en K8s) — patrón SBOS establecido.
Los servicios de infraestructura (PostgreSQL, Redis, NATS) corren en K8s namespace `infra`.

---

## 2. Unit systemd

```ini
# /etc/systemd/system/bnotify.service
[Unit]
Description=SBOS bNotify — Orchestrador de Notificaciones
After=network.target postgresql.service redis.service nats.service
Requires=network.target

[Service]
Type=notify
User=bnotify
Group=bosagent
ExecStart=/usr/local/bin/bnotify --config /etc/bnotify/config.toml
ExecReload=/bin/kill -HUP $MAINPID
Restart=always
RestartSec=5s
WatchdogSec=30s
TimeoutStartSec=30s
TimeoutStopSec=15s

# Secretos inyectados por Vault Agent como variables de entorno
EnvironmentFile=/run/bnotify/secrets.env

# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/run/bos /var/log/bnotify

[Install]
WantedBy=multi-user.target
```

### 2.1 Socket y permisos

```bash
# /run/bos/bnotify.sock — creado por el daemon al arrancar
# Permisos: 0660, usuario: bnotify, grupo: bosagent
# Los daemons emisores (bAuth, bPay, etc.) pertenecen al grupo bosagent
```

---

## 3. Secretos — Vault Agent Sidecar

Los secretos se inyectan desde Vault (no están en archivos de config):

```hcl
# vault-agent-bnotify.hcl
template {
  contents = <<EOF
BNOTIFY_DB_PASS={{ with secret "sbos/bnotify/database" }}{{ .Data.data.password }}{{ end }}
BNOTIFY_REDIS_PASS={{ with secret "sbos/bnotify/redis" }}{{ .Data.data.password }}{{ end }}
NATS_CREDENTIALS={{ with secret "sbos/bnotify/nats" }}{{ .Data.data.creds }}{{ end }}
FCM_SERVICE_ACCOUNT={{ with secret "sbos/bnotify/adapters/push/fcm/default" }}{{ .Data.data.json }}{{ end }}
EOF
  destination = "/run/bnotify/secrets.env"
  perms = "0600"
}
```

Vault Agent se ejecuta como sidecar del daemon bNotify y renueva los secretos
antes de que expiren. El daemon recibe `SIGHUP` cuando los secretos rotan.

---

## 4. Observabilidad

### 4.1 Métricas Prometheus

bNotify expone métricas en `http://localhost:9450/metrics` (no expuesto fuera del host).
Prometheus scraping configurado con `scrape_interval: 15s`.

**Dashboard Grafana "bNotify Overview" — 6 paneles core:**

| Panel | Métrica | Tipo |
|-------|---------|------|
| Dispatch rate | `bnotify_dispatch_total[5m]` | Rate |
| Latencia Dispatch | `histogram_quantile(0.99, bnotify_dispatch_latency_ms)` | Gauge |
| Cola por clase | `bnotify_queue_depth{class="A|B|C"}` | Gauge |
| Tasa de DLQ | `bnotify_dlq_total[5m]` | Rate |
| Entregas por canal | `bnotify_delivery_total{channel="..."}[5m]` | Rate |
| Errores CAEP | `bnotify_caep_events_total{type="session-revoked"}[5m]` | Rate |

### 4.2 Logs estructurados (tracing + Wazuh)

```json
// Formato de log (JSON a stdout, capturado por Wazuh)
{
  "timestamp": "2026-07-06T12:00:00.123Z",
  "level": "INFO",
  "service": "bnotify",
  "ctx_id": "{ctx_id}",
  "delivery_id": "{delivery_id}",
  "event_type": "{event_type}",
  "message": "Dispatch aceptado: clase A, canal chat"
}
```

---

## 5. Helm Charts (componentes K8s)

### 5.1 Namespaces y recursos de bRocket

```yaml
# charts/bns-messaging/values.yaml
rocketchat:
  replicaCount: 3
  resources:
    requests: { cpu: "500m", memory: "1Gi" }
    limits:   { cpu: "2", memory: "2Gi" }

mongodb:
  replicaCount: 3
  storage:
    size: "50Gi"
    class: "local-path"  # StorageClass del cluster

jitsi:
  enabled: true
  domain: "jitsi.sbos.internal"
```

### 5.2 Namespaces de infraestructura

Los charts de PostgreSQL, Redis, NATS y Vault son charts de la comunidad
(Bitnami, NATS org) con un `values.yaml` propio en `charts/infra/`.

---

## 6. Respaldos

### 6.1 PostgreSQL — schema bnotify

```bash
# Job diario (cron K8s o systemd timer):
pg_dump -h postgres.infra -U sbos_admin -n bnotify SBOS_db \
  | gzip > /backup/bnotify_$(date +%Y%m%d).sql.gz

# Retención: 30 días de backups diarios
# Verificación: restore semanal en staging con verificar_afirmacion.sh
```

### 6.2 MongoDB (bRocket)

```bash
# Mongodump del replica set — solo durante la era bRocket
mongodump --uri "mongodb://mongodb-0.mongodb:27017/?replicaSet=rs0" \
  --out /backup/mongodb_$(date +%Y%m%d)/
```

---

## 7. Runbooks — procedimientos de emergencia

### 7.1 Cola A se acumula (DLQ growing)

```
1. Verificar estado del adaptador del canal afectado:
   grpcurl -plaintext unix:///run/bos/bnotify.sock bnotify.v1.AdapterChannel/Health

2. Si CHANNEL_UNAVAILABLE: verificar el servicio externo (bRocket, FCM, etc.)

3. Si los workers clase A están caídos:
   journalctl -u bnotify --since "5 minutes ago" | grep ERROR

4. Reiniciar bNotify (las colas Redis persisten):
   systemctl restart bnotify

5. Verificar que la cola empieza a vaciarse:
   redis-cli ZCARD queue:A
```

### 7.2 ctx_id revocado no suspende entregas a tiempo

```
1. Verificar que bAuth está emitiendo CAEP:
   journalctl -u bauth --since "5 minutes ago" | grep "session-revoked"

2. Verificar que bNotify recibe el CAEP:
   journalctl -u bnotify --since "5 minutes ago" | grep "caep.session_revoked"

3. Verificar la caché Redis:
   redis-cli GET "revoked_ctx:{ctx_id}"
```

---

*BNOTIFY-071 v1.0.0 · BnotifyAgent/context/ · 2026-07-06*
*Un sistema que no se puede operar no se puede usar. La observabilidad y los runbooks son parte del sistema, no un complemento.*
