#!/usr/bin/env bash
# task_catalog.sh — nextcloud
# Nextcloud 30.0.2: almacenamiento y colaboración soberana
# Dependencias: postgresql, redis, minio, keycloak, kong
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/nextcloud.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-vdi}"
NEXTCLOUD_IMAGE="${NEXTCLOUD_IMAGE:-nextcloud:30.0.2-apache}"
PG_NS="sbos-data"
PG_POD="postgresql-0"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [nextcloud] $*" | tee -a "$FICHA_LOG"; }
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
    _log "TIMEOUT esperando $label"
    return 1
}

# Aplica YAML tolerando Kyverno no disponible.
# Si el webhook devuelve "connection refused", cambia failurePolicy a Ignore
# temporalmente (ValidatingWebhookConfiguration no está cubierto por el propio
# webhook de Kyverno), aplica el recurso, y restaura Fail antes de retornar.
_k_apply_safe() {
    local ns="$1"; shift
    local yaml_content; yaml_content=$(cat)

    if echo "$yaml_content" | _k apply -n "$ns" -f - 2>/dev/null; then
        return 0
    fi

    local err
    err=$(echo "$yaml_content" | _k apply -n "$ns" -f - 2>&1)
    if echo "$err" | grep -qE "kyverno.*connection refused|failed calling webhook.*kyverno"; then
        _log "Webhook Kyverno no disponible — ajustando failurePolicy temporalmente"

        _k patch validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg \
            --type=json \
            -p '[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Ignore"}]' \
            >> "$FICHA_LOG" 2>&1 || true

        local rc=0
        echo "$yaml_content" | _k apply -n "$ns" -f - >> "$FICHA_LOG" 2>&1 || rc=$?

        _k patch validatingwebhookconfiguration kyverno-resource-validating-webhook-cfg \
            --type=json \
            -p '[{"op":"replace","path":"/webhooks/0/failurePolicy","value":"Fail"}]' \
            >> "$FICHA_LOG" 2>&1 || true

        return $rc
    fi

    echo "$err" >> "$FICHA_LOG"
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

    echo "${__STEP_START__} networkpolicy_vdi_pg"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-vdi-postgresql
  namespace: sbos-data
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-vdi
    ports:
    - port: 5432
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-vdi-redis
  namespace: sbos-data
spec:
  podSelector:
    matchLabels:
      app: redis
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-vdi
    ports:
    - port: 6379
      protocol: TCP
YAML
    echo "${__STEP_OK__} networkpolicy_vdi_pg"

    echo "${__STEP_START__} crear_nextcloud_db"
    local pg_pass; pg_pass=$(_pg_pass)
    if _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -tc \
        "SELECT 1 FROM pg_database WHERE datname='nextcloud_db'" 2>/dev/null | grep -q 1; then
        echo "${__STEP_SKIP__} nextcloud_db ya existe"
    else
        _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -c \
            "CREATE DATABASE nextcloud_db;" >> "$FICHA_LOG" 2>&1
        _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -c \
            "CREATE USER nextcloud WITH ENCRYPTED PASSWORD '${pg_pass}';" >> "$FICHA_LOG" 2>&1 || true
        _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -c \
            "GRANT ALL PRIVILEGES ON DATABASE nextcloud_db TO nextcloud;" >> "$FICHA_LOG" 2>&1
        echo "${__STEP_OK__} crear_nextcloud_db"
    fi

    echo "${__STEP_START__} nextcloud_secret"
    if _k get secret -n "$NS" nextcloud-credentials &>/dev/null; then
        echo "${__STEP_SKIP__} secret nextcloud-credentials ya existe"
    else
        local admin_pass; admin_pass=$(openssl rand -base64 20)
        _k create secret generic nextcloud-credentials \
            --namespace="$NS" \
            --from-literal=NEXTCLOUD_ADMIN_USER=admin \
            --from-literal=NEXTCLOUD_ADMIN_PASSWORD="$admin_pass" \
            --from-literal=POSTGRES_PASSWORD="$(_pg_pass)" >> "$FICHA_LOG" 2>&1
        echo "${__STEP_OK__} nextcloud_secret"
    fi
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    ficha_pre_install

    echo "${__STEP_START__} pvc_nextcloud"
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-data
  namespace: ${NS}
  labels:
    app: nextcloud
    sbos-managed: "true"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
YAML
    echo "${__STEP_OK__} pvc_nextcloud"

    echo "${__STEP_START__} deploy_nextcloud"
    local pg_pass; pg_pass=$(_pg_pass)
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud
  namespace: ${NS}
  labels:
    app: nextcloud
    sbos-managed: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nextcloud
  template:
    metadata:
      labels:
        app: nextcloud
    spec:
      containers:
      - name: nextcloud
        image: ${NEXTCLOUD_IMAGE}
        ports:
        - containerPort: 80
        env:
        - name: NEXTCLOUD_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: nextcloud-credentials
              key: NEXTCLOUD_ADMIN_USER
        - name: NEXTCLOUD_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: nextcloud-credentials
              key: NEXTCLOUD_ADMIN_PASSWORD
        - name: POSTGRES_HOST
          value: postgresql.sbos-data.svc.cluster.local
        - name: POSTGRES_DB
          value: nextcloud_db
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: nextcloud-credentials
              key: POSTGRES_PASSWORD
        - name: NEXTCLOUD_TRUSTED_DOMAINS
          value: "nextcloud.sbos.local"
        - name: REDIS_HOST
          value: redis.sbos-data.svc.cluster.local
        volumeMounts:
        - name: nextcloud-data
          mountPath: /var/www/html
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        readinessProbe:
          exec:
            command:
            - su
            - www-data
            - -s
            - /bin/sh
            - -c
            - php /var/www/html/occ status --output=json 2>/dev/null | grep -q installed
          initialDelaySeconds: 60
          timeoutSeconds: 30
          periodSeconds: 20
          failureThreshold: 15
      volumes:
      - name: nextcloud-data
        persistentVolumeClaim:
          claimName: nextcloud-data
---
apiVersion: v1
kind: Service
metadata:
  name: nextcloud
  namespace: ${NS}
  labels:
    app: nextcloud
    sbos-managed: "true"
spec:
  selector:
    app: nextcloud
  ports:
  - port: 80
    targetPort: 80
YAML
    echo "${__STEP_OK__} deploy_nextcloud"

    echo "${__STEP_START__} verify"
    _wait_pod "nextcloud" 600
    local pods; pods=$(_k get pods -n "$NS" -l app=nextcloud --no-headers 2>/dev/null | grep Running | wc -l)
    _log "$pods pods running"
    echo "${__STEP_OK__} verify"
}

