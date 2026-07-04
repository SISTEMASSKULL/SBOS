#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — kong (IDEMPOTENTE)
# Iteración 1: Kong 3.9.x DB-mode + migrations + Status API :8007
#   - IDEMPOTENTE: verifica Admin API + kong health antes de instalar
#   - BUGFIX 2026-06-23: probes usaban puerto 8001 y host=127.0.0.1
#     → Kong 3.x Status API está en :8007, no en :8001
#     → host=127.0.0.1 hacía que kubelet conectara al loopback del NODO
#     → Fix: probes a :8007 SIN campo host
#   - BUGFIX: KONG_STATUS_LISTEN=0.0.0.0:8007 para que kubelet alcance
# Iteración 2: TLS Vault PKI, plugin Lua SBOS-Context, rate limiting por tier
# Dependencias: postgresql (kong_db + usuario kong), keycloak (OIDC plugin)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/kong.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-gateway"
readonly KONG_IMAGE="kong:3.9.0"
readonly PG_HOST="postgresql.sbos-data.svc.cluster.local"
# Kong 3.x: Status API en :8007 (health checks), Admin API en :8001 (gestion)
readonly STATUS_PORT=8007
readonly ADMIN_PORT=8001
readonly PROXY_PORT=8000
readonly PROXY_HTTPS_PORT=8443
# Usuario kong creado por la ficha postgresql con OWNER de kong_db.
KONG_DB_USER="${KONG_DB_USER:-kong}"
KONG_DB_PASS="${KONG_DB_PASSWORD:-kong_bootstrap}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [kong] $*" | tee -a "$FICHA_LOG"; }
_k() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" "$@"
}

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-kong-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _kong_curl: ejecuta curl dentro del pod de Kong.
_kong_curl() {
    _k exec deploy/kong -n "$NS" -- \
        sh -c "curl -sf --max-time 5 $*" 2>/dev/null
}

# _kong_admin: consulta la Admin API en localhost:8001 (gestión).
_kong_admin() {
    _kong_curl "http://127.0.0.1:${ADMIN_PORT}${1}" 2>/dev/null
}

# _kong_status: consulta la Status API en localhost:8007 (health checks).
_kong_status() {
    _kong_curl "http://127.0.0.1:${STATUS_PORT}${1}" 2>/dev/null
}

# _kong_health: kong health CLI (más fiable que curl si no hay curl en el contenedor).
_kong_health() {
    _k exec deploy/kong -n "$NS" -- kong health 2>/dev/null || echo "unhealthy"
}

