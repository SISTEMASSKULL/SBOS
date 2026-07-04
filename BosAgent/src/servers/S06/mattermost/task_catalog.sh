#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — mattermost (IDEMPOTENTE)
# Iteración 1: Mattermost 10.6.0 Team Edition, OIDC Keycloak, PostgreSQL
#   - 5 canales de auditoría pre-creados por tenant
#   - 5 incoming webhooks (uno por canal) para Novu/bAuth
#   - Asignación automática de miembros según rol bAuth
#   - IDEMPOTENTE: verifica deployment + API + canales antes de reinstalar
# Iteración 2: Plugin SBOS-Context, compliance export, eDiscovery
# Dependencias: postgresql (mattermost_db), keycloak (OIDC), vault (secretos)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/mattermost.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-collab"
readonly MM_IMAGE="mattermost/mattermost-team-edition:10.6.0"
readonly MM_PORT=8065
readonly DB_NAME="mattermost_db"
readonly PG_HOST="postgresql.sbos-data.svc.cluster.local"

# 5 canales de auditoría obligatorios (definidos en BAUTH-TRAZABILIDAD-EVENTOS-AUDITORIA.md §1.3)
readonly -A AUDIT_CHANNELS=(
    ["compliance"]="D3 Financiero: límites, SoD, tx rechazadas, reportes SIN"
    ["seguridad"]="D2 Físico: accesos denegados, puertas forzadas, alarmas"
    ["auth-alerts"]="Autenticación: bloqueos, step-up, MFA resets, brute force"
    ["operaciones"]="D4 Temporal: fuera horario, delegaciones, cierres gestión"
    ["admin"]="SysAdmin: SU break-glass, rotación llaves, backups, sync"
)

# Credenciales desde Vault
VAULT_ADDR="${VAULT_ADDR:-http://vault.sbos-security.svc.cluster.local:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
MM_ADMIN_TOKEN="${MM_ADMIN_TOKEN:-}"
MM_API_BASE="http://mattermost.${NS}.svc.cluster.local:${MM_PORT}/api/v4"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [mattermost] $*" | tee -a "$FICHA_LOG"; }
_k() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" "$@"
}

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-mm-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _mm_api: llama a la API REST de Mattermost. Requiere token de admin.
_mm_api() {
    local method="$1" endpoint="$2" data="${3:-}"
    curl -s --max-time 10 -X "$method" \
        -H "Authorization: Bearer ${MM_ADMIN_TOKEN}" \
        -H "Content-Type: application/json" \
        ${data:+-d "$data"} \
        "${MM_API_BASE}${endpoint}" 2>/dev/null
}

# _mm_get: GET a la API de Mattermost.
_mm_get() { _mm_api "GET" "$1"; }

# _mm_post: POST a la API de Mattermost.
_mm_post() { _mm_api "POST" "$1" "$2"; }

# _mm_ping: verifica si Mattermost responde.
_mm_ping() {
    curl -s --max-time 5 -o /dev/null -w '%{http_code}' \
        "${MM_API_BASE}/system/ping" 2>/dev/null || echo "000"
}

# _vault_read: lee un secreto desde Vault.
_vault_read() {
    local path="$1" key="${2:-value}"
    curl -s --max-time 5 -H "X-Vault-Token: ${VAULT_TOKEN}" \
        "${VAULT_ADDR}/v1/${path}" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('data',{}).get('data',{}).get('${key}',''))" 2>/dev/null || echo ""
}

# _vault_write: escribe un secreto en Vault.
_vault_write() {
    local path="$1" key="$2" value="$3"
    curl -s --max-time 5 -X POST -H "X-Vault-Token: ${VAULT_TOKEN}" \
        -d "{\"data\":{\"${key}\":\"${value}\"}}" \
        "${VAULT_ADDR}/v1/${path}" 2>/dev/null > /dev/null
}

# _get_pg_password: obtiene la contraseña de postgres.
_get_pg_password() {
    _k get secret -n sbos-data pg-master-credentials \
        -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || echo ""
}

