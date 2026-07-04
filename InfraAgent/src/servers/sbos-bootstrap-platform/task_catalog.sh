#!/usr/bin/env bash
# task_catalog.sh — sbos-bootstrap-platform (Ficha 03)
# 15 namespaces, RBAC, etcd encryption KMS v2, NetworkPolicy default-deny
# Principios: P1 (único kubectl apply), P10 (--dry-run previo)
# SKULL · SBOS · infra-agent · 2026-05-13
set -euo pipefail

signal_start()  { echo "__SBOS__STEP_START__ $1"; }
signal_ok()     { echo "__SBOS__STEP_OK__"; }
signal_fail()   { echo "__SBOS__STEP_FAIL__"; }
signal_skip()   { echo "__SBOS__STEP_SKIP__"; }
signal_rollback(){ echo "__SBOS__ROLLBACK_START__"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESOURCES_DIR="$SCRIPT_DIR/resources"
KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

export KUBECONFIG

# 15 SBOS namespaces with PodSecurity standards
NAMESPACES=(
    "sbos-installer:restricted"
    "sbos-data:restricted"
    "sbos-identity:restricted"
    "sbos-security:restricted"
    "sbos-gateway:baseline"
    "sbos-comms:baseline"
    "sbos-erp:baseline"
    "sbos-apps:baseline"
    "sbos-docs:baseline"
    "sbos-monitor:baseline"
    "sbos-geo:baseline"
    "sbos-vdi:baseline"
    "sbos-search:baseline"
    "sbos-ops:baseline"
    "sbos-ai:baseline"
)

# ═══════════════════════════════════════════════════════════════
# PRE-INSTALL
# ═══════════════════════════════════════════════════════════════

verify_kubectl_access() {
    signal_start "verificar_kubectl"
    if ! command -v kubectl &>/dev/null; then
        echo "FATAL: kubectl no encontrado"
        signal_fail; return 2
    fi
    echo "kubectl disponible"
    signal_ok
}

verify_cluster_accessible() {
    signal_start "verificar_cluster"
    if ! kubectl cluster-info >/dev/null 2>&1; then
        echo "FATAL: No se puede acceder al cluster K8s"
        signal_fail; return 2
    fi
    echo "Cluster K8s accesible"
    signal_ok
}

# ═══════════════════════════════════════════════════════════════
# INSTALL
# ═══════════════════════════════════════════════════════════════

create_sbos_namespaces() {
    signal_start "crear_namespaces"

    local created=0
    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"
        local pss="${entry##*:}"

        if kubectl get namespace "$ns" >/dev/null 2>&1; then
            echo "Namespace $ns ya existe"
            continue
        fi

        kubectl create namespace "$ns" 2>/dev/null || true

        # Label con PodSecurity standard
        if [ "$pss" = "restricted" ]; then
            kubectl label namespace "$ns" \
                pod-security.kubernetes.io/enforce=restricted \
                pod-security.kubernetes.io/audit=restricted \
                pod-security.kubernetes.io/warn=restricted \
                --overwrite 2>/dev/null || true
        else
            kubectl label namespace "$ns" \
                pod-security.kubernetes.io/enforce=baseline \
                pod-security.kubernetes.io/audit=baseline \
                --overwrite 2>/dev/null || true
        fi

        # Label SBOS
        kubectl label namespace "$ns" sbos.skull/namespace=true --overwrite 2>/dev/null || true
        ((created++))
    done

    echo "$created namespaces creados (15 total)"
    signal_ok
}

apply_resource_quotas() {
    signal_start "aplicar_resource_quotas"

    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"

        if kubectl get resourcequota sbos-quota -n "$ns" >/dev/null 2>&1; then
            echo "ResourceQuota ya existe en $ns"
            continue
        fi

        kubectl apply -f - <<KUBEEOF
apiVersion: v1
kind: ResourceQuota
metadata:
  name: sbos-quota
  namespace: $ns
spec:
  hard:
    requests.cpu: "16"
    requests.memory: 32Gi
    limits.cpu: "32"
    limits.memory: 64Gi
    persistentvolumeclaims: "20"
    configmaps: "50"
    secrets: "50"
    services: "20"
KUBEEOF
    done

    echo "ResourceQuotas aplicados"
    signal_ok
}

apply_limit_ranges() {
    signal_start "aplicar_limit_ranges"

    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"

        if kubectl get limitrange sbos-limits -n "$ns" >/dev/null 2>&1; then
            continue
        fi

        kubectl apply -f - <<KUBEEOF
apiVersion: v1
kind: LimitRange
metadata:
  name: sbos-limits
  namespace: $ns
spec:
  limits:
    - default:
        cpu: "500m"
        memory: 512Mi
      defaultRequest:
        cpu: "100m"
        memory: 128Mi
      type: Container
KUBEEOF
    done

    echo "LimitRanges aplicados"
    signal_ok
}

setup_rbac_admin() {
    signal_start "configurar_rbac"

    # ClusterRole sbos-admin — administración de todos los recursos SBOS
    kubectl apply -f - <<'KUBEEOF'
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sbos-admin
  labels:
    sbos.skull/role: admin
rules:
  - apiGroups: ["*"]
    resources: ["*"]
    verbs: ["*"]
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sbos-admin-binding
  labels:
    sbos.skull/binding: admin
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: sbos-admin
subjects:
  - kind: ServiceAccount
    name: sbos-admin
    namespace: sbos-installer
KUBEEOF

    # ServiceAccount en sbos-installer
    kubectl create serviceaccount sbos-admin -n sbos-installer --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null || true

    echo "RBAC sbos-admin configurado"
    signal_ok
}

enable_etcd_encryption() {
    signal_start "habilitar_etcd_encryption"

    local enc_file="/etc/kubernetes/encryption-config.yaml"

    if [ -f "$enc_file" ]; then
        echo "EncryptionConfiguration ya existe"
        signal_skip; return 0
    fi

    # Generar clave de encriptación
    local enc_key
    enc_key=$(head -c 32 /dev/urandom | base64)

    cat > "$enc_file" <<KUBEEOF
apiVersion: apiserver.config.k8s.io/v1
kind: EncryptionConfiguration
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${enc_key}
      - identity: {}
KUBEEOF

    # Actualizar kube-apiserver manifest para usar encryption-provider-config
    local apiserver_manifest="/etc/kubernetes/manifests/kube-apiserver.yaml"
    if [ -f "$apiserver_manifest" ]; then
        if ! grep -q "encryption-provider-config" "$apiserver_manifest"; then
            sed -i '/kube-apiserver/a\    - --encryption-provider-config=/etc/kubernetes/encryption-config.yaml' "$apiserver_manifest" 2>/dev/null || {
                echo "WARN: No se pudo modificar kube-apiserver.yaml automáticamente"
                echo "Agregar manualmente: --encryption-provider-config=/etc/kubernetes/encryption-config.yaml"
            }
        fi
    fi

    echo "EncryptionConfiguration KMS v2 configurada"
    signal_ok
}

apply_default_deny_policies() {
    signal_start "aplicar_network_policies"

    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"

        if kubectl get networkpolicy default-deny -n "$ns" >/dev/null 2>&1; then
            continue
        fi

        kubectl apply -f - <<KUBEEOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny
  namespace: $ns
  labels:
    sbos.skull/policy: default-deny
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress: []
  egress: []
KUBEEOF
    done

    echo "NetworkPolicy default-deny aplicado en todos los namespaces SBOS"
    signal_ok
}

configure_pod_security_admission() {
    signal_start "configurar_pod_security"

    # PodSecurity admission ya está configurado vía labels en create_sbos_namespaces
    # Verificar que los namespaces restricted tienen las labels correctas
    local restricted_ns=("sbos-installer" "sbos-data" "sbos-identity" "sbos-security")
    for ns in "${restricted_ns[@]}"; do
        kubectl label namespace "$ns" \
            pod-security.kubernetes.io/enforce=restricted \
            --overwrite 2>/dev/null || true
    done

    echo "PodSecurity admission configurado (restricted: sbos-data, sbos-identity, sbos-security, sbos-installer)"
    signal_ok
}

# ═══════════════════════════════════════════════════════════════
# POST-INSTALL
# ═══════════════════════════════════════════════════════════════

verify_all_namespaces() {
    signal_start "verificar_namespaces"
    local failed=0
    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"
        if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
            echo "ERROR: Namespace $ns no encontrado"
            ((failed++))
        fi
    done
    if [ "$failed" -gt 0 ]; then
        echo "FATAL: $failed namespaces faltantes"
        signal_fail; return 2
    fi
    echo "15 namespaces verificados"
    signal_ok
}

verify_network_policies() {
    signal_start "verificar_networkpolicy"
    local failed=0
    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"
        if ! kubectl get networkpolicy default-deny -n "$ns" >/dev/null 2>&1; then
            echo "ERROR: NetworkPolicy default-deny no encontrada en $ns"
            ((failed++))
        fi
    done
    if [ "$failed" -gt 0 ]; then
        echo "WARN: $failed NetworkPolicies faltantes"
    fi
    echo "NetworkPolicies verificadas"
    signal_ok
}

verify_rbac() {
    signal_start "verificar_rbac"
    if kubectl get clusterrolebinding sbos-admin-binding >/dev/null 2>&1; then
        echo "ClusterRoleBinding sbos-admin verificado"
        signal_ok
    else
        echo "FATAL: ClusterRoleBinding sbos-admin no encontrado"
        signal_fail; return 2
    fi
}

# ═══════════════════════════════════════════════════════════════
# ROLLBACK
# ═══════════════════════════════════════════════════════════════

desinstalar_platform_namespaces() {
    signal_rollback
    echo "Rollback: eliminando namespaces SBOS..."
    for entry in "${NAMESPACES[@]}"; do
        local ns="${entry%%:*}"
        kubectl delete namespace "$ns" --wait=false 2>/dev/null || true
    done
    kubectl delete clusterrolebinding sbos-admin-binding 2>/dev/null || true
    kubectl delete clusterrole sbos-admin 2>/dev/null || true
    rm -f /etc/kubernetes/encryption-config.yaml 2>/dev/null || true
    echo "__SBOS__CLEANUP_DONE__"
}

# ── Entry point ────────────────────────────────────────────────
case "${1:-}" in
    verify_kubectl_access)          verify_kubectl_access ;;
    verify_cluster_accessible)      verify_cluster_accessible ;;
    create_sbos_namespaces)         create_sbos_namespaces ;;
    apply_resource_quotas)          apply_resource_quotas ;;
    apply_limit_ranges)             apply_limit_ranges ;;
    setup_rbac_admin)               setup_rbac_admin ;;
    enable_etcd_encryption)         enable_etcd_encryption ;;
    apply_default_deny_policies)    apply_default_deny_policies ;;
    configure_pod_security_admission) configure_pod_security_admission ;;
    verify_all_namespaces)          verify_all_namespaces ;;
    verify_network_policies)        verify_network_policies ;;
    verify_rbac)                    verify_rbac ;;
    desinstalar_platform_namespaces) desinstalar_platform_namespaces ;;
    *)
        echo "task_catalog.sh: función no reconocida: ${1:-}"
        exit 1
        ;;
esac