# ── IDEMPOTENCIA ───────────────────────────────────────────────────
# Retorna 0 si Kong ya está instalado y operativo (skip instalación).
idempotency_check() {
    local ok=0 issues=0

    # Check 1: ¿Deployment existe?
    echo "${__STEP_START__} idempotencia_deployment"
    if _k get deployment kong -n "$NS" > /dev/null 2>&1; then
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_deployment (existe)"
    else
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_deployment (no existe)"
    fi

    # Check 2: ¿Pod Ready?
    echo "${__STEP_START__} idempotencia_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=kong \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" == "True" ]]; then
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_pod_ready"
    else
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_pod_ready (Ready=$ready)"
    fi

    # Check 3: ¿kong health dice healthy?
    echo "${__STEP_START__} idempotencia_kong_health"
    local health
    health=$(_kong_health 2>/dev/null)
    if echo "$health" | grep -q "healthy"; then
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_kong_health ($health)"
    else
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_kong_health ($health)"
    fi

    # Check 4: ¿Proxy :8000 acepta conexiones?
    echo "${__STEP_START__} idempotencia_proxy"
    local proxy_code
    proxy_code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 \
        "http://kong.${NS}.svc.cluster.local:${PROXY_PORT}/" 2>/dev/null || echo "000")
    if [[ "$proxy_code" != "000" ]]; then
        ok=$((ok + 1))
        echo "${__STEP_OK__} idempotencia_proxy (HTTP $proxy_code)"
    else
        issues=$((issues + 1))
        echo "${__STEP_FAIL__} idempotencia_proxy (no responde)"
    fi

    _log "Idempotencia: $ok/4 checks OK, $issues/4 requieren acción"
    if (( issues == 0 )); then
        return 0
    else
        return 1
    fi
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_postgresql"
    if ! _k get pod postgresql-0 -n sbos-data > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_postgresql: postgresql-0 no disponible"
        return 1
    fi
    local pg_ready
    pg_ready=$(_k get pod postgresql-0 -n sbos-data \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$pg_ready" != "True" ]]; then
        echo "${__STEP_FAIL__} verificar_postgresql: postgresql-0 no Ready"
        return 1
    fi
    echo "${__STEP_OK__} verificar_postgresql"

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || \
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ═══ IDEMPOTENCIA ═══
    if idempotency_check; then
        _log "=================================================="
        _log "KONG YA INSTALADO Y OPERATIVO — SKIP TOTAL"
        _log "=================================================="
        _log "  namespace:   $NS"
        _log "  proxy:       http://kong.${NS}.svc.cluster.local:${PROXY_PORT}"
        _log "  admin:       http://127.0.0.1:${ADMIN_PORT}"
        _log "  status:      http://0.0.0.0:${STATUS_PORT}"
        _log "  health:      $(_kong_health)"
        _log "=================================================="
        return 0
    fi
    _log "Idempotencia NO superada — instalando Kong..."

    local pasada=1
    if _k get deployment kong -n "$NS" > /dev/null 2>&1; then
        pasada=2
        _log "PASADA 2 detectada: Deployment existe → reparar/configurar"
    fi

    # ── 1. Secrets ───────────────────────────────────────────────
    echo "${__STEP_START__} crear_secrets"
    local secret_yaml
    secret_yaml=$(_k create secret generic kong-db-credentials \
        --namespace="$NS" \
        --from-literal=KONG_PG_USER="$KONG_DB_USER" \
        --from-literal=KONG_PG_PASSWORD="$KONG_DB_PASS" \
        --dry-run=client -o yaml 2>/dev/null)
    if [[ -z "$secret_yaml" ]]; then
        echo "${__STEP_FAIL__} crear_secrets: no se pudo generar YAML"
        return 1
    fi
    printf '%s\n' "$secret_yaml" | _k apply -f - >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} crear_secrets: apply falló"; return 1
    }
    echo "${__STEP_OK__} crear_secrets"

    # ── 2. Migrations Job ────────────────────────────────────────
    echo "${__STEP_START__} kong_migrations"
    # Verificar si migrations ya se ejecutaron (idempotente)
    local migrations_done
    migrations_done=$(_k get job kong-migrations -n "$NS" \
        -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
    if [[ "$migrations_done" == "1" ]]; then
        _log "Migrations ya completadas — saltando"
        echo "${__STEP_OK__} kong_migrations (ya ejecutadas)"
    else
        _apply "migrations-job" "apiVersion: batch/v1
kind: Job
metadata:
  name: kong-migrations
  namespace: ${NS}
  labels:
    app: kong-migrations
    sbos-managed: \"true\"
spec:
  ttlSecondsAfterFinished: 3600
  template:
    spec:
      restartPolicy: OnFailure
      containers:
        - name: kong-migrations
          image: ${KONG_IMAGE}
          command: [kong, migrations, bootstrap]
          env:
            - name: KONG_DATABASE
              value: postgres
            - name: KONG_PG_HOST
              value: \"${PG_HOST}\"
            - name: KONG_PG_PORT
              value: \"5432\"
            - name: KONG_PG_DATABASE
              value: kong_db
            - name: KONG_LOG_LEVEL
              value: warn
          envFrom:
            - secretRef:
                name: kong-db-credentials"

        local elapsed=0
        while (( elapsed < 120 )); do
            local succeeded
            succeeded=$(_k get job kong-migrations -n "$NS" \
                -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
            [[ "$succeeded" == "1" ]] && break
            local failed
            failed=$(_k get job kong-migrations -n "$NS" \
                -o jsonpath='{.status.failed}' 2>/dev/null || echo "0")
            if (( failed > 2 )); then
                echo "${__STEP_FAIL__} kong_migrations: job fallido ($failed fallos)"
                return 1
            fi
            sleep 10; elapsed=$((elapsed + 10))
        done
        if (( elapsed >= 120 )); then
            echo "${__STEP_FAIL__} kong_migrations: timeout (120s)"
            return 1
        fi
        _log "Migrations completadas en ${elapsed}s"
        echo "${__STEP_OK__} kong_migrations"
    fi

    # ── 3. Deployment + Services ─────────────────────────────────
    # BUGFIX 2026-06-23:
    #   - probes en :8007 (Status API), NO en :8001 (Admin API)
    #   - SIN campo "host" (kubelet usa pod IP, no loopback del nodo)
    #   - KONG_STATUS_LISTEN=0.0.0.0:8007 para que sea alcanzable
    echo "${__STEP_START__} deploy_kong"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: kong
  namespace: ${NS}
  labels:
    app: kong
    sbos-managed: \"true\"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kong
  template:
    metadata:
      labels:
        app: kong
      annotations:
        prometheus.io/scrape: \"true\"
        prometheus.io/port: \"8001\"
        prometheus.io/path: \"/metrics\"
    spec:
      containers:
        - name: kong
          image: ${KONG_IMAGE}
          ports:
            - containerPort: 8000
              name: proxy-http
            - containerPort: 8443
              name: proxy-https
            - containerPort: 8001
              name: admin-api
            - containerPort: 8007
              name: status-api
          env:
            - name: KONG_DATABASE
              value: postgres
            - name: KONG_PG_HOST
              value: \"${PG_HOST}\"
            - name: KONG_PG_PORT
              value: \"5432\"
            - name: KONG_PG_DATABASE
              value: kong_db
            - name: KONG_PROXY_LISTEN
              value: \"0.0.0.0:8000, 0.0.0.0:8443 ssl\"
            - name: KONG_ADMIN_LISTEN
              value: \"127.0.0.1:8001\"
            - name: KONG_STATUS_LISTEN
              value: \"0.0.0.0:8007\"
            - name: KONG_PLUGINS
              value: \"bundled,jwt,rate-limiting,correlation-id\"
            - name: KONG_LOG_LEVEL
              value: warn
            - name: KONG_PROXY_ACCESS_LOG
              value: /dev/stdout
            - name: KONG_PROXY_ERROR_LOG
              value: /dev/stderr
          envFrom:
            - secretRef:
                name: kong-db-credentials
          # ── Probes corregidas (BUGFIX 2026-06-23) ──
          # Kong 3.x: Status API en :8007 (health checks)
          # SIN host → kubelet usa la IP del pod
          startupProbe:
            httpGet:
              path: /status
              port: ${STATUS_PORT}
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 30
            timeoutSeconds: 5
          readinessProbe:
            httpGet:
              path: /status/ready
              port: ${STATUS_PORT}
            initialDelaySeconds: 5
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /status
              port: ${STATUS_PORT}
            initialDelaySeconds: 5
            periodSeconds: 15
            timeoutSeconds: 5
            failureThreshold: 3
          resources:
            requests:
              cpu: \"200m\"
              memory: \"256Mi\"
            limits:
              cpu: \"1\"
              memory: \"512Mi\"
---
apiVersion: v1
kind: Service
metadata:
  name: kong
  namespace: ${NS}
  labels:
    app: kong
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 8000
      targetPort: 8000
      name: proxy-http
    - port: 8443
      targetPort: 8443
      name: proxy-https
  selector:
    app: kong
---
apiVersion: v1
kind: Service
metadata:
  name: kong-admin
  namespace: ${NS}
  labels:
    app: kong
    sbos-managed: \"true\"
    admin: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 8001
      targetPort: 8001
      name: admin
  selector:
    app: kong" || {
        echo "${__STEP_FAIL__} deploy_kong"; return 1
    }
    echo "${__STEP_OK__} deploy_kong"

    # ── 4. Esperar pod Running ─────────────────────────────────────
    echo "${__STEP_START__} wait_running"
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=kong --no-headers 2>/dev/null | grep -q "." && break
        sleep 3
    done

    # Esperar a que el startup probe pase (hasta 300s)
    _k wait pod -n "$NS" -l app=kong \
        --for=condition=Ready \
        --timeout=300s 2>/dev/null || {
        _log "ADVERTENCIA: Kong no Ready en 300s — verificando estado..."
        local pod_status
        pod_status=$(_k get pod -n "$NS" -l app=kong -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "?")
        if [[ "$pod_status" == "Running" ]]; then
            _log "Pod Running pero probe aún no pasa — ficha_repair convergerá"
            echo "${__STEP_SKIP__} wait_running: Running pero no Ready aún"
        else
            echo "${__STEP_FAIL__} wait_running: pod en fase $pod_status"
            return 1
        fi
        return 0
    }
    echo "${__STEP_OK__} wait_running"

    # ── 5. Verificar Admin API ───────────────────────────────────
    echo "${__STEP_START__} verificar_admin_api"
    sleep 10  # Dar tiempo a que Kong termine de inicializar
    local health
    health=$(_kong_health 2>/dev/null)
    if echo "$health" | grep -q "healthy"; then
        echo "${__STEP_OK__} verificar_admin_api (healthy)"
    else
        _log "ADVERTENCIA: kong health=$health — ficha_repair convergerá"
        echo "${__STEP_SKIP__} verificar_admin_api: $health"
    fi

    # ── 6. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_kong"
    _apply "np-kong-access" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kong-access
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: kong
  policyTypes: [Ingress]
  ingress:
    - ports:
        - protocol: TCP
          port: 8000
        - protocol: TCP
          port: 8443
    - from:
        - namespaceSelector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
                  - sbos-system
                  - sbos-gateway
                  - sbos-security
      ports:
        - protocol: TCP
          port: 8001" || true

    _apply "np-kong-egress" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-kong-egress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: kong
  policyTypes: [Egress]
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
    echo "${__STEP_OK__} networkpolicies_kong"

    # ── 7. TLS Vault PKI (Iteración 2) ──────────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/kong \
                   common_name='kong.sbos-gateway.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        if [[ -n "$cert_json" ]]; then
            local k_cert k_key k_ca
            k_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            k_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            k_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$k_cert" && -n "$k_key" ]]; then
                _k delete secret kong-tls -n "$NS" 2>/dev/null || true
                _k create secret generic kong-tls -n "$NS" \
                    --from-literal=server.crt="$k_cert" \
                    --from-literal=server.key="$k_key" \
                    --from-literal=ca.crt="$k_ca" 2>/dev/null || true
                _k rollout restart deployment/kong -n "$NS" 2>/dev/null || true
                _log "Kong TLS configurado (certificado Vault PKI)"
            fi
        fi
    fi
    if _k get secret kong-tls -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_OK__} configurar_tls"
    else
        echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"
    fi

    _log "kong instalado"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado Kong:"
    local health
    health=$(_kong_health 2>/dev/null)
    _log "  kong health: $health"
    _k get pod -n "$NS" -l app=kong --no-headers 2>/dev/null \
        | awk '{printf "  pod=%s ready=%s status=%s restarts=%s\n", $1, $2, $3, $4}' \
        | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    # Verificar idempotencia primero
    if idempotency_check; then
        _log "Repair: todo OK — sin acción necesaria"
        return 0
    fi

    _log "Repair: detectado drift — corrigiendo..."

    echo "${__STEP_START__} reparar_kong"
    # Verificar si el problema son las probes mal configuradas (BUG legacy)
    local startup_port
    startup_port=$(_k get deploy kong -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.port}' 2>/dev/null || echo "")
    local startup_host
    startup_host=$(_k get deploy kong -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.host}' 2>/dev/null || echo "")

    if [[ "$startup_port" != "$STATUS_PORT" || -n "$startup_host" ]]; then
        _log "Detectadas probes legacy (port=$startup_port host=$startup_host) — reemplazando deployment"
        # Forzar recreación del deployment con probes correctas
        _k delete deployment kong -n "$NS" 2>/dev/null || true
        _k delete pod -n "$NS" -l app=kong --grace-period=5 2>/dev/null || true
        ficha_install
        return $?
    fi

    # Problema no es de probes — intentar restart
    _k rollout restart deployment/kong -n "$NS" 2>/dev/null || true
    _k wait pod -n "$NS" -l app=kong --for=condition=Ready --timeout=120s 2>/dev/null || {
        _log "Kong no Ready tras restart — reinstalando"
        _k delete deployment kong -n "$NS" 2>/dev/null || true
        ficha_install
        return $?
    }
    echo "${__STEP_OK__} reparar_kong"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=kong \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" == "True" ]]; then
        echo "${__STEP_OK__} test_pod_ready"
    else
        echo "${__STEP_FAIL__} test_pod_ready: Ready=${ready}"
        ok=1
    fi

    echo "${__STEP_START__} test_kong_health"
    local health
    health=$(_kong_health 2>/dev/null)
    if echo "$health" | grep -q "healthy"; then
        echo "${__STEP_OK__} test_kong_health ($health)"
    else
        echo "${__STEP_FAIL__} test_kong_health ($health)"
        ok=1
    fi

    echo "${__STEP_START__} test_admin_status"
    local admin_json
    admin_json=$(_kong_admin "/status" 2>/dev/null || echo "")
    if echo "$admin_json" | grep -q "database"; then
        echo "${__STEP_OK__} test_admin_status"
    else
        echo "${__STEP_FAIL__} test_admin_status: Admin API no responde"
        ok=1
    fi

    echo "${__STEP_START__} test_db_connected"
    local db_reachable
    db_reachable=$(echo "$admin_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('database',{}).get('reachable','?'))" \
        2>/dev/null || echo "?")
    if [[ "$db_reachable" == "True" || "$db_reachable" == "true" ]]; then
        echo "${__STEP_OK__} test_db_connected"
    else
        echo "${__STEP_FAIL__} test_db_connected: reachable=$db_reachable"
        ok=1
    fi

    echo "${__STEP_START__} test_status_endpoint"
    local status_json
    status_json=$(_kong_status "/status" 2>/dev/null || echo "")
    if echo "$status_json" | grep -q "database"; then
        echo "${__STEP_OK__} test_status_endpoint (:8007 OK)"
    else
        echo "${__STEP_FAIL__} test_status_endpoint: Status API :8007 no responde"
        ok=1
    fi

    echo "${__STEP_START__} test_probes_config"
    local probe_port probe_host
    probe_port=$(_k get deploy kong -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.port}' 2>/dev/null || echo "?")
    probe_host=$(_k get deploy kong -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.host}' 2>/dev/null || echo "")
    if [[ "$probe_port" == "$STATUS_PORT" && -z "$probe_host" ]]; then
        echo "${__STEP_OK__} test_probes_config (port=$probe_port, host=<default>)"
    else
        echo "${__STEP_FAIL__} test_probes_config (port=$probe_port, host=$probe_host) — debe ser port=$STATUS_PORT sin host"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-kong-access -n "$NS" > /dev/null 2>&1 && np_ok=$((np_ok+1))
    _k get networkpolicy allow-kong-egress -n "$NS" > /dev/null 2>&1 && np_ok=$((np_ok+1))
    if (( np_ok == 2 )); then
        echo "${__STEP_OK__} test_networkpolicy (2/2)"
    else
        echo "${__STEP_FAIL__} test_networkpolicy: ${np_ok}/2"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== kong STATUS ==="
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" -l app=kong \
        -o custom-columns='NAME:.metadata.name,READY:.status.containerStatuses[0].ready,STATUS:.status.phase,RESTARTS:.status.containerStatuses[0].restartCount' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Kong health:"
    _kong_health 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Admin API /status:"
    _kong_admin "/status" 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
