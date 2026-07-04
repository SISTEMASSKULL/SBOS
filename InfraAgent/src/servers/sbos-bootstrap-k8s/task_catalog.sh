#!/usr/bin/env bash
# task_catalog.sh — sbos-bootstrap-k8s (Ficha 02)
# Inicializa el cluster K8s: kubeadm init, Calico eBPF, MetalLB, ingress
# Principios: P1 (único kubectl apply), P2 (pre_install ABORT), P10 (--dry-run)
# SKULL · SBOS · infra-agent · 2026-05-13
set -euo pipefail

signal_start()  { echo "__SBOS__STEP_START__ $1"; }
signal_ok()     { echo "__SBOS__STEP_OK__"; }
signal_fail()   { echo "__SBOS__STEP_FAIL__"; }
signal_skip()   { echo "__SBOS__STEP_SKIP__"; }
signal_rollback(){ echo "__SBOS__ROLLBACK_START__"; }

K8S_MIN="1.28"
KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

# ═══════════════════════════════════════════════════════════════
# PRE-INSTALL
# ═══════════════════════════════════════════════════════════════

verify_k8s_version_128() {
    signal_start "verificar_k8s_128"
    local v
    v=$(kubeadm version -o short 2>/dev/null | sed 's/v//')
    if [ -z "$v" ]; then
        echo "FATAL: kubeadm no encontrado. Ejecute Ficha 01 primero."
        signal_fail; return 2
    fi
    if ! printf '%s\n' "$K8S_MIN" "$v" | sort -V -C 2>/dev/null; then
        echo "FATAL: kubeadm $v < $K8S_MIN. K8s 1.28+ es el mínimo absoluto (SBOS-004-K8S)."
        signal_fail; return 2
    fi
    echo "kubeadm $v >= $K8S_MIN OK"
    signal_ok
}

verify_crio_active() {
    signal_start "verificar_crio_activo"
    if ! systemctl is-active --quiet crio; then
        echo "FATAL: CRI-O no está corriendo"
        signal_fail; return 2
    fi
    if ! crictl info >/dev/null 2>&1; then
        echo "FATAL: crictl no puede conectar con CRI-O"
        signal_fail; return 2
    fi
    echo "CRI-O activo"
    signal_ok
}

verify_swap_disabled() {
    signal_start "verificar_swap_off"
    if swapon --show 2>/dev/null | grep -q .; then
        echo "Swap activo detectado. Deshabilitando..."
        swapoff -a
        sed -i '/swap/d' /etc/fstab
    fi
    if swapon --show 2>/dev/null | grep -q .; then
        echo "FATAL: No se pudo deshabilitar swap"
        signal_fail; return 2
    fi
    echo "Swap deshabilitado"
    signal_ok
}

verify_network_prereqs() {
    signal_start "verificar_red"
    # Verificar puerto API server
    if ss -tlnp | grep -q ':6443 '; then
        echo "WARN: Puerto 6443 en uso — posible kubeadm previo"
    fi
    # Verificar conectividad
    if ! ping -c1 -W2 8.8.8.8 >/dev/null 2>&1; then
        echo "WARN: Sin conectividad externa detectada"
    fi
    echo "Red verificada"
    signal_ok
}

# ═══════════════════════════════════════════════════════════════
# INSTALL
# ═══════════════════════════════════════════════════════════════

run_kubeadm_init() {
    signal_start "kubeadm_init"

    if kubectl get nodes --kubeconfig="$KUBECONFIG" >/dev/null 2>&1; then
        echo "Cluster ya inicializado — omitiendo kubeadm init"
        signal_skip; return 0
    fi

    kubeadm init \
        --kubernetes-version="stable-${K8S_MIN}" \
        --cri-socket=unix:///var/run/crio/crio.sock \
        --pod-network-cidr=10.244.0.0/16 \
        --service-cidr=10.96.0.0/12 \
        --skip-phases=addon/kube-proxy \
        --upload-certs 2>&1 || {
        echo "FATAL: kubeadm init falló"
        signal_fail; return 2
    }

    echo "kubeadm init completado — K8s >= $K8S_MIN"
    signal_ok
}

