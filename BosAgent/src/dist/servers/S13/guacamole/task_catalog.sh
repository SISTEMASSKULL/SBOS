#!/usr/bin/env bash
# task_catalog.sh — guacamole
# Apache Guacamole 1.5.5: gateway de escritorio remoto (VNC/RDP/SSH)
# Dependencias: postgresql, keycloak, kong
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/guacamole.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="${NS:-sbos-vdi}"
GUACAMOLE_IMAGE="${GUACAMOLE_IMAGE:-guacamole/guacamole:1.5.5}"
GUACD_IMAGE="${GUACD_IMAGE:-guacamole/guacd:1.5.5}"
PG_NS="sbos-data"
PG_POD="postgresql-0"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [guacamole] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_pg_pass() {
    _k get secret -n "$PG_NS" postgresql-credentials \
        -o jsonpath="{.data.POSTGRES_PASSWORD}" 2>/dev/null | base64 -d
}

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

    echo "${__STEP_START__} crear_guacamole_db"
    if _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -tc \
        "SELECT 1 FROM pg_database WHERE datname='guacamole_db'" 2>/dev/null | grep -q 1; then
        echo "${__STEP_SKIP__} guacamole_db ya existe"
    else
        _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -c \
            "CREATE DATABASE guacamole_db;" >> "$FICHA_LOG" 2>&1
        # Inicializar esquema Guacamole
        _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -d guacamole_db -c "
            CREATE TABLE guacamole_connection (connection_id SERIAL PRIMARY KEY, connection_name TEXT NOT NULL);
            CREATE TABLE guacamole_connection_parameter (connection_id INTEGER, parameter_name TEXT, parameter_value TEXT);
            CREATE TABLE guacamole_user (user_id SERIAL PRIMARY KEY, username TEXT NOT NULL UNIQUE, password_hash BYTEA, password_salt BYTEA, password_date TIMESTAMPTZ DEFAULT now());
        " >> "$FICHA_LOG" 2>&1 || true
        echo "${__STEP_OK__} crear_guacamole_db"
    fi

    echo "${__STEP_START__} guacamole_secret"
    if _k get secret -n "$NS" guacamole-credentials &>/dev/null; then
        echo "${__STEP_SKIP__} secret guacamole-credentials ya existe"
    else
        _k create secret generic guacamole-credentials \
            --namespace="$NS" \
            --from-literal=POSTGRES_PASSWORD="$(_pg_pass)" >> "$FICHA_LOG" 2>&1
        echo "${__STEP_OK__} guacamole_secret"
    fi
}

_apply_guacamole() {
    local pg_pass; pg_pass=$(_pg_pass)
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
# guacd — daemon de protocolos (VNC/RDP/SSH)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: guacd
  namespace: ${NS}
  labels:
    app: guacd
    sbos-managed: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: guacd
  template:
    metadata:
      labels:
        app: guacd
    spec:
      containers:
      - name: guacd
        image: ${GUACD_IMAGE}
        ports:
        - containerPort: 4822
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: guacd
  namespace: ${NS}
spec:
  selector:
    app: guacd
  ports:
  - port: 4822
    targetPort: 4822
---
# guacamole — interfaz web
apiVersion: apps/v1
kind: Deployment
metadata:
  name: guacamole
  namespace: ${NS}
  labels:
    app: guacamole
    sbos-managed: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: guacamole
  template:
    metadata:
      labels:
        app: guacamole
    spec:
      containers:
      - name: guacamole
        image: ${GUACAMOLE_IMAGE}
        ports:
        - containerPort: 8080
        env:
        - name: GUACD_HOSTNAME
          value: guacd.${NS}.svc.cluster.local
        - name: GUACD_PORT
          value: "4822"
        - name: POSTGRES_HOSTNAME
          value: postgresql.sbos-data.svc.cluster.local
        - name: POSTGRES_PORT
          value: "5432"
        - name: POSTGRES_DATABASE
          value: guacamole_db
        - name: POSTGRES_USER
          value: postgres
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: guacamole-credentials
              key: POSTGRES_PASSWORD
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        readinessProbe:
          httpGet:
            path: /guacamole/
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 15
          failureThreshold: 6
---
apiVersion: v1
kind: Service
metadata:
  name: guacamole
  namespace: ${NS}
  labels:
    app: guacamole
    sbos-managed: "true"
spec:
  selector:
    app: guacamole
  ports:
  - port: 8080
    targetPort: 8080
YAML
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    # BUG-47: idempotencia P15 — si ya hay pods Running, no reinstalar
    local _running
    _running=$(_k get pods -n "$NS" -l app=guacamole --no-headers 2>/dev/null \
        | grep -c "Running" || echo "0")
    if (( _running >= 1 )); then
        _log "guacamole ya tiene ${_running} pods Running — skip reinstalación"
        echo "${__STEP_SKIP__} deploy_guacamole: ya running (${_running} pods)"
        return 0
    fi

    ficha_pre_install
    echo "${__STEP_START__} deploy_guacamole"
    _apply_guacamole
    echo "${__STEP_OK__} deploy_guacamole"

    echo "${__STEP_START__} verify"
    _wait_pod "guacamole" 300
    echo "${__STEP_OK__} verify"

    ficha_post_install
}

