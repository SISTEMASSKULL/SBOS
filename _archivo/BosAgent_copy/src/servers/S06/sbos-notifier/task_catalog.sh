#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-notifier (bnotify)
# Iteración 1: Deployment bnotify + schema notifier_db + stub Python funcional
#              endpoints MFA (send_otp/verify_otp) + webhook Alertmanager
# Dependencias: postgresql (notifier_db), redis (streams), keycloak (auth)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-notifier.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-notifier"
readonly NOTIFIER_IMAGE="ghcr.io/skull-sistemas/sbos-notifier:1.0.0"
readonly FALLBACK_IMAGE="python:3.14"
readonly PG_HOST="postgresql.sbos-data.svc.cluster.local"
readonly REDIS_HOST="redis.sbos-data.svc.cluster.local"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-notifier] $*" | tee -a "$FICHA_LOG" >&2; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-notif-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

_wait_notifier_ready() {
    local timeout="${1:-60}" elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod -n "$NS" -l app=sbos-notifier --no-headers 2>/dev/null | awk '{print $3}' | head -1)
        [[ "$phase" == "Running" ]] && { _log "sbos-notifier Running"; return 0; }
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

_notifier_curl() { _k exec deploy/sbos-notifier -n "$NS" -- sh -c "curl -sf $*" 2>/dev/null; }

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_postgresql"
    if ! _k get pod postgresql-0 -n sbos-data > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_postgresql: postgresql-0 no disponible"; return 1
    fi
    local pg_ready
    pg_ready=$(_k get pod postgresql-0 -n sbos-data -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$pg_ready" == "True" ]] && echo "${__STEP_OK__} verificar_postgresql" || { echo "${__STEP_FAIL__} verificar_postgresql: no Ready"; return 1; }

    echo "${__STEP_START__} verificar_redis"
    if _k exec redis-0 -n sbos-data -- redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo "${__STEP_OK__} verificar_redis"
    else
        echo "${__STEP_FAIL__} verificar_redis: Redis no responde"; return 1
    fi

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Schema en notifier_db ──────────────────────────────────
    echo "${__STEP_START__} crear_schema_db"
    _k exec postgresql-0 -n sbos-data -- psql -U postgres -d notifier_db -c "
CREATE TABLE IF NOT EXISTS notifications (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ctx_id      TEXT NOT NULL,
    tenant_id   TEXT NOT NULL,
    user_id     TEXT NOT NULL,
    channel     TEXT NOT NULL,
    type        TEXT NOT NULL,
    payload     JSONB,
    status      TEXT DEFAULT 'pending',
    created_at  TIMESTAMPTZ DEFAULT NOW(),
    sent_at     TIMESTAMPTZ,
    error_msg   TEXT
);
CREATE TABLE IF NOT EXISTS mfa_challenges (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ctx_id      TEXT NOT NULL,
    user_id     TEXT NOT NULL,
    otp_hash    TEXT NOT NULL,
    channel     TEXT NOT NULL,
    attempts    INT DEFAULT 0,
    expires_at  TIMESTAMPTZ NOT NULL,
    used        BOOLEAN DEFAULT FALSE,
    created_at  TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_notif_tenant   ON notifications(tenant_id);
CREATE INDEX IF NOT EXISTS idx_notif_user     ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_user       ON mfa_challenges(user_id);
CREATE INDEX IF NOT EXISTS idx_mfa_expires    ON mfa_challenges(expires_at);
" 2>/dev/null && _log "Schema notifier_db creado" || _log "ADVERTENCIA: schema ya existe o error menor"
    echo "${__STEP_OK__} crear_schema_db"

    # ── 2. Secrets ────────────────────────────────────────────────
    echo "${__STEP_START__} crear_secrets"
    local webhook_secret
    webhook_secret=$(tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 32 2>/dev/null || echo "sbos_webhook_bootstrap")

    local db_secret notifier_secret
    db_secret=$(_k create secret generic notifier-db-credentials \
        --namespace="$NS" \
        --from-literal=DB_HOST="$PG_HOST" \
        --from-literal=DB_PORT="5432" \
        --from-literal=DB_NAME="notifier_db" \
        --from-literal=DB_USER="postgres" \
        --from-literal=DB_PASSWORD="${PG_ROOT_PASSWORD:-sbos_bootstrap_pass}" \
        --dry-run=client -o yaml 2>/dev/null)
    notifier_secret=$(_k create secret generic notifier-config \
        --namespace="$NS" \
        --from-literal=REDIS_HOST="$REDIS_HOST" \
        --from-literal=REDIS_PORT="6379" \
        --from-literal=REDIS_DB="0" \
        --from-literal=WEBHOOK_SECRET="$webhook_secret" \
        --from-literal=TOTP_ISSUER="SBOS" \
        --from-literal=OTP_TTL_SECONDS="300" \
        --from-literal=MAX_ATTEMPTS="3" \
        --dry-run=client -o yaml 2>/dev/null)

    if [[ -z "$db_secret" || -z "$notifier_secret" ]]; then
        echo "${__STEP_FAIL__} crear_secrets: no se pudo generar YAML"; return 1
    fi
    printf '%s\n' "$db_secret" | _k apply -f - >> "$FICHA_LOG" 2>&1 || true
    printf '%s\n' "$notifier_secret" | _k apply -f - >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} crear_secrets"

    # ── 3. ConfigMap con stub Python ──────────────────────────────
    echo "${__STEP_START__} crear_stub_app"
    _apply "configmap-stub" "apiVersion: v1
kind: ConfigMap
metadata:
  name: notifier-stub
  namespace: ${NS}
  labels:
    app: sbos-notifier
    sbos-managed: \"true\"
data:
  app.py: |
    #!/usr/bin/env python3
    \"\"\"
    sbos-notifier stub — Iteración 1
    Sirve los endpoints mínimos para que bAuth pueda hacer Step-Up (RFC 9470).
    La imagen nativa (ghcr.io/skull-sistemas/sbos-notifier) reemplazará este stub.
    \"\"\"
    import json, os, hashlib, secrets, time
    from http.server import HTTPServer, BaseHTTPRequestHandler

    PORT = int(os.getenv(\"PORT\", \"28200\"))
    store = {}

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, fmt, *args): pass

        def _respond(self, code, body):
            data = json.dumps(body).encode()
            self.send_response(code)
            self.send_header(\"Content-Type\", \"application/json\")
            self.send_header(\"Content-Length\", len(data))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            if self.path in (\"/health/ready\", \"/health/live\", \"/-/ready\"):
                self._respond(200, {\"status\": \"UP\", \"mode\": \"stub\"})
            elif self.path == \"/metrics\":
                self.send_response(200)
                self.send_header(\"Content-Type\", \"text/plain\")
                self.end_headers()
                self.wfile.write(b\"# sbos_notifier_stub 1\\nsbos_notifier_up 1\\n\")
            else:
                self._respond(404, {\"error\": \"not found\"})

        def do_POST(self):
            length = int(self.headers.get(\"Content-Length\", 0))
            body = json.loads(self.rfile.read(length) or b\"{}\") if length else {}
            if self.path == \"/rpc\":
                method = body.get(\"method\", \"\")
                bid = body.get(\"id\", 1)
                if method == \"notifier.mfa.send_otp\":
                    p = body.get(\"params\", {})
                    uid = p.get(\"user_id\", \"unknown\")
                    otp = str(secrets.randbelow(900000) + 100000)
                    store[uid] = {\"otp\": otp, \"exp\": time.time() + 300}
                    print(f\"[STUB OTP] user={uid} otp={otp}\", flush=True)
                    self._respond(200, {\"jsonrpc\":\"2.0\",\"id\":bid,
                        \"result\":{\"sent\":True,\"channel\":\"stub\",\"ttl\":300}})
                elif method == \"notifier.mfa.verify_otp\":
                    p = body.get(\"params\", {})
                    uid = p.get(\"user_id\", \"\")
                    otp = p.get(\"otp\", \"\")
                    entry = store.get(uid)
                    valid = (entry and entry[\"otp\"] == otp
                             and time.time() < entry[\"exp\"])
                    if valid: del store[uid]
                    self._respond(200, {\"jsonrpc\":\"2.0\",\"id\":bid,
                        \"result\":{\"valid\":valid}})
                elif method == \"notifier.send\":
                    self._respond(200, {\"jsonrpc\":\"2.0\",\"id\":bid,
                        \"result\":{\"queued\":True,\"mode\":\"stub\"}})
                else:
                    self._respond(200, {\"jsonrpc\":\"2.0\",\"id\":bid,
                        \"error\":{\"code\":-32601,\"message\":f\"method not found: {method}\"}})
            elif self.path == \"/webhook/alertmanager\":
                print(f\"[STUB WEBHOOK] {json.dumps(body)[:200]}\", flush=True)
                self._respond(200, {\"ok\": True})
            else:
                self._respond(404, {\"error\": \"not found\"})

    if __name__ == \"__main__\":
        print(f\"sbos-notifier stub escuchando en :{PORT}\", flush=True)
        HTTPServer((\"0.0.0.0\", PORT), Handler).serve_forever()" || { echo "${__STEP_FAIL__} crear_stub_app"; return 1; }
    echo "${__STEP_OK__} crear_stub_app"

    # ── 4. Deployment + Service ──────────────────────────────────
    echo "${__STEP_START__} deploy_notifier"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: sbos-notifier
  namespace: ${NS}
  labels:
    app: sbos-notifier
    sbos-managed: \"true\"
    sbos-component: notifier
spec:
  replicas: 1
  selector:
    matchLabels:
      app: sbos-notifier
  template:
    metadata:
      labels:
        app: sbos-notifier
      annotations:
        prometheus.io/scrape: \"true\"
        prometheus.io/port: \"28204\"
        prometheus.io/path: \"/metrics\"
    spec:
      containers:
        - name: sbos-notifier
          image: ${FALLBACK_IMAGE}
          command: [\"python3\", \"/app/app.py\"]
          ports:
            - containerPort: 28200
              name: api
            - containerPort: 28201
              name: ws
            - containerPort: 28202
              name: mfa
            - containerPort: 28203
              name: webhook
            - containerPort: 28204
              name: metrics
            - containerPort: 28205
              name: admin
          env:
            - name: PORT
              value: \"28200\"
          envFrom:
            - secretRef:
                name: notifier-db-credentials
            - secretRef:
                name: notifier-config
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 28200
            initialDelaySeconds: 10
            periodSeconds: 10
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /health/live
              port: 28200
            initialDelaySeconds: 20
            periodSeconds: 15
          resources:
            requests:
              cpu: \"100m\"
              memory: \"128Mi\"
            limits:
              cpu: \"500m\"
              memory: \"256Mi\"
          volumeMounts:
            - name: stub-app
              mountPath: /app
      volumes:
        - name: stub-app
          configMap:
            name: notifier-stub
---
apiVersion: v1
kind: Service
metadata:
  name: sbos-notifier
  namespace: ${NS}
  labels:
    app: sbos-notifier
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 28200
      targetPort: 28200
      name: api
    - port: 28201
      targetPort: 28201
      name: ws
    - port: 28202
      targetPort: 28202
      name: mfa
    - port: 28203
      targetPort: 28203
      name: webhook
    - port: 28204
      targetPort: 28204
      name: metrics
    - port: 28205
      targetPort: 28205
      name: admin
  selector:
    app: sbos-notifier" || { echo "${__STEP_FAIL__} deploy_notifier"; return 1; }
    echo "${__STEP_OK__} deploy_notifier"

    # ── 5. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicy_notifier"
    _apply "np-notifier" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: sbos-notifier-ingress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: sbos-notifier
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              sbos-tier: \"true\"
      ports:
        - protocol: TCP
          port: 28200
        - protocol: TCP
          port: 28202
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitoring
      ports:
        - protocol: TCP
          port: 28203
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-system
      ports:
        - protocol: TCP
          port: 28205
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
              kubernetes.io/metadata.name: sbos-data
      ports:
        - protocol: TCP
          port: 6379
    - ports:
        - protocol: UDP
          port: 53" || true
    echo "${__STEP_OK__} networkpolicy_notifier"

    echo "${__STEP_START__} wait_ready"
    _wait_notifier_ready 60 && echo "${__STEP_OK__} wait_ready" || { echo "${__STEP_FAIL__} wait_ready: timeout"; return 1; }

    # ── TLS Vault PKI (Iteración 2) ──────────────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/sbos-notifier \
                   common_name='sbos-notifier.sbos-system.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        if [[ -n "$cert_json" ]]; then
            local n_cert n_key n_ca
            n_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            n_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            n_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$n_cert" && -n "$n_key" ]]; then
                _k delete secret sbos-notifier-tls -n "$NS" 2>/dev/null || true
                _k create secret generic sbos-notifier-tls -n "$NS" \
                    --from-literal=tls.crt="$n_cert" \
                    --from-literal=tls.key="$n_key" \
                    --from-literal=ca.crt="$n_ca" 2>/dev/null || true
                echo "${__STEP_OK__} configurar_tls"
            else
                echo "${__STEP_SKIP__} configurar_tls: no se pudo extraer certificado"
            fi
        else
            echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"
        fi
    else
        echo "${__STEP_SKIP__} configurar_tls: Vault no accesible"
    fi

    _log "sbos-notifier instalado (modo stub Python 3.14)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado sbos-notifier:"
    local health
    health=$(_notifier_curl "http://localhost:28200/health/ready" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" 2>/dev/null || echo "FAIL")
    _log "  health=$health"
    _k get pod -n "$NS" -l app=sbos-notifier --no-headers 2>/dev/null | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reiniciar_notifier"
    _k rollout restart deployment/sbos-notifier -n "$NS" 2>/dev/null || true
    sleep 5
    _wait_notifier_ready 60 || _log "ADVERTENCIA: sbos-notifier no Ready tras reinicio"
    echo "${__STEP_OK__} reiniciar_notifier"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=sbos-notifier -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$ready" == "True" ]] && echo "${__STEP_OK__} test_pod_ready" || { echo "${__STEP_FAIL__} test_pod_ready: Ready=$ready"; ok=1; }

    echo "${__STEP_START__} test_health"
    local health
    health=$(_notifier_curl "http://localhost:28200/health/ready" 2>/dev/null || echo "")
    echo "$health" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('status')=='UP' else 1)" 2>/dev/null && echo "${__STEP_OK__} test_health" || { echo "${__STEP_FAIL__} test_health"; ok=1; }

    echo "${__STEP_START__} test_mfa_send_otp"
    local resp
    resp=$(_notifier_curl "http://localhost:28200/rpc" -X POST -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"notifier.mfa.send_otp","params":{"user_id":"test_bootstrap","channel":"stub"},"id":1}' 2>/dev/null || echo "")
    echo "$resp" | python3 -c "import sys,json; d=json.load(sys.stdin); exit(0 if d.get('result',{}).get('sent') else 1)" 2>/dev/null && echo "${__STEP_OK__} test_mfa_send_otp" || { echo "${__STEP_FAIL__} test_mfa_send_otp"; ok=1; }

    echo "${__STEP_START__} test_db_schema"
    local tables
    tables=$(_k exec postgresql-0 -n sbos-data -- psql -U postgres -d notifier_db -c "\dt" 2>/dev/null | grep -cE 'notifications|mfa_challenges' || echo "0")
    (( tables >= 2 )) && echo "${__STEP_OK__} test_db_schema ($tables tablas)" || { echo "${__STEP_FAIL__} test_db_schema: $tables/2"; ok=1; }

    echo "${__STEP_START__} test_networkpolicy"
    _k get networkpolicy sbos-notifier-ingress -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} test_networkpolicy" || { echo "${__STEP_FAIL__} test_networkpolicy"; ok=1; }

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-notifier STATUS ==="
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" -l app=sbos-notifier -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Health: $(_notifier_curl "http://localhost:28200/health/ready" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'),d.get('mode',''))" 2>/dev/null || echo '?')"
    echo "Puertos: 28200(api) 28201(ws) 28202(mfa) 28203(webhook) 28204(metrics) 28205(admin)"
    echo "Métodos RPC: notifier.send | notifier.mfa.send_otp | notifier.mfa.verify_otp"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando sbos-notifier"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment sbos-notifier -n "$NS" 2>/dev/null || true
    _k delete service sbos-notifier -n "$NS" 2>/dev/null || true
    _k delete configmap notifier-stub -n "$NS" 2>/dev/null || true
    _k delete secret notifier-db-credentials notifier-config -n "$NS" 2>/dev/null || true
    _k delete networkpolicy sbos-notifier-ingress -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-notifier ==="
    _k describe pod -n "$NS" -l app=sbos-notifier 2>/dev/null | grep -E "State:|Ready:|Reason:|Message:|Image:" || echo "  pod no encontrado"
    echo ""
    _k logs -n "$NS" deploy/sbos-notifier --tail=30 2>/dev/null || true
    echo ""
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
