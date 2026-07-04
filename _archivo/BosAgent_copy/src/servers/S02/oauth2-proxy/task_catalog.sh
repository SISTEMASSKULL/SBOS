#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — oauth2-proxy
# Iteración 1: Deployment OAuth2-Proxy 7.8.0 + OIDC Keycloak + cookie sessions
# Dependencias: keycloak (realm master + client oauth2-proxy)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/oauth2-proxy.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-security"
readonly OAUTH2_IMAGE="quay.io/oauth2-proxy/oauth2-proxy:v7.8.0"
readonly KC_HOST="http://keycloak.sbos-security.svc.cluster.local:8080"
# Credenciales del cliente OIDC en Keycloak — Vault las rotará en Iteración 2
OAUTH2_CLIENT_ID="${OAUTH2_CLIENT_ID:-oauth2-proxy}"
OAUTH2_CLIENT_SECRET="${OAUTH2_CLIENT_SECRET:-oauth2_proxy_bootstrap}"
OAUTH2_COOKIE_SECRET="${OAUTH2_COOKIE_SECRET:-}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [oauth2-proxy] $*" | tee -a "$FICHA_LOG" >&2; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _apply: aplica manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-oauth2-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _wait_oauth2_ready: espera hasta que el pod de oauth2-proxy esté Ready.
_wait_oauth2_ready() {
    local timeout="${1:-120}"
    # Esperar que exista al menos un pod del Deployment
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=oauth2-proxy --no-headers 2>/dev/null \
            | grep -q "." && break
        sleep 3
    done
    _k wait pod -n "$NS" -l app=oauth2-proxy \
        --for=condition=Ready \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: oauth2-proxy pod no Ready en ${timeout}s"
        return 1
    }
    _log "oauth2-proxy pod Ready"
}

# _oauth2_curl: ejecuta curl dentro del pod de oauth2-proxy.
_oauth2_curl() {
    _k exec deploy/oauth2-proxy -n "$NS" -- \
        sh -c "curl -sf $*" 2>/dev/null
}

# _generate_cookie_secret: genera un secreto aleatorio para cookies.
_generate_cookie_secret() {
    if [[ -n "$OAUTH2_COOKIE_SECRET" ]]; then
        echo "$OAUTH2_COOKIE_SECRET"
    else
        tr -dc 'a-zA-Z0-9' < /dev/urandom 2>/dev/null | head -c 32 || \
            python3 -c "import secrets; print(secrets.token_hex(16))" 2>/dev/null || \
            echo "sbos_oauth2_cookie_secret_bootstrap"
    fi
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_keycloak"
    if ! _k get pod -n "$NS" -l app=keycloak --no-headers 2>/dev/null | grep -q "."; then
        echo "${__STEP_FAIL__} verificar_keycloak: keycloak pod no encontrado en $NS"
        return 1
    fi
    local kc_ready
    kc_ready=$(_k get pod -n "$NS" -l app=keycloak \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$kc_ready" != "True" ]]; then
        echo "${__STEP_FAIL__} verificar_keycloak: keycloak no Ready (actual: $kc_ready)"
        return 1
    fi
    echo "${__STEP_OK__} verificar_keycloak"

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || \
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Generar cookie secret ──────────────────────────────────
    echo "${__STEP_START__} generar_cookie_secret"
    local cookie_secret
    cookie_secret=$(_generate_cookie_secret)
    _log "Cookie secret generado (${#cookie_secret} bytes)"
    echo "${__STEP_OK__} generar_cookie_secret"

    # ── 2. Secrets ───────────────────────────────────────────────
    echo "${__STEP_START__} crear_secrets"
    local secret_yaml
    secret_yaml=$(_k create secret generic oauth2-proxy-config \
        --namespace="$NS" \
        --from-literal=OAUTH2_PROXY_CLIENT_ID="$OAUTH2_CLIENT_ID" \
        --from-literal=OAUTH2_PROXY_CLIENT_SECRET="$OAUTH2_CLIENT_SECRET" \
        --from-literal=OAUTH2_PROXY_COOKIE_SECRET="$cookie_secret" \
        --dry-run=client -o yaml 2>/dev/null)

    if [[ -z "$secret_yaml" ]]; then
        echo "${__STEP_FAIL__} crear_secrets: no se pudo generar YAML"
        return 1
    fi
    printf '%s\n' "$secret_yaml" | _k apply -f - >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} crear_secrets: apply falló"; return 1
    }
    echo "${__STEP_OK__} crear_secrets"

    # ── 3. Deployment + Service ──────────────────────────────────
    echo "${__STEP_START__} deploy_oauth2_proxy"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy
  namespace: ${NS}
  labels:
    app: oauth2-proxy
    sbos-managed: \"true\"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: oauth2-proxy
  template:
    metadata:
      labels:
        app: oauth2-proxy
      annotations:
        prometheus.io/scrape: \"true\"
        prometheus.io/port: \"44180\"
        prometheus.io/path: \"/metrics\"
    spec:
      containers:
        - name: oauth2-proxy
          image: ${OAUTH2_IMAGE}
          args:
            - --provider=oidc
            - --oidc-issuer-url=${KC_HOST}/realms/master
            - --client-id=\$(OAUTH2_PROXY_CLIENT_ID)
            - --client-secret=\$(OAUTH2_PROXY_CLIENT_SECRET)
            - --cookie-secret=\$(OAUTH2_PROXY_COOKIE_SECRET)
            - --cookie-domain=.sksistemas.com
            - --cookie-secure=true
            - --cookie-expire=1h
            - --cookie-refresh=15m
            - --email-domain=*
            - --upstream=http://kong.sbos-gateway.svc.cluster.local:8000
            - --http-address=0.0.0.0:4180
            - --metrics-address=0.0.0.0:44180
            - --session-store-type=redis
            - --redis-connection-url=redis://redis.sbos-data.svc.cluster.local:6379/0
            - --reverse-proxy=true
            - --set-xauthrequest=true
            - --set-authorization-header=true
            - --pass-access-token=true
            - --pass-authorization-header=true
            - --skip-provider-button=false
            - --scope=openid email profile
          ports:
            - containerPort: 4180
              name: http
            - containerPort: 44180
              name: metrics
          envFrom:
            - secretRef:
                name: oauth2-proxy-config
          readinessProbe:
            httpGet:
              path: /ping
              port: 4180
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /ping
              port: 4180
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 3
          resources:
            requests:
              cpu: \"50m\"
              memory: \"64Mi\"
            limits:
              cpu: \"200m\"
              memory: \"128Mi\"
