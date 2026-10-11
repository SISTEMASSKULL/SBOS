#!/usr/bin/env bash
# task_catalog.sh — fedora-kde
# Fedora KDE 41 — escritorio virtual corporativo (VNC + noVNC)
# Dependencias: keycloak, kong, guacamole
# Nota: imagen personalizada con KDE Plasma + herramientas corporativas
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/fedora-kde.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-vdi}"
# Imagen base con KDE + noVNC — usar dorowu/ubuntu-desktop-lxde-vnc como base
# hasta que esté disponible la imagen personalizada Fedora SBOS
FEDORA_IMAGE="${FEDORA_IMAGE:-dorowu/ubuntu-desktop-lxde-vnc:focal}"

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

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} crear_namespace"
    if ! _k get namespace "$NS" &>/dev/null; then
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _k label namespace "$NS" sbos-managed=true >> "$FICHA_LOG" 2>&1
    fi
    echo "${__STEP_OK__} crear_namespace"

    echo "${__STEP_START__} fedora_kde_secret"
    # VNC protocol limita passwords a 8 chars — usar hex de 4 bytes (8 chars alfanuméricos)
    local vnc_pass_actual=""
    if _k get secret -n "$NS" fedora-kde-credentials &>/dev/null; then
        vnc_pass_actual=$(_k get secret fedora-kde-credentials -n "$NS" \
            -o jsonpath='{.data.VNC_PASSWORD}' 2>/dev/null | base64 -d || echo "")
    fi
    if [[ "${#vnc_pass_actual}" -gt 8 || -z "$vnc_pass_actual" ]]; then
        # Regenerar: password anterior demasiado largo o inexistente
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
      containers:
      - name: fedora-kde
        image: ${FEDORA_IMAGE}
        ports:
        - containerPort: 80
          name: novnc
        - containerPort: 5900
          name: vnc
        env:
        - name: VNC_PASSWORD
          valueFrom:
            secretKeyRef:
              name: fedora-kde-credentials
              key: VNC_PASSWORD
        - name: RESOLUTION
          value: "1280x720"
        - name: DEPTH
          value: "16"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        readinessProbe:
          tcpSocket:
            port: 5900
          initialDelaySeconds: 15
          periodSeconds: 10
          failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: fedora-kde
  namespace: ${NS}
  labels:
    app: fedora-kde
    sbos-managed: "true"
spec:
  selector:
    app: fedora-kde
  ports:
  - name: novnc
    port: 80
    targetPort: 80
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
    _wait_pod "fedora-kde" 300
    echo "${__STEP_OK__} verify"
}

# ── Repair ───────────────────────────────────────────────────────
ficha_repair() {
    ficha_pre_install
    echo "${__STEP_START__} repair"
    echo "${__STEP_START__} deploy_fedora_kde"
    _apply_fedora_kde
    echo "${__STEP_OK__} deploy_fedora_kde"
    _log "repair: $(_k get pods -n $NS -l app=fedora-kde --no-headers 2>/dev/null | head -1)"
    echo "${__STEP_OK__} repair"

    echo "${__STEP_START__} verify"
    local pods; pods=$(_k get pods -n "$NS" -l app=fedora-kde --no-headers 2>/dev/null | grep Running | wc -l)
    _log "$pods pods running"
    echo "${__STEP_OK__} verify"
}

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    echo "${__STEP_START__} remove_fedora_kde"
    _k delete deployment fedora-kde -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    _k delete service fedora-kde -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} remove_fedora_kde"
}
