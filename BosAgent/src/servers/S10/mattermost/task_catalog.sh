#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — mattermost (Ficha S10)
# Mattermost Team Edition 9.11 — Chat empresarial SBOS
#
# IDEMPOTENTE: install y update producen el mismo resultado.
# - Si el pod no existe → lo crea
# - Si el pod existe → verifica health y reconfigura canales
# ============================================================================
set -euo pipefail

__STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
__STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
__STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
__STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/mattermost.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S10/mattermost}"
NS="sbos-comm"
IMAGE="mattermost/mattermost-team-edition:9.11"
PG_NAMESPACE="${PG_NAMESPACE:-sbos-data}"
PG_POD="${PG_POD:-postgresql-0}"
MM_SECRETS_FILE="${MM_SECRETS_FILE:-/etc/bos/.mm-pg-pass}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [mattermost] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }
_pg()  { _k exec -n "$PG_NAMESPACE" "$PG_POD" -- psql -U postgres "$@"; }

# ── Pre-install ────────────────────────────────────────────────────────────
ficha_pre_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} verificar_postgresql"
    _k get pod -n "$PG_NAMESPACE" "$PG_POD" --no-headers 2>/dev/null | grep -q Running || {
        echo "${__STEP_FAIL__} verificar_postgresql: $PG_POD no está Running en $PG_NAMESPACE"
        return 1
    }
    echo "${__STEP_OK__} verificar_postgresql"

    echo "${__STEP_START__} generar_credenciales"
    local mm_pass
    if [[ ! -f "$MM_SECRETS_FILE" ]]; then
        openssl rand -hex 16 > "$MM_SECRETS_FILE"
        chmod 600 "$MM_SECRETS_FILE"
        _log "Contraseña mattermost generada en $MM_SECRETS_FILE"
    fi
    mm_pass=$(cat "$MM_SECRETS_FILE")
    echo "${__STEP_OK__} generar_credenciales"

    echo "${__STEP_START__} crear_mattermost_db"
    _pg -tAc "SELECT 1 FROM pg_database WHERE datname='mattermost'" 2>/dev/null | grep -q 1 \
        && echo "${__STEP_SKIP__} mattermost DB ya existe" \
        || { _pg -c "CREATE DATABASE mattermost;" 2>/dev/null \
             && echo "${__STEP_OK__} mattermost DB creada" \
             || { echo "${__STEP_FAIL__} no se pudo crear mattermost DB"; return 1; }; }

    echo "${__STEP_START__} crear_mattermost_user"
    if _pg -tAc "SELECT 1 FROM pg_roles WHERE rolname='mattermost'" 2>/dev/null | grep -q 1; then
        _pg -c "ALTER ROLE mattermost WITH LOGIN PASSWORD '${mm_pass}';" 2>/dev/null || true
        echo "${__STEP_SKIP__} usuario mattermost ya existe (password actualizado)"
    else
        _pg -c "CREATE ROLE mattermost WITH LOGIN PASSWORD '${mm_pass}'; GRANT ALL PRIVILEGES ON DATABASE mattermost TO mattermost;" 2>/dev/null \
            && echo "${__STEP_OK__} usuario mattermost creado" \
            || { echo "${__STEP_FAIL__} no se pudo crear usuario mattermost"; return 1; }
    fi
    return 0
}

# ── Install ────────────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    local mm_pass
    mm_pass=$(cat "$MM_SECRETS_FILE" 2>/dev/null || openssl rand -hex 16)
    local datasource="postgres://mattermost:${mm_pass}@postgresql.${PG_NAMESPACE}.svc.cluster.local:5432/mattermost?sslmode=disable&connect_timeout=10"

    echo "${__STEP_START__} crear_namespace"
    _k create namespace "$NS" --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} crear_namespace"

    echo "${__STEP_START__} networkpolicy_postgresql"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-comm-postgresql
  namespace: sbos-data
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ${NS}
    ports:
    - port: 5432
      protocol: TCP
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-mattermost-egress-pg
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: mattermost
  policyTypes:
  - Egress
  egress:
  - to:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: sbos-data
    ports:
    - port: 5432
      protocol: TCP
  - to:
    ports:
    - port: 53
      protocol: UDP
    - port: 53
      protocol: TCP