copy_kubeconfig_to_user() {
    signal_start "copiar_kubeconfig"
    mkdir -p /root/.kube
    cp -f /etc/kubernetes/admin.conf /root/.kube/config
    chmod 600 /root/.kube/config

    # Copiar para usuario skull si existe
    if id skull &>/dev/null; then
        mkdir -p /home/skull/.kube
        cp -f /etc/kubernetes/admin.conf /home/skull/.kube/config
        chown -R skull:skull /home/skull/.kube
        chmod 600 /home/skull/.kube/config
    fi

    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo "Kubeconfig copiado a /root/.kube/config"
    signal_ok
}

install_calico_ebpf() {
    signal_start "instalar_calico"

    export KUBECONFIG=/etc/kubernetes/admin.conf

    # Verificar si Calico ya está instalado
    if kubectl get pods -n kube-system -l k8s-app=calico-node 2>/dev/null | grep -q Running; then
        echo "Calico ya instalado y corriendo"
        signal_skip; return 0
    fi

    # Instalar Tigera Operator
    kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/tigera-operator.yaml 2>&1 || {
        echo "FATAL: Falló la instalación del Tigera Operator"
        signal_fail; return 2
    }

    # Esperar que el operator esté listo
    kubectl wait --for=condition=available deployment/tigera-operator -n tigera-operator --timeout=120s 2>/dev/null || true

    # Instalar Calico con eBPF
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.27.0/manifests/custom-resources.yaml 2>&1 || {
        echo "FATAL: Falló la instalación de Calico"
        signal_fail; return 2
    }

    echo "Calico eBPF CNI instalado"
    signal_ok
}

