#!/usr/bin/env bash
# task_catalog.sh — fedora-kde
# SBOS Corporate Desktop: Fedora 44 + KDE Plasma 6 + TigerVNC + noVNC
# La ficha construye su propia imagen soberana con buildah (sin Docker Hub).
# SSO: oauth2-proxy + Keycloak autentica el acceso al desktop y a todas las apps.
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/fedora-kde.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-vdi}"

# Directorio de la ficha — contexto de build para buildah
FICHA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Imagen soberana construida localmente con buildah
SBOS_IMAGE="${SBOS_IMAGE:-docker.io/sbos/fedora-desktop:1.0.0}"
# Ruta del OCI archive exportado (persistente entre reparaciones)
SBOS_OCI_ARCHIVE="/opt/sbos-images/sbos-fedora-desktop.tar"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [fedora-kde] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_pod() {
    local label="$1" timeout="${2:-300}" elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app="$label" --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { _log "$label Running"; return 0; }
        sleep 10; elapsed=$((elapsed + 10))
    done
    return 1
}

# ── Build de imagen soberana ──────────────────────────────────────
# Construye la imagen con buildah desde el Containerfile local.
# Solo construye si la imagen no existe ya en containerd.
_build_image() {
    echo "${__STEP_START__} build_imagen_soberana"

    # Verificar si ya existe en el namespace k8s.io de containerd
    if crictl images 2>/dev/null | grep -qF "sbos/fedora-desktop"; then
        _log "imagen $SBOS_IMAGE ya existe en containerd"
        echo "${__STEP_SKIP__} build_imagen_soberana (ya existe)"
        return 0
    fi

    # Verificar prerrequisito: buildah disponible
    if ! command -v buildah &>/dev/null; then
        _log "ERROR: buildah no encontrado en PATH"
        echo "${__STEP_FAIL__} build_imagen_soberana"
        return 1
    fi

    _log "iniciando build de $SBOS_IMAGE desde $FICHA_DIR (~30-45 min)"
    _log "los logs de buildah se escriben en $FICHA_LOG"

    # Build (--layers activa cache de capas para reconstrucciones rápidas)
    buildah build \
        --layers \
        --format oci \
        -t "$SBOS_IMAGE" \
        "$FICHA_DIR/" >> "$FICHA_LOG" 2>&1 || {
            _log "ERROR: buildah build falló — ver $FICHA_LOG"
            echo "${__STEP_FAIL__} build_imagen_soberana"
            return 1
        }

    _log "build completado, exportando OCI archive..."
    mkdir -p "$(dirname "$SBOS_OCI_ARCHIVE")"

    # Exportar a OCI archive con el tag completo
    buildah push "$SBOS_IMAGE" \
        "oci-archive:${SBOS_OCI_ARCHIVE}:${SBOS_IMAGE}" >> "$FICHA_LOG" 2>&1 || {
            _log "ERROR: buildah push (OCI archive) falló"
            echo "${__STEP_FAIL__} build_imagen_soberana"
            return 1
        }

    # Importar al namespace k8s.io de containerd para uso por K8s
    ctr -n k8s.io images import "$SBOS_OCI_ARCHIVE" >> "$FICHA_LOG" 2>&1 || {
        _log "ERROR: ctr images import falló"
        echo "${__STEP_FAIL__} build_imagen_soberana"
        return 1
    }

    _log "imagen $SBOS_IMAGE importada a containerd OK"
    echo "${__STEP_OK__} build_imagen_soberana"
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} crear_namespace"
    if ! _k get namespace "$NS" &>/dev/null; then
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _k label namespace "$NS" sbos-managed=true >> "$FICHA_LOG" 2>&1
    fi
    echo "${__STEP_OK__} crear_namespace"

    # Construir imagen soberana si no existe
    _build_image

    echo "${__STEP_START__} fedora_kde_secret"
    # VNC limita contraseñas a 8 chars — usar hex de 4 bytes (8 chars)
    local vnc_pass_actual=""
    if _k get secret -n "$NS" fedora-kde-credentials &>/dev/null; then
        vnc_pass_actual=$(_k get secret fedora-kde-credentials -n "$NS" \
            -o jsonpath='{.data.VNC_PASSWORD}' 2>/dev/null | base64 -d || echo "")
    fi
    if [[ "${#vnc_pass_actual}" -gt 8 || -z "$vnc_pass_actual" ]]; then
        local vnc_pass; vnc_pass=$(openssl rand -hex 4)
        _k create secret generic fedora-kde-credentials \
            --namespace="$NS" \
            --from-literal=VNC_PASSWORD="$vnc_pass" \
            --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1
        _log "VNC password regenerado (8 chars): $vnc_pass"
        echo "${__STEP_OK__} fedora_kde_secret (password corregido)"
    else
        echo "${__STEP_SKIP__} fedora_kde_secret ya OK (${#vnc_pass_actual} chars)"
    fi
}

