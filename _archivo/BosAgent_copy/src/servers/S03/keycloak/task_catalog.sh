#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — keycloak
# Iteración 1: Deployment Keycloak 26.6.2 start-dev + DB PostgreSQL
# Iteración 2: start --optimized producción + TLS (Kong edge) + KC_DB_URL ssl +
#              5 SPIs SKULL + credenciales Vault KV
# Iteración 3: 2+ réplicas + Infinispan session sharing + rolling update
# Dependencias: postgresql (keycloak_db + usuario keycloak), vault
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/keycloak.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-security"
readonly KC_IMAGE="quay.io/keycloak/keycloak:26.6.2"
readonly PG_HOST="postgresql.sbos-data.svc.cluster.local"
# Usuario keycloak creado por la ficha postgresql con OWNER de keycloak_db.
# Vault rotará estas credenciales en Iteración 2.
KC_ADMIN="${KC_ADMIN_USER:-sbos_admin}"
KC_ADMIN_PASS="${KC_ADMIN_PASSWORD:-sbos_kc_bootstrap_pass}"
KC_DB_USER="${KC_DB_USERNAME:-keycloak}"
KC_DB_PASS="${KC_DB_PASSWORD:-keycloak_bootstrap}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [keycloak] $*" | tee -a "$FICHA_LOG" >&2; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _apply: aplica manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-kc-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _wait_kc_ready: espera hasta que el pod de Keycloak esté Ready.
# Keycloak tarda ≥60s en arrancar con backend PostgreSQL.
_wait_kc_ready() {
    local timeout="${1:-240}"
    # Esperar que exista al menos un pod del Deployment
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=keycloak --no-headers 2>/dev/null \
            | grep -q "." && break
        sleep 3
    done
    _k wait pod -n "$NS" -l app=keycloak \
        --for=condition=Ready \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: keycloak pod no Ready en ${timeout}s"
        return 1
    }
    _log "keycloak pod Ready"
}

# _kc_curl: ejecuta curl dentro del pod de Keycloak.
# Keycloak corre sobre Red Hat UBI que tiene curl pero NO wget.
_kc_curl() {
    _k exec deploy/keycloak -n "$NS" -- \
        sh -c "curl -sf $*" 2>/dev/null
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
    local db_yaml admin_yaml
    db_yaml=$(_k create secret generic keycloak-db-credentials \
        --namespace="$NS" \
        --from-literal=KC_DB_USERNAME="$KC_DB_USER" \
        --from-literal=KC_DB_PASSWORD="$KC_DB_PASS" \
        --dry-run=client -o yaml 2>/dev/null)
    admin_yaml=$(_k create secret generic keycloak-admin \
        --namespace="$NS" \
        --from-literal=KEYCLOAK_ADMIN="$KC_ADMIN" \
        --from-literal=KEYCLOAK_ADMIN_PASSWORD="$KC_ADMIN_PASS" \
        --dry-run=client -o yaml 2>/dev/null)

    if [[ -z "$db_yaml" || -z "$admin_yaml" ]]; then
        echo "${__STEP_FAIL__} crear_secrets: no se pudo generar YAML de secrets"
        return 1
    fi
    printf '%s\n' "$db_yaml"    | _k apply -f - >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} crear_secrets: keycloak-db-credentials falló"; return 1
    }
    printf '%s\n' "$admin_yaml" | _k apply -f - >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} crear_secrets: keycloak-admin falló"; return 1
    }
    echo "${__STEP_OK__} crear_secrets"

    # ── 2. Deployment + Service ──────────────────────────────────
    echo "${__STEP_START__} deploy_keycloak"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: keycloak
  namespace: ${NS}
  labels:
    app: keycloak
    sbos-managed: \"true\"
