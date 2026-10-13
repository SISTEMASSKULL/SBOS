#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — linkerd
# Iteración 1: Linkerd stable-2.14.10 service mesh + mTLS + auto-inject namespaces SBOS
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
# Versiones de chart helm (app version stable-2.14.10)
readonly LINKERD_CRDS_VERSION="1.8.0"
readonly LINKERD_CP_VERSION="1.16.11"

# Helm usa /.config/helm cuando el proceso no tiene HOME=/root (ej: bosagent o systemd).
# Respetar lo que ya esté seteado; si no, apuntar al directorio donde se registraron
# los repos durante el bootstrap (kyverno los registró con este mismo contexto).
export HELM_CONFIG_HOME="${HELM_CONFIG_HOME:-/.config/helm}"
export HELM_DATA_HOME="${HELM_DATA_HOME:-/.local/share/helm}"
export HELM_CACHE_HOME="${HELM_CACHE_HOME:-/.cache/helm}"
# KUBECONFIG para helm (BOS executor lo pasa; modo manual usa KUBECONFIG_DEST)
export KUBECONFIG="${KUBECONFIG:-${KUBECONFIG_DEST}}"

# Directorio temporal para certs TLS — variable global para que sobreviva el return
# de _gen_linkerd_certs y los archivos sean legibles por helm --set-file
_LINKERD_CERT_TMP=""

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