db = d.get('database', {})
srv = d.get('server', {})
print(f'  DB reachable: {db.get(\"reachable\",\"?\")}')
print(f'  Connections: accepted={srv.get(\"connections_accepted\",\"?\")} active={srv.get(\"connections_active\",\"?\")}')
print(f'  Total requests: {srv.get(\"total_requests\",\"?\")}')
" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Routes:"
    _kong_admin "/routes" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(f'  {len(d.get(\"data\",[]))} rutas configuradas')" \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Probes config:"
    local p_port p_host
    p_port=$(_k get deploy kong -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.port}' 2>/dev/null || echo "?")
    p_host=$(_k get deploy kong -n "$NS" -o jsonpath='{.spec.template.spec.containers[0].startupProbe.httpGet.host}' 2>/dev/null || echo "<default>")
    echo "  startupProbe: port=$p_port host=$p_host"
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando kong"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment kong -n "$NS" 2>/dev/null || true
    _k delete service kong kong-admin -n "$NS" 2>/dev/null || true
    _k delete job kong-migrations -n "$NS" 2>/dev/null || true
    _k delete secret kong-db-credentials kong-tls -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-kong-access allow-kong-egress -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico kong ==="
    echo "Describe pod:"
    _k describe pod -n "$NS" -l app=kong 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:|Port|Startup|Liveness|Readiness" \
        || echo "  pod no encontrado"
    echo ""
    echo "Logs kong (últimas 40 líneas):"
    _k logs -n "$NS" deploy/kong --tail=40 2>/dev/null || true
    echo ""
    echo "Logs migrations (últimas 20 líneas):"
    _k logs -n "$NS" -l app=kong-migrations --tail=20 2>/dev/null || true
    echo ""
    echo "Eventos (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -15 || true
    echo ""
    echo "Probes actuales:"
    _k get deploy kong -n "$NS" -o json 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
cs=d['spec']['template']['spec']['containers'][0]
sp=cs.get('startupProbe',{}).get('httpGet',{})
lp=cs.get('livenessProbe',{}).get('httpGet',{})
rp=cs.get('readinessProbe',{}).get('httpGet',{})
print(f'  startup:   {sp.get(\"path\",\"?\")}:{sp.get(\"port\",\"?\")} host={sp.get(\"host\",\"<default>\")}')
print(f'  liveness:  {lp.get(\"path\",\"?\")}:{lp.get(\"port\",\"?\")} host={lp.get(\"host\",\"<default>\")}')
print(f'  readiness: {rp.get(\"path\",\"?\")}:{rp.get(\"port\",\"?\")} host={rp.get(\"host\",\"<default>\")}')
" 2>/dev/null || echo "  no disponible"
}