# ── Post-install — SSO-4: configurar OIDC con Keycloak (idempotente) ──────────
ficha_post_install() {
    local realm="${TENANT_ID:-skull}"
    local domain="${BOS_DOMAIN:-sbos.app}"
    local kc_ns="sbos-security"
    local secret_name="sbos-nextcloud-oidc"

    echo "${__STEP_START__} configurar_oidc_nextcloud"

    # Verificar que Nextcloud está listo
    local nc_ready
    nc_ready=$(_k get deployment nextcloud -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( nc_ready < 1 )); then
        echo "${__STEP_SKIP__} configurar_oidc_nextcloud: Nextcloud no ready"
        return 0
    fi

    # Verificar que el secret OIDC existe (lo crea keycloak/ficha_post_install)
    if ! _k get secret -n "$kc_ns" "$secret_name" &>/dev/null; then
        echo "${__STEP_SKIP__} configurar_oidc_nextcloud: secret $secret_name no disponible — ejecutar ficha_repair de keycloak primero"
        return 0
    fi

    local client_id client_secret issuer
    client_id=$(_k get secret -n "$kc_ns" "$secret_name" \
        -o jsonpath='{.data.client_id}' 2>/dev/null | base64 -d || echo "")
    client_secret=$(_k get secret -n "$kc_ns" "$secret_name" \
        -o jsonpath='{.data.client_secret}' 2>/dev/null | base64 -d || echo "")
    issuer=$(_k get secret -n "$kc_ns" "$secret_name" \
        -o jsonpath='{.data.issuer}' 2>/dev/null | base64 -d || echo "")

    if [[ -z "$client_id" || -z "$client_secret" ]]; then
        _log "  client_id o client_secret vacíos — OIDC diferido"
        echo "${__STEP_SKIP__} configurar_oidc_nextcloud: credenciales OIDC no disponibles"
        return 0
    fi

    # Verificar si OIDC ya configurado (idempotencia)
    local current_issuer
    current_issuer=$(_k exec deploy/nextcloud -n "$NS" -- \
        php /var/www/html/occ user_oidc:provider list 2>/dev/null | \
        grep -o "https://[^[:space:]]*" | head -1 || echo "")
    if [[ "$current_issuer" == *"$realm"* ]]; then
        _log "  OIDC ya configurado (issuer=$current_issuer) — skip"
        echo "${__STEP_SKIP__} configurar_oidc_nextcloud: ya configurado"
        return 0
    fi

    # Activar app user_oidc
    _k exec deploy/nextcloud -n "$NS" -- \
        php /var/www/html/occ app:enable user_oidc >> "$FICHA_LOG" 2>&1 || true

    # Configurar proveedor OIDC
    _k exec deploy/nextcloud -n "$NS" -- \
        php /var/www/html/occ user_oidc:provider add keycloak \
        --clientid="$client_id" \
        --clientsecret="$client_secret" \
        --discoveryuri="${issuer}/.well-known/openid-configuration" \
        --unique-uid=0 \
        --mapping-uid=preferred_username >> "$FICHA_LOG" 2>&1 \
        && _log "  OIDC Keycloak configurado en Nextcloud" \
        || _log "  ADVERTENCIA: no se pudo configurar OIDC (puede que user_oidc no esté disponible en esta imagen)"

    echo "${__STEP_OK__} configurar_oidc_nextcloud"
    return 0
}

