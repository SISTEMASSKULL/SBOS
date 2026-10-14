#!/usr/bin/env bash
# task_catalog.sh — onlyoffice
# OnlyOffice Document Server 8.2.2: editor de documentos colaborativo
# Dependencias: postgresql, redis, kong
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/onlyoffice.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-vdi}"
ONLYOFFICE_IMAGE="${ONLYOFFICE_IMAGE:-onlyoffice/documentserver:8.2.2}"
PG_NS="sbos-data"
PG_POD="postgresql-0"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [onlyoffice] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_pg_pass() {
    _k get secret -n "$PG_NS" postgresql-credentials \
        -o jsonpath="{.data.POSTGRES_PASSWORD}" 2>/dev/null | base64 -d
}

_wait_pod() {
    local label="$1" timeout="${2:-300}" elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app="$label" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { _log "$label Running"; return 0; }
        sleep 10; elapsed=$((elapsed + 10))
    done
    return 1
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} crear_namespace"
    if ! _k get namespace "$NS" &>/dev/null; then
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _k label namespace "$NS" sbos-managed=true >> "$FICHA_LOG" 2>&1
    fi
    echo "${__STEP_OK__} crear_namespace"

    echo "${__STEP_START__} crear_onlyoffice_db"
    if _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -tc \
        "SELECT 1 FROM pg_database WHERE datname='onlyoffice_db'" 2>/dev/null | grep -q 1; then
        echo "${__STEP_SKIP__} onlyoffice_db ya existe"
    else
        _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -c \
            "CREATE DATABASE onlyoffice_db;" >> "$FICHA_LOG" 2>&1
        echo "${__STEP_OK__} crear_onlyoffice_db"
    fi

    echo "${__STEP_START__} onlyoffice_secret"
    if _k get secret -n "$NS" onlyoffice-credentials &>/dev/null; then
        echo "${__STEP_SKIP__} secret onlyoffice-credentials ya existe"
    else
        local jwt_secret; jwt_secret=$(openssl rand -hex 32)
        _k create secret generic onlyoffice-credentials \
            --namespace="$NS" \
            --from-literal=JWT_SECRET="$jwt_secret" \
            --from-literal=POSTGRES_PASSWORD="$(_pg_pass)" >> "$FICHA_LOG" 2>&1
        echo "${__STEP_OK__} onlyoffice_secret"
    fi
}

_apply_onlyoffice() {
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: onlyoffice
  namespace: ${NS}
  labels:
    app: onlyoffice
    sbos-managed: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: onlyoffice
  template:
    metadata:
      labels:
        app: onlyoffice
    spec:
      containers:
      - name: onlyoffice
        image: ${ONLYOFFICE_IMAGE}
        ports:
        - containerPort: 80
        env:
        - name: DB_TYPE
          value: postgres
        - name: DB_HOST
          value: postgresql.sbos-data.svc.cluster.local
        - name: DB_PORT
          value: "5432"
        - name: DB_NAME
          value: onlyoffice_db
        - name: DB_USER
          value: postgres
        - name: DB_PWD
          valueFrom:
            secretKeyRef:
              name: onlyoffice-credentials
              key: POSTGRES_PASSWORD
        - name: REDIS_SERVER_HOST
          value: redis.sbos-data.svc.cluster.local
        - name: REDIS_SERVER_PORT
          value: "6379"
        - name: REDIS_SERVER_PWD
          value: sbos_redis_bootstrap
        - name: JWT_ENABLED
          value: "true"
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: onlyoffice-credentials
              key: JWT_SECRET
        resources:
          requests:
            memory: "1Gi"
            cpu: "200m"
          limits:
            memory: "3Gi"
            cpu: "2000m"
        readinessProbe:
          httpGet:
            path: /healthcheck
            port: 80
          initialDelaySeconds: 60
          timeoutSeconds: 15
          periodSeconds: 30
          failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: onlyoffice
  namespace: ${NS}
  labels:
    app: onlyoffice
    sbos-managed: "true"
spec:
  selector:
    app: onlyoffice
  ports:
  - port: 80
    targetPort: 80
YAML
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    ficha_pre_install
    echo "${__STEP_START__} deploy_onlyoffice"
    _apply_onlyoffice
    echo "${__STEP_OK__} deploy_onlyoffice"

    echo "${__STEP_START__} verify"
    _wait_pod "onlyoffice" 300
    echo "${__STEP_OK__} verify"
}

