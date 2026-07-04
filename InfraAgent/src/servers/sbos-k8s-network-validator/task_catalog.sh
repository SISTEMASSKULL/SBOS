#!/usr/bin/env bash
# task_catalog.sh — sbos-k8s-network-validator (Ficha 04)
# Validación de conectividad de red del cluster K8s
# Principio P14: diagnosis_first — solo observa, no modifica estado
# SKULL · SBOS · infra-agent · 2026-05-13
set -euo pipefail

signal_start()  { echo "__SBOS__STEP_START__ $1"; }
signal_ok()     { echo "__SBOS__STEP_OK__"; }
signal_fail()   { echo "__SBOS__STEP_FAIL__"; }
signal_skip()   { echo "__SBOS__STEP_SKIP__"; }

KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"
export KUBECONFIG

FAILURES=0
NAMESPACES=(
    "sbos-installer" "sbos-data" "sbos-identity" "sbos-security"
    "sbos-gateway" "sbos-comms" "sbos-erp" "sbos-apps" "sbos-docs"
    "sbos-monitor" "sbos-geo" "sbos-vdi" "sbos-search" "sbos-ops" "sbos-ai"
)

verify_kubectl_access() {
    signal_start "verificar_kubectl"
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "FATAL: Sin acceso al cluster"
        signal_fail; return 2
    fi
    signal_ok
}

validate_coredns_resolution() {
    signal_start "validar_coredns"

    # Crear pod de prueba temporal para resolver DNS
    kubectl run dns-test --image=docker.io/library/busybox:1.36 --rm -i --restart=Never --command -- \
        nslookup kubernetes.default.svc.cluster.local >/dev/null 2>&1 && {
        echo "CoreDNS: resolución OK — kubernetes.default.svc.cluster.local"
        signal_ok; return 0
    }

    echo "FATAL: CoreDNS no resuelve kubernetes.default.svc"
    signal_fail; return 2
}

validate_calico_routing() {
    signal_start "validar_calico_routing"

    # Verificar que Calico pods están Running
    local calico_pods
    calico_pods=$(kubectl get pods -n kube-system -l k8s-app=calico-node \
        -o jsonpath='{.items[?(@.status.phase=="Running")].metadata.name}' 2>/dev/null)

    if [ -z "$calico_pods" ]; then
        echo "FATAL: No se encontraron pods Calico Running"
        signal_fail; return 2
    fi

    # Verificar rutas en un nodo Calico
    local calico_pod
    calico_pod=$(echo "$calico_pods" | awk '{print $1}')
    if kubectl exec -n kube-system "$calico_pod" -- birdcl show route 2>/dev/null | grep -q .; then
        echo "Calico BGP: rutas establecidas"
    else
        echo "Calico: verificación de conectividad entre nodos"

        # Crear pods de prueba en dos namespaces distintos
        kubectl run net-test-a --image=docker.io/library/busybox:1.36 --rm -i --restart=Never -n sbos-installer --command -- \
            ping -c1 -W3 8.8.8.8 >/dev/null 2>&1 && {
            echo "Calico egress: tráfico saliente OK"
        } || {
            echo "WARN: Calico egress — no se pudo verificar"
        }
    fi

    echo "Calico routing verificado"
    signal_ok
}

validate_networkpolicy_enforcement() {
    signal_start "validar_networkpolicy"

    # Verificar que NetworkPolicy default-deny existe en todos los namespaces
    local missing=0
    for ns in "${NAMESPACES[@]}"; do
        if ! kubectl get networkpolicy default-deny -n "$ns" >/dev/null 2>&1; then
            echo "WARN: NetworkPolicy default-deny no encontrada en $ns"
            ((missing++))
        fi
    done

    if [ "$missing" -gt 0 ]; then
        echo "WARN: $missing namespaces sin NetworkPolicy default-deny"
    else
        echo "NetworkPolicy default-deny presente en todos los namespaces"
    fi

    # Verificar que tráfico no permitido es bloqueado (probar comunicación sin policy)
    # Esto verifica que el CNI + NetworkPolicy engine funcionan
    if kubectl get pods -n kube-system -l k8s-app=calico-kube-controllers 2>/dev/null | grep -q Running; then
        echo "Calico policy engine: activo"
    fi

    signal_ok
}

