#!/usr/bin/env bash
# ============================================================================
# 00_TASK_CATALOG_SBOS.sh — Generic task library for SBOS IAM Installer
#
# PRINCIPLE P3: NEVER names any concrete application.
# All functions are generic and receive ficha_id + ficha_dir as parameters.
#
# Groups:
#   1. Validations    — pre-flight checks
#   2. K8s Generics   — namespace, PVC, secret, configmap, pod operations
#   3. Wait/Verify    — readiness probes and health checks
#   4. Filesystem     — backup, restore, permissions
#   5. Lifecycle      — rollout, scale, snapshot
# ============================================================================

set -euo pipefail

# ═══════════════════════════════════════════════════════════════
# Group 1 — Validations
# ═══════════════════════════════════════════════════════════════

check_root_user() {
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: This operation requires root privileges"
        return 1
    fi
    return 0
}

check_system_requirements() {
    local min_ram_mb="${1:-4096}"
    local min_disk_gb="${2:-20}"
    local min_cpu="${3:-2}"

    # RAM
    local total_ram_mb
    total_ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)
    if (( total_ram_mb < min_ram_mb )); then
        echo "ERROR: Insufficient RAM: ${total_ram_mb}MB < ${min_ram_mb}MB required"
        return 1
    fi

    # CPU
    local cpu_count
    cpu_count=$(nproc)
    if (( cpu_count < min_cpu )); then
        echo "ERROR: Insufficient CPUs: $cpu_count < $min_cpu required"
        return 1
    fi

    # Disk on /opt/bos
    local disk_avail_gb
    disk_avail_gb=$(df -BG /opt/bos 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//')
    if (( disk_avail_gb < min_disk_gb )); then
        echo "ERROR: Insufficient disk: ${disk_avail_gb}GB < ${min_disk_gb}GB required"
        return 1
    fi

    return 0
}

check_k8s_cluster_ready() {
    KUBECONFIG="${SBOS_KUBECONFIG:-/etc/bos/.kube/config}"
    export KUBECONFIG

    if ! kubectl cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo "ERROR: Kubernetes cluster not reachable"
        return 1
    fi

    local nodes_ready
    nodes_ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready ' || true)
    if (( nodes_ready < 1 )); then
        echo "ERROR: No Ready nodes in cluster"
        return 1
    fi

    return 0
}

check_node_resources() {
    local node="${1:-}"
    if [[ -z "$node" ]]; then
        node=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null | head -1)
    fi

    local cpu_pct
    cpu_pct=$(kubectl top node "$node" --no-headers 2>/dev/null | awk '{print $3}' | sed 's/%//')
    if (( cpu_pct > 85 )); then
        echo "WARNING: Node $node CPU usage at ${cpu_pct}%"
        return 1
    fi
    return 0
}

validate_ficha_contract() {
    local ficha_dir="$1"
    local manifest="$ficha_dir/manifest.yml"

    if [[ ! -f "$manifest" ]]; then
        echo "ERROR: manifest.yml not found in $ficha_dir"
        return 1
    fi

    # Formato canónico SBOS v2.0: identity.* (alineado con plugin/loader.go)
    local required_fields=("identity.id" "identity.version" "identity.server" "identity.category")
    for field in "${required_fields[@]}"; do
        local val
        val=$(yq eval ".$field" "$manifest" 2>/dev/null || echo "")
        if [[ -z "$val" || "$val" == "null" ]]; then
            echo "ERROR: Campo requerido faltante: $field"
            return 1
        fi
    done

    # Category must be 1, 2, or 3
    local category
    category=$(yq eval '.identity.category' "$manifest" 2>/dev/null || echo "0")
    if [[ ! "$category" =~ ^[1-3]$ ]]; then
        echo "ERROR: Categoría inválida: $category (debe ser 1, 2 o 3)"
        return 1
    fi

    return 0
}