YAML
    echo "${__STEP_OK__} networkpolicy_postgresql"

    echo "${__STEP_START__} deploy_mattermost"
    _k apply -n "$NS" -f - >> "$FICHA_LOG" 2>&1 <<YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mattermost
  namespace: ${NS}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mattermost
  template:
    metadata:
      labels:
        app: mattermost
    spec:
      containers:
      - name: mattermost
        image: ${IMAGE}
        command: ["mattermost", "server"]
        securityContext:
          privileged: false
          allowPrivilegeEscalation: false
        env:
        - name: MM_SERVICESETTINGS_SITEURL
          value: "http://localhost:8065"
        - name: MM_SERVICESETTINGS_LISTENADDRESS
          value: ":8065"
        - name: MM_SQLSETTINGS_DRIVERNAME
          value: "postgres"
        - name: MM_SQLSETTINGS_DATASOURCE
          value: "${datasource}"
        - name: MM_EMAILSETTINGS_SENDEMAILNOTIFICATIONS
          value: "false"
        - name: MM_LOGSETTINGS_FILELEVEL
          value: "ERROR"
        ports:
        - containerPort: 8065
        readinessProbe:
          httpGet:
            path: /api/v4/system/ping
            port: 8065
          initialDelaySeconds: 60
          periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: mattermost
  namespace: ${NS}
spec:
  type: ClusterIP
  ports:
  - port: 8065
    targetPort: 8065
  selector:
    app: mattermost
YAML
    echo "${__STEP_OK__} deploy_mattermost"

    echo "${__STEP_START__} wait_mattermost_running"
    local elapsed=0 timeout=180
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app=mattermost --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { echo "${__STEP_OK__} mattermost Running"; break; }
        sleep 5; elapsed=$((elapsed + 5))
    done
    if (( elapsed >= timeout )); then
        echo "${__STEP_FAIL__} mattermost no arrancó en ${timeout}s"
        return 1
    fi

    return 0
}

# ── Post-install ───────────────────────────────────────────────────
ficha_post_install() {
    echo "${__STEP_START__} init_channels"
    local catalog="${FICHA_DIR}/init_channels.sh"
    if [[ ! -f "$catalog" ]]; then
        echo "${__STEP_SKIP__} init_channels: script no encontrado"
        return 0
    fi
    # Esperar a que la API de Mattermost esté accesible antes de configurar canales
    local elapsed=0
    while (( elapsed < 120 )); do
        if _k exec -n "$NS" deploy/mattermost -- \
            curl -sf http://localhost:8065/api/v4/system/ping > /dev/null 2>&1; then
            break
        fi
        sleep 10; elapsed=$((elapsed + 10))
    done
    if (( elapsed >= 120 )); then
        _log "ADVERTENCIA: API Mattermost no disponible en 120s — init_channels diferido"
        echo "${__STEP_SKIP__} init_channels: API no ready"
        return 0
    fi
    timeout 120 bash "$catalog" >> "$FICHA_LOG" 2>&1 \
        && echo "${__STEP_OK__} init_channels" \
        || { _log "ADVERTENCIA: init_channels falló (no fatal)"; echo "${__STEP_SKIP__} init_channels: error"; }
    return 0
}

# ── Health ──────────────────────────────────────────────────────────────────
ficha_health_check() {
    local phase
    phase=$(_k get pod -n "$NS" -l app=mattermost -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$phase" == "True" ]] && { echo "${__STEP_OK__} mattermost Ready"; return 0; }
    echo "${__STEP_FAIL__} mattermost no Ready"; return 1
}

# ── Uninstall ────────────────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} remove_mattermost"
    _k delete deployment mattermost -n "$NS" --ignore-not-found=true
    _k delete svc mattermost -n "$NS" --ignore-not-found=true
    echo "${__STEP_OK__} mattermost removido"
}

export -f ficha_pre_install ficha_install ficha_post_install ficha_health_check ficha_uninstall