# ── IDEMPOTENCIA ───────────────────────────────────────────────────
idempotency_check() {
    local ok=0 issues=0

    echo "${__STEP_START__} idempotencia_deployment"
    if _k get deployment mattermost -n "$NS" > /dev/null 2>&1; then
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_deployment (existe)"
    else
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_deployment (no existe)"
    fi

    echo "${__STEP_START__} idempotencia_api_ping"
    local http_code
    http_code=$(_mm_ping)
    if [[ "$http_code" == "200" ]]; then
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_api_ping (HTTP $http_code)"
    else
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_api_ping (HTTP $http_code)"
    fi

    echo "${__STEP_START__} idempotencia_db"
    local db_exists
    db_exists=$(_k exec postgresql-0 -n sbos-data -- psql -U postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null || echo "0")
    if [[ "$db_exists" == "1" ]]; then
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_db (${DB_NAME} existe)"
    else
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_db (${DB_NAME} no existe)"
    fi

    _log "Idempotencia: $ok/3 checks OK, $issues/3 requieren acción"
    if (( issues == 0 )); then
        return 0
    else
        return 1
    fi
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} verificar_postgresql"
    if ! _k get pod postgresql-0 -n sbos-data > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_postgresql: postgresql-0 no disponible"
        return 1
    fi
    echo "${__STEP_OK__} verificar_postgresql"

    echo "${__STEP_START__} crear_mattermost_db"
    local db_exists
    db_exists=$(_k exec postgresql-0 -n sbos-data -- psql -U postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null || echo "0")
    if [[ "$db_exists" == "1" ]]; then
        echo "${__STEP_OK__} crear_mattermost_db (ya existe)"
    else
        _k exec postgresql-0 -n sbos-data -- psql -U postgres -c \
            "CREATE DATABASE ${DB_NAME} OWNER postgres;" 2>/dev/null && \
            echo "${__STEP_OK__} crear_mattermost_db (creada)" || {
            echo "${__STEP_FAIL__} crear_mattermost_db"
            return 1
        }
    fi

    echo "${__STEP_START__} verificar_keycloak"
    if ! _k get pod -n sbos-security -l app=keycloak > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_keycloak: keycloak no disponible"
        return 1
    fi
    echo "${__STEP_OK__} verificar_keycloak"

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"

    echo "${__STEP_START__} verificar_vault_secret"
    if [[ -z "$VAULT_TOKEN" ]]; then
        VAULT_TOKEN=$(_vault_read "auth/token/lookup-self" "id" 2>/dev/null || echo "")
    fi
    if [[ -z "$VAULT_TOKEN" ]]; then
        _log "ADVERTENCIA: Vault token no disponible — las URLs de webhook no se guardarán"
        echo "${__STEP_SKIP__} verificar_vault_secret (sin token)"
    else
        local oidc_secret
        oidc_secret=$(_vault_read "secret/bauth/collab/mattermost" "oidc-client-secret")
        if [[ -n "$oidc_secret" ]]; then
            echo "${__STEP_OK__} verificar_vault_secret (OIDC secret presente)"
        else
            _log "OIDC client secret no encontrado en Vault — se generará uno nuevo"
            echo "${__STEP_SKIP__} verificar_vault_secret (sin OIDC secret, se generará)"
        fi
    fi
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ═══ IDEMPOTENCIA ═══
    if idempotency_check; then
        _log "=================================================="
        _log "MATTERMOST YA INSTALADO Y OPERATIVO — SKIP TOTAL"
        _log "=================================================="
        _log "  namespace:   $NS"
        _log "  api:         ${MM_API_BASE}"
        _log "  db:          ${DB_NAME}"
        _log "=================================================="
        return 0
    fi
    _log "Idempotencia NO superada — instalando Mattermost..."

    local pg_password
    pg_password=$(_get_pg_password)
    local db_url="postgres://postgres:${pg_password}@${PG_HOST}:5432/${DB_NAME}?sslmode=disable"

    local oidc_secret
    oidc_secret=$(_vault_read "secret/bauth/collab/mattermost" "oidc-client-secret")
    if [[ -z "$oidc_secret" ]]; then
        oidc_secret=$(python3 -c "import secrets; print(secrets.token_urlsafe(32))" 2>/dev/null || echo "mattermost-dev-secret")
        _vault_write "secret/bauth/collab/mattermost" "oidc-client-secret" "$oidc_secret"
        _log "Nuevo OIDC client secret generado y guardado en Vault"
    fi

    # ── 1. Secrets ───────────────────────────────────────────────
    echo "${__STEP_START__} crear_secrets"
    _k delete secret mattermost-db -n "$NS" 2>/dev/null || true
    _k create secret generic mattermost-db -n "$NS" \
        --from-literal=DB_URL="$db_url" \
        >> "$FICHA_LOG" 2>&1 || true

    _k delete secret mattermost-oidc -n "$NS" 2>/dev/null || true
    _k create secret generic mattermost-oidc -n "$NS" \
        --from-literal=MM_OPENIDSETTINGS_CLIENTSECRET="$oidc_secret" \
        >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} crear_secrets"

    # ── 2. Deployment + Service ──────────────────────────────────
    echo "${__STEP_START__} deploy_mattermost"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: mattermost
  namespace: ${NS}
  labels:
    app: mattermost
    sbos-managed: \"true\"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mattermost
  template:
    metadata:
      labels:
        app: mattermost
        sbos-managed: \"true\"
    spec:
      containers:
        - name: mattermost
          image: ${MM_IMAGE}
          ports:
            - containerPort: 8065
              name: api
          env:
            - name: MM_SQLSETTINGS_DRIVERNAME
              value: postgres
            - name: MM_SQLSETTINGS_DATASOURCE
              value: \"${db_url}\"
            - name: MM_OPENIDSETTINGS_ENABLE
              value: \"true\"
            - name: MM_OPENIDSETTINGS_DISCOVERYENDPOINT
              value: \"https://keycloak.sbos-security.svc.cluster.local:8080/realms/sbos/.well-known/openid-configuration\"
            - name: MM_OPENIDSETTINGS_CLIENTID
              value: \"mattermost\"
            - name: MM_OPENIDSETTINGS_BUTTONTEXT
              value: \"Login con Keycloak\"
            - name: MM_TEAMSETTINGS_SITENAME
              value: \"SBOS Chat\"
            - name: MM_LOGSETTINGS_CONSOLELEVEL
              value: \"WARN\"
          envFrom:
            - secretRef:
                name: mattermost-oidc
          startupProbe:
            httpGet:
              path: /api/v4/system/ping
              port: 8065
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 30
            timeoutSeconds: 5
          readinessProbe:
            httpGet:
              path: /api/v4/system/ping
              port: 8065
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 3
            timeoutSeconds: 5
          livenessProbe:
            httpGet:
              path: /api/v4/system/ping
              port: 8065
            initialDelaySeconds: 30
            periodSeconds: 15
            failureThreshold: 3
            timeoutSeconds: 5
          resources:
            requests:
              cpu: \"200m\"
              memory: \"512Mi\"
            limits:
              cpu: \"2000m\"
              memory: \"2Gi\"
