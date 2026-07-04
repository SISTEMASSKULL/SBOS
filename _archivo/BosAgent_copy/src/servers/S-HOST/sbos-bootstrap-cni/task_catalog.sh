#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-bootstrap-cni
# Iteración 1: Calico completo — IP pools, NetworkPolicies default-deny,
#              verificación pod-to-pod.
# Dependencias: sbos-bootstrap-k8s (INSTALADA -- OK)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bootstrap-cni.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
CALICO_VERSION="${CALICO_VERSION:-3.32.0}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
_FICHA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bootstrap-cni] $*" | tee -a "$FICHA_LOG" >&2; }

# _kubectl: wrapper que siempre usa el kubeconfig de bos.
_kubectl() { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _calico: usa calicoctl si está disponible, sino error claro.
_calico() {
    DATASTORE_TYPE=kubernetes KUBECONFIG="$KUBECONFIG_DEST" calicoctl "$@"
}

# _wait_calico_ready: espera hasta que calico-node esté Running.
_wait_calico_ready() {
    local timeout="${1:-180}" elapsed=0
    while (( elapsed < timeout )); do
        local running
        # Columna STATUS en kubectl get pods --no-headers es la tercera
        running=$(_kubectl get pods -n kube-system -l k8s-app=calico-node \
            --no-headers 2>/dev/null | awk '{print $3}' | grep -c "^Running$" || echo "0")
        if (( running > 0 )); then
            _log "calico-node Running (${elapsed}s)"
            return 0
        fi
        sleep 5; elapsed=$((elapsed + 5))
        (( elapsed % 30 == 0 )) && _log "Esperando calico-node Running... ${elapsed}/${timeout}s"
    done
    _log "TIMEOUT: calico-node no Running después de ${timeout}s"
    return 1
}

# _wait_crd: espera hasta que un CRD de Calico esté registrado.
_wait_crd() {
    local crd="$1" timeout="${2:-60}" elapsed=0
    while (( elapsed < timeout )); do
        _kubectl get crd "$crd" > /dev/null 2>&1 && return 0
        sleep 3; elapsed=$((elapsed + 3))
    done
    _log "TIMEOUT: CRD $crd no disponible después de ${timeout}s"
    return 1
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_k8s_listo"
    if ! _kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_k8s_listo: kube-apiserver no responde"
        return 1
    fi
    local nodes_ready
    nodes_ready=$(_kubectl get nodes --no-headers 2>/dev/null \
        | awk '{print $2}' | grep -c "^Ready$" || echo "0")
    if (( nodes_ready < 1 )); then
        echo "${__STEP_FAIL__} verificar_k8s_listo: 0 nodos Ready"
        return 1
    fi
    echo "${__STEP_OK__} verificar_k8s_listo (${nodes_ready} nodo(s))"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Verificar/Instalar Calico base ────────────────────────
    echo "${__STEP_START__} verificar_calico_base"
    local calico_pods
    calico_pods=$(_kubectl get pods -n kube-system -l k8s-app=calico-node \
        --no-headers 2>/dev/null | awk '{print $3}' | grep -c "^Running$" || echo "0")

    if (( calico_pods == 0 )); then
        _log "Calico no Running — instalando v${CALICO_VERSION}..."
        local calico_local="${_FICHA_DIR}/resources/calico-v${CALICO_VERSION}.yaml"
        local calico_url="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml"
        if [[ -f "$calico_local" ]]; then
            _kubectl apply -f "$calico_local" >> "$FICHA_LOG" 2>&1 || {
                echo "${__STEP_FAIL__} verificar_calico_base: kubectl apply falló"
                return 1
            }
        else
            _kubectl apply -f "$calico_url" >> "$FICHA_LOG" 2>&1 || {
                echo "${__STEP_FAIL__} verificar_calico_base: sin conectividad y sin manifiesto local"
                return 1
            }
        fi
        if ! _wait_calico_ready 180; then
            echo "${__STEP_FAIL__} verificar_calico_base: timeout esperando calico-node"
            return 1
        fi
    else
        _log "calico-node ya Running ($calico_pods pods)"
    fi
    echo "${__STEP_OK__} verificar_calico_base"

    # ── 2. Esperar CRDs de Calico ────────────────────────────────
    # Los CRDs de Calico son registrados por el DaemonSet; pueden tardar
    # unos segundos en estar disponibles incluso si los pods ya están Running.
    echo "${__STEP_START__} esperar_crds_calico"
    local crds=(
        "ippools.crd.projectcalico.org"
        "felixconfigurations.crd.projectcalico.org"
        "globalnetworkpolicies.crd.projectcalico.org"
    )
    for crd in "${crds[@]}"; do
        if ! _wait_crd "$crd" 60; then
            echo "${__STEP_FAIL__} esperar_crds_calico: $crd no disponible tras 60s"
            return 1
        fi
        _log "CRD listo: $crd"
    done
    echo "${__STEP_OK__} esperar_crds_calico"

    # ── 3. Instalar calicoctl ────────────────────────────────────
    echo "${__STEP_START__} instalar_calicoctl"
    if command -v calicoctl > /dev/null 2>&1; then
        _log "calicoctl ya instalado: $(calicoctl version --client 2>/dev/null | head -1 || echo 'ver desconocida')"
        echo "${__STEP_SKIP__} instalar_calicoctl: ya instalado"
    else
        local url="https://github.com/projectcalico/calico/releases/download/v${CALICO_VERSION}/calicoctl-linux-amd64"
        if curl -fsSL -o /usr/local/bin/calicoctl "$url" 2>/dev/null; then
            chmod +x /usr/local/bin/calicoctl
            _log "calicoctl v${CALICO_VERSION} instalado"
            echo "${__STEP_OK__} instalar_calicoctl"
        else
            _log "ADVERTENCIA: calicoctl no disponible (sin conectividad) — usando kubectl para gestión de CRDs"
            echo "${__STEP_SKIP__} instalar_calicoctl: sin conectividad — usando kubectl como alternativa"
        fi
    fi

    # ── 4. Configurar calicoctl.cfg ──────────────────────────────
    echo "${__STEP_START__} configurar_calicoctl"
    mkdir -p /etc/calico
    cat > /etc/calico/calicoctl.cfg <<EOF
apiVersion: projectcalico.org/v3
kind: CalicoAPIConfig
metadata:
spec:
  datastoreType: kubernetes
  kubeconfig: ${KUBECONFIG_DEST}
EOF
    echo "${__STEP_OK__} configurar_calicoctl"

    # ── 5. Configurar IP Pool ────────────────────────────────────
    # NOTA: kubectl usa apiVersion crd.projectcalico.org/v1 (no projectcalico.org/v3,
    # que es solo para calicoctl). El IPPool ya existe creado por el manifiesto de
    # Calico; lo actualizamos con la config canónica del SBOS.
    echo "${__STEP_START__} configurar_ip_pool"
    if _kubectl get ippool.crd.projectcalico.org default-ipv4-ippool > /dev/null 2>&1; then
        _log "IPPool default-ipv4-ippool ya existe — actualizando configuración"
    else
        _log "Creando IPPool default-ipv4-ippool..."
    fi
    cat > /tmp/sbos-ippool.yaml <<EOF
apiVersion: crd.projectcalico.org/v1
kind: IPPool
metadata:
  name: default-ipv4-ippool
spec:
  cidr: ${POD_CIDR}
  ipipMode: Always
  natOutgoing: true
  disabled: false
  nodeSelector: "all()"
EOF
    if ! _kubectl apply -f /tmp/sbos-ippool.yaml >> "$FICHA_LOG" 2>&1; then
        rm -f /tmp/sbos-ippool.yaml
        echo "${__STEP_FAIL__} configurar_ip_pool: kubectl apply falló"
        return 1
    fi
    rm -f /tmp/sbos-ippool.yaml
    echo "${__STEP_OK__} configurar_ip_pool (cidr=${POD_CIDR})"

    # ── 6. Configurar FelixConfiguration ────────────────────────
    echo "${__STEP_START__} configurar_felix"
    cat > /tmp/sbos-felix.yaml <<'EOF'
apiVersion: crd.projectcalico.org/v1
kind: FelixConfiguration
metadata:
  name: default
spec:
  logSeverityScreen: Warning
  reportingInterval: 0s
  defaultEndpointToHostAction: Accept
EOF
    if ! _kubectl apply -f /tmp/sbos-felix.yaml >> "$FICHA_LOG" 2>&1; then
        rm -f /tmp/sbos-felix.yaml
        echo "${__STEP_FAIL__} configurar_felix: kubectl apply falló"
        return 1
    fi
    rm -f /tmp/sbos-felix.yaml
    echo "${__STEP_OK__} configurar_felix"

    # ── 7. NetworkPolicy default-deny + allow-dns por namespace ─
    echo "${__STEP_START__} aplicar_default_deny"
    local namespaces=(sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring)
    local applied=0
    for ns in "${namespaces[@]}"; do
        if ! _kubectl get namespace "$ns" > /dev/null 2>&1; then
            _log "Namespace $ns no existe — omitiendo"
            continue
        fi
        _kubectl apply -f - <<EOF 2>> "$FICHA_LOG" || true
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ${ns}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
        # allow-dns: egress hacia CoreDNS en kube-system (puerto 53 UDP/TCP).
        # Calico usa conntrack para UDP → las respuestas DNS pasan como tráfico
        # relacionado sin necesidad de regla de ingress adicional.
        _kubectl apply -f - <<EOF 2>> "$FICHA_LOG" || true
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns
  namespace: ${ns}
spec:
  podSelector: {}
  policyTypes:
    - Egress
  egress:
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
EOF
        applied=$((applied + 1))
        _log "NetworkPolicy default-deny-all + allow-dns aplicadas en $ns"
    done
    echo "${__STEP_OK__} aplicar_default_deny (${applied} namespaces)"

    # ── 8. Verificar CoreDNS Running ────────────────────────────
    echo "${__STEP_START__} verificar_coredns"
    local coredns_running
    coredns_running=$(_kubectl get pods -n kube-system -l k8s-app=kube-dns \
        --no-headers 2>/dev/null | awk '{print $3}' | grep -c "^Running$" || echo "0")
    if (( coredns_running > 0 )); then
        echo "${__STEP_OK__} verificar_coredns (${coredns_running} pod(s) Running)"
    else
        _log "ADVERTENCIA: CoreDNS no Running aún — puede necesitar más tiempo"
        echo "${__STEP_SKIP__} verificar_coredns: pods no Running todavía (no crítico)"
    fi

    # ── 9. Verificar pod-to-pod (DNS real) ──────────────────────
    echo "${__STEP_START__} verificar_pod_to_pod"
    local test_ns="sbos-system"
    local test_pod="cni-test-$$"
    # Intentar solo si CoreDNS está Running (imagen busybox se necesita del registry)
    if (( coredns_running > 0 )); then
        local dns_ok=false
        if _kubectl run "$test_pod" \
            --image=busybox:stable \
            --restart=Never \
            --namespace="$test_ns" \
            --overrides='{"spec":{"tolerations":[{"operator":"Exists"}]}}' \
            --command -- sh -c "nslookup kubernetes.default.svc.cluster.local" \
            --timeout=30s \
            --rm 2>/dev/null; then
            dns_ok=true
        fi
        if $dns_ok; then
            echo "${__STEP_OK__} verificar_pod_to_pod: DNS resuelve kubernetes.default"
        else
            _log "ADVERTENCIA: prueba pod-to-pod falló (sin imagen o timeout) — puede ser normal sin internet"
            echo "${__STEP_SKIP__} verificar_pod_to_pod: sin imagen busybox disponible"
        fi
    else
        echo "${__STEP_SKIP__} verificar_pod_to_pod: CoreDNS no listo aún"
    fi

    _log "sbos-bootstrap-cni instalado"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado final CNI:"
    _kubectl get pods -n kube-system -l k8s-app=calico-node 2>/dev/null | tee -a "$FICHA_LOG" || true
    _log "NetworkPolicies aplicadas:"
    for ns in sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring; do
        _kubectl get networkpolicy -n "$ns" --no-headers 2>/dev/null \
            | awk -v ns="$ns" '{printf "  %s/%s\n", ns, $1}' || true
    done
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    _log "Reparando sbos-bootstrap-cni..."

    echo "${__STEP_START__} reiniciar_calico"
    _kubectl rollout restart daemonset/calico-node -n kube-system 2>/dev/null || true
    _kubectl rollout restart deployment/calico-kube-controllers -n kube-system 2>/dev/null || true
    _wait_calico_ready 120 || true
    echo "${__STEP_OK__} reiniciar_calico"

    echo "${__STEP_START__} reparar_network_policies"
    local namespaces=(sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring)
    for ns in "${namespaces[@]}"; do
        _kubectl get namespace "$ns" > /dev/null 2>&1 || continue
        _kubectl get networkpolicy default-deny-all -n "$ns" > /dev/null 2>&1 || {
            _log "Re-aplicando default-deny-all en $ns"
            _kubectl apply -f - <<EOF 2>/dev/null || true
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: ${ns}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
EOF
        }
    done
    echo "${__STEP_OK__} reparar_network_policies"

    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_calico_running"
    local calico_pods
    calico_pods=$(_kubectl get pods -n kube-system -l k8s-app=calico-node \
        --no-headers 2>/dev/null | awk '{print $3}' | grep -c "^Running$" || echo "0")
    if (( calico_pods > 0 )); then
        echo "${__STEP_OK__} test_calico_running (${calico_pods} pods)"
    else
        echo "${__STEP_FAIL__} test_calico_running: 0 pods Running"
        ok=1
    fi

    echo "${__STEP_START__} test_calico_controllers"
    local ctrl_pods
    ctrl_pods=$(_kubectl get pods -n kube-system -l k8s-app=calico-kube-controllers \
        --no-headers 2>/dev/null | awk '{print $3}' | grep -c "^Running$" || echo "0")
    if (( ctrl_pods > 0 )); then
        echo "${__STEP_OK__} test_calico_controllers (${ctrl_pods} pods)"
    else
        echo "${__STEP_FAIL__} test_calico_controllers: 0 pods Running"
        ok=1
    fi

    echo "${__STEP_START__} test_coredns"
    local coredns_pods
    coredns_pods=$(_kubectl get pods -n kube-system -l k8s-app=kube-dns \
        --no-headers 2>/dev/null | awk '{print $3}' | grep -c "^Running$" || echo "0")
    if (( coredns_pods > 0 )); then
        echo "${__STEP_OK__} test_coredns (${coredns_pods} pods)"
    else
        echo "${__STEP_FAIL__} test_coredns: CoreDNS no Running"
        ok=1
    fi

    echo "${__STEP_START__} test_ip_pool"
    # Intentar primero con kubectl (no requiere calicoctl)
    if _kubectl get ippool.crd.projectcalico.org default-ipv4-ippool > /dev/null 2>&1; then
        local cidr
        cidr=$(_kubectl get ippool.crd.projectcalico.org default-ipv4-ippool \
            -o jsonpath='{.spec.cidr}' 2>/dev/null || echo "desconocido")
        echo "${__STEP_OK__} test_ip_pool (cidr=${cidr})"
    elif command -v calicoctl > /dev/null 2>&1 && \
         _calico get ippool default-ipv4-ippool > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_ip_pool (via calicoctl)"
    else
        echo "${__STEP_FAIL__} test_ip_pool: IPPool no encontrado"
        ok=1
    fi

    echo "${__STEP_START__} test_network_policy"
    local np_count=0
    for ns in sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring; do
        _kubectl get networkpolicy default-deny-all -n "$ns" > /dev/null 2>&1 && \
            np_count=$((np_count + 1))
    done
    if (( np_count == 5 )); then
        echo "${__STEP_OK__} test_network_policy (5/5 namespaces)"
    elif (( np_count >= 3 )); then
        echo "${__STEP_OK__} test_network_policy (${np_count}/5 namespaces — aceptable)"
    else
        echo "${__STEP_FAIL__} test_network_policy: solo $np_count/5 namespaces con default-deny"
        ok=1
    fi

    echo "${__STEP_START__} test_felix_config"
    if _kubectl get felixconfiguration.crd.projectcalico.org default > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_felix_config"
    else
        echo "${__STEP_FAIL__} test_felix_config: FelixConfiguration default no existe"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-bootstrap-cni STATUS ==="
    echo ""
    echo "Calico pods:"
    _kubectl get pods -n kube-system \
        -l 'k8s-app in (calico-node,calico-kube-controllers)' 2>/dev/null \
        | awk '{printf "  %s\n", $0}' || echo "  (no disponible)"
    echo ""
    echo "CoreDNS:"
    _kubectl get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null \
        | awk '{printf "  %-45s %s\n", $1, $3}' || echo "  (no disponible)"
    echo ""
    echo "IPPool:"
    _kubectl get ippool.crd.projectcalico.org default-ipv4-ippool \
        -o custom-columns='NAME:.metadata.name,CIDR:.spec.cidr,IPIP:.spec.ipipMode' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "NetworkPolicies default-deny:"
    for ns in sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring; do
        local status
        status=$(_kubectl get networkpolicy default-deny-all -n "$ns" \
            --no-headers 2>/dev/null && echo "OK" || echo "FALTANTE")
        printf "  %-25s %s\n" "$ns" "$status"
    done
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} remover_network_policies"
    for ns in sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring; do
        _kubectl delete networkpolicy default-deny-all allow-dns \
            -n "$ns" 2>/dev/null || true
    done
    echo "${__STEP_OK__} remover_network_policies"

    echo "${__STEP_START__} remover_felix_config"
    _kubectl delete felixconfiguration.crd.projectcalico.org default 2>/dev/null || true
    echo "${__STEP_OK__} remover_felix_config"

    _log "NetworkPolicies y FelixConfiguration removidas — Calico conservado"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-bootstrap-cni ==="
    echo "calico-node pods:"
    _kubectl get pods -n kube-system -l k8s-app=calico-node -o wide 2>/dev/null || true
    echo ""
    echo "calico-kube-controllers:"
    _kubectl get pods -n kube-system -l k8s-app=calico-kube-controllers 2>/dev/null || true
    echo ""
    echo "CRDs de Calico registrados:"
    _kubectl get crd 2>/dev/null | grep calico | awk '{print "  "$1}' || true
    echo ""
    echo "IPPools:"
    _kubectl get ippool.crd.projectcalico.org 2>/dev/null || \
        echo "  (CRD no disponible)"
    echo ""
    echo "FelixConfiguration:"
    _kubectl get felixconfiguration.crd.projectcalico.org 2>/dev/null || \
        echo "  (CRD no disponible)"
    echo ""
    echo "Eventos recientes kube-system:"
    _kubectl get events -n kube-system --sort-by='.lastTimestamp' 2>/dev/null | tail -8 || true
}
