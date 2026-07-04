#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-bootstrap-k8s
# Iteración 1: Capa 1 — containerd + kubeadm + Calico básico
#
# Dependencias: sbos-bootstrap-os (INSTALADA -- OK)
# Señales __SBOS__STEP__* obligatorias en cada paso.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bootstrap-k8s.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
K8S_VERSION="${K8S_VERSION:-1.32}"
CALICO_VERSION="${CALICO_VERSION:-3.32.0}"
POD_CIDR="${POD_CIDR:-192.168.0.0/16}"
SERVICE_CIDR="${SERVICE_CIDR:-10.96.0.0/12}"
_FICHA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bootstrap-k8s] $*" | tee -a "$FICHA_LOG"; }

# Verifica si un módulo kernel está cargado. Funciona en nspawn (sin lsmod).
_module_loaded() {
    grep -q "^${1} \|^${1}$" /proc/modules 2>/dev/null
}

# Retorna 0 si el cluster K8s ya está inicializado y responde.
_cluster_exists() {
    [[ -f "$KUBECONFIG_DEST" ]] && \
        KUBECONFIG="$KUBECONFIG_DEST" kubectl cluster-info --request-timeout=5s > /dev/null 2>&1
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_dependencias_os"
    # Intentar cargar br_netfilter si no está activo (en nspawn, el host lo carga)
    if ! _module_loaded "br_netfilter"; then
        modprobe br_netfilter 2>/dev/null || true
        if ! _module_loaded "br_netfilter"; then
            _log "ADVERTENCIA: br_netfilter no cargado — continuando (módulo en el host puede no estar disponible)"
        fi
    fi
    if [[ ! -d /data ]]; then
        echo "${__STEP_FAIL__} verificar_dependencias_os: /data no existe — ejecutar sbos-bootstrap-os primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_dependencias_os"

    echo "${__STEP_START__} verificar_swap_off"
    local swap
    swap=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
    if (( swap > 0 )); then
        _log "Swap activo (${swap}kB) — desactivando..."
        swapoff -a 2>/dev/null || true
    fi
    echo "${__STEP_OK__} verificar_swap_off"

    echo "${__STEP_START__} verificar_recursos"
    local ram_mb cpu_count
    ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
    cpu_count=$(nproc)
    if (( ram_mb < 4096 )); then
        echo "${__STEP_FAIL__} verificar_recursos: RAM ${ram_mb}MB < 4096MB requerido para K8s"
        return 1
    fi
    if (( cpu_count < 2 )); then
        echo "${__STEP_FAIL__} verificar_recursos: ${cpu_count} CPU < 2 requerido para kubeadm"
        return 1
    fi
    echo "${__STEP_OK__} verificar_recursos (${ram_mb}MB RAM, ${cpu_count} CPUs)"

    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"
    mkdir -p "$(dirname "$KUBECONFIG_DEST")"
    export DEBIAN_FRONTEND=noninteractive

    # /dev/kmsg requerido por kubelet para el OOM watcher.
    # En entornos bare-metal existe nativamente.
    # En nspawn/LXC/contenedores puede no existir — solución estándar Kind: symlink a /dev/console.
    if [[ ! -e /dev/kmsg ]]; then
        _log "Creando /dev/kmsg → /dev/console (workaround kubelet en contenedor)"
        ln -sf /dev/console /dev/kmsg
        # Persistir via tmpfiles.d para que sobreviva reinicios
        echo 'L /dev/kmsg - - - - /dev/console' > /etc/tmpfiles.d/kmsg.conf
    fi

    # ── 0. Esperar dpkg (unattended-upgrades en Ubuntu nuevo) ─────
    _wait_dpkg() {
        local waited=0
        while fuser /var/lib/dpkg/lock > /dev/null 2>&1; do
            if (( waited >= 30 )); then
                _log "dpkg bloqueado ${waited}s — forzando liberación"
                local pid
                pid=$(fuser /var/lib/dpkg/lock 2>/dev/null | tr -d ' ')
                if [[ -n "$pid" ]]; then
                    kill -9 $pid 2>/dev/null || true
                    rm -f /var/lib/dpkg/lock /var/lib/dpkg/lock-frontend 2>/dev/null || true
                    dpkg --configure -a 2>/dev/null || true
                    break
                fi
            fi
            _log "Esperando liberación de dpkg... ${waited}s"
            sleep 5
            waited=$((waited + 5))
        done
    }
    _wait_dpkg

    # ── 1. containerd.io ─────────────────────────────────────────
    echo "${__STEP_START__} instalar_containerd"
    if command -v containerd > /dev/null 2>&1; then
        _log "containerd ya instalado: $(containerd --version 2>/dev/null || echo 'desconocida')"
        echo "${__STEP_SKIP__} instalar_containerd: ya instalado"
    else
        _log "Instalando containerd.io..."
        local installed=false

        # Intento 1: repositorio Docker APT
        if curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
                | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null; then
            local codename
            codename=$(lsb_release -cs 2>/dev/null || echo "noble")
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${codename} stable" \
                > /etc/apt/sources.list.d/docker.list
            apt-get update -qq 2>/dev/null && \
                apt-get install -y -qq containerd.io 2>/dev/null && \
                installed=true || true
        fi

        # Intento 2: APT estándar (paquete containerd, versión más antigua pero funcional)
        if ! $installed; then
            _log "Repositorio Docker no disponible — intentando 'containerd' del APT estándar"
            apt-get update -qq 2>/dev/null || true
            apt-get install -y -qq containerd 2>/dev/null && installed=true || true
        fi

        if ! $installed; then
            echo "${__STEP_FAIL__} instalar_containerd: no se pudo instalar (sin conectividad y no preinstalado)"
            return 1
        fi
        _log "containerd instalado: $(containerd --version 2>/dev/null)"
        echo "${__STEP_OK__} instalar_containerd"
    fi

    # ── 2. Configurar containerd con SystemdCgroup=true ──────────
    echo "${__STEP_START__} configurar_containerd"
    mkdir -p /etc/containerd
    if [[ ! -f /etc/containerd/config.toml ]] || \
       ! grep -q "SystemdCgroup = true" /etc/containerd/config.toml 2>/dev/null; then
        containerd config default > /etc/containerd/config.toml 2>/dev/null || {
            echo "${__STEP_FAIL__} configurar_containerd: error generando config default"
            return 1
        }
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
        _log "SystemdCgroup=true aplicado"
    fi
    systemctl enable containerd 2>/dev/null || true
    systemctl restart containerd 2>/dev/null || true

    # Esperar hasta 20s que containerd responda
    local ct=0
    until systemctl is-active --quiet containerd 2>/dev/null || (( ct >= 20 )); do
        sleep 1; ct=$((ct+1))
    done
    if ! systemctl is-active --quiet containerd 2>/dev/null; then
        echo "${__STEP_FAIL__} configurar_containerd: containerd no activo tras reinicio (${ct}s)"
        return 1
    fi
    echo "${__STEP_OK__} configurar_containerd"

    # ── 3. crictl ────────────────────────────────────────────────
    echo "${__STEP_START__} configurar_crictl"
    cat > /etc/crictl.yaml <<'EOF'
runtime-endpoint: unix:///run/containerd/containerd.sock
image-endpoint: unix:///run/containerd/containerd.sock
timeout: 10
debug: false
EOF
    echo "${__STEP_OK__} configurar_crictl"

    # ── 4. kubeadm / kubectl / kubelet ───────────────────────────
    echo "${__STEP_START__} instalar_kubeadm_kubectl_kubelet"
    if command -v kubeadm > /dev/null 2>&1 && \
       kubeadm version 2>/dev/null | grep -q "${K8S_VERSION}"; then
        _log "kubeadm v${K8S_VERSION} ya instalado"
        echo "${__STEP_SKIP__} instalar_kubeadm_kubectl_kubelet: ya instalado"
    else
        _log "Instalando kubeadm/kubectl/kubelet v${K8S_VERSION}..."
        mkdir -p /etc/apt/keyrings
        local k8s_key="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
        if curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/Release.key" \
                | gpg --dearmor -o "$k8s_key" 2>/dev/null; then
            echo "deb [signed-by=${k8s_key}] \
https://pkgs.k8s.io/core:/stable:/v${K8S_VERSION}/deb/ /" \
                > /etc/apt/sources.list.d/kubernetes.list
            apt-get update -qq 2>/dev/null || true
            apt-get install -y -qq kubelet kubeadm kubectl 2>/dev/null || {
                echo "${__STEP_FAIL__} instalar_kubeadm_kubectl_kubelet: apt install falló"
                return 1
            }
            apt-mark hold kubelet kubeadm kubectl 2>/dev/null || true
            _log "kubeadm/kubectl/kubelet instalados y fijados a v${K8S_VERSION}"
            echo "${__STEP_OK__} instalar_kubeadm_kubectl_kubelet"
        else
            _log "Sin conectividad APT — verificando si está preinstalado..."
            if ! command -v kubeadm > /dev/null 2>&1; then
                echo "${__STEP_FAIL__} instalar_kubeadm_kubectl_kubelet: no instalado y sin conectividad"
                return 1
            fi
            _log "kubeadm preinstalado: $(kubeadm version 2>/dev/null || echo 'ver desconocida')"
            echo "${__STEP_SKIP__} instalar_kubeadm_kubectl_kubelet: asumido preinstalado"
        fi
    fi

    # ── 5. kubelet ───────────────────────────────────────────────
    echo "${__STEP_START__} habilitar_kubelet"
    systemctl enable --now kubelet 2>/dev/null || true
    echo "${__STEP_OK__} habilitar_kubelet"

    # ── 6. kubeadm init ──────────────────────────────────────────
    echo "${__STEP_START__} kubeadm_init"
    if _cluster_exists; then
        _log "Cluster K8s ya inicializado — omitiendo kubeadm init"
        echo "${__STEP_SKIP__} kubeadm_init: cluster ya existe"
    else
        # Activar ip_forward (requerido por kubeadm preflight)
        sysctl -w net.ipv4.ip_forward=1 > /dev/null 2>&1 || true

        # Verificar y liberar puertos K8s antes de init (pueden quedar de instalación anterior)
        for _port in 6443 2379 2380 10250 10257 10259; do
            _pid=$(fuser "${_port}/tcp" 2>/dev/null | tr -s ' ' '\n' | grep -E '^[0-9]+$' | head -1 || true)
            if [[ -n "$_pid" ]]; then
                _log "Puerto ${_port} ocupado por PID ${_pid} — liberando"
                kill -9 "$_pid" 2>/dev/null || true
                sleep 1
            fi
        done
        # Limpiar manifiestos estáticos del apiserver/etcd que kubeadm pudo haber dejado
        rm -f /etc/kubernetes/manifests/kube-apiserver.yaml \
              /etc/kubernetes/manifests/etcd.yaml \
              /etc/kubernetes/manifests/kube-controller-manager.yaml \
              /etc/kubernetes/manifests/kube-scheduler.yaml 2>/dev/null || true
        sleep 2

        # Detectar versión exacta instalada — kubectl version --client puede variar su formato
        local k8s_exact
        k8s_exact=$(kubectl version --client --output=yaml 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        [[ -z "$k8s_exact" ]] && \
            k8s_exact=$(kubectl version --client 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        [[ -z "$k8s_exact" ]] && \
            k8s_exact=$(kubeadm version -o short 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)
        [[ -z "$k8s_exact" ]] && k8s_exact="v${K8S_VERSION}.0"
        _log "Ejecutando kubeadm init (k8s=${k8s_exact}, pod-cidr=${POD_CIDR})"

        local out_file
        out_file=$(mktemp /tmp/kubeadm_init_XXXXXX.log)
        local cfg="${_FICHA_DIR}/resources/kubeadm-config.yaml"

        # En nspawn algunos preflight checks fallan (hugetlb, hostname DNS, kernel config)
        # pero no son errores reales. Se ignoran selectivamente.
        local preflight_ignore="Swap,NumCPU,FileExisting-tc,FileExisting-ethtool,SystemVerification,Hostname"

        if [[ -f "$cfg" ]]; then
            sed -e "s|__K8S_VERSION__|${k8s_exact}|g" \
                -e "s|__POD_CIDR__|${POD_CIDR}|g" \
                -e "s|__SERVICE_CIDR__|${SERVICE_CIDR}|g" \
                -e "s|__NODE_NAME__|$(hostname)|g" \
                "$cfg" > /tmp/kubeadm-rendered.yaml
            kubeadm init \
                --config=/tmp/kubeadm-rendered.yaml \
                --upload-certs \
                --ignore-preflight-errors="${preflight_ignore}" > "$out_file" 2>&1
        else
            kubeadm init \
                --kubernetes-version="${k8s_exact}" \
                --pod-network-cidr="${POD_CIDR}" \
                --service-cidr="${SERVICE_CIDR}" \
                --cri-socket="unix:///run/containerd/containerd.sock" \
                --node-name="$(hostname)" \
                --upload-certs \
                --ignore-preflight-errors="${preflight_ignore}" > "$out_file" 2>&1
        fi
        local rc=$?
        cat "$out_file" >> "$FICHA_LOG"
        grep -E "Your Kubernetes|kubeadm join|error:|Error" "$out_file" || true
        rm -f "$out_file" /tmp/kubeadm-rendered.yaml 2>/dev/null || true

        if (( rc != 0 )); then
            echo "${__STEP_FAIL__} kubeadm_init: exit ${rc} — ver $FICHA_LOG"
            return 1
        fi
        _log "kubeadm init exitoso"
        echo "${__STEP_OK__} kubeadm_init"
    fi

    # ── 7. kubeconfig ────────────────────────────────────────────
    echo "${__STEP_START__} configurar_kubeconfig"
    if [[ ! -f "$KUBECONFIG_DEST" ]]; then
        if [[ ! -f /etc/kubernetes/admin.conf ]]; then
            echo "${__STEP_FAIL__} configurar_kubeconfig: /etc/kubernetes/admin.conf no encontrado"
            return 1
        fi
        install -d -m 0750 "$(dirname "$KUBECONFIG_DEST")"
        install -m 0600 /etc/kubernetes/admin.conf "$KUBECONFIG_DEST"
        _log "kubeconfig instalado en $KUBECONFIG_DEST"
    fi
    export KUBECONFIG="$KUBECONFIG_DEST"
    echo "${__STEP_OK__} configurar_kubeconfig"

    # ── 8. Calico CNI ────────────────────────────────────────────
    echo "${__STEP_START__} instalar_calico"
    local calico_count
    calico_count=$(KUBECONFIG="$KUBECONFIG_DEST" kubectl get pods -n kube-system \
        --no-headers 2>/dev/null | grep -c "calico" || echo "0")

    if (( calico_count > 0 )); then
        _log "Calico ya instalado ($calico_count pods)"
        echo "${__STEP_SKIP__} instalar_calico: ya instalado"
    else
        local calico_local="${_FICHA_DIR}/resources/calico-v${CALICO_VERSION}.yaml"
        local calico_url="https://raw.githubusercontent.com/projectcalico/calico/v${CALICO_VERSION}/manifests/calico.yaml"

        if [[ -f "$calico_local" ]]; then
            _log "Aplicando Calico desde manifiesto local..."
            KUBECONFIG="$KUBECONFIG_DEST" kubectl apply -f "$calico_local" >> "$FICHA_LOG" 2>&1 || {
                echo "${__STEP_FAIL__} instalar_calico: kubectl apply falló (manifiesto local)"
                return 1
            }
        else
            _log "Descargando Calico v${CALICO_VERSION}..."
            KUBECONFIG="$KUBECONFIG_DEST" kubectl apply -f "$calico_url" >> "$FICHA_LOG" 2>&1 || {
                _log "Sin manifiesto local ni conectividad para Calico"
                _log "Solución: descargar $calico_url → $calico_local"
                echo "${__STEP_FAIL__} instalar_calico: sin conectividad y sin manifiesto local"
                return 1
            }
        fi
        _log "Calico aplicado"
        echo "${__STEP_OK__} instalar_calico"
    fi

    # ── 9. Esperar nodo Ready (depende de Calico + descarga de imágenes) ─────
    echo "${__STEP_START__} esperar_nodo_ready"
    # 600s (10 min) para cubrir descarga de imágenes en servidor nuevo
    local timeout=600 elapsed=0
    while (( elapsed < timeout )); do
        local ready_count
        ready_count=$(KUBECONFIG="$KUBECONFIG_DEST" kubectl get nodes --no-headers 2>/dev/null \
            | grep -c " Ready " || echo "0")
        if (( ready_count >= 1 )); then
            _log "Nodo Ready tras ${elapsed}s"
            break
        fi
        sleep 10; elapsed=$((elapsed + 10))
        if (( elapsed % 60 == 0 )); then
            _log "Esperando nodo Ready... ${elapsed}/${timeout}s"
            # Mostrar qué pods aún no están ready para ayudar al diagnóstico
            KUBECONFIG="$KUBECONFIG_DEST" kubectl get pods -n kube-system --no-headers 2>/dev/null \
                | grep -v Running | grep -v Completed | head -5 | \
                while read line; do _log "  pendiente: $line"; done || true
        fi
    done
    if (( elapsed >= timeout )); then
        _log "Diagnóstico pods kube-system:"
        KUBECONFIG="$KUBECONFIG_DEST" kubectl get pods -n kube-system 2>/dev/null | head -15 | \
            while read line; do _log "  $line"; done || true
        echo "${__STEP_FAIL__} esperar_nodo_ready: timeout ${timeout}s — revisar logs de kube-system"
        return 1
    fi
    echo "${__STEP_OK__} esperar_nodo_ready (${elapsed}s)"

    # ── 10. Remover taint control-plane (single-node) ────────────
    echo "${__STEP_START__} quitar_taint_master"
    KUBECONFIG="$KUBECONFIG_DEST" kubectl taint nodes --all \
        node-role.kubernetes.io/control-plane:NoSchedule- 2>/dev/null || true
    _log "Taint control-plane:NoSchedule removido — pods de fichas pueden schedularse"
    echo "${__STEP_OK__} quitar_taint_master"

    # ── 11. Namespaces SBOS ───────────────────────────────────────
    echo "${__STEP_START__} crear_namespaces"
    local namespaces=(sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring)
    for ns in "${namespaces[@]}"; do
        KUBECONFIG="$KUBECONFIG_DEST" kubectl create namespace "$ns" 2>/dev/null || true
    done
    _log "Namespaces SBOS creados: ${namespaces[*]}"
    echo "${__STEP_OK__} crear_namespaces"

    # ── 12. StorageClass local ────────────────────────────────────
    echo "${__STEP_START__} crear_storageclass"
    KUBECONFIG="$KUBECONFIG_DEST" kubectl apply -f - 2>/dev/null <<'EOF' || true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-path
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: kubernetes.io/no-provisioner
reclaimPolicy: Retain
volumeBindingMode: WaitForFirstConsumer
EOF
    echo "${__STEP_OK__} crear_storageclass"

    _log "Instalación sbos-bootstrap-k8s completada"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    export KUBECONFIG="$KUBECONFIG_DEST"
    _log "Estado final del cluster:"
    kubectl get nodes 2>/dev/null | tee -a "$FICHA_LOG" || true
    kubectl get pods -n kube-system --no-headers 2>/dev/null | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    export KUBECONFIG="$KUBECONFIG_DEST"
    _log "Reparando sbos-bootstrap-k8s..."

    echo "${__STEP_START__} reparar_containerd"
    if ! systemctl is-active --quiet containerd 2>/dev/null; then
        systemctl restart containerd 2>/dev/null && \
            _log "containerd reiniciado" || \
            _log "ADVERTENCIA: no se pudo reiniciar containerd"
    else
        _log "containerd activo — sin acción necesaria"
    fi
    echo "${__STEP_OK__} reparar_containerd"

    echo "${__STEP_START__} reparar_kubelet"
    if ! systemctl is-active --quiet kubelet 2>/dev/null; then
        systemctl restart kubelet 2>/dev/null && \
            _log "kubelet reiniciado" || \
            _log "ADVERTENCIA: no se pudo reiniciar kubelet"
    else
        _log "kubelet activo — sin acción necesaria"
    fi
    echo "${__STEP_OK__} reparar_kubelet"

    echo "${__STEP_START__} reparar_calico"
    kubectl rollout restart daemonset/calico-node -n kube-system 2>/dev/null || true
    echo "${__STEP_OK__} reparar_calico"

    echo "${__STEP_START__} reparar_namespaces"
    for ns in sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring; do
        kubectl create namespace "$ns" 2>/dev/null || true
    done
    echo "${__STEP_OK__} reparar_namespaces"

    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    export KUBECONFIG="$KUBECONFIG_DEST"
    local ok=0

    echo "${__STEP_START__} test_containerd"
    if systemctl is-active --quiet containerd 2>/dev/null; then
        echo "${__STEP_OK__} test_containerd"
    else
        echo "${__STEP_FAIL__} test_containerd: servicio no activo"
        ok=1
    fi

    echo "${__STEP_START__} test_kube_apiserver"
    if kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_kube_apiserver"
    else
        echo "${__STEP_FAIL__} test_kube_apiserver: no responde"
        ok=1
    fi

    echo "${__STEP_START__} test_nodo_ready"
    local nodes_ready
    nodes_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -c " Ready " || echo "0")
    if (( nodes_ready >= 1 )); then
        echo "${__STEP_OK__} test_nodo_ready (${nodes_ready} nodo(s))"
    else
        echo "${__STEP_FAIL__} test_nodo_ready: 0 nodos Ready"
        ok=1
    fi

    echo "${__STEP_START__} test_calico"
    local calico_running
    calico_running=$(kubectl get pods -n kube-system -l k8s-app=calico-node \
        --no-headers 2>/dev/null | grep -c "^.*Running" || echo "0")
    if (( calico_running > 0 )); then
        echo "${__STEP_OK__} test_calico (${calico_running} pod(s) Running)"
    else
        echo "${__STEP_FAIL__} test_calico: calico-node no Running"
        ok=1
    fi

    echo "${__STEP_START__} test_namespaces"
    local missing=0
    for ns in sbos-system sbos-data sbos-security sbos-gateway sbos-monitoring; do
        kubectl get namespace "$ns" > /dev/null 2>&1 || missing=$((missing + 1))
    done
    if (( missing == 0 )); then
        echo "${__STEP_OK__} test_namespaces (5/5)"
    else
        echo "${__STEP_FAIL__} test_namespaces: $missing namespaces faltantes"
        ok=1
    fi

    echo "${__STEP_START__} test_storageclass"
    if kubectl get storageclass local-path > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_storageclass"
    else
        echo "${__STEP_FAIL__} test_storageclass: local-path no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_taint_removido"
    local taint_count
    taint_count=$(kubectl get nodes -o json 2>/dev/null | \
        python3 -c "
import sys, json
data = json.load(sys.stdin)
count = 0
for n in data.get('items', []):
    for t in n.get('spec', {}).get('taints', []):
        if t.get('key') == 'node-role.kubernetes.io/control-plane' and t.get('effect') == 'NoSchedule':
            count += 1
print(count)
" 2>/dev/null || echo "0")
    if [[ "$taint_count" == "0" ]]; then
        echo "${__STEP_OK__} test_taint_removido"
    else
        echo "${__STEP_FAIL__} test_taint_removido: ${taint_count} nodo(s) aún con taint control-plane:NoSchedule"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-bootstrap-k8s STATUS ==="
    echo "containerd:   $(systemctl is-active containerd 2>/dev/null || echo inactivo)"
    echo "kubelet:      $(systemctl is-active kubelet 2>/dev/null || echo inactivo)"
    echo "kubeconfig:   $([[ -f "$KUBECONFIG_DEST" ]] && echo existe || echo 'NO existe')"
    echo ""
    echo "Nodos K8s:"
    KUBECONFIG="$KUBECONFIG_DEST" kubectl get nodes 2>/dev/null || echo "  (cluster no accesible)"
    echo ""
    echo "Pods kube-system:"
    KUBECONFIG="$KUBECONFIG_DEST" kubectl get pods -n kube-system --no-headers 2>/dev/null \
        | awk '{printf "  %-45s %s\n", $1, $3}' || echo "  (no disponible)"
    echo ""
    echo "Namespaces SBOS:"
    KUBECONFIG="$KUBECONFIG_DEST" kubectl get namespaces 2>/dev/null | grep sbos || echo "  (ninguno)"
    echo ""
    echo "StorageClass:"
    KUBECONFIG="$KUBECONFIG_DEST" kubectl get storageclass local-path 2>/dev/null \
        || echo "  local-path: NO existe"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando K8s — esto destruye el cluster"

    echo "${__STEP_START__} kubeadm_reset"
    kubeadm reset --force 2>/dev/null || true
    echo "${__STEP_OK__} kubeadm_reset"

    echo "${__STEP_START__} limpiar_configs"
    rm -f /etc/apt/sources.list.d/kubernetes.list
    rm -f /etc/apt/keyrings/kubernetes-apt-keyring.gpg
    rm -f "$KUBECONFIG_DEST"
    rm -f /etc/crictl.yaml
    rm -f /tmp/kubeadm-rendered.yaml
    echo "${__STEP_OK__} limpiar_configs"

    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-bootstrap-k8s ==="
    echo "containerd:  $(containerd --version 2>/dev/null || echo 'no instalado')"
    echo "  servicio:  $(systemctl is-active containerd 2>/dev/null || echo 'no activo')"
    echo "  socket:    $([[ -S /run/containerd/containerd.sock ]] && echo 'OK' || echo 'NO existe')"
    echo "crictl:      $(crictl --version 2>/dev/null || echo 'no instalado')"
    echo "  config:    $([[ -f /etc/crictl.yaml ]] && echo 'OK' || echo 'NO existe')"
    echo "kubeadm:     $(kubeadm version --output=short 2>/dev/null || echo 'no instalado')"
    echo "kubectl:     $(kubectl version --client --short 2>/dev/null || echo 'no instalado')"
    echo "kubelet:     $(systemctl is-active kubelet 2>/dev/null || echo 'no activo')"
    echo "kubeconfig:  $([[ -f "$KUBECONFIG_DEST" ]] && echo 'OK' || echo 'NO existe')"
    if [[ -f "$KUBECONFIG_DEST" ]]; then
        export KUBECONFIG="$KUBECONFIG_DEST"
        echo ""
        echo "cluster-info:"
        kubectl cluster-info 2>/dev/null || echo "  (no accesible)"
        echo ""
        echo "get nodes:"
        kubectl get nodes 2>/dev/null || echo "  (no accesible)"
    fi
    echo ""
    echo "Últimas 15 líneas de kubelet:"
    journalctl -u kubelet -n 15 --no-pager 2>/dev/null || true
}