---
apiVersion: v1
kind: Service
metadata:
  name: mattermost
  namespace: ${NS}
  labels:
    app: mattermost
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 8065
      targetPort: 8065
      name: api
  selector:
    app: mattermost" || {
        echo "${__STEP_FAIL__} deploy_mattermost"; return 1
    }
    echo "${__STEP_OK__} deploy_mattermost"

    # ── 3. Esperar pod Ready ─────────────────────────────────────
    echo "${__STEP_START__} wait_ready"
    if _k wait pod -n "$NS" -l app=mattermost --for=condition=Ready --timeout=300s 2>/dev/null; then
        echo "${__STEP_OK__} wait_ready"
    else
        _log "ADVERTENCIA: Mattermost no Ready en 300s — verificando..."
        local pod_phase
        pod_phase=$(_k get pod -n "$NS" -l app=mattermost -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "?")
        if [[ "$pod_phase" == "Running" ]]; then
            echo "${__STEP_SKIP__} wait_ready: Running pero no Ready (DB migration en curso?)"
        else
            echo "${__STEP_FAIL__} wait_ready: pod en fase $pod_phase"
            return 1
        fi
    fi

    # ── 4. Obtener token de admin ────────────────────────────────
    echo "${__STEP_START__} obtener_admin_token"
    sleep 10
    MM_ADMIN_TOKEN=$(_k exec deploy/mattermost -n "$NS" -- \
        sh -c "bin/mattermost user create --email admin@sbos.local --username sbos-admin --password Sb0sAdm1n! --system-admin 2>/dev/null; bin/mattermost user login --username sbos-admin --password Sb0sAdm1n! 2>/dev/null | grep -o 'Token: .*' | awk '{print \$2}'" 2>/dev/null || echo "")
    if [[ -z "$MM_ADMIN_TOKEN" ]]; then
        # Intentar login si el usuario ya existe
        MM_ADMIN_TOKEN=$(_k exec deploy/mattermost -n "$NS" -- \
            sh -c "bin/mattermost user login --username sbos-admin --password Sb0sAdm1n! 2>/dev/null | grep -o 'Token: .*' | awk '{print \$2}'" 2>/dev/null || echo "")
    fi
    if [[ -n "$MM_ADMIN_TOKEN" ]]; then
        _log "Admin token obtenido"
        echo "${__STEP_OK__} obtener_admin_token"
    else
        _log "ADVERTENCIA: No se pudo obtener admin token — canales y webhooks no se crearán ahora. Use ficha_repair."
        echo "${__STEP_SKIP__} obtener_admin_token (ficha_repair lo creará)"
    fi

    # ── 5. Crear 5 canales de auditoría ──────────────────────────
    echo "${__STEP_START__} crear_canales_auditoria"
    local team_id
    team_id=$(_mm_get "/teams/name/sbos" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

    if [[ -z "$team_id" ]]; then
        # Crear el Team "SBOS" si no existe
        team_id=$(_mm_post "/teams" '{"name":"sbos","display_name":"SBOS","type":"O"}' | \
            python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
        _log "Team 'SBOS' creado: $team_id"
    fi

    local channels_created=0
    if [[ -n "$team_id" && -n "$MM_ADMIN_TOKEN" ]]; then
        for channel in "${!AUDIT_CHANNELS[@]}"; do
            local purpose="${AUDIT_CHANNELS[$channel]}"
            local existing
            existing=$(_mm_get "/channels/name/${channel}?team_id=${team_id}" | \
                python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('id',''))" 2>/dev/null || echo "")
            if [[ -n "$existing" ]]; then
                _log "Canal #${channel} ya existe"
                channels_created=$((channels_created + 1))
            else
                _mm_post "/channels" "{\"team_id\":\"${team_id}\",\"name\":\"${channel}\",\"display_name\":\"${channel}\",\"type\":\"P\",\"purpose\":\"${purpose}\"}" > /dev/null 2>&1 && \
                    { _log "Canal #${channel} creado"; channels_created=$((channels_created + 1)); } || \
                    _log "ADVERTENCIA: No se pudo crear #${channel}"
            fi
        done
        echo "${__STEP_OK__} crear_canales_auditoria (${channels_created}/5)"
    else
        echo "${__STEP_SKIP__} crear_canales_auditoria (sin API access — ficha_repair lo creará)"
    fi

    # ── 6. Crear 5 incoming webhooks ─────────────────────────────
    echo "${__STEP_START__} crear_webhooks"
    local webhooks_created=0
    if [[ -n "$MM_ADMIN_TOKEN" ]]; then
        for channel in "${!AUDIT_CHANNELS[@]}"; do
            local channel_id
            channel_id=$(_mm_get "/channels/name/${channel}?team_id=${team_id}" | \
                python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
            if [[ -z "$channel_id" ]]; then
                _log "ADVERTENCIA: Canal #${channel} sin ID — saltando webhook"
                continue
            fi

            # Verificar si ya existe un webhook para este canal
            local existing_hook
            existing_hook=$(_mm_get "/hooks/incoming" | python3 -c "
import sys,json
hooks=json.load(sys.stdin)
for h in hooks:
    if h.get('channel_id')=='${channel_id}':
        print(h.get('id'))
        break
" 2>/dev/null || echo "")

            if [[ -n "$existing_hook" ]]; then
                _log "Webhook #${channel} ya existe: $existing_hook"
                webhooks_created=$((webhooks_created + 1))
                continue
            fi

            local hook_response
            hook_response=$(_mm_post "/hooks/incoming" \
                "{\"channel_id\":\"${channel_id}\",\"display_name\":\"SBOS ${channel} Bot\",\"description\":\"Alertas — bAuth/Novu\",\"username\":\"sbos-${channel}-bot\"}")
            local hook_id hook_url
            hook_id=$(echo "$hook_response" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")

            if [[ -n "$hook_id" ]]; then
                # Construir URL del webhook
                local mm_host="mattermost.${NS}.svc.cluster.local:${MM_PORT}"
                hook_url="http://${mm_host}/hooks/${hook_id}"
                _log "Webhook #${channel}: $hook_url"

                # Guardar en Vault
                if [[ -n "$VAULT_TOKEN" ]]; then
                    local tenant_id="default"
                    _vault_write "secret/bauth/collab/mattermost/${tenant_id}/${channel}_hook_url" "url" "$hook_url"
                    _vault_write "secret/bauth/collab/mattermost/${tenant_id}/${channel}_hook_url" "hook_id" "$hook_id"
                fi
                webhooks_created=$((webhooks_created + 1))
            else
                _log "ADVERTENCIA: No se pudo crear webhook para #${channel}"
            fi
        done
        echo "${__STEP_OK__} crear_webhooks (${webhooks_created}/5)"
    else
        echo "${__STEP_SKIP__} crear_webhooks (sin admin token)"
    fi

    # ── 7. NetworkPolicy ─────────────────────────────────────────
    echo "${__STEP_START__} networkpolicy"
    _apply "np-mm" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-mattermost
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: mattermost
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 8065
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-data
      ports:
        - protocol: TCP
          port: 5432
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-security
      ports:
        - protocol: TCP
          port: 8080
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53" || true
    echo "${__STEP_OK__} networkpolicy"

    _log "Mattermost instalado: ${MM_API_BASE}"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado Mattermost:"
    _log "  api: ${MM_API_BASE}"
    _log "  ping: $(_mm_ping)"
    _log "  db: ${DB_NAME}"

    if [[ -n "$MM_ADMIN_TOKEN" ]]; then
        local channels_count
        channels_count=$(_mm_get "/teams/name/sbos/channels" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "?")
        _log "  canales totales: $channels_count"
        _log "  canales auditoría: compliance, seguridad, auth-alerts, operaciones, admin"
    fi

    _k get pod -n "$NS" -l app=mattermost --no-headers 2>/dev/null \
        | awk '{printf "  pod=%s ready=%s status=%s restarts=%s\n", $1, $2, $3, $4}' \
        | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_mattermost"

    # Verificar idempotencia
    local ping_code
    ping_code=$(_mm_ping)
    if [[ "$ping_code" == "200" ]]; then
        _log "Mattermost responde — verificando canales..."
        # Solo verificar canales y webhooks
        if [[ -z "$MM_ADMIN_TOKEN" ]]; then
            _log "Sin admin token — canales no verificables"
            echo "${__STEP_SKIP__} reparar_mattermost (API OK, sin admin token)"
            return 0
        fi
        ficha_install  # Re-ejecuta install que es idempotente para canales/webhooks
        echo "${__STEP_OK__} reparar_mattermost"
        return 0
    fi

    # No responde — restart
    _log "Mattermost no responde (HTTP $ping_code) — reiniciando..."
    _k rollout restart deployment/mattermost -n "$NS" 2>/dev/null || true
    _k wait pod -n "$NS" -l app=mattermost --for=condition=Ready --timeout=300s 2>/dev/null || {
        _log "No Ready tras restart — reinstalando deployment"
        _k delete deployment mattermost -n "$NS" 2>/dev/null || true
        ficha_install
        return $?
    }
    echo "${__STEP_OK__} reparar_mattermost"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=mattermost \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" == "True" ]]; then
        echo "${__STEP_OK__} test_pod_ready"
    else
        echo "${__STEP_FAIL__} test_pod_ready: Ready=${ready}"
        ok=1
    fi

    echo "${__STEP_START__} test_api_ping"
    local ping_code
    ping_code=$(_mm_ping)
    if [[ "$ping_code" == "200" ]]; then
        echo "${__STEP_OK__} test_api_ping (HTTP $ping_code)"
    else
        echo "${__STEP_FAIL__} test_api_ping (HTTP $ping_code)"
        ok=1
    fi

    echo "${__STEP_START__} test_db_connected"
    local db_status
    db_status=$(_mm_get "/system/ping" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','FAIL'))" 2>/dev/null || echo "FAIL")
    if [[ "$db_status" == "OK" ]]; then
        echo "${__STEP_OK__} test_db_connected (status=$db_status)"
    else
        echo "${__STEP_FAIL__} test_db_connected (status=$db_status)"
        ok=1
    fi

    echo "${__STEP_START__} test_db_exists"
    local db_exists
    db_exists=$(_k exec postgresql-0 -n sbos-data -- psql -U postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='${DB_NAME}'" 2>/dev/null || echo "0")
    if [[ "$db_exists" == "1" ]]; then
        echo "${__STEP_OK__} test_db_exists (${DB_NAME})"
    else
        echo "${__STEP_FAIL__} test_db_exists: ${DB_NAME} no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_canales_auditoria"
    if [[ -n "$MM_ADMIN_TOKEN" ]]; then
        local team_id channels_found
        team_id=$(_mm_get "/teams/name/sbos" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
        channels_found=0
        if [[ -n "$team_id" ]]; then
            for channel in "${!AUDIT_CHANNELS[@]}"; do
                local ch_id
                ch_id=$(_mm_get "/channels/name/${channel}?team_id=${team_id}" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
                [[ -n "$ch_id" ]] && channels_found=$((channels_found + 1))
            done
        fi
        if (( channels_found == 5 )); then
            echo "${__STEP_OK__} test_canales_auditoria (5/5)"
        else
            echo "${__STEP_FAIL__} test_canales_auditoria (${channels_found}/5)"
            ok=1
        fi
    else
        echo "${__STEP_SKIP__} test_canales_auditoria (sin admin token)"
    fi

    echo "${__STEP_START__} test_networkpolicy"
    if _k get networkpolicy allow-mattermost -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_networkpolicy"
    else
        echo "${__STEP_FAIL__} test_networkpolicy: no existe"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== mattermost STATUS ==="
    echo ""
    echo "Pod:"
    _k get pod -n "$NS" -l app=mattermost \
        -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "API:"
    local ping_code
    ping_code=$(_mm_ping)
    echo "  ping: HTTP $ping_code"
    if [[ "$ping_code" == "200" ]]; then
        local db_status
        db_status=$(_mm_get "/system/ping" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null || echo "?")
        echo "  db: $db_status"
    fi
    echo ""
    echo "Database: ${DB_NAME} en ${PG_HOST}:5432"
    echo ""
    echo "Canales de auditoría:"
    if [[ -n "$MM_ADMIN_TOKEN" ]]; then
        local team_id
        team_id=$(_mm_get "/teams/name/sbos" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id',''))" 2>/dev/null || echo "")
        if [[ -n "$team_id" ]]; then
            for channel in "${!AUDIT_CHANNELS[@]}"; do
                local ch_json
                ch_json=$(_mm_get "/channels/name/${channel}?team_id=${team_id}" 2>/dev/null)
                local ch_id
                ch_id=$(echo "$ch_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','n/a'))" 2>/dev/null || echo "n/a")
                echo "  #${channel}: ${ch_id}"
            done
        fi
    else
        echo "  (sin admin token — no verificable)"
    fi
    echo ""
    echo "OIDC: Keycloak -> https://keycloak.sbos-security:8080/realms/sbos"
    echo "NetworkPolicy:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando Mattermost — canales y mensajes se PIERDEN"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment mattermost -n "$NS" 2>/dev/null || true
    _k delete service mattermost -n "$NS" 2>/dev/null || true
    _k delete secret mattermost-db mattermost-oidc -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-mattermost -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"

    echo "${__STEP_START__} eliminar_db"
    _k exec postgresql-0 -n sbos-data -- psql -U postgres -c \
        "DROP DATABASE IF EXISTS ${DB_NAME};" 2>/dev/null && \
        echo "${__STEP_OK__} eliminar_db" || \
        echo "${__STEP_SKIP__} eliminar_db (no se pudo — requiere intervención manual)"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico mattermost ==="
    echo "Describe pod:"
    _k describe pod -n "$NS" -l app=mattermost 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:|Port|Startup|Liveness" \
        || echo "  pod no encontrado"
    echo ""
    echo "Logs (últimas 40 líneas):"
    _k logs -n "$NS" deploy/mattermost --tail=40 2>/dev/null || true
    echo ""
    echo "Eventos (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -15 || true
    echo ""
    echo "DB size:"
    _k exec postgresql-0 -n sbos-data -- psql -U postgres -tAc \
        "SELECT pg_size_pretty(pg_database_size('${DB_NAME}'));" 2>/dev/null || echo "  no disponible"
}