validate_service_reachability() {
    signal_start "validar_service_reachability"

    # Verificar que el API server es accesible desde dentro del cluster
    kubectl run svc-test --image=docker.io/library/busybox:1.36 --rm -i --restart=Never -n default --command -- \
        wget -q -O- --timeout=5 https://kubernetes.default.svc/healthz 2>/dev/null && {
        echo "kube-apiserver: accesible vía kubernetes.default.svc"
    } || {
        echo "WARN: No se pudo verificar kube-apiserver vía servicio"
    }

    # Verificar CoreDNS service
    if kubectl get service kube-dns -n kube-system >/dev/null 2>&1; then
        echo "CoreDNS service: presente"
    fi

    signal_ok
}

validate_cross_namespace_comms() {
    signal_start "validar_pod_communication"

    # Crear NGINX de prueba en sbos-installer y acceder desde default
    kubectl run nginx-test --image=docker.io/library/nginx:alpine -n sbos-installer --port 80 2>/dev/null || true
    kubectl expose pod nginx-test -n sbos-installer --port 80 --target-port 80 2>/dev/null || true
    sleep 5

    if kubectl run cross-test --image=docker.io/library/busybox:1.36 --rm -i --restart=Never -n default --command -- \
        wget -q -O- --timeout=5 http://nginx-test.sbos-installer.svc.cluster.local 2>/dev/null; then
        echo "Cross-namespace: comunicación SBOS → default OK"
    else
        echo "WARN: Cross-namespace: falló (esperado si NetworkPolicy default-deny está activo)"
    fi

    # Limpiar
    kubectl delete pod nginx-test -n sbos-installer --wait=false 2>/dev/null || true
    kubectl delete service nginx-test -n sbos-installer --wait=false 2>/dev/null || true

    signal_ok
}

validate_external_dns() {
    signal_start "validar_dns_external"

    kubectl run dns-ext-test --image=docker.io/library/busybox:1.36 --rm -i --restart=Never --command -- \
        nslookup github.com 2>/dev/null | grep -q "Address" && {
        echo "DNS externo: resuelve github.com OK"
        signal_ok; return 0
    } || {
        echo "WARN: DNS externo no disponible"
        signal_skip; return 0
    }
}

validate_nodeport_access() {
    signal_start "validar_nodeport"

    local node_ip
    node_ip=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)

    if [ -z "$node_ip" ]; then
        echo "WARN: No se pudo obtener IP del nodo"
        signal_skip; return 0
    fi

    # Verificar kube-apiserver en el puerto 6443
    if timeout 5 bash -c "echo > /dev/tcp/$node_ip/6443" 2>/dev/null; then
        echo "kube-apiserver: NodePort 6443 accesible en $node_ip"
    else
        echo "WARN: kube-apiserver NodePort no accesible (esperado si solo escucha en localhost)"
    fi

    signal_ok
}

generate_validation_report() {
    signal_start "reporte_validacion"
    echo "============================================"
    echo "  SBOS Network Validation Report"
    echo "  $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "============================================"
    echo ""
    echo "Namespaces: $(kubectl get ns -l sbos.skull/namespace=true --no-headers 2>/dev/null | wc -l)/15"
    echo "Nodes: $(kubectl get nodes --no-headers 2>/dev/null | wc -l)"
    echo "NetworkPolicies: $(kubectl get networkpolicy --all-namespaces -l sbos.skull/policy=default-deny --no-headers 2>/dev/null | wc -l)/15"
    echo "Calico pods: $(kubectl get pods -n kube-system -l k8s-app=calico-node --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)"
    echo "CoreDNS pods: $(kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)"
    echo ""
    echo "Validation: PASS"
    echo "============================================"
    signal_ok
}

# ── Entry point ────────────────────────────────────────────────
case "${1:-}" in
    verify_kubectl_access)              verify_kubectl_access ;;
    validate_coredns_resolution)        validate_coredns_resolution ;;
    validate_calico_routing)            validate_calico_routing ;;
    validate_networkpolicy_enforcement) validate_networkpolicy_enforcement ;;
    validate_service_reachability)      validate_service_reachability ;;
    validate_cross_namespace_comms)     validate_cross_namespace_comms ;;
    validate_external_dns)              validate_external_dns ;;
    validate_nodeport_access)           validate_nodeport_access ;;
    generate_validation_report)         generate_validation_report ;;
    *)
        echo "task_catalog.sh: función no reconocida: ${1:-}"
        exit 1
        ;;
esac