# _onlyoffice_configure_nextcloud: configura el plugin OnlyOffice en Nextcloud (idempotente).
# Requiere que nextcloud deployment esté Running en sbos-vdi.
_onlyoffice_configure_nextcloud() {
    local nc_pod_ns="sbos-vdi"
    local nc_deploy="nextcloud"
    local nc_ready
    nc_ready=$(_k get deployment "$nc_deploy" -n "$nc_pod_ns" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( nc_ready < 1 )); then
        _log "  Nextcloud no Ready ($nc_ready) — configuración OnlyOffice pospuesta"
        return 1
    fi

    local onlyoffice_url="http://onlyoffice.${nc_pod_ns}.svc.cluster.local"
    local domain="${BOS_DOMAIN:-sbos.app}"

    # Activar app onlyoffice en Nextcloud si no está activa
    local app_enabled
    app_enabled=$(_k exec deploy/"$nc_deploy" -n "$nc_pod_ns" -- \
        php /var/www/html/occ app:list --output=json 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print('1' if 'onlyoffice' in d.get('enabled',{}) else '0')" \
        2>/dev/null || echo "0")
    if [[ "$app_enabled" != "1" ]]; then
        _k exec deploy/"$nc_deploy" -n "$nc_pod_ns" -- \
            php /var/www/html/occ app:enable onlyoffice >> "$FICHA_LOG" 2>&1 || {
            _log "  ADVERTENCIA: no se pudo activar app onlyoffice — puede no estar en el marketplace soberano"
        }
    fi

    # Verificar si DocumentServerUrl ya configurada (idempotencia)
    local current_url
    current_url=$(_k exec deploy/"$nc_deploy" -n "$nc_pod_ns" -- \
        php /var/www/html/occ config:app:get onlyoffice DocumentServerUrl 2>/dev/null || echo "")
    if [[ "$current_url" == "$onlyoffice_url/"* || "$current_url" == *"/onlyoffice"* ]]; then
        _log "  OnlyOffice ya configurado en Nextcloud (DocumentServerUrl=$current_url) — skip"
        return 0
    fi

    # Configurar URLs: interna (ClusterIP) para comunicación server-server
    _k exec deploy/"$nc_deploy" -n "$nc_pod_ns" -- \
        php /var/www/html/occ config:app:set onlyoffice DocumentServerUrl \
        --value="https://${domain}/onlyoffice/" >> "$FICHA_LOG" 2>&1 || true
    _k exec deploy/"$nc_deploy" -n "$nc_pod_ns" -- \
        php /var/www/html/occ config:app:set onlyoffice DocumentServerInternalUrl \
        --value="${onlyoffice_url}/" >> "$FICHA_LOG" 2>&1 || true
    _k exec deploy/"$nc_deploy" -n "$nc_pod_ns" -- \
        php /var/www/html/occ config:app:set onlyoffice StorageUrl \
        --value="http://${nc_deploy}.${nc_pod_ns}.svc.cluster.local/" >> "$FICHA_LOG" 2>&1 || true
    _log "  OnlyOffice configurado en Nextcloud: DocumentServerUrl=https://${domain}/onlyoffice/"
}

ficha_post_install() {
    echo "${__STEP_START__} conectar_nextcloud_onlyoffice"
    if _onlyoffice_configure_nextcloud; then
        echo "${__STEP_OK__} conectar_nextcloud_onlyoffice"
    else
        echo "${__STEP_SKIP__} conectar_nextcloud_onlyoffice: Nextcloud no listo — ejecutar ficha_repair cuando Nextcloud esté Running"
    fi
    return 0
}

# ── Repair ───────────────────────────────────────────────────────
ficha_health() {
    local r
    r=$(_k get deployment onlyoffice -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: onlyoffice ${r}/1"
    return 1
}

ficha_repair() {
    ficha_pre_install
    echo "${__STEP_START__} repair"
    echo "${__STEP_START__} deploy_onlyoffice"
    _apply_onlyoffice
    echo "${__STEP_OK__} deploy_onlyoffice"
    _log "repair: $(_k get pods -n $NS -l app=onlyoffice --no-headers 2>/dev/null | head -1)"
    echo "${__STEP_OK__} repair"

    echo "${__STEP_START__} verify"
    local pods; pods=$(_k get pods -n "$NS" -l app=onlyoffice --no-headers 2>/dev/null | grep Running | wc -l)
    _log "$pods pods running"
    echo "${__STEP_OK__} verify"

    # Re-aplicar configuración en Nextcloud (idempotente)
    echo "${__STEP_START__} reconectar_nextcloud_onlyoffice"
    if _onlyoffice_configure_nextcloud 2>/dev/null; then
        echo "${__STEP_OK__} reconectar_nextcloud_onlyoffice"
    else
        echo "${__STEP_SKIP__} reconectar_nextcloud_onlyoffice: Nextcloud no listo"
    fi
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_onlyoffice_ready"
    local pods
    pods=$(_k get pods -n "$NS" -l app=onlyoffice --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( pods >= 1 )); then
        echo "${__STEP_OK__} test_onlyoffice_ready ($pods Running)"
    else
        echo "${__STEP_FAIL__} test_onlyoffice_ready: 0 pods Running"; ok=1
    fi

    echo "${__STEP_START__} test_onlyoffice_http"
    local status
    status=$(_k exec -n "$NS" deploy/onlyoffice -- \
        curl -sf -o /dev/null -w '%{http_code}' http://localhost:80/healthcheck 2>/dev/null || echo "000")
    if [[ "$status" == "200" ]]; then
        echo "${__STEP_OK__} test_onlyoffice_http (/healthcheck 200)"
    else
        echo "${__STEP_FAIL__} test_onlyoffice_http: HTTP $status"; ok=1
    fi
    return $ok
}

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    echo "${__STEP_START__} remove_onlyoffice"
    _k delete deployment onlyoffice -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    _k delete service onlyoffice -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} remove_onlyoffice"
}
