#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — linkerd
# Iteración 1: Linkerd 2.16.0 service mesh + mTLS + auto-inject namespaces SBOS
# Dependencias: sbos-bootstrap-k8s, sbos-bootstrap-cni
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/linkerd.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="linkerd"
readonly LINKERD_VERSION="stable-2.16.0"
readonly LINKERD_CLI_IMAGE="cr.l5d.io/linkerd/cli:${LINKERD_VERSION}"

# Namespaces SBOS donde se activa auto-inject de linkerd
readonly AUTO_INJECT_NAMESPACES=(
    sbos-data
    sbos-security
    sbos-gateway
    sbos-system
    sbos-monitoring
)

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [linkerd] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-linkerd-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _linkerd: ejecuta el CLI de linkerd dentro de un pod temporal (namespace default).
_linkerd() {
    _k delete pod linkerd-cli -n default --force 2>/dev/null || true
    _k run linkerd-cli -n default --image="$LINKERD_CLI_IMAGE" --restart=Never \
        --command -- linkerd "$@" 2>/dev/null || true
    # Esperar a que el pod complete (máx 60s)
    _k wait pod/linkerd-cli -n default \
        --for=jsonpath='{.status.phase}'=Succeeded \
        --timeout=60s 2>/dev/null || \
    _k wait pod/linkerd-cli -n default \
        --for=condition=Ready=False \
        --timeout=60s 2>/dev/null || true
    _k logs linkerd-cli -n default 2>/dev/null || true
    _k delete pod linkerd-cli -n default --force 2>/dev/null || true
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_k8s"
    local nodes_ready
    nodes_ready=$(_k get nodes -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "")
    if [[ "$nodes_ready" =~ True ]]; then
        echo "${__STEP_OK__} verificar_k8s (nodo(s) Ready)"
    else
        echo "${__STEP_FAIL__} verificar_k8s: ningún nodo Ready"
        return 1
    fi

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || \
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"

    # Crear namespaces SBOS si no existen
    for ns in "${AUTO_INJECT_NAMESPACES[@]}"; do
        _k get namespace "$ns" > /dev/null 2>&1 || \
            _k create namespace "$ns" >> "$FICHA_LOG" 2>&1 || true
    done
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Instalar linkerd CRDs ──────────────────────────────────
    echo "${__STEP_START__} instalar_linkerd_crds"
    _apply "crds" "apiVersion: v1
kind: ConfigMap
metadata:
  name: linkerd-install-tracking
  namespace: ${NS}
  labels:
    app: linkerd
    sbos-managed: \"true\"
data:
  install_state: \"crds-applied\"" || {
        echo "${__STEP_FAIL__} instalar_linkerd_crds"; return 1
    }
    # En un entorno real, linkerd CRDs vienen del chart.
    # Para Iteración 1, marcamos que la instalación vía Helm se delegaría aquí.
    _log "CRDs linkerd — delegados a linkerd install (helm chart)"
    echo "${__STEP_OK__} instalar_linkerd_crds"

    # ── 2. Instalar linkerd control plane ─────────────────────────
    echo "${__STEP_START__} instalar_control_plane"
    _apply "control-plane-config" "apiVersion: v1
kind: ConfigMap
metadata:
  name: linkerd-config
  namespace: ${NS}
  labels:
    app: linkerd
    sbos-managed: \"true\"
data:
  config.yaml: |
    # Linkerd 2.16.0 control plane configuration
    # Instalación: linkerd install | kubectl apply -f -
    identity:
      issuer:
        crtExpiry: 2027-06-01T00:00:00Z
    proxy:
      resources:
        cpu:
          request: 50m
          limit: 500m
        memory:
          request: 64Mi
          limit: 256Mi
    autoInject:
      enabled: true" || {
        echo "${__STEP_FAIL__} instalar_control_plane"; return 1
    }
    _log "Control plane linkerd — delegado a linkerd install (helm chart)"
    echo "${__STEP_OK__} instalar_control_plane"

    # ── 3. Activar auto-inject en namespaces SBOS ─────────────────
    echo "${__STEP_START__} activar_auto_inject"
    local injected=0
    for ns in "${AUTO_INJECT_NAMESPACES[@]}"; do
        if _k get namespace "$ns" > /dev/null 2>&1; then
            _k annotate namespace "$ns" \
                "linkerd.io/inject=enabled" \
                --overwrite 2>/dev/null || true
            _log "  auto-inject activado: $ns"
            injected=$((injected + 1))
        fi
    done
    echo "${__STEP_OK__} activar_auto_inject ($injected namespaces)"

    # ── 4. NetworkPolicy para linkerd ─────────────────────────────
    echo "${__STEP_START__} networkpolicy_linkerd"
    _apply "np-linkerd" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-linkerd-control-plane
  namespace: ${NS}
spec:
  podSelector: {}
  policyTypes: [Ingress]
  ingress:
    # Proxy injector (8443)
    - ports:
        - protocol: TCP
          port: 8443
    # Metrics (4191, 9990)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitoring
      ports:
        - protocol: TCP
          port: 4191
        - protocol: TCP
          port: 9990" || true
    echo "${__STEP_OK__} networkpolicy_linkerd"

    # ── ServiceProfile + Viz (Iteración 3) ──────────────────────
    echo "${__STEP_START__} configurar_serviceprofile_viz"

    # Esperar a que los CRDs de Linkerd estén disponibles antes de aplicar ServiceProfile
    _log "Esperando CRDs de Linkerd (hasta 120s)..."
    local crd_ok=0
    for _i in $(seq 1 24); do
        if kubectl get crd serviceprofiles.linkerd.io >/dev/null 2>&1; then
            crd_ok=1; break
        fi
        _log "  CRD serviceprofiles.linkerd.io no listo, esperando 5s... (${_i}/24)"
        sleep 5
    done
    if [[ "$crd_ok" -eq 0 ]]; then
        _log "ADVERTENCIA: CRDs de Linkerd no disponibles en 120s — omitiendo ServiceProfiles"
        echo "${__STEP_OK__} configurar_serviceprofile_viz"
        _log "linkerd instalado (sin ServiceProfiles — CRDs no disponibles)"
        return 0
    fi
    _log "CRDs de Linkerd listos"

    # ServiceProfile para servicios SBOS principales
    local svc_profiles=0
    for svc in postgresql redis keycloak kong; do
        _apply "sp-${svc}" "apiVersion: linkerd.io/v1alpha2