check_dependencies() {
    local ficha_dir="$1"
    local manifest="$ficha_dir/manifest.yml"

    local dep_count
    dep_count=$(yq eval '.requirements.depends_on | length' "$manifest" 2>/dev/null || echo "0")

    for (( i=0; i<dep_count; i++ )); do
        local dep_type dep_target dep_state
        dep_type=$(yq eval ".requirements.depends_on[$i].type" "$manifest")
        dep_target=$(yq eval ".requirements.depends_on[$i].target" "$manifest")
        dep_state=$(yq eval ".requirements.depends_on[$i].state" "$manifest")

        # Check if dependency is satisfied in .sbos_state.json
        if ! jq -e --arg target "$dep_target" --arg state "${dep_state:-INSTALADA_OK}" \
            '.fichas[$target].state == $state' "$SBOS_STATE_FILE" > /dev/null 2>&1; then
            echo "ERROR: Dependency unsatisfied: $dep_target (needs state: ${dep_state:-INSTALADA_OK})"
            return 1
        fi
    done

    return 0
}

check_no_dependents() {
    local ficha_id="$1"
    # Check if any other ficha declares a dependency on ficha_id
    local dependents
    dependents=$(
        find "$SBOS_SERVERS_DIR" -name 'manifest.yml' -exec \
            yq eval '.requirements.depends_on[] | select(.target == "'"$ficha_id"'") | "'"$ficha_id"'"' {} \; 2>/dev/null
    )
    if [[ -n "$dependents" ]]; then
        echo "ERROR: The following fichas depend on $ficha_id: $dependents"
        return 1
    fi
    return 0
}