# ── Post-install ─────────────────────────────────────────────────
ficha_post_install() {
    echo "${__STEP_START__} registrar_conexion_vnc"
    # GAP-4: registrar la conexión VNC al escritorio fedora-kde en guacamole_db.
    # Sin esta entrada, Guacamole no sabe a dónde conectar al usuario.
    # VNC sin contraseña (-SecurityTypes None en start-desktop.sh).
    local vnc_host="fedora-kde.sbos-vdi.svc.cluster.local"
    local vnc_port="5900"

    # Verificar si la conexión ya existe (idempotente)
    local existe
    existe=$(_k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -d guacamole_db -tc \
        "SELECT COUNT(*) FROM guacamole_connection WHERE connection_name='Escritorio SBOS';" \
        2>/dev/null | tr -d ' ')

    if [[ "$existe" == "1" ]]; then
        echo "${__STEP_SKIP__} registrar_conexion_vnc: conexión ya existe"
        return 0
    fi

    _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -d guacamole_db -c "
        INSERT INTO guacamole_connection (connection_name) VALUES ('Escritorio SBOS') RETURNING connection_id;
    " >> "$FICHA_LOG" 2>&1 || { echo "${__STEP_FAIL__} registrar_conexion_vnc: INSERT falló"; return 1; }

    local conn_id
    conn_id=$(_k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -d guacamole_db -tc \
        "SELECT connection_id FROM guacamole_connection WHERE connection_name='Escritorio SBOS';" \
        2>/dev/null | tr -d ' ')

    if [[ -z "$conn_id" ]]; then
        echo "${__STEP_FAIL__} registrar_conexion_vnc: no se pudo obtener connection_id"
        return 1
    fi

    _k exec "$PG_POD" -n "$PG_NS" -- psql -U postgres -d guacamole_db -c "
        INSERT INTO guacamole_connection_parameter VALUES
            ($conn_id, 'hostname', '${vnc_host}'),
            ($conn_id, 'port',     '${vnc_port}');
    " >> "$FICHA_LOG" 2>&1 || { echo "${__STEP_FAIL__} registrar_conexion_vnc: parámetros fallaron"; return 1; }

    _log "Conexión VNC 'Escritorio SBOS' → ${vnc_host}:${vnc_port} registrada (conn_id=${conn_id})"
    echo "${__STEP_OK__} registrar_conexion_vnc"
}

# ── Repair ───────────────────────────────────────────────────────
ficha_health() {
    local r
    r=$(_k get deployment guacamole -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: guacamole ${r}/1"
    return 1
}

ficha_repair() {
    ficha_pre_install
    echo "${__STEP_START__} repair"
    echo "${__STEP_START__} deploy_guacamole"
    _apply_guacamole
    echo "${__STEP_OK__} deploy_guacamole"
    _log "repair: $(_k get pods -n $NS -l app=guacamole --no-headers 2>/dev/null | head -1)"
    echo "${__STEP_OK__} repair"

    echo "${__STEP_START__} verify"
    local pods; pods=$(_k get pods -n "$NS" -l app=guacamole --no-headers 2>/dev/null | grep Running | wc -l)
    _log "$pods pods running"
    echo "${__STEP_OK__} verify"
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_guacamole_pod"
    local pods
    pods=$(_k get pods -n "$NS" -l app=guacamole --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( pods >= 1 )); then
        echo "${__STEP_OK__} test_guacamole_pod ($pods Running)"
    else
        echo "${__STEP_FAIL__} test_guacamole_pod: 0 pods Running"; ok=1
    fi

    echo "${__STEP_START__} test_conexion_vnc"
    local PG_POD PG_NS
    PG_POD=$(grep "PG_POD" "$(dirname "$0")/task_catalog.sh" 2>/dev/null | head -1 | awk -F'"' '{print $2}' || echo "postgresql-0")
    PG_NS="sbos-data"
    local conn_count
    conn_count=$(_k exec "${PG_POD:-postgresql-0}" -n "$PG_NS" -- \
        psql -U postgres -d guacamole_db -tc \
        "SELECT COUNT(*) FROM guacamole_connection WHERE connection_name='Escritorio SBOS';" \
        2>/dev/null | tr -d ' \n' || echo "0")
    if [[ "$conn_count" =~ ^[0-9]+$ ]] && (( conn_count >= 1 )); then
        echo "${__STEP_OK__} test_conexion_vnc (conexión VNC registrada)"
    else
        echo "${__STEP_FAIL__} test_conexion_vnc: guacamole_connection vacía (ejecutar ficha_post_install)"
        ok=1
    fi
    return $ok
}

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    echo "${__STEP_START__} remove_guacamole"
    _k delete deployment guacamole guacd -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    _k delete service guacamole guacd -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} remove_guacamole"
}