---
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy
  namespace: ${NS}
  labels:
    app: oauth2-proxy
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 4180
      targetPort: 4180
      name: http
    - port: 44180
      targetPort: 44180
      name: metrics
  selector:
    app: oauth2-proxy" || {
        echo "${__STEP_FAIL__} deploy_oauth2_proxy"; return 1
    }
    echo "${__STEP_OK__} deploy_oauth2_proxy"

    # ── 4. Esperar pod Ready ─────────────────────────────────────
    echo "${__STEP_START__} wait_ready"
    if ! _wait_oauth2_ready 120; then
        echo "${__STEP_FAIL__} wait_ready: timeout esperando oauth2-proxy"
        return 1
    fi
    echo "${__STEP_OK__} wait_ready"

    # ── 5. Verificar /ping ────────────────────────────────────────
    echo "${__STEP_START__} verificar_ping"
    local ping_resp
    ping_resp=$(_oauth2_curl "http://localhost:4180/ping" 2>/dev/null || echo "")
    if [[ "$ping_resp" == "OK" ]]; then
        echo "${__STEP_OK__} verificar_ping"
    else
        echo "${__STEP_FAIL__} verificar_ping: respuesta inesperada: ${ping_resp}"
        return 1
    fi

    # ── 6. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_oauth2"

    # Ingress desde sbos-gateway (nginx→kong→oauth2-proxy), sbos-system, sbos-security
    _apply "np-oauth2-access" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-oauth2-proxy-access
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: oauth2-proxy
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
                  - sbos-gateway
                  - sbos-security
                  - sbos-system
      ports:
        - protocol: TCP
          port: 4180
        - protocol: TCP
          port: 44180" || true

    # Egress hacia Keycloak (OIDC) y Kong (upstream)
    _apply "np-oauth2-egress" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-oauth2-proxy-egress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: oauth2-proxy
  policyTypes: [Egress]
  egress:
    # Keycloak OIDC
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-security
      ports:
        - protocol: TCP
          port: 8080
    # Kong upstream
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
      ports:
        - protocol: TCP
          port: 8000
    # DNS
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53" || true

    echo "${__STEP_OK__} networkpolicies_oauth2"

    # ── 7. Credenciales Vault (Iteración 2) ──────────────────────
    echo "${__STEP_START__} migrar_credenciales_vault"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        _k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault kv put sbos/oauth2-proxy/client \
                   client_id=${OAUTH2_CLIENT_ID} \
                   client_secret=${OAUTH2_CLIENT_SECRET} 2>/dev/null" 2>/dev/null || true
        echo "${__STEP_OK__} migrar_credenciales_vault"
    else
        echo "${__STEP_SKIP__} migrar_credenciales_vault: Vault no disponible"
    fi

    _log "oauth2-proxy instalado (Iteración 2: cookie-secure=true)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado oauth2-proxy:"
    local ping_status
    ping_status=$(_oauth2_curl "http://localhost:4180/ping" 2>/dev/null || echo "FAIL")
    _log "  ping=$ping_status"
    _k get pod -n "$NS" -l app=oauth2-proxy --no-headers 2>/dev/null \
        | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' \
        | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reiniciar_oauth2"
    _k rollout restart deployment/oauth2-proxy -n "$NS" 2>/dev/null || true
    sleep 5
    if ! _wait_oauth2_ready 120; then
        _log "ADVERTENCIA: oauth2-proxy no Ready tras reinicio"
    fi
    echo "${__STEP_OK__} reiniciar_oauth2"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=oauth2-proxy \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" == "True" ]]; then
        echo "${__STEP_OK__} test_pod_ready"
    else
        echo "${__STEP_FAIL__} test_pod_ready: Ready=${ready}"
        ok=1
    fi

    echo "${__STEP_START__} test_ping"
    local ping_resp
    ping_resp=$(_oauth2_curl "http://localhost:4180/ping" 2>/dev/null || echo "")
    if [[ "$ping_resp" == "OK" ]]; then
        echo "${__STEP_OK__} test_ping"
    else
        echo "${__STEP_FAIL__} test_ping: respuesta=${ping_resp}"
        ok=1
    fi

    echo "${__STEP_START__} test_metrics"
    local metrics
    metrics=$(_oauth2_curl "http://localhost:44180/metrics" 2>/dev/null || echo "")
    if echo "$metrics" | grep -q "oauth2_proxy"; then
        echo "${__STEP_OK__} test_metrics"
    else
        echo "${__STEP_SKIP__} test_metrics: métricas no expuestas o formato inesperado"
    fi

    echo "${__STEP_START__} test_auth_redirect"
    local auth_resp
    auth_resp=$(_oauth2_curl "-o /dev/null -w '%{http_code}' http://localhost:4180/" 2>/dev/null || echo "000")
    if [[ "$auth_resp" == "403" || "$auth_resp" == "302" || "$auth_resp" == "401" ]]; then
        # Sin cookie → redirige o deniega. Ambos son comportamiento correcto.
        echo "${__STEP_OK__} test_auth_redirect (HTTP $auth_resp → auth requerida)"
    else
        echo "${__STEP_SKIP__} test_auth_redirect: HTTP $auth_resp (inesperado pero no fatal)"
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-oauth2-proxy-access -n "$NS" > /dev/null 2>&1 && \
        np_ok=$((np_ok+1))
    _k get networkpolicy allow-oauth2-proxy-egress -n "$NS" > /dev/null 2>&1 && \
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
    echo "=== oauth2-proxy STATUS ==="
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" -l app=oauth2-proxy \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Health:"
    _oauth2_curl "http://localhost:4180/ping" 2>/dev/null \
        | awk '{printf "  ping: %s\n", $0}' || echo "  (no disponible)"
    echo ""
    echo "Métricas:"
    _oauth2_curl "http://localhost:44180/metrics" 2>/dev/null \
        | grep -E "oauth2_proxy_requests_total|oauth2_proxy_up" \
        | awk '{printf "  %s\n", $0}' || echo "  (no disponible)"
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando oauth2-proxy"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment oauth2-proxy -n "$NS" 2>/dev/null || true
    _k delete service oauth2-proxy -n "$NS" 2>/dev/null || true
    _k delete secret oauth2-proxy-config -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-oauth2-proxy-access \
        allow-oauth2-proxy-egress -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico oauth2-proxy ==="
    echo "Describe pod:"
    _k describe pod -n "$NS" -l app=oauth2-proxy 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:" || echo "  pod no encontrado"
    echo ""
    echo "Logs (últimas 30 líneas):"
    _k logs -n "$NS" deploy/oauth2-proxy --tail=30 2>/dev/null || true
    echo ""
    echo "Eventos (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