install_metallb_l2() {
    signal_start "instalar_metallb"

    export KUBECONFIG=/etc/kubernetes/admin.conf

    if kubectl get pods -n metallb-system 2>/dev/null | grep -q Running; then
        echo "MetalLB ya instalado"
        signal_skip; return 0
    fi

    kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.13.12/config/manifests/metallb-native.yaml 2>&1 || {
        echo "FATAL: Falló la instalación de MetalLB"
        signal_fail; return 2
    }

    kubectl wait --for=condition=available deployment/controller -n metallb-system --timeout=120s 2>/dev/null || true

    # Configurar IPAddressPool en L2 mode
    local node_ip
    node_ip=$(ip -4 addr show scope global | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
    local subnet="${node_ip%.*}.240/28"

    kubectl apply -f - <<KUBEEOF
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: sbos-pool
  namespace: metallb-system
spec:
  addresses:
    - ${subnet}
---
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: sbos-l2
  namespace: metallb-system
spec:
  ipAddressPools:
    - sbos-pool
KUBEEOF

    echo "MetalLB instalado en modo L2"
    signal_ok
}

install_nginx_ingress() {
    signal_start "instalar_nginx_ingress"

    export KUBECONFIG=/etc/kubernetes/admin.conf

    if kubectl get pods -n ingress-nginx 2>/dev/null | grep -q Running; then
        echo "NGINX Ingress ya instalado"
        signal_skip; return 0
    fi

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/baremetal/deploy.yaml 2>&1 || {
        echo "WARN: Falló nginx ingress — continuando"
        signal_skip; return 0
    }

    echo "NGINX Ingress Controller instalado"
    signal_ok
}

install_cert_manager() {
    signal_start "instalar_cert_manager"

    export KUBECONFIG=/etc/kubernetes/admin.conf

    if kubectl get pods -n cert-manager 2>/dev/null | grep -q Running; then
        echo "cert-manager ya instalado"
        signal_skip; return 0
    fi

    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.14.0/cert-manager.yaml 2>&1 || {
        echo "WARN: Falló cert-manager — continuando"
        signal_skip; return 0
    }
    echo "cert-manager instalado"
    signal_ok
}

install_metrics_server() {
    signal_start "instalar_metrics_server"

    export KUBECONFIG=/etc/kubernetes/admin.conf

    if kubectl get pods -n kube-system -l k8s-app=metrics-server 2>/dev/null | grep -q Running; then
        echo "metrics-server ya instalado"
        signal_skip; return 0
    fi

    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml 2>&1 || {
        echo "WARN: Falló metrics-server — continuando"
        signal_skip; return 0
    }
    echo "metrics-server instalado"
    signal_ok
}

# ═══════════════════════════════════════════════════════════════
# POST-INSTALL
# ═══════════════════════════════════════════════════════════════

verify_node_ready() {
    signal_start "verificar_nodo_ready"

    export KUBECONFIG=/etc/kubernetes/admin.conf

    for i in $(seq 1 24); do
        if kubectl get nodes --no-headers 2>/dev/null | grep -q " Ready "; then
            echo "Nodo Ready después de ${i}5s"
            signal_ok; return 0
        fi
        sleep 5
    done

    echo "FATAL: Nodo no Ready después de 120s"
    kubectl get nodes 2>/dev/null || true
    signal_fail; return 2
}

verify_system_pods() {
    signal_start "verificar_pods_sistema"

    export KUBECONFIG=/etc/kubernetes/admin.conf

    for i in $(seq 1 36); do
        local pending
        pending=$(kubectl get pods -n kube-system --no-headers 2>/dev/null | grep -v Running | grep -v Completed | wc -l || echo 99)
        if [ "$pending" -eq 0 ]; then
            echo "Todos los pods de sistema Running después de ${i}5s"
            signal_ok; return 0
        fi
        sleep 5
    done

    echo "FATAL: No todos los pods de sistema están Running"
    kubectl get pods -n kube-system 2>/dev/null || true
    signal_fail; return 2
}

verify_calico_pods() {
    signal_start "verificar_calico_pods"

    export KUBECONFIG=/etc/kubernetes/admin.conf
    if kubectl get pods -n kube-system -l k8s-app=calico-node 2>/dev/null | grep -q Running; then
        echo "Calico pods Running"
        signal_ok
    else
        echo "FATAL: Calico pods no Running"
        signal_fail; return 2
    fi
}

verify_metallb_pods() {
    signal_start "verificar_metallb"
    export KUBECONFIG=/etc/kubernetes/admin.conf
    if kubectl get pods -n metallb-system 2>/dev/null | grep -q Running; then
        echo "MetalLB pods Running"
        signal_ok
    else
        echo "FATAL: MetalLB pods no Running"
        signal_fail; return 2
    fi
}

verify_coredns() {
    signal_start "verificar_coredns"
    export KUBECONFIG=/etc/kubernetes/admin.conf
    if kubectl get pods -n kube-system -l k8s-app=kube-dns 2>/dev/null | grep -q Running; then
        echo "CoreDNS Running"
        signal_ok
    else
        echo "FATAL: CoreDNS no Running"
        signal_fail; return 2
    fi
}

# ═══════════════════════════════════════════════════════════════
# ROLLBACK
# ═══════════════════════════════════════════════════════════════

kubeadm_reset() {
    signal_rollback
    echo "Rollback: kubeadm reset..."
    kubeadm reset -f 2>/dev/null || true
    rm -rf /etc/kubernetes/ /var/lib/etcd/ /root/.kube/config
    rm -rf /home/skull/.kube/config 2>/dev/null || true
    echo "Cluster K8s desmantelado"
    echo "__SBOS__CLEANUP_DONE__"
}

# ── Entry point ────────────────────────────────────────────────
case "${1:-}" in
    verify_k8s_version_128)     verify_k8s_version_128 ;;
    verify_crio_active)         verify_crio_active ;;
    verify_swap_disabled)       verify_swap_disabled ;;
    verify_network_prereqs)     verify_network_prereqs ;;
    run_kubeadm_init)           run_kubeadm_init ;;
    copy_kubeconfig_to_user)    copy_kubeconfig_to_user ;;
    install_calico_ebpf)        install_calico_ebpf ;;
    install_metallb_l2)         install_metallb_l2 ;;
    install_nginx_ingress)      install_nginx_ingress ;;
    install_cert_manager)       install_cert_manager ;;
    install_metrics_server)     install_metrics_server ;;
    verify_node_ready)          verify_node_ready ;;
    verify_system_pods)         verify_system_pods ;;
    verify_calico_pods)         verify_calico_pods ;;
    verify_metallb_pods)        verify_metallb_pods ;;
    verify_coredns)             verify_coredns ;;
    kubeadm_reset)              kubeadm_reset ;;
    *)
        echo "task_catalog.sh: función no reconocida: ${1:-}"
        exit 1
        ;;
esac
