#!/usr/bin/env bash
# task_catalog.sh — calcom
# Cal.com 6.1: Calendario profesional open-source (AGPLv3)
# Dependencias: postgresql, keycloak, vault, kong
# DB: calcom_db en PostgreSQL S01 · Auth: OIDC contra Keycloak
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/calcom.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-collab}"
CALCOM_IMAGE="${CALCOM_IMAGE:-calcom/cal.com:v6.2.0}"
KC_ISSUER="${KC_ISSUER:-http://keycloak.sbos-security.svc.cluster.local:8080/realms/sbos}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [calcom] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_pod() {
    local label="$1" timeout="${2:-120}" elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app="$label" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { _log "$label Running"; return 0; }
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} networkpolicies_calcom"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-calcom-postgresql
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
          kubernetes.io/metadata.name: sbos-collab
    ports:
    - port: 5432
      protocol: TCP
YAML
    echo "${__STEP_OK__} networkpolicies_calcom"

    echo "${__STEP_START__} crear_calcom_db"
    _k exec postgresql-0 -n sbos-data -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='calcom_db'" 2>/dev/null | grep -q 1 \
        && echo "${__STEP_SKIP__} calcom_db ya existe" \
        || { _k exec postgresql-0 -n sbos-data -- psql -U postgres -c "CREATE DATABASE calcom_db OWNER postgres;" 2>/dev/null \
             && echo "${__STEP_OK__} calcom_db creada" \
             || { echo "${__STEP_FAIL__} no se pudo crear calcom_db"; return 1; }; }
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    # BUG-44: idempotencia P15 — si ya hay pods Running, no reinstalar
    local _running
    _running=$(_k get pods -n "$NS" -l app=calcom --no-headers 2>/dev/null \
        | grep -c "Running" || echo "0")
    if (( _running >= 1 )); then
        _log "calcom ya tiene ${_running} pods Running — skip reinstalación"
        echo "${__STEP_SKIP__} deploy_calcom: ya running (${_running} pods)"
        return 0
    fi

    local _pg_pass _nextauth_secret _enc_key
    _pg_pass=$(_k get secret -n sbos-data postgresql-credentials \
        -o jsonpath='{.data.POSTGRES_PASSWORD}' 2>/dev/null | base64 -d 2>/dev/null || echo "sbos_bootstrap_pass")
    local PG_DSN="postgresql://postgres:${_pg_pass}@postgresql.sbos-data.svc.cluster.local:5432/calcom_db"
    _nextauth_secret=$(cat /etc/bos/.calcom-nextauth-secret 2>/dev/null || \
        { openssl rand -base64 32 | tr -d '\n' | tee /etc/bos/.calcom-nextauth-secret; chmod 600 /etc/bos/.calcom-nextauth-secret; cat /etc/bos/.calcom-nextauth-secret; })
    _enc_key=$(cat /etc/bos/.calcom-enc-key 2>/dev/null || \
        { openssl rand -hex 16 | tee /etc/bos/.calcom-enc-key; chmod 600 /etc/bos/.calcom-enc-key; cat /etc/bos/.calcom-enc-key; })

    echo "${__STEP_START__} crear_namespace"
    _k create namespace "$NS" --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} crear_namespace"

    echo "${__STEP_START__} deploy_calcom"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: calcom
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: calcom
  template:
    metadata:
      labels:
        app: calcom
    spec:
      containers:
      - name: calcom
        image: ${CALCOM_IMAGE}
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
        env:
        - name: DATABASE_URL
          value: "${PG_DSN}"
        - name: DATABASE_DIRECT_URL
          value: "${PG_DSN}"
        - name: NEXTAUTH_SECRET
          value: "${_nextauth_secret}"
        - name: NEXTAUTH_URL
          value: "https://calcom.sbos.local"
        - name: CALENDSO_ENCRYPTION_KEY
          value: "${_enc_key}"
        - name: NODE_ENV
          value: "production"
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /api/auth/session
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: calcom
  namespace: ${NS}
spec:
  type: ClusterIP
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: calcom
YAML
    echo "${__STEP_OK__} deploy_calcom"
    _wait_pod "calcom" 300 || { _log "ADVERTENCIA: calcom no llegó a Running — deployment aplicado"; return 0; }
}

# ── Health ────────────────────────────────────────────────────────
ficha_health() {
    ficha_health_check
}

ficha_health_check() {
    _k exec deploy/calcom -n "$NS" -- curl -sf http://localhost:3000/api/auth/session > /dev/null 2>&1 \
        && { echo "${__STEP_OK__} calcom health OK"; return 0; } \
        || { echo "${__STEP_FAIL__} calcom health fail"; return 1; }
}

# ── Repair (re-aplica estado completo — idempotente) ─────────────
ficha_repair() {
    ficha_pre_install
    ficha_install
}

# ── Test ─────────────────────────────────────────────────────────
ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_calcom_pod"
    local pods
    pods=$(_k get pods -n "$NS" -l app=calcom --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( pods >= 1 )); then
        echo "${__STEP_OK__} test_calcom_pod ($pods Running)"
    else
        echo "${__STEP_FAIL__} test_calcom_pod: 0 pods Running"; ok=1
    fi

    echo "${__STEP_START__} test_calcom_http"
    local status
    status=$(_k exec -n "$NS" deploy/calcom -- \
        curl -sf -o /dev/null -w '%{http_code}' http://localhost:3000/api/health 2>/dev/null || echo "000")
    if [[ "$status" == "200" ]]; then
        echo "${__STEP_OK__} test_calcom_http (/api/health 200)"
    else
        echo "${__STEP_FAIL__} test_calcom_http: HTTP $status"; ok=1
    fi
    return $ok
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} remove_calcom"
    _k delete deployment calcom -n "$NS" --ignore-not-found=true
    _k delete svc calcom -n "$NS" --ignore-not-found=true
    echo "${__STEP_OK__} calcom removido"
}

export -f ficha_pre_install ficha_install ficha_repair ficha_health_check ficha_test ficha_uninstall