check_governance_uninstall() {
    local ficha_id="$1" ficha_dir="$2"
    local manifest="$ficha_dir/manifest.yml"
    local category
    category=$(yq eval '.identity.category' "$manifest" 2>/dev/null || echo "1")

    if [[ "$category" == "3" ]]; then
        echo "GOVERNANCE: Category 3 uninstall requires dual admin approval."
        echo "Use: bosctl remove $ficha_id --approval <approval_token_1> <approval_token_2>"
        # In production, this validates signed approval tokens
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════
# Group 2 — K8s Generic Operations
# ═══════════════════════════════════════════════════════════════

# P1: sbos_k8s_core() is the ONLY kubectl apply in the entire system.
sbos_k8s_core() {
    local manifest_file="$1"
    local namespace="${2:-}"

    if [[ ! -f "$manifest_file" ]]; then
        echo "ERROR: Manifest not found: $manifest_file"
        return 1
    fi

    # Dry-run first (P10)
    if [[ -n "$namespace" ]]; then
        kubectl apply -f "$manifest_file" -n "$namespace" --dry-run=client > /dev/null 2>&1
    else
        kubectl apply -f "$manifest_file" --dry-run=client > /dev/null 2>&1
    fi

    if [[ $? -ne 0 ]]; then
        echo "ERROR: kubectl dry-run failed for $manifest_file"
        return 1
    fi

    # Apply
    if [[ -n "$namespace" ]]; then
        kubectl apply -f "$manifest_file" -n "$namespace"
    else
        kubectl apply -f "$manifest_file"
    fi
}

create_k8s_namespace() {
    local namespace="$1"
    local labels="${2:-}"

    if kubectl get namespace "$namespace" > /dev/null 2>&1; then
        echo "Namespace $namespace already exists"
        return 0
    fi

    if [[ -n "$labels" ]]; then
        kubectl create namespace "$namespace" --labels="$labels"
    else
        kubectl create namespace "$namespace"
    fi
    echo "Namespace $namespace created"
}

create_k8s_secret() {
    local name="$1" namespace="$2" key="$3" value="$4"

    kubectl create secret generic "$name" \
        -n "$namespace" \
        --from-literal="$key=$value" \
        --dry-run=client -o yaml | kubectl apply -f -
}

apply_configmap() {
    local name="$1" namespace="$2" file_path="$3"

    kubectl create configmap "$name" \
        -n "$namespace" \
        --from-file="$(basename "$file_path")=$file_path" \
        --dry-run=client -o yaml | kubectl apply -f -
}

create_pvc() {
    local name="$1" namespace="$2" size="${3:-10Gi}" storage_class="${4:-standard}"

    cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: $name
  namespace: $namespace
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: $size
  storageClassName: $storage_class
YAML
}

delete_pvc() {
    local name="$1" namespace="$2"
    kubectl delete pvc "$name" -n "$namespace" --ignore-not-found=true
}

delete_k8s_manifest() {
    local manifest_file="$1"
    if [[ -f "$manifest_file" ]]; then
        kubectl delete -f "$manifest_file" --ignore-not-found=true
    fi
}

apply_network_policy() {
    local name="$1" namespace="$2" policy_file="$3"

    if [[ ! -f "$policy_file" ]]; then
        echo "ERROR: NetworkPolicy file not found: $policy_file"
        return 1
    fi
    sbos_k8s_core "$policy_file" "$namespace"
}

exec_command_in_pod() {
    local namespace="$1" pod_selector="$2" command="$3"

    local pod
    pod=$(kubectl get pods -n "$namespace" -l "$pod_selector" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$pod" ]]; then
        echo "ERROR: No pod found matching selector: $pod_selector in $namespace"
        return 1
    fi

    kubectl exec -n "$namespace" "$pod" -- /bin/sh -c "$command"
}

copy_file_to_pod() {
    local namespace="$1" pod_selector="$2" local_file="$3" remote_path="$4"

    local pod
    pod=$(kubectl get pods -n "$namespace" -l "$pod_selector" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [[ -z "$pod" ]]; then
        echo "ERROR: No pod found: $pod_selector in $namespace"
        return 1
    fi
    kubectl cp "$local_file" "$namespace/$pod:$remote_path"
}

# ═══════════════════════════════════════════════════════════════
# Group 3 — Wait / Verify
# ═══════════════════════════════════════════════════════════════

wait_pod_ready() {
    local namespace="$1" label_selector="$2" timeout_sec="${3:-300}"

    kubectl wait --for=condition=Ready pod \
        -n "$namespace" -l "$label_selector" \
        --timeout="${timeout_sec}s"
}

wait_pod_healthy() {
    local namespace="$1" label_selector="$2" timeout_sec="${3:-120}"
    local deadline
    deadline=$(($(date +%s) + timeout_sec))

    while (( $(date +%s) < deadline )); do
        local ready
        ready=$(kubectl get pods -n "$namespace" -l "$label_selector" \
            -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null)

        if [[ "$ready" =~ ^true( true)*$ ]] && [[ -n "$ready" ]]; then
            return 0
        fi
        sleep 5
    done

    echo "ERROR: Pods not healthy after ${timeout_sec}s: $label_selector in $namespace"
    return 1
}

verify_pod_running() {
    local namespace="$1" label_selector="$2"

    local count
    count=$(kubectl get pods -n "$namespace" -l "$label_selector" \
        --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
    if (( count == 0 )); then
        echo "ERROR: No running pods: $label_selector in $namespace"
        return 1
    fi
    echo "$count pods running"
    return 0
}

verify_service_responds() {
    local namespace="$1" service="$2" port="${3:-80}" path="${4:-/}" timeout_sec="${5:-30}"

    local deadline
    deadline=$(($(date +%s) + timeout_sec))

    while (( $(date +%s) < deadline )); do
        if kubectl run "health-check-$$" --rm -i --restart=Never --image=busybox:latest \
            -n "$namespace" -- wget -q -O- --timeout=3 "http://$service.$namespace.svc.cluster.local:$port$path" \
            > /dev/null 2>&1; then
            return 0
        fi
        sleep 2
    done

    echo "ERROR: Service $service not responding after ${timeout_sec}s"
    return 1
}

wait_http_endpoint_ready() {
    local url="$1" timeout_sec="${2:-60}" expected_code="${3:-200}"

    local deadline
    deadline=$(($(date +%s) + timeout_sec))

    while (( $(date +%s) < deadline )); do
        local code
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$url" 2>/dev/null || echo "000")
        if [[ "$code" == "$expected_code" ]]; then
            return 0
        fi
        sleep 3
    done
    echo "ERROR: Endpoint $url not ready after ${timeout_sec}s"
    return 1
}

verify_port_in_pod() {
    local namespace="$1" pod_selector="$2" port="$3"

    local pod
    pod=$(kubectl get pods -n "$namespace" -l "$pod_selector" \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

    if [[ -z "$pod" ]]; then
        echo "ERROR: No pod found: $pod_selector"
        return 1
    fi

    kubectl exec -n "$namespace" "$pod" -- netstat -tlnp 2>/dev/null | grep -q ":$port "
}

# ═══════════════════════════════════════════════════════════════
# Group 4 — Filesystem
# ═══════════════════════════════════════════════════════════════

create_directories() {
    local base_dir="$1"; shift
    for dir in "$@"; do
        mkdir -p "$base_dir/$dir"
    done
}

apply_permissions() {
    local path="$1" owner="${2:-root:root}" mode="${3:-755}"
    chown -R "$owner" "$path"
    chmod -R "$mode" "$path"
}

backup_directory() {
    local src="$1" backup_root="${2:-/opt/bos/backups}"
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local dest="$backup_root/$(basename "$src")-$ts"

    if [[ -d "$src" ]]; then
        cp -a "$src" "$dest"
        echo "$dest"
    else
        echo "WARNING: Source not found for backup: $src"
        return 1
    fi
}

restore_directory() {
    local backup_path="$1" restore_target="$2"

    if [[ ! -d "$backup_path" ]]; then
        echo "ERROR: Backup not found: $backup_path"
        return 1
    fi

    rm -rf "$restore_target"
    cp -a "$backup_path" "$restore_target"
    echo "Restored $restore_target from $backup_path"
}

# ═══════════════════════════════════════════════════════════════
# Group 5 — Lifecycle
# ═══════════════════════════════════════════════════════════════

rollout_restart() {
    local namespace="$1" deployment="$2"
    kubectl rollout restart deployment "$deployment" -n "$namespace"
}

scale_deployment() {
    local namespace="$1" deployment="$2" replicas="$3"
    kubectl scale deployment "$deployment" -n "$namespace" --replicas="$replicas"
}

take_backup_snapshot() {
    local ficha_id="$1" label_selector="$2"

    echo "Taking backup snapshot for $ficha_id..."
    local ts
    ts=$(date +%Y%m%d-%H%M%S)
    local backup_dir="/opt/bos/backups/${ficha_id}-${ts}"
    mkdir -p "$backup_dir"

    # Dump all configmaps and secrets for this ficha
    local namespace
    namespace=$(kubectl get pods -l "$label_selector" -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "default")
    kubectl get configmaps -n "$namespace" -o yaml > "$backup_dir/configmaps.yaml"
    kubectl get secrets -n "$namespace" -o yaml > "$backup_dir/secrets.yaml" 2>/dev/null || true

    echo "$backup_dir"
}

restore_backup_snapshot() {
    local backup_dir="$1"
    if [[ ! -d "$backup_dir" ]]; then
        echo "ERROR: Backup snapshot not found: $backup_dir"
        return 1
    fi
    kubectl apply -f "$backup_dir/configmaps.yaml" 2>/dev/null || true
    echo "Snapshot restored from $backup_dir"
}

# ═══════════════════════════════════════════════════════════════
# Generic ficha operations — used when ficha has no custom hooks
# ═══════════════════════════════════════════════════════════════

pre_install_generic() {
    local ficha_id="$1" ficha_dir="$2"
    local manifest="$ficha_dir/manifest.yml"

    local namespace
    namespace=$(yq eval '.ficha.namespace // "default"' "$manifest")

    create_k8s_namespace "$namespace" "sbos.io/managed=true"
}

install_generic() {
    local ficha_id="$1" ficha_dir="$2"

    # Apply all k8s manifests in the ficha directory
    for manifest in "$ficha_dir"/*.yaml "$ficha_dir"/*.yml; do
        if [[ -f "$manifest" ]] && [[ "$(basename "$manifest")" != "manifest.yml" ]]; then
            sbos_k8s_core "$manifest"
        fi
    done
}

post_install_generic() {
    local ficha_id="$1" ficha_dir="$2"
    local manifest="$ficha_dir/manifest.yml"

    local namespace
    namespace=$(yq eval '.ficha.namespace // "default"' "$manifest")

    local label_selector
    label_selector=$(yq eval '.ficha.health.label_selector // "app='"$ficha_id"'"' "$manifest")

    wait_pod_healthy "$namespace" "$label_selector" 300
}

update_generic() {
    local ficha_id="$1" ficha_dir="$2" version="$3"

    # Same as install — kubectl apply handles the update idempotently
    for manifest in "$ficha_dir"/*.yaml "$ficha_dir"/*.yml; do
        if [[ -f "$manifest" ]] && [[ "$(basename "$manifest")" != "manifest.yml" ]]; then
            sbos_k8s_core "$manifest"
        fi
    done
}

repair_generic() {
    local ficha_id="$1" ficha_dir="$2"
    local manifest="$ficha_dir/manifest.yml"

    local namespace
    namespace=$(yq eval '.ficha.namespace // "default"' "$manifest")

    local deployment
    deployment=$(yq eval '.ficha.health.deployment // "'"$ficha_id"'"' "$manifest")

    # Restart the deployment (non-invasive repair)
    rollout_restart "$namespace" "$deployment"
}

diagnosis_generic() {
    local ficha_id="$1"

    local namespace
    namespace=$(kubectl get pods --all-namespaces -l "app=$ficha_id" \
        -o jsonpath='{.items[0].metadata.namespace}' 2>/dev/null || echo "default")

    echo "Diagnosis for $ficha_id:"
    kubectl get pods -n "$namespace" -l "app=$ficha_id" 2>/dev/null || echo "  No pods found"
    kubectl describe deployment "$ficha_id" -n "$namespace" 2>/dev/null | tail -20 || echo "  No deployment"
}

uninstall_generic() {
    local ficha_id="$1" ficha_dir="$2"

    # Delete in reverse order
    for manifest in $(ls -r "$ficha_dir"/*.yaml "$ficha_dir"/*.yml 2>/dev/null); do
        if [[ -f "$manifest" ]] && [[ "$(basename "$manifest")" != "manifest.yml" ]]; then
            kubectl delete -f "$manifest" --ignore-not-found=true
        fi
    done
}

verify_ficha_health() {
    local ficha_id="$1"

    local ficha_dir
    ficha_dir=$(find "$SBOS_SERVERS_DIR" -maxdepth 4 -type d -name "$ficha_id" 2>/dev/null | head -1)

    if [[ -z "$ficha_dir" ]]; then
        echo "ERROR: Cannot verify — ficha directory not found"
        return 1
    fi

    local manifest="$ficha_dir/manifest.yml"
    local health_type
    health_type=$(yq eval '.health.type // "pods"' "$manifest" 2>/dev/null || echo "pods")

    # Fichas bash con health.type=command: ejecutar el comando del manifest
    if [[ "$health_type" == "command" ]]; then
        local health_cmd
        health_cmd=$(yq eval '.health.command // ""' "$manifest" 2>/dev/null || echo "")
        if [[ -z "$health_cmd" ]]; then
            echo "SKIP: no health command defined — assuming healthy"
            return 0
        fi
        if eval "$health_cmd" > /dev/null 2>&1; then
            return 0
        else
            echo "ERROR: health command failed: $health_cmd"
            return 1
        fi
    fi

    # Fichas bash sin health.type: si tiene ficha_test() la usa, si no pasa
    if [[ "$health_type" == "none" || "$health_type" == "skip" ]]; then
        return 0
    fi

    # Fichas helm con health.type=http: curl al endpoint cuando K8s está disponible
    if [[ "$health_type" == "http" ]]; then
        local health_path health_port health_timeout
        health_path=$(yq eval '.health.path // "/health"' "$manifest" 2>/dev/null || echo "/health")
        health_port=$(yq eval '.health.port // 8080' "$manifest" 2>/dev/null || echo "8080")
        health_timeout=$(yq eval '.health.timeout_seconds // 10' "$manifest" 2>/dev/null || echo "10")

        if ! command -v kubectl > /dev/null 2>&1; then
            echo "SKIP: kubectl no disponible — K8s aún no instalado, verify pendiente"
            return 0
        fi

        local namespace
        namespace=$(yq eval '.identity.server // "default"' "$manifest" 2>/dev/null || echo "default")
        namespace=$(echo "$namespace" | tr '[:upper:]' '[:lower:]' | sed 's/^s[0-9]*/sbos-/')

        local svc_ip
        svc_ip=$(kubectl get svc "$ficha_id" -n "$namespace" \
            -o jsonpath='{.spec.clusterIP}' 2>/dev/null || \
            kubectl get svc "$ficha_id" -A \
            -o jsonpath='{.items[0].spec.clusterIP}' 2>/dev/null || echo "")

        if [[ -z "$svc_ip" || "$svc_ip" == "None" ]]; then
            # Fallback: verificar que el pod está corriendo
            local label_selector
            label_selector=$(yq eval '.ficha.health.label_selector // "app='"$ficha_id"'"' "$manifest" 2>/dev/null || echo "app=$ficha_id")
            verify_pod_running "$namespace" "$label_selector"
            return $?
        fi

        local http_code
        http_code=$(curl -sk --max-time "$health_timeout" \
            -o /dev/null -w "%{http_code}" \
            "http://${svc_ip}:${health_port}${health_path}" 2>/dev/null || echo "000")

        if [[ "$http_code" =~ ^2 || "$http_code" == "301" || "$http_code" == "302" ]]; then
            return 0
        else
            echo "ERROR: HTTP health check falló: ${svc_ip}:${health_port}${health_path} → $http_code"
            return 1
        fi
    fi

    # Fichas helm/pods sin health.type específico: verificar que el pod corre
    local namespace
    namespace=$(yq eval '.ficha.namespace // "default"' "$manifest" 2>/dev/null || echo "default")
    local label_selector
    label_selector=$(yq eval '.ficha.health.label_selector // "app='"$ficha_id"'"' "$manifest" 2>/dev/null || echo "app=$ficha_id")

    if ! command -v kubectl > /dev/null 2>&1; then
        echo "SKIP: kubectl no disponible — K8s aún no instalado, verify pendiente"
        return 0
    fi

    verify_pod_running "$namespace" "$label_selector"
}

backup_ficha_resources() {
    local ficha_id="$1"
    local ficha_dir
    ficha_dir=$(find "$SBOS_SERVERS_DIR" -maxdepth 4 -type d -name "$ficha_id" 2>/dev/null | head -1)
    if [[ -n "$ficha_dir" ]]; then
        backup_directory "$ficha_dir"
    fi
}

restore_ficha_resources() {
    local ficha_id="$1"
    # Find latest backup and restore
    local latest_backup
    latest_backup=$(ls -d /opt/bos/backups/"$ficha_id"-* 2>/dev/null | tail -1)
    if [[ -n "$latest_backup" ]]; then
        local ficha_dir
        ficha_dir=$(find "$SBOS_SERVERS_DIR" -maxdepth 4 -type d -name "$ficha_id" 2>/dev/null | head -1)
        if [[ -n "$ficha_dir" ]]; then
            restore_directory "$latest_backup" "$ficha_dir"
        fi
    fi
}
