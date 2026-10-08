#!/usr/bin/env bash
# task_catalog.sh — ferretdb
# FerretDB 2.0: MongoDB wire protocol → PostgreSQL storage
# Dependencias: postgresql (notifier_db)
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/ferretdb.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-notifier}"
FERRETDB_IMAGE="${FERRETDB_IMAGE:-ghcr.io/ferretdb/ferretdb:2.0.0}"
PG_HOST="${PG_HOST:-postgresql.sbos-data.svc.cluster.local}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [ferretdb] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }
_apply() {
    local label="$1" content="$2" tmp rc=0
    tmp=$(mktemp /tmp/sbos-ferret-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} networkpolicy_postgresql"
    _k create namespace "$NS" --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1 || true
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-notifier-postgresql
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
          kubernetes.io/metadata.name: ${NS}
    ports:
    - port: 5432
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ferretdb-egress-pg
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: ferretdb
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-data
    ports:
    - port: 5432
      protocol: TCP
  - to:
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
YAML
    echo "${__STEP_OK__} networkpolicy_postgresql"

    echo "${__STEP_START__} verificar_postgresql"
    _k get pod postgresql-0 -n sbos-data > /dev/null 2>&1 || { echo "${__STEP_FAIL__} postgresql-0 no disponible"; return 1; }
    echo "${__STEP_OK__} verificar_postgresql"

    echo "${__STEP_START__} crear_notifier_db"
    _k exec postgresql-0 -n sbos-data -- psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='notifier_db'" 2>/dev/null | grep -q 1 \
        && echo "${__STEP_SKIP__} notifier_db ya existe" \
        || { _k exec postgresql-0 -n sbos-data -- psql -U postgres -c "CREATE DATABASE notifier_db OWNER postgres;" 2>/dev/null \
             && echo "${__STEP_OK__} notifier_db creada" \
             || { echo "${__STEP_FAIL__} no se pudo crear notifier_db"; return 1; }; }
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    echo "${__STEP_START__} deploy_ferretdb"
    local _pg_pass
    _pg_pass=$(_k get secret -n sbos-data pg-master-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo "postgres")
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ferretdb
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ferretdb
  template:
    metadata:
      labels:
        app: ferretdb
    spec:
      containers:
      - name: ferretdb
        image: ${FERRETDB_IMAGE}
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
        env:
        - name: FERRETDB_POSTGRESQL_URL
          value: "postgres://postgres:${_pg_pass}@${PG_HOST}:5432/notifier_db?sslmode=disable"
        ports:
        - containerPort: 27017
        readinessProbe:
          tcpSocket:
            port: 27017
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: ferretdb
  namespace: ${NS}
spec:
  type: ClusterIP
  ports:
  - port: 27017
    targetPort: 27017
  selector:
    app: ferretdb
YAML
    echo "${__STEP_OK__} deploy_ferretdb"

    echo "${__STEP_START__} wait_ferretdb_ready"
    local timeout=120 elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app=ferretdb --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { echo "${__STEP_OK__} ferretdb Running"; return 0; }
        sleep 10; elapsed=$((elapsed + 10))
    done
    _log "ADVERTENCIA: ferretdb no llegó a Running en ${timeout}s — deployment aplicado"
    echo "${__STEP_SKIP__} wait_ferretdb_ready: timeout no fatal"
    return 0
}

# ── Health ────────────────────────────────────────────────────────
ficha_health_check() {
    local phase
    phase=$(_k get pod -n "$NS" -l app=ferretdb -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$phase" == "True" ]] && { echo "${__STEP_OK__} ferretdb Ready"; return 0; }
    echo "${__STEP_FAIL__} ferretdb no Ready"; return 1
}

# ── Repair (re-aplica estado completo — idempotente) ─────────────
ficha_repair() {
    ficha_pre_install
    ficha_install
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} remove_ferretdb"
    _k delete deployment ferretdb -n "$NS" --ignore-not-found=true
    _k delete svc ferretdb -n "$NS" --ignore-not-found=true
    echo "${__STEP_OK__} ferretdb removido"
}

export -f ficha_pre_install ficha_install ficha_repair ficha_health_check ficha_uninstall