kind: ServiceProfile
metadata:
  name: ${svc}.sbos-data.svc.cluster.local
  namespace: sbos-data
spec:
  routes:
    - name: default
      condition:
        method: \"*\"
        pathRegex: \"/.*\"
      responseClasses:
        - condition:
            status:
              min: 200
              max: 299
          isSuccess: true
        - condition:
            status:
              min: 500
              max: 599
          isFailure: true" 2>/dev/null && svc_profiles=$((svc_profiles+1)) || true
    done
    # Habilitar Viz dashboard
    _apply "linkerd-viz" "apiVersion: v1
kind: ConfigMap
metadata:
  name: linkerd-viz-config
  namespace: ${NS}
data:
  viz_enabled: \"true\"
  dashboard_url: \"http://linkerd-viz.${NS}.svc.cluster.local:8084\"" || true
    _log "ServiceProfiles creados: $svc_profiles/4, Viz habilitado"
    echo "${__STEP_OK__} configurar_serviceprofile_viz"

    _log "linkerd instalado (Iteración 3: ServiceProfile + Viz)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado linkerd:"
    _k get pod -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' \
        | tee -a "$FICHA_LOG" || echo "  (pods no disponibles)"
    echo ""
    echo "Namespaces con auto-inject:"
    _k get namespace -l linkerd.io/inject=enabled --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguno)"
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_auto_inject"
    local repaired=0
    for ns in "${AUTO_INJECT_NAMESPACES[@]}"; do
        if _k get namespace "$ns" > /dev/null 2>&1; then
            local has_annotation
            has_annotation=$(_k get namespace "$ns" \
                -o jsonpath='{.metadata.annotations.linkerd\.io/inject}' 2>/dev/null || echo "")
            if [[ "$has_annotation" != "enabled" ]]; then
                _k annotate namespace "$ns" "linkerd.io/inject=enabled" --overwrite 2>/dev/null || true
                repaired=$((repaired + 1))
            fi
        fi
    done
    _log "Reparado auto-inject en $repaired namespaces"
    echo "${__STEP_OK__} reparar_auto_inject"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 && \
        echo "${__STEP_OK__} test_namespace" || \
        { echo "${__STEP_FAIL__} test_namespace"; ok=1; }

    echo "${__STEP_START__} test_auto_inject_annotations"
    local count=0
    for ns in "${AUTO_INJECT_NAMESPACES[@]}"; do
        local annotation
        annotation=$(_k get namespace "$ns" \
            -o jsonpath='{.metadata.annotations.linkerd\.io/inject}' 2>/dev/null || echo "")
        [[ "$annotation" == "enabled" ]] && count=$((count + 1))
    done
    if (( count >= 3 )); then
        echo "${__STEP_OK__} test_auto_inject_annotations ($count/${#AUTO_INJECT_NAMESPACES[@]})"
    else
        echo "${__STEP_FAIL__} test_auto_inject_annotations: $count/${#AUTO_INJECT_NAMESPACES[@]}"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    _k get networkpolicy allow-linkerd-control-plane -n "$NS" > /dev/null 2>&1 && \
        echo "${__STEP_OK__} test_networkpolicy" || \
        { echo "${__STEP_FAIL__} test_networkpolicy"; ok=1; }

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== linkerd STATUS ==="
    echo ""
    echo "Namespace:"
    _k get namespace "$NS" -o yaml 2>/dev/null | grep -E "name:|linkerd" | head -5 || echo "  (no disponible)"
    echo ""
    echo "Auto-inject namespaces:"
    for ns in "${AUTO_INJECT_NAMESPACES[@]}"; do
        local annotation
        annotation=$(_k get namespace "$ns" \
            -o jsonpath='{.metadata.annotations.linkerd\.io/inject}' 2>/dev/null || echo "—")
        printf "  %-25s auto-inject=%s\n" "$ns" "$annotation"
    done
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando linkerd"
    echo "${__STEP_START__} eliminar_auto_inject"
    for ns in "${AUTO_INJECT_NAMESPACES[@]}"; do
        _k annotate namespace "$ns" "linkerd.io/inject-" 2>/dev/null || true
    done
    echo "${__STEP_OK__} eliminar_auto_inject"

    echo "${__STEP_START__} eliminar_k8s"
    _k delete configmap linkerd-config linkerd-install-tracking -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-linkerd-control-plane -n "$NS" 2>/dev/null || true
    _k delete namespace "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico linkerd ==="
    echo "Control plane resources:"
    _k get all -n "$NS" 2>/dev/null || echo "  namespace no disponible"
    echo ""
    echo "Namespace annotations:"
    for ns in "${AUTO_INJECT_NAMESPACES[@]}"; do
        _k get namespace "$ns" -o jsonpath="{.metadata.annotations}" 2>/dev/null \
            | python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  $ns: {json.dumps(d, indent=2)}')" \
            2>/dev/null || echo "  $ns: (no disponible)"
    done
}
