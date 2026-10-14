#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — mailserver
# docker-mailserver 14.0.0 — servidor de correo soberano (Postfix + Dovecot).
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/mailserver.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-comms"
MAIL_VERSION="${MAIL_VERSION:-14.0.0}"
DOMAIN="${BOS_DOMAIN:-sbos.app}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [mailserver] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_sts_ready() {
    local s="$1" n="$2" t="${3:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get statefulset "$s" -n "$n" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5)); (( e % 30 == 0 )) && _log "Esperando $s... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || { echo "${__STEP_FAIL__} verificar_namespace: $NS no existe"; return 1; }
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /data/mailserver/data /data/mailserver/state

    local ready
    ready=$(_k get statefulset mailserver -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} mailserver_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} aplicar_manifests_mailserver"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS}
  labels:
    kubernetes.io/metadata.name: ${NS}
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sbos-mailserver-data-pv
  labels:
    sbos.app/managed-by: bos
spec:
  capacity:
    storage: 50Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /data/mailserver/data
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    namespace: ${NS}
    name: mailserver-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mailserver-data
  namespace: ${NS}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests:
      storage: 50Gi
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mailserver
  namespace: ${NS}
  labels:
    app: mailserver
    app.kubernetes.io/part-of: commsserver
    sbos.app/managed-by: bos
spec:
  serviceName: mailserver
  replicas: 1
  selector:
    matchLabels:
      app: mailserver
  template:
    metadata:
      labels:
        app: mailserver
    spec:
      hostname: mail
      containers:
        - name: mailserver
          image: ghcr.io/docker-mailserver/docker-mailserver:${MAIL_VERSION}
          env:
            - name: OVERRIDE_HOSTNAME
              value: "mail.${DOMAIN}"
            - name: SSL_TYPE
              value: "manual"
            - name: ENABLE_SPAMASSASSIN
              value: "1"
            - name: ENABLE_CLAMAV
              value: "0"
            - name: ENABLE_FAIL2BAN
              value: "0"
            - name: ONE_DIR
              value: "1"
          ports:
            - containerPort: 25
            - containerPort: 465
            - containerPort: 587
            - containerPort: 143
            - containerPort: 993
          volumeMounts:
            - name: data
              mountPath: /var/mail
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: mailserver-data
---
apiVersion: v1
kind: Service
metadata:
  name: mailserver
  namespace: ${NS}
spec:
  selector:
    app: mailserver
  ports:
    - name: smtp
      port: 25
      targetPort: 25
    - name: smtps
      port: 465
      targetPort: 465
    - name: smtp-submission
      port: 587
      targetPort: 587
    - name: imap
      port: 143
      targetPort: 143
    - name: imaps
      port: 993
      targetPort: 993
EOF
    echo "${__STEP_OK__} aplicar_manifests_mailserver"

    echo "${__STEP_START__} esperar_mailserver_ready"
    _wait_sts_ready mailserver "$NS" 180 || { echo "${__STEP_FAIL__} esperar_mailserver_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_mailserver_ready"

    # Abrir puertos de correo en UFW si está activo (idempotente con --force)
    echo "${__STEP_START__} abrir_puertos_ufw"
    if command -v ufw > /dev/null 2>&1 && ufw status 2>/dev/null | grep -q "active"; then
        for port in 25 465 587 143 993; do
            ufw allow "$port/tcp" >> "$FICHA_LOG" 2>&1 || true
        done
        _log "UFW: puertos SMTP/IMAP abiertos (25/465/587/143/993)"
        echo "${__STEP_OK__} abrir_puertos_ufw"
    else
        echo "${__STEP_SKIP__} abrir_puertos_ufw: UFW no activo"
    fi
    return 0
}

ficha_post_install() {
    echo "${__STEP_START__} schema_mailserver_db"
    local pg_pod pg_ns
    pg_pod="postgresql-0"
    pg_ns="sbos-data"

    # Verificar acceso a PostgreSQL
    if ! _k get pod "$pg_pod" -n "$pg_ns" > /dev/null 2>&1; then
        echo "${__STEP_SKIP__} schema_mailserver_db: pod PG no disponible — se reintentará en repair"
        return 0
    fi

    # Idempotencia: verificar si tabla ya existe
    local tbl_exists
    tbl_exists=$(_k exec "$pg_pod" -n "$pg_ns" -- psql -U postgres -tAc \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_name='virtual_mailboxes';" \
        2>/dev/null | tr -d '[:space:]' || echo "0")
    if [[ "$tbl_exists" == "1" ]]; then
        echo "${__STEP_SKIP__} schema_mailserver_db: tablas ya existen — skip"
        return 0
    fi

    _k exec "$pg_pod" -n "$pg_ns" -- psql -U postgres -d mailserver_db -c "
CREATE TABLE IF NOT EXISTS virtual_mailboxes (
    email    TEXT        NOT NULL PRIMARY KEY,
    password TEXT        NOT NULL,
    quota    TEXT        NOT NULL DEFAULT '1G',
    enabled  BOOLEAN     NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS virtual_aliases (
    alias       TEXT    NOT NULL,
    destination TEXT    NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (alias, destination)
);
" >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} schema_mailserver_db: error al crear tablas"
        return 1
    }
    _log "Schema mailserver_db: tablas virtual_mailboxes + virtual_aliases creadas"
    echo "${__STEP_OK__} schema_mailserver_db"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_mailserver"
    local ready
    ready=$(_k get statefulset mailserver -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( ready >= 1 )) || { echo "${__STEP_FAIL__} verificar_mailserver: ${ready}/1"; return 1; }
    echo "${__STEP_OK__} verificar_mailserver"
    return 0
}

ficha_health() {
    local r
    r=$(_k get statefulset mailserver -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r < 1 )); then
        echo "DEGRADED: StatefulSet mailserver ${r}/1"
        return 1
    fi
    # Verificar que postfix está activo dentro del pod
    local postfix_ok
    postfix_ok=$(_k exec mailserver-0 -n "$NS" -- \
        sh -c "postfix status 2>/dev/null && echo ok || echo fail" 2>/dev/null | tail -1 || echo "fail")
    if [[ "$postfix_ok" == "ok" ]]; then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: pod Running pero postfix no activo"
    return 1
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests mailserver (kubectl apply idempotente)"
    ficha_install
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_pod_running"
    local r
    r=$(_k get statefulset mailserver -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_OK__} test_pod_running (${r}/1)"
    else
        echo "${__STEP_FAIL__} test_pod_running: ${r}/1"
        ok=1
    fi

    echo "${__STEP_START__} test_smtp_puerto"
    local clusterip
    clusterip=$(_k get service mailserver -n "$NS" \
        -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [[ -n "$clusterip" ]]; then
        if timeout 5 bash -c "echo '' > /dev/tcp/${clusterip}/25" 2>/dev/null; then
            echo "${__STEP_OK__} test_smtp_puerto (puerto 25 accesible)"
        else
            echo "${__STEP_FAIL__} test_smtp_puerto: puerto 25 no responde"
            ok=1
        fi
    else
        echo "${__STEP_FAIL__} test_smtp_puerto: ClusterIP no encontrada"
        ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_mailserver"
    _k delete statefulset mailserver -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service mailserver -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete pvc mailserver-data -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete pv sbos-mailserver-data-pv --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_mailserver"
    return 0
}
