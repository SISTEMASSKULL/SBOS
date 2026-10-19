#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-namespace
# Crea un namespace K8s con NetworkPolicy default-deny + labels para el tenant.
# Idempotente: si el namespace ya existe, actualiza labels y continúa.
#
# Variables de entorno:
#   TENANT_ID      — ID del tenant (default: skull)
#   TENANT_NAME    — nombre visible (default: "SKULL Tenant")
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-namespace.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly TENANT_ID="${TENANT_ID:-skull}"
readonly TENANT_NAME="${TENANT_NAME:-SKULL Tenant}"
readonly DOMAIN_ID="${DOMAIN_ID:-${TENANT_ID}-prod}"
readonly DOMAIN_TYPE="${DOMAIN_TYPE:-production}"
readonly NS="sbos-${TENANT_ID}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-namespace] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2" tmp rc=0
    tmp=$(mktemp /tmp/sbos-ns-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# ── Pre-install ───────────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_k8s"
    if ! _k get nodes --no-headers 2>/dev/null | grep -q " Ready "; then
        echo "${__STEP_FAIL__} verificar_k8s: cluster K8s no disponible"
        return 1
    fi
    echo "${__STEP_OK__} verificar_k8s"
    return 0
}

# ── Install ───────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Crear namespace ───────────────────────────────────────────
    echo "${__STEP_START__} crear_namespace"
    if _k get namespace "$NS" > /dev/null 2>&1; then
        _log "namespace $NS ya existe — actualizando labels"
        _k label namespace "$NS" \
            tenant="${TENANT_ID}" \
            name="${TENANT_NAME}" \
            domain-id="${DOMAIN_ID}" \
            domain-type="${DOMAIN_TYPE}" \
            managed-by="bos" \
            sbos-namespace="true" \
            --overwrite 2>/dev/null || true
    else
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _k label namespace "$NS" \
            tenant="${TENANT_ID}" \
            name="${TENANT_NAME}" \
            domain-id="${DOMAIN_ID}" \
            domain-type="${DOMAIN_TYPE}" \
            managed-by="bos" \
            sbos-namespace="true" \
            --overwrite 2>/dev/null || true
        _log "namespace $NS creado"
    fi
    echo "${__STEP_OK__} crear_namespace"

    # ── 2. NetworkPolicy default-deny ────────────────────────────────
    echo "${__STEP_START__} crear_networkpolicy"
    _apply "default-deny" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ${NS}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress"
    _log "NetworkPolicy default-deny aplicada en ${NS}"
    echo "${__STEP_OK__} crear_networkpolicy"

    # ── 3. ResourceQuota ─────────────────────────────────────────────
    echo "${__STEP_START__} crear_resourcequota"
    _apply "resource-quota" "apiVersion: v1
kind: ResourceQuota
metadata:
  name: tenant-quota
  namespace: ${NS}
spec:
  hard:
    requests.cpu: '16'
    requests.memory: 64Gi
    limits.cpu: '32'
    limits.memory: 128Gi
    persistentvolumeclaims: '20'
    pods: '50'
    services: '20'
    secrets: '100'
    configmaps: '50'"
    _log "ResourceQuota aplicada en ${NS}"
    echo "${__STEP_OK__} crear_resourcequota"

    # ── 4. LimitRange ────────────────────────────────────────────────
    echo "${__STEP_START__} crear_limitrange"
    _apply "limit-range" "apiVersion: v1
kind: LimitRange
metadata:
  name: tenant-limits
  namespace: ${NS}
spec:
  limits:
    - default:
        cpu: '500m'
        memory: 512Mi
      defaultRequest:
        cpu: '100m'
        memory: 128Mi
      type: Container"
    _log "LimitRange aplicada en ${NS}"
    echo "${__STEP_OK__} crear_limitrange"

    _log "namespace ${NS} instalado (tenant=${TENANT_ID})"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado namespace ${NS}:"
    _k get namespace "$NS" -o jsonpath='{.metadata.name}{"\t"}{.status.phase}' 2>/dev/null \
        | tee -a "$FICHA_LOG" || _log "namespace no encontrado"
    echo ""
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  NP: %s\n", $1}' | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_namespace"
    ficha_install
    echo "${__STEP_OK__} reparar_namespace"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_namespace"
    if _k get namespace "$NS" --no-headers 2>/dev/null | grep -q Active; then
        echo "${__STEP_OK__} test_namespace"
    else
        echo "${__STEP_FAIL__} test_namespace: no existe o no Active"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    if _k get networkpolicy default-deny-all -n "$NS" --no-headers 2>/dev/null | grep -q .; then
        echo "${__STEP_OK__} test_networkpolicy"
    else
        echo "${__STEP_FAIL__} test_networkpolicy: no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_labels"
    local tenant_label
    tenant_label=$(_k get namespace "$NS" -o jsonpath='{.metadata.labels.tenant}' 2>/dev/null || echo "")
    if [[ "$tenant_label" == "$TENANT_ID" ]]; then
        echo "${__STEP_OK__} test_labels (tenant=${tenant_label})"
    else
        echo "${__STEP_FAIL__} test_labels: esperado=${TENANT_ID} real=${tenant_label}"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-namespace STATUS (${NS}) ==="
    echo ""
    _k get namespace "$NS" -o json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
print('  name:     ' + d['metadata']['name'])
print('  phase:    ' + d['status']['phase'])
print('  tenant:   ' + d['metadata'].get('labels',{}).get('tenant','?'))
print('  managed:  ' + d['metadata'].get('labels',{}).get('managed-by','?'))
" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
    echo ""
    echo "ResourceQuota:"
    _k get resourcequota -n "$NS" --no-headers 2>/dev/null | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: eliminando namespace ${NS}"
    echo "${__STEP_START__} eliminar_namespace"
    _k delete namespace "$NS" --wait=false 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_namespace (asíncrono)"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico namespace ${NS} ==="
    _k describe namespace "$NS" 2>/dev/null | grep -E "Name:|Status:|tenant=" || echo "  namespace no encontrado"
    echo ""
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