# _gen_linkerd_certs: genera trust anchor + issuer cert ECDSA P-256 y los almacena
# como secret K8s. Idempotente: no regenera si el secret ya existe.
# Usa _LINKERD_CERT_TMP (global) en lugar de local+trap para que los archivos
# sobrevivan al return y puedan ser leídos por helm --set-file.
_gen_linkerd_certs() {
    _LINKERD_CERT_TMP=$(mktemp -d /tmp/linkerd-certs-XXXXXX)

    # Si el secret de issuer ya existe (instalación previa), usar los existentes
    if _k get secret linkerd-identity-issuer -n "$NS" > /dev/null 2>&1; then
        _log "Secret linkerd-identity-issuer ya existe — reutilizando certificados"
        _k get secret linkerd-identity-issuer -n "$NS" \
            -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d > "${_LINKERD_CERT_TMP}/issuer.crt"
        _k get secret linkerd-identity-issuer -n "$NS" \
            -o jsonpath='{.data.tls\.key}' 2>/dev/null | base64 -d > "${_LINKERD_CERT_TMP}/issuer.key"
        _k get secret linkerd-identity-issuer -n "$NS" \
            -o jsonpath='{.data.ca\.crt}' 2>/dev/null | base64 -d > "${_LINKERD_CERT_TMP}/ca.crt" || \
        _k get configmap linkerd-identity-trust-roots -n "$NS" \
            -o jsonpath='{.data.ca-bundle\.crt}' 2>/dev/null > "${_LINKERD_CERT_TMP}/ca.crt" || true
        if [[ -s "${_LINKERD_CERT_TMP}/issuer.crt" ]]; then
            LINKERD_CA_CRT="${_LINKERD_CERT_TMP}/ca.crt"
            LINKERD_ISSUER_CRT="${_LINKERD_CERT_TMP}/issuer.crt"
            LINKERD_ISSUER_KEY="${_LINKERD_CERT_TMP}/issuer.key"
            export LINKERD_CA_CRT LINKERD_ISSUER_CRT LINKERD_ISSUER_KEY
            return 0
        fi
    fi

    _log "Generando certificados TLS ECDSA P-256 para linkerd identity..."

    # Trust anchor (CA raíz auto-firmado, 10 años)
    openssl ecparam -genkey -name prime256v1 -noout -out "${_LINKERD_CERT_TMP}/ca.key" 2>/dev/null
    openssl req -x509 -new -nodes -days 3650 \
        -subj "/CN=root.linkerd.cluster.local" \
        -key "${_LINKERD_CERT_TMP}/ca.key" \
        -out "${_LINKERD_CERT_TMP}/ca.crt" \
        -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null

    # Issuer cert (CA intermedio firmado por trust anchor, 1 año)
    openssl ecparam -genkey -name prime256v1 -noout -out "${_LINKERD_CERT_TMP}/issuer.key" 2>/dev/null
    openssl req -new -nodes \
        -subj "/CN=identity.linkerd.cluster.local" \
        -key "${_LINKERD_CERT_TMP}/issuer.key" -out "${_LINKERD_CERT_TMP}/issuer.csr" 2>/dev/null
    openssl x509 -req -days 365 \
        -CA "${_LINKERD_CERT_TMP}/ca.crt" -CAkey "${_LINKERD_CERT_TMP}/ca.key" -CAcreateserial \
        -in "${_LINKERD_CERT_TMP}/issuer.csr" -out "${_LINKERD_CERT_TMP}/issuer.crt" \
        -extfile <(printf 'basicConstraints=critical,CA:TRUE,pathlen:0\nkeyUsage=critical,keyCertSign,cRLSign\n') \
        2>/dev/null

    # Guardar issuer secret para idempotencia en futuras ejecuciones
    _k create namespace "$NS" 2>/dev/null || true
    _k create secret generic linkerd-identity-issuer \
        -n "$NS" \
        --from-file=tls.crt="${_LINKERD_CERT_TMP}/issuer.crt" \
        --from-file=tls.key="${_LINKERD_CERT_TMP}/issuer.key" \
        --from-file=ca.crt="${_LINKERD_CERT_TMP}/ca.crt" \
        --dry-run=client -o yaml | _k apply -f - 2>/dev/null || true

    LINKERD_CA_CRT="${_LINKERD_CERT_TMP}/ca.crt"
    LINKERD_ISSUER_CRT="${_LINKERD_CERT_TMP}/issuer.crt"
    LINKERD_ISSUER_KEY="${_LINKERD_CERT_TMP}/issuer.key"
    export LINKERD_CA_CRT LINKERD_ISSUER_CRT LINKERD_ISSUER_KEY

    _log "Certificados generados: CA=$(openssl x509 -noout -subject -in "${_LINKERD_CERT_TMP}/ca.crt" 2>/dev/null | sed 's/.*CN=//')"
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

    # ── 0. Verificar/instalar helm ────────────────────────────────
    echo "${__STEP_START__} verificar_helm"
    if ! command -v helm &>/dev/null; then
        local HELM_VERSION="3.16.3"
        local HELM_TMP; HELM_TMP=$(mktemp -d)
        _log "Helm no encontrado — descargando v${HELM_VERSION}..."
        curl -fsSL "https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz" \
            -o "${HELM_TMP}/helm.tar.gz" >> "$FICHA_LOG" 2>&1 || {
            echo "${__STEP_FAIL__} verificar_helm: descarga fallida"
            rm -rf "$HELM_TMP"; return 1
        }
        tar -xzf "${HELM_TMP}/helm.tar.gz" -C "$HELM_TMP" >> "$FICHA_LOG" 2>&1
        install -m 755 "${HELM_TMP}/linux-amd64/helm" /usr/local/bin/helm
        rm -rf "$HELM_TMP"
    fi
    echo "${__STEP_OK__} verificar_helm ($(helm version --short 2>/dev/null))"

    # ── 1. Agregar repo linkerd y generar certificados TLS ────────
    echo "${__STEP_START__} preparar_certificados"
    helm repo add linkerd https://helm.linkerd.io/stable >> "$FICHA_LOG" 2>&1 || true
    helm repo update >> "$FICHA_LOG" 2>&1 || true
    _k create namespace "$NS" 2>/dev/null || true

    _gen_linkerd_certs || {
        echo "${__STEP_FAIL__} preparar_certificados: error generando TLS"
        return 1
    }
    echo "${__STEP_OK__} preparar_certificados"

    # ── 2. Instalar linkerd CRDs ──────────────────────────────────
    echo "${__STEP_START__} instalar_linkerd_crds"
    _log "Instalando/actualizando linkerd-crds (v${LINKERD_CRDS_VERSION})..."
    helm upgrade --install linkerd-crds "linkerd/linkerd-crds" \
        --namespace "$NS" \
        --version "${LINKERD_CRDS_VERSION}" \
        --timeout 5m \
        >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} instalar_linkerd_crds: helm upgrade --install falló"
        return 1
    }
    # Esperar a que el CRD principal esté registrado
    local crd_ok=0
    for _i in $(seq 1 24); do
        if _k get crd serviceprofiles.linkerd.io >/dev/null 2>&1; then
            crd_ok=1; break
        fi
        _log "  CRD serviceprofiles.linkerd.io aún no registrado, esperando 5s... (${_i}/24)"
        sleep 5
    done
    if [[ "$crd_ok" -eq 0 ]]; then
        echo "${__STEP_FAIL__} instalar_linkerd_crds: CRDs no registrados en 120s"
        return 1
    fi
    echo "${__STEP_OK__} instalar_linkerd_crds"

    # ── 3. Instalar linkerd control plane ─────────────────────────
    echo "${__STEP_START__} instalar_control_plane"

    # Adoptar el secret de identity-issuer por helm antes del install.
    # Si fue creado manualmente (sin labels helm), helm rechaza adoptarlo.
    if _k get secret linkerd-identity-issuer -n "$NS" > /dev/null 2>&1; then
        _k annotate secret linkerd-identity-issuer -n "$NS" \
            "meta.helm.sh/release-name=linkerd-control-plane" \
            "meta.helm.sh/release-namespace=${NS}" \
            --overwrite >> "$FICHA_LOG" 2>&1 || true
        _k label secret linkerd-identity-issuer -n "$NS" \
            "app.kubernetes.io/managed-by=Helm" \
            --overwrite >> "$FICHA_LOG" 2>&1 || true
        _log "Secret linkerd-identity-issuer etiquetado para adopción por helm"
    fi

    _log "Instalando/actualizando linkerd-control-plane v${LINKERD_CP_VERSION} (app stable-2.14.10)..."
    helm upgrade --install linkerd-control-plane "linkerd/linkerd-control-plane" \
        --namespace "$NS" \
        --version "${LINKERD_CP_VERSION}" \
        --set-file identityTrustAnchorsPEM="${LINKERD_CA_CRT}" \
        --set-file identity.issuer.tls.crtPEM="${LINKERD_ISSUER_CRT}" \
        --set-file identity.issuer.tls.keyPEM="${LINKERD_ISSUER_KEY}" \
        --set controllerReplicas=1 \
        --set "proxy.resources.cpu.request=50m" \
        --set "proxy.resources.cpu.limit=500m" \
        --set "proxy.resources.memory.request=64Mi" \
        --set "proxy.resources.memory.limit=256Mi" \
        --set "proxyInit.iptablesMode=nft" \
        --timeout 10m \
        >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} instalar_control_plane: helm upgrade --install falló"
        return 1
    }
    echo "${__STEP_OK__} instalar_control_plane"

    # ── 4. Esperar que los pods del control plane estén Ready ─────
    echo "${__STEP_START__} wait_control_plane_ready"
    _log "Esperando pods linkerd control plane (hasta 15m — descarga de imágenes puede tardar)..."
    local pods_ok=0
    for _i in $(seq 1 90); do
        local ready_count
        ready_count=$(_k get pod -n "$NS" --no-headers 2>/dev/null | \
            grep -v "^$" | grep -E "^[a-z0-9-]+ +[0-9]+/[0-9]+ +Running" | \
            awk -F'[ /]+' '{if ($2==$3) print}' | wc -l || echo "0")
        local total_count
        total_count=$(_k get pod -n "$NS" --no-headers 2>/dev/null | grep -v "^$" | wc -l || echo "0")
        if [[ "$total_count" -gt 0 && "$ready_count" -ge "$total_count" ]]; then
            pods_ok=1; break
        fi
        _log "  Control plane pods ready: ${ready_count}/${total_count} (${_i}/90)"
        sleep 10
    done
    if [[ "$pods_ok" -eq 0 ]]; then
        echo "${__STEP_FAIL__} wait_control_plane_ready: pods no Ready en 15m"
        return 1
    fi
    _log "Control plane listo"
    echo "${__STEP_OK__} wait_control_plane_ready"

    # ── 5. Activar auto-inject en namespaces SBOS ─────────────────
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

    # ── 6. NetworkPolicy para linkerd ─────────────────────────────
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
    # Proxy injector webhook (8443) — API server lo alcanza desde cualquier NS
    - ports:
        - protocol: TCP
          port: 8443
    # Métricas (4191, 9990) — desde monitoring
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

    # Limpiar directorio temporal de certs
    [[ -n "${_LINKERD_CERT_TMP:-}" ]] && rm -rf "$_LINKERD_CERT_TMP" || true
    _LINKERD_CERT_TMP=""

    _log "linkerd ${LINKERD_CP_VERSION} instalado (control plane + auto-inject ${injected} namespaces)"
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
    # Si el control plane no está desplegado (stub previo), re-instalar completamente
    local pod_count
    pod_count=$(_k get pod -n "$NS" --no-headers 2>/dev/null | grep -v "^$" | wc -l || echo "0")
    if [[ "$pod_count" -eq 0 ]]; then
        _log "No hay pods en namespace linkerd — ejecutando instalación completa"
        ficha_install
        return $?
    fi

    # BUG-29: limpiar ReplicaSets huérfanos (0/0/0) de instalaciones/crashes anteriores.
    # Consumen registros en la API pero no sirven ningún propósito.
    echo "${__STEP_START__} limpiar_replicasets_huerfanos"
    local orphan_rs
    orphan_rs=$(_k get rs -n "$NS" --no-headers 2>/dev/null | awk '$2==0 && $3==0 && $4==0 {print $1}')
    if [[ -n "$orphan_rs" ]]; then
        local count=0
        while IFS= read -r rs; do
            _k delete rs "$rs" -n "$NS" 2>/dev/null && count=$((count+1)) || true
        done <<< "$orphan_rs"
        _log "ReplicaSets huérfanos eliminados: $count"
        echo "${__STEP_OK__} limpiar_replicasets_huerfanos ($count eliminados)"
    else
        echo "${__STEP_SKIP__} limpiar_replicasets_huerfanos: ninguno"
    fi

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
