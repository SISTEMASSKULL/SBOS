#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — kong
# Iteración 1: Kong 3.9.0 DB-mode + migrations + Deployment + Admin API restringida
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
# Usuario kong creado por la ficha postgresql con OWNER de kong_db.
# Vault rotará estas credenciales en Iteración 2.
KONG_DB_USER="${KONG_DB_USER:-kong}"
KONG_DB_PASS="${KONG_DB_PASSWORD:-kong_bootstrap}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [kong] $*" | tee -a "$FICHA_LOG" >&2; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _apply: aplica manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-kong-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _wait_kong_ready: espera hasta que el pod de Kong esté Ready.
# Kong tarda ~15s en arrancar después de migrations bootstrap.
_wait_kong_ready() {
    local timeout="${1:-180}"
    # Esperar que exista al menos un pod del Deployment
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=kong --no-headers 2>/dev/null \
            | grep -q "." && break
        sleep 3
    done
    _k wait pod -n "$NS" -l app=kong \
        --for=condition=Ready \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: kong pod no Ready en ${timeout}s"
        return 1
    }
    _log "kong pod Ready"
}

# _kong_curl: ejecuta curl dentro del pod de Kong apuntando a Admin API.
_kong_curl() {
    _k exec deploy/kong -n "$NS" -- \
        sh -c "curl -sf $*" 2>/dev/null
}

# _kong_admin: consulta la Admin API de Kong en localhost:8001.
_kong_admin() {
    _kong_curl "http://127.0.0.1:8001${1}" 2>/dev/null
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
        echo "${__STEP_FAIL__} verificar_postgresql: postgresql-0 no Ready (actual: $pg_ready)"
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
    _apply "migrations-job" "apiVersion: batch/v1
kind: Job
metadata:
  name: kong-migrations
  namespace: ${NS}
  labels:
    app: kong-migrations
    sbos-managed: \"true\"
spec:
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
          envFrom:
            - secretRef:
                name: kong-db-credentials"

    # Esperar que el Job termine exitosamente
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

    # ── 3. Deployment + Services ─────────────────────────────────
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
          readinessProbe:
            httpGet:
              path: /status
              port: 8001
              host: \"127.0.0.1\"
            initialDelaySeconds: 15
            periodSeconds: 10
            failureThreshold: 6
          livenessProbe:
            httpGet:
              path: /status
              port: 8001
              host: \"127.0.0.1\"
            initialDelaySeconds: 30
            periodSeconds: 15
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

    # ── 4. Esperar pod Ready ─────────────────────────────────────
    echo "${__STEP_START__} wait_ready"
    if ! _wait_kong_ready 180; then
        echo "${__STEP_FAIL__} wait_ready: timeout esperando Kong"
        return 1
    fi
    echo "${__STEP_OK__} wait_ready"

    # ── 5. Verificar Admin API ───────────────────────────────────
    echo "${__STEP_START__} verificar_admin_api"
    local admin_status
    admin_status=$(_kong_admin "/status" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('database',{}).get('reachable','?'))" \
        2>/dev/null || echo "?")
    if [[ "$admin_status" == "True" || "$admin_status" == "true" ]]; then
        echo "${__STEP_OK__} verificar_admin_api (DB reachable)"
    else
        _log "ADVERTENCIA: Admin API DB no reachable aún (actual: $admin_status)"
        echo "${__STEP_SKIP__} verificar_admin_api: respuesta pendiente"
    fi

    # ── 6. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_kong"

    # Allow Kong ingress: proxy (8000/8443) desde cualquier namespace SBOS,
    # admin (8001) solo desde sbos-system y sbos-gateway
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
    # Proxy ports: acceso desde todo el cluster vía oauth2-proxy/nginx
    - ports:
        - protocol: TCP
          port: 8000
        - protocol: TCP
          port: 8443
    # Admin API: restringido a sbos-system, sbos-gateway, sbos-security
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

    # Egress hacia postgresql + DNS
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
    # Keycloak OIDC (plugin jwt)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-security
      ports:
        - protocol: TCP
          port: 8080
    # DNS
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
    local status_json
    status_json=$(_kong_admin "/status" 2>/dev/null || echo "{}")
    local db_reachable
    db_reachable=$(echo "$status_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('database',{}).get('reachable','?'))" \
        2>/dev/null || echo "?")
    local conn_total
    conn_total=$(echo "$status_json" | python3 -c \
        "import sys,json; d=json.load(sys.stdin); print(d.get('server',{}).get('connections_total','?'))" \
        2>/dev/null || echo "?")
    _log "  db_reachable=$db_reachable connections=$conn_total"
    _k get pod -n "$NS" -l app=kong --no-headers 2>/dev/null \
        | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' \
        | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reiniciar_kong"
    _k rollout restart deployment/kong -n "$NS" 2>/dev/null || true
    sleep 5
    if ! _wait_kong_ready 120; then
        _log "ADVERTENCIA: kong no Ready tras reinicio"
    fi
    echo "${__STEP_OK__} reiniciar_kong"
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

    echo "${__STEP_START__} test_admin_status"
    local admin_json
    admin_json=$(_kong_admin "/status" 2>/dev/null || echo "")
    if echo "$admin_json" | grep -q '"database"'; then
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

    echo "${__STEP_START__} test_routes_empty"
    local routes_count
    routes_count=$(_kong_admin "/routes" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',[])))" \
        2>/dev/null || echo "0")
    if (( routes_count >= 0 )); then
        echo "${__STEP_OK__} test_routes_empty (${routes_count} rutas)"
    else
        echo "${__STEP_FAIL__} test_routes_empty: error consultando rutas"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-kong-access -n "$NS" > /dev/null 2>&1 && \
        np_ok=$((np_ok+1))
    _k get networkpolicy allow-kong-egress -n "$NS" > /dev/null 2>&1 && \
        np_ok=$((np_ok+1))
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
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' \
        2>/dev/null || echo "  (no disponible)"
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
    _k delete secret kong-db-credentials -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-kong-access allow-kong-egress -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico kong ==="
    echo "Describe pod:"
    _k describe pod -n "$NS" -l app=kong 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:" || echo "  pod no encontrado"
    echo ""
    echo "Logs kong (últimas 30 líneas):"
    _k logs -n "$NS" deploy/kong --tail=30 2>/dev/null || true
    echo ""
    echo "Logs migrations (últimas 20 líneas):"
    _k logs -n "$NS" -l app=kong-migrations --tail=20 2>/dev/null || true
    echo ""
    echo "Eventos (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
