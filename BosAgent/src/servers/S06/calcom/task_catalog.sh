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
CALCOM_IMAGE="${CALCOM_IMAGE:-calcom/cal.com:6.1.0}"
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
    echo "${__STEP_START__} crear_calcom_db"
    _k exec postgresql-0 -n sbos-data -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='calcom_db'" 2>/dev/null | grep -q 1 \
        && echo "${__STEP_SKIP__} calcom_db ya existe" \
        || { _k exec postgresql-0 -n sbos-data -- psql -U postgres -c "CREATE DATABASE calcom_db OWNER postgres;" 2>/dev/null \
             && echo "${__STEP_OK__} calcom_db creada" \
             || { echo "${__STEP_FAIL__} no se pudo crear calcom_db"; return 1; }; }

    echo "${__STEP_START__} verificar_keycloak"
    _k get pod -n sbos-security -l app=keycloak > /dev/null 2>&1 || { echo "${__STEP_FAIL__} keycloak no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_keycloak"
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    local _pg_pass
    _pg_pass=$(_k get secret -n sbos-data pg-master-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "postgres")
    local DB_URL="postgresql://postgres:${_pg_pass}@postgresql.sbos-data.svc.cluster.local:5432/calcom_db"

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
          value: "${DB_URL}"
        - name: CALCOM_OIDC_ISSUER
          value: "${KC_ISSUER}"
        - name: CALCOM_OIDC_CLIENT_ID
          value: "calcom"
        - name: NEXTAUTH_URL
          value: "https://calcom.sbos.local"
        - name: NODE_ENV
          value: "production"
        ports:
        - containerPort: 3000
        readinessProbe:
          httpGet:
            path: /api/health
            port: 3000
          initialDelaySeconds: 60
          periodSeconds: 10
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
    _wait_pod "calcom" 180
}

# ── Health ────────────────────────────────────────────────────────
ficha_health_check() {
    _k exec deploy/calcom -n "$NS" -- curl -sf http://localhost:3000/api/health > /dev/null 2>&1 \
        && { echo "${__STEP_OK__} calcom health OK"; return 0; } \
        || { echo "${__STEP_FAIL__} calcom health fail"; return 1; }
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} remove_calcom"
    _k delete deployment calcom -n "$NS" --ignore-not-found=true
    _k delete svc calcom -n "$NS" --ignore-not-found=true
    echo "${__STEP_OK__} calcom removido"
}

export -f ficha_pre_install ficha_install ficha_health_check ficha_uninstall