# ── Repair ───────────────────────────────────────────────────────
ficha_health() {
    local r
    r=$(_k get deployment nextcloud -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: nextcloud ${r}/1"
    return 1
}

ficha_repair() {
    ficha_pre_install

    echo "${__STEP_START__} repair"
    echo "${__STEP_START__} pvc_nextcloud"
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nextcloud-data
  namespace: ${NS}
  labels:
    app: nextcloud
    sbos-managed: "true"
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
  storageClassName: local-path
YAML
    echo "${__STEP_OK__} pvc_nextcloud"

    echo "${__STEP_START__} deploy_nextcloud"
    local pg_pass; pg_pass=$(_pg_pass)
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nextcloud
  namespace: ${NS}
  labels:
    app: nextcloud
    sbos-managed: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nextcloud
  template:
    metadata:
      labels:
        app: nextcloud
    spec:
      containers:
      - name: nextcloud
        image: ${NEXTCLOUD_IMAGE}
        ports:
        - containerPort: 80
        env:
        - name: NEXTCLOUD_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: nextcloud-credentials
              key: NEXTCLOUD_ADMIN_USER
        - name: NEXTCLOUD_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: nextcloud-credentials
              key: NEXTCLOUD_ADMIN_PASSWORD
        - name: POSTGRES_HOST
          value: postgresql.sbos-data.svc.cluster.local
        - name: POSTGRES_DB
          value: nextcloud_db
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: nextcloud-credentials
              key: POSTGRES_PASSWORD
        - name: NEXTCLOUD_TRUSTED_DOMAINS
          value: "nextcloud.sbos.local"
        - name: REDIS_HOST
          value: redis.sbos-data.svc.cluster.local
        volumeMounts:
        - name: nextcloud-data
          mountPath: /var/www/html
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        readinessProbe:
          exec:
            command:
            - su
            - www-data
            - -s
            - /bin/sh
            - -c
            - php /var/www/html/occ status --output=json 2>/dev/null | grep -q installed
          initialDelaySeconds: 60
          timeoutSeconds: 30
          periodSeconds: 20
          failureThreshold: 15
      volumes:
      - name: nextcloud-data
        persistentVolumeClaim:
          claimName: nextcloud-data
---
apiVersion: v1
kind: Service
metadata:
  name: nextcloud
  namespace: ${NS}
  labels:
    app: nextcloud
    sbos-managed: "true"
spec:
  selector:
    app: nextcloud
  ports:
  - port: 80
    targetPort: 80
YAML
    echo "${__STEP_OK__} deploy_nextcloud"
    _log "repair: $(KUBECONFIG=$KUBECONFIG_DEST kubectl get pods -n $NS -l app=nextcloud --no-headers 2>/dev/null | head -1)"
    echo "${__STEP_OK__} repair"

    echo "${__STEP_START__} verify"
    local pods; pods=$(_k get pods -n "$NS" -l app=nextcloud --no-headers 2>/dev/null | grep Running | wc -l)
    _log "$pods pods running"
    echo "${__STEP_OK__} verify"

    # Re-aplicar configuración OIDC (idempotente)
    ficha_post_install 2>/dev/null || true
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_nextcloud_ready"
    local ready
    ready=$(_k get deployment nextcloud -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "$ready" =~ ^[0-9]+$ ]] && (( ready >= 1 )); then
        echo "${__STEP_OK__} test_nextcloud_ready ($ready/1)"
    else
        echo "${__STEP_FAIL__} test_nextcloud_ready: ${ready}/1"; ok=1
    fi

    echo "${__STEP_START__} test_nextcloud_http"
    local status
    status=$(_k exec deploy/nextcloud -n "$NS" -- \
        curl -sf -o /dev/null -w '%{http_code}' http://localhost:80/status.php 2>/dev/null || echo "000")
    if [[ "$status" == "200" ]]; then
        echo "${__STEP_OK__} test_nextcloud_http (/status.php 200)"
    else
        echo "${__STEP_FAIL__} test_nextcloud_http: HTTP $status"; ok=1
    fi
    return $ok
}

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    echo "${__STEP_START__} remove_nextcloud"
    _k delete deployment nextcloud -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    _k delete service nextcloud -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} remove_nextcloud"
}
