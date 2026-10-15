#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-bootstrap-platform
# Crea los 13 namespaces canónicos de SBOS, instala local-path-provisioner
# (StorageClass dinámica rancher.io/local-path) y aplica RBAC base.
# Prerequisito de todas las fichas K8s del stack.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bootstrap-platform.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
LPP_VERSION="${LPP_VERSION:-0.0.30}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bootstrap-platform] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# Namespaces canónicos con su label de servidor lógico.
readonly NAMESPACES=(
    "sbos-data:dataserver:maxima"
    "sbos-security:identityserver:maxima"
    "sbos-gateway:gatewayserver:maxima"
    "sbos-monitor:monitorserver:maxima"
    "sbos-erp:erpserver:maxima"
    "sbos-apps:appsserver:alta"
    "sbos-docs:docserver:alta"
    "sbos-vdi:vdiserver:alta"
    "sbos-comms:commsserver:alta"
    "sbos-ops:opsserver:alta"
    "sbos-search:searchserver:alta"
    "sbos-geo:geoserver:media"
    "sbos-system:hostserver:maxima"
)

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_k8s"
    if ! _k cluster-info --request-timeout=5s > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_k8s: kube-apiserver no responde"
        return 1
    fi
    echo "${__STEP_OK__} verificar_k8s"

    echo "${__STEP_START__} verificar_calico_ready"
    local calico_running
    calico_running=$(_k get pods -n kube-system -l k8s-app=calico-node \
        --no-headers 2>/dev/null | awk '{print $3}' | grep -c "^Running$" || echo "0")
    if (( calico_running < 1 )); then
        echo "${__STEP_FAIL__} verificar_calico_ready: calico-node no está Running — ejecutar sbos-bootstrap-cni primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_calico_ready"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Namespaces ─────────────────────────────────────────────
    echo "${__STEP_START__} crear_namespaces"
    local creados=0 existentes=0
    for entry in "${NAMESPACES[@]}"; do
        local ns server criticidad
        ns="${entry%%:*}"
        server="${entry#*:}"; server="${server%%:*}"
        criticidad="${entry##*:}"

        if _k get namespace "$ns" > /dev/null 2>&1; then
            # Namespace ya existe — solo asegura los labels (idempotente)
            _k label namespace "$ns" \
                "sbos.app/server=${server}" \
                "sbos.app/criticality=${criticidad}" \
                --overwrite > /dev/null 2>&1
            (( existentes++ ))
        else
            _k create namespace "$ns" >> "$FICHA_LOG" 2>&1
            _k label namespace "$ns" \
                "sbos.app/server=${server}" \
                "sbos.app/criticality=${criticidad}" \
                --overwrite >> "$FICHA_LOG" 2>&1
            _log "Namespace creado: $ns"
            (( creados++ ))
        fi
    done
    _log "Namespaces: ${creados} creados, ${existentes} ya existían"
    echo "${__STEP_OK__} crear_namespaces (${creados} nuevos, ${existentes} existentes)"

    # ── 2. local-path-provisioner (StorageClass dinámica) ─────────
    echo "${__STEP_START__} instalar_local_path_provisioner"

    local sc_exists lpp_exists
    sc_exists=$(_k get storageclass local-path --no-headers 2>/dev/null | grep -c "rancher.io/local-path" || echo "0")
    lpp_exists=$(_k get deployment local-path-provisioner -n local-path-storage --no-headers 2>/dev/null | wc -l || echo "0")

    if (( sc_exists > 0 )) && (( lpp_exists > 0 )); then
        _log "local-path-provisioner ya instalado — verificando estado"
        local ready
        ready=$(_k get deployment local-path-provisioner -n local-path-storage \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if (( ready > 0 )); then
            echo "${__STEP_SKIP__} instalar_local_path_provisioner: ya existe y está Ready"
        else
            _log "ADVERTENCIA: local-path-provisioner existe pero no está Ready"
            echo "${__STEP_OK__} instalar_local_path_provisioner: existe (degradado — reconciler reintentará)"
        fi
    else
        _log "Instalando local-path-provisioner v${LPP_VERSION}..."
        local lpp_url="https://raw.githubusercontent.com/rancher/local-path-provisioner/v${LPP_VERSION}/deploy/local-path-storage.yaml"
        local lpp_manifest
        lpp_manifest=$(mktemp)

        if command -v curl > /dev/null 2>&1; then
            curl -fsSL "$lpp_url" -o "$lpp_manifest" 2>>"$FICHA_LOG"
        else
            wget -q "$lpp_url" -O "$lpp_manifest" 2>>"$FICHA_LOG"
        fi

        _k apply -f "$lpp_manifest" >> "$FICHA_LOG" 2>&1
        rm -f "$lpp_manifest"

        _log "Esperando local-path-provisioner Ready (hasta 120s)..."
        local elapsed=0
        while (( elapsed < 120 )); do
            local ready
            ready=$(_k get deployment local-path-provisioner -n local-path-storage \
                -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            if (( ready > 0 )); then
                _log "local-path-provisioner Ready (${elapsed}s)"
                break
            fi
            sleep 5; elapsed=$((elapsed + 5))
        done
        if (( elapsed >= 120 )); then
            echo "${__STEP_FAIL__} instalar_local_path_provisioner: timeout 120s — pod no Ready"
            return 1
        fi
        echo "${__STEP_OK__} instalar_local_path_provisioner"
    fi

    # ── 3. Marcar local-path como StorageClass por defecto ────────
    echo "${__STEP_START__} marcar_storageclass_default"
    _k patch storageclass local-path \
        -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' \
        >> "$FICHA_LOG" 2>&1 || true

    # Quitar default de cualquier otra SC que lo tenga
    _k get storageclass --no-headers 2>/dev/null | awk '{print $1}' | while read -r sc; do
        [[ "$sc" == "local-path" ]] && continue
        local is_default
        is_default=$(_k get storageclass "$sc" \
            -o jsonpath='{.metadata.annotations.storageclass\.kubernetes\.io/is-default-class}' \
            2>/dev/null || echo "false")
        if [[ "$is_default" == "true" ]]; then
            _k patch storageclass "$sc" \
                -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' \
                >> "$FICHA_LOG" 2>&1 || true
            _log "StorageClass $sc desmarcada como default"
        fi
    done
    echo "${__STEP_OK__} marcar_storageclass_default"

    # ── 4. RBAC base: ClusterRole lectura para daemons SBOS ───────
    echo "${__STEP_START__} rbac_base"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sbos-daemon-reader
  labels:
    sbos.app/managed-by: bos
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "endpoints", "namespaces", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "statefulsets", "replicasets"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["batch"]
    resources: ["jobs"]
    verbs: ["get", "list", "watch"]
EOF
    echo "${__STEP_OK__} rbac_base"

    return 0
}

# ── Verify ────────────────────────────────────────────────────────
ficha_verify() {
    echo "${__STEP_START__} verificar_namespaces"
    local missing=0
    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"
        if ! _k get namespace "$ns" > /dev/null 2>&1; then
            _log "FALTA namespace: $ns"
            (( missing++ ))
        fi
    done
    if (( missing > 0 )); then
        echo "${__STEP_FAIL__} verificar_namespaces: faltan ${missing} namespaces"
        return 1
    fi
    echo "${__STEP_OK__} verificar_namespaces (${#NAMESPACES[@]} presentes)"

    echo "${__STEP_START__} verificar_storageclass"
    local sc_count
    sc_count=$(_k get storageclass local-path --no-headers 2>/dev/null | wc -l || echo "0")
    if (( sc_count < 1 )); then
        echo "${__STEP_FAIL__} verificar_storageclass: local-path no existe"
        return 1
    fi
    echo "${__STEP_OK__} verificar_storageclass"
    return 0
}

# ── Repair ───────────────────────────────────────────────────────
ficha_repair() {
    _log "ficha_repair: re-creando namespaces y StorageClass faltantes"
    # Re-ejecutar install es idempotente: kubectl apply no destruye namespaces existentes.
    ficha_install
}

# ── Test ─────────────────────────────────────────────────────────
ficha_test() {
    local ok=0
    local critical_ns=(sbos-data sbos-security sbos-gateway sbos-monitor sbos-ai sbos-docs sbos-ops)

    echo "${__STEP_START__} test_namespaces_criticos"
    local missing=0
    for ns in "${critical_ns[@]}"; do
        _k get namespace "$ns" > /dev/null 2>&1 || { _log "FALTA namespace: $ns"; missing=$((missing+1)); }
    done
    if (( missing == 0 )); then
        echo "${__STEP_OK__} test_namespaces_criticos (${#critical_ns[@]} presentes)"
    else
        echo "${__STEP_FAIL__} test_namespaces_criticos: ${missing} namespaces faltantes"; ok=1
    fi

    echo "${__STEP_START__} test_storageclass_local_path"
    _k get storageclass local-path > /dev/null 2>&1 \
        && echo "${__STEP_OK__} test_storageclass_local_path" \
        || { echo "${__STEP_FAIL__} test_storageclass_local_path: local-path no existe"; ok=1; }
    return $ok
}

# ── Health ────────────────────────────────────────────────────────
ficha_health() {
    local ns_count
    ns_count=$(_k get ns sbos-data sbos-security sbos-gateway sbos-monitor \
        --no-headers 2>/dev/null | wc -l || echo "0")
    if (( ns_count >= 4 )); then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: solo ${ns_count}/4 namespaces críticos presentes"
    return 1
}

# ── Post-install ─────────────────────────────────────────────────
# sbos-bootstrap-platform no tiene pods propios — post_install_generic esperaría
# 300s buscando pods que no existen. Esta función evita ese bloqueo.
ficha_post_install() { return 0; }

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    # Eliminar namespaces SOLO si están vacíos (sin pods).
    # Nunca eliminar en caliente — requiere aprobación HITL.
    _log "ADVERTENCIA: sbos-bootstrap-platform.remove() no elimina namespaces automáticamente."
    _log "Los namespaces contienen datos de producción. Usar 'bosctl ficha remove --force' para confirmar."
    echo "${__STEP_SKIP__} remove: requiere --force para eliminar namespaces con datos"
    return 0
}