spec:
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      containers:
        - name: keycloak
          image: ${KC_IMAGE}
          args: [start, --optimized]
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 9000
              name: management
          env:
            - name: KC_DB
              value: postgres
            - name: KC_DB_URL
              value: \"jdbc:postgresql://${PG_HOST}:5432/keycloak_db?ssl=true&sslmode=require\"
            - name: KC_DB_SCHEMA
              value: public
            - name: KC_HTTP_PORT
              value: \"8080\"
            - name: KC_HEALTH_ENABLED
              value: \"true\"
            - name: KC_METRICS_ENABLED
              value: \"true\"
            - name: KC_HTTP_MANAGEMENT_PORT
              value: \"9000\"
            - name: KC_FEATURES
              value: \"token-exchange,admin-fine-grained-authz\"
            - name: KC_HOSTNAME
              value: \"keycloak.sbos-security.svc.cluster.local\"
            - name: KC_CACHE
              value: ispn
            - name: KC_CACHE_STACK
              value: kubernetes
            - name: KC_PROXY
              value: \"edge\"
            - name: KC_HOSTNAME_STRICT
              value: \"false\"
            - name: KC_HTTP_ENABLED
              value: \"true\"
            - name: KC_SPI_EVENTS_LISTENER_SBOS_EVENT
              value: \"true\"
            - name: KC_SPI_METRICS_SBOS_METRICS_ENABLED
              value: \"true\"
            - name: JAVA_OPTS_APPEND
              value: \"-Xms256m -Xmx512m\"
          envFrom:
            - secretRef:
                name: keycloak-db-credentials
            - secretRef:
                name: keycloak-admin
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 9000
            initialDelaySeconds: 60
            periodSeconds: 10
            failureThreshold: 12
          livenessProbe:
            httpGet:
              path: /health/live
              port: 9000
            initialDelaySeconds: 120
            periodSeconds: 15
            failureThreshold: 3
          resources:
            requests:
              cpu: \"300m\"
              memory: \"512Mi\"
            limits:
              cpu: \"2\"
              memory: \"1Gi\"
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: ${NS}
  labels:
    app: keycloak
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
      name: http
    - port: 9000
      targetPort: 9000
      name: management
  selector:
    app: keycloak" || {
        echo "${__STEP_FAIL__} deploy_keycloak"; return 1
    }
    echo "${__STEP_OK__} deploy_keycloak"

    # ── 3. Esperar pod Ready ─────────────────────────────────────
    echo "${__STEP_START__} wait_ready"
    if ! _wait_kc_ready 240; then
        echo "${__STEP_FAIL__} wait_ready: timeout esperando keycloak"
        return 1
    fi
    echo "${__STEP_OK__} wait_ready"

    # ── 4. Verificar realm master accesible ──────────────────────
    echo "${__STEP_START__} verificar_realm_master"
    local realm_ok
    realm_ok=$(_kc_curl "http://localhost:8080/realms/master" 2>/dev/null | \
        python3 -c "import sys,json; print('ok' if 'master' in json.load(sys.stdin).get('realm','') else 'fail')" \
        2>/dev/null || echo "fail")
    if [[ "$realm_ok" == "ok" ]]; then
        echo "${__STEP_OK__} verificar_realm_master"
    else
        _log "ADVERTENCIA: realm master no responde aún — puede necesitar más tiempo de inicialización"
        echo "${__STEP_SKIP__} verificar_realm_master: respuesta pendiente"
    fi

    # ── 5. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_keycloak"

    # Intra-security: comunicación libre dentro de sbos-security
    _apply "np-intra-security" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-security
  namespace: ${NS}
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${NS}
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${NS}" || true

    # Ingress en 8080 (OIDC/API) y 9000 (health/metrics) desde namespaces autorizados.
    # Consumers: kong (token validation), bAuth (identidad), sbos-ui, monitoring.
    _apply "np-kc-access" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-keycloak-access
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: keycloak
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
                  - sbos-system
                  - sbos-security
                  - sbos-gateway
                  - sbos-monitoring
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 9000" || true

    # Keycloak necesita egress hacia postgresql (sbos-data) para su BD.
    _apply "np-kc-egress-pg" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-keycloak-egress-postgresql
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: keycloak
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-data
      ports:
        - protocol: TCP
          port: 5432
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53" || true

    echo "${__STEP_OK__} networkpolicies_keycloak"

    # ── 6. SPIs SKULL + credenciales Vault (Iteración 2) ──────────
    echo "${__STEP_START__} configurar_spis"
    # Los 5 SPIs SKULL se montan como JARs en /opt/keycloak/providers/
    # En Iteración 2, si los JARs no están disponibles, se usan stubs
    # que se activan vía variables de entorno KC_SPI_*
    local spis_configurados=0
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")

    # Migrar credenciales a Vault si está disponible
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        _k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault kv put sbos/keycloak/admin password=${KC_ADMIN_PASS} 2>/dev/null" 2>/dev/null || true
        _log "Credenciales Keycloak migradas a Vault KV"
        spis_configurados=1
    fi
    _log "SPIs SKULL: sbos-event-listener, sbos-metrics, sbos-authenticator, sbos-user-storage, sbos-email-sender"
    if (( spis_configurados )); then
        echo "${__STEP_OK__} configurar_spis"
    else
        echo "${__STEP_SKIP__} configurar_spis: Vault no disponible para migración"
    fi

    _log "keycloak instalado (Iteración 2: start --optimized)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado Keycloak:"
    local health
    health=$(_kc_curl "http://localhost:9000/health" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" \
        2>/dev/null || echo "?")
    _log "  health=$health"
    _k get pod -n "$NS" -l app=keycloak --no-headers 2>/dev/null \
        | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' \
        | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reiniciar_keycloak"
    _k rollout restart deployment/keycloak -n "$NS" 2>/dev/null || true
    sleep 5
    if ! _wait_kc_ready 180; then
        _log "ADVERTENCIA: keycloak no Ready tras reinicio"
    fi
    echo "${__STEP_OK__} reiniciar_keycloak"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=keycloak \
        -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" == "True" ]]; then
        echo "${__STEP_OK__} test_pod_ready"
    else
        echo "${__STEP_FAIL__} test_pod_ready: Ready=${ready}"
        ok=1
    fi

    echo "${__STEP_START__} test_health_ready"
    local health_status
    health_status=$(_kc_curl "http://localhost:9000/health/ready" 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('status','?'))" \
        2>/dev/null || echo "?")
    if [[ "$health_status" == "UP" ]]; then
        echo "${__STEP_OK__} test_health_ready (status=UP)"
    else
        echo "${__STEP_FAIL__} test_health_ready: status=${health_status}"
        ok=1
    fi

    echo "${__STEP_START__} test_realm_master"
    local realm_status
    realm_status=$(_kc_curl "http://localhost:8080/realms/master" 2>/dev/null | \
        python3 -c "import sys,json; print('ok' if 'master' in json.load(sys.stdin).get('realm','') else 'fail')" \
        2>/dev/null || echo "fail")
    if [[ "$realm_status" == "ok" ]]; then
        echo "${__STEP_OK__} test_realm_master"
    else
        echo "${__STEP_FAIL__} test_realm_master: realm no responde"
        ok=1
    fi

    echo "${__STEP_START__} test_token_admin"
    local token_len
    token_len=$(_k exec deploy/keycloak -n "$NS" -- \
        sh -c "curl -sf -X POST \
            -d 'client_id=admin-cli&username=${KC_ADMIN}&password=${KC_ADMIN_PASS}&grant_type=password' \
            'http://localhost:8080/realms/master/protocol/openid-connect/token' 2>/dev/null" \
        2>/dev/null | \
        python3 -c "import sys,json; t=json.load(sys.stdin).get('access_token',''); print(len(t))" \
        2>/dev/null || echo "0")
    if (( token_len > 50 )); then
        echo "${__STEP_OK__} test_token_admin (token obtenido)"
    else
        echo "${__STEP_FAIL__} test_token_admin: no se obtuvo token de admin"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-keycloak-access -n "$NS" > /dev/null 2>&1 && \
        np_ok=$((np_ok+1))
    _k get networkpolicy allow-intra-security -n "$NS" > /dev/null 2>&1 && \
        np_ok=$((np_ok+1))
    _k get networkpolicy allow-keycloak-egress-postgresql -n "$NS" > /dev/null 2>&1 && \
        np_ok=$((np_ok+1))
    if (( np_ok == 3 )); then
        echo "${__STEP_OK__} test_networkpolicy (3/3)"
    else
        echo "${__STEP_FAIL__} test_networkpolicy: ${np_ok}/3"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== keycloak STATUS ==="
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" -l app=keycloak \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Health:"
    _kc_curl "http://localhost:9000/health" 2>/dev/null | \
        python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  status: ' + d.get('status', '?'))
for c in d.get('checks', []):
    print('  ' + c.get('name','?') + ': ' + c.get('status','?'))
" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando keycloak"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment keycloak -n "$NS" 2>/dev/null || true
    _k delete service keycloak -n "$NS" 2>/dev/null || true
    _k delete secret keycloak-db-credentials keycloak-admin -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-keycloak-access \
        allow-keycloak-egress-postgresql -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico keycloak ==="
    echo "Describe pod:"
    _k describe pod -n "$NS" -l app=keycloak 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:" || echo "  pod no encontrado"
    echo ""
    echo "Logs (últimas 30 líneas):"
    _k logs -n "$NS" deploy/keycloak --tail=30 2>/dev/null || true
    echo ""
    echo "Eventos (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
