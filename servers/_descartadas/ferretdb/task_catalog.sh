#!/usr/bin/env bash
# task_catalog.sh — ferretdb
# FerretDB 2.0: MongoDB wire protocol → PostgreSQL storage
# Dependencias: postgresql (notifier_db)
set -euo pipefail

# readonly (removed for multi-source compatibility) __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
# readonly (removed for multi-source compatibility) __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
# readonly (removed for multi-source compatibility) __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
# readonly (removed for multi-source compatibility) __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/ferretdb.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
# readonly (removed for multi-source compatibility) NS="sbos-notifier"
# readonly (removed for multi-source compatibility) FERRETDB_IMAGE="ghcr.io/ferretdb/ferretdb:2.0.0"
# readonly (removed for multi-source compatibility) PG_HOST="postgresql.sbos-data.svc.cluster.local"
# readonly (removed for multi-source compatibility) PG_URL="postgres://postgres:$(kubectl --kubeconfig="$KUBECONFIG_DEST" get secret -n sbos-data pg-master-credentials -o jsonpath='{.data.password}' 2>/dev/null | base64 -d)@${PG_HOST}:5432/notifier_db"

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
    if _k get deployment ferretdb -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_SKIP__} ferretdb ya desplegado"
    else
        _k create deployment ferretdb -n "$NS" --image="$FERRETDB_IMAGE" \
            --replicas=1 --port=27017 --dry-run=client -o yaml | _k apply -f -
        echo "${__STEP_OK__} deploy_ferretdb"
    fi

    echo "${__STEP_START__} wait_ferretdb_ready"
    local timeout=90 elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app=ferretdb --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { echo "${__STEP_OK__} ferretdb Running"; return 0; }
        sleep 5; elapsed=$((elapsed + 5))
    done
    echo "${__STEP_FAIL__} ferretdb no arrancó"; return 1
}

# ── Health ────────────────────────────────────────────────────────
ficha_health_check() {
    local phase
    phase=$(_k get pod -n "$NS" -l app=ferretdb -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$phase" == "True" ]] && { echo "${__STEP_OK__} ferretdb Ready"; return 0; }
    echo "${__STEP_FAIL__} ferretdb no Ready"; return 1
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} remove_ferretdb"
    _k delete deployment ferretdb -n "$NS" --ignore-not-found=true
    _k delete svc ferretdb -n "$NS" --ignore-not-found=true
    echo "${__STEP_OK__} ferretdb removido"
}

export -f ficha_pre_install ficha_install ficha_health_check ficha_uninstall