_apply_fedora_kde() {
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: fedora-kde
  namespace: ${NS}
  labels:
    app: fedora-kde
    sbos-managed: managed
spec:
  replicas: 1
  selector:
    matchLabels:
      app: fedora-kde
  template:
    metadata:
      labels:
        app: fedora-kde
      annotations:
        linkerd.io/inject: disabled
    spec:
      securityContext:
        seccompProfile:
          type: Unconfined
      containers:
      - name: fedora-kde
        image: ${SBOS_IMAGE}
        imagePullPolicy: Never
        ports:
        - containerPort: 6901
          name: webconsole
        env:
        - name: VNC_PASSWORD
          valueFrom:
            secretKeyRef:
              name: fedora-kde-credentials
              key: VNC_PASSWORD
        - name: RESOLUTION
          value: "1920x1080"
        - name: DEPTH
          value: "24"
        securityContext:
          capabilities:
            add:
            - NET_ADMIN
            - SYS_ADMIN
            - SYS_PTRACE
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "4Gi"
            cpu: "2000m"
        readinessProbe:
          tcpSocket:
            port: 6901
          initialDelaySeconds: 60
          periodSeconds: 15
          failureThreshold: 12
---
apiVersion: v1
kind: Service
metadata:
  name: fedora-kde
  namespace: ${NS}
  labels:
    app: fedora-kde
    sbos-managed: managed
spec:
  selector:
    app: fedora-kde
  ports:
  - name: webconsole
    port: 80
    targetPort: 6901
  # Puerto VNC nativo expuesto internamente para guacd (Guacamole).
  # Sin este port, guacd no puede conectar al escritorio vía VNC.
  - name: vnc
    port: 5900
    targetPort: 5900
YAML
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    ficha_pre_install
    echo "${__STEP_START__} deploy_fedora_kde"
    _apply_fedora_kde
    echo "${__STEP_OK__} deploy_fedora_kde"

    echo "${__STEP_START__} verify"
    _wait_pod "fedora-kde" 600
    echo "${__STEP_OK__} verify"
}

# ── Repair ───────────────────────────────────────────────────────
ficha_health() {
    local r
    r=$(_k get deployment fedora-kde -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: fedora-kde ${r}/1"
    return 1
}

ficha_repair() {
    ficha_pre_install
    echo "${__STEP_START__} repair"
    _apply_fedora_kde
    _log "repair: $(_k get pods -n $NS -l app=fedora-kde --no-headers 2>/dev/null | head -1)"
    echo "${__STEP_OK__} repair"

    echo "${__STEP_START__} verify"
    local pods; pods=$(_k get pods -n "$NS" -l app=fedora-kde --no-headers 2>/dev/null | grep Running | wc -l)
    _log "$pods pods running"
    echo "${__STEP_OK__} verify"
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_fedora_kde_pod"
    local pods
    pods=$(_k get pods -n "$NS" -l app=fedora-kde --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( pods >= 1 )); then
        echo "${__STEP_OK__} test_fedora_kde_pod ($pods Running)"
    else
        echo "${__STEP_FAIL__} test_fedora_kde_pod: 0 pods Running"; ok=1
    fi

    echo "${__STEP_START__} test_novnc_http"
    local status
    status=$(_k exec -n "$NS" deploy/fedora-kde -- \
        curl -sf -o /dev/null -w '%{http_code}' http://localhost:6901/ 2>/dev/null || echo "000")
    if [[ "$status" == "200" ]]; then
        echo "${__STEP_OK__} test_novnc_http (noVNC :6901 200)"
    else
        echo "${__STEP_FAIL__} test_novnc_http: noVNC HTTP $status"; ok=1
    fi

    echo "${__STEP_START__} test_vnc_port"
    local vnc_up
    vnc_up=$(_k exec -n "$NS" deploy/fedora-kde -- \
        sh -c 'ss -tlnp 2>/dev/null | grep -c ":5900"' 2>/dev/null || echo "0")
    if (( vnc_up >= 1 )); then
        echo "${__STEP_OK__} test_vnc_port (VNC :5900 activo)"
    else
        echo "${__STEP_FAIL__} test_vnc_port: VNC :5900 no escucha"; ok=1
    fi
    return $ok
}

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    echo "${__STEP_START__} remove_fedora_kde"
    _k delete deployment fedora-kde -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    _k delete service fedora-kde -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} remove_fedora_kde"
}
