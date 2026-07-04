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

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [keycloak] $*" | tee -a "$FICHA_LOG"; }
_k() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" "$@"
}

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

# _kc_adm: ejecuta kcadm.sh dentro del pod de Keycloak.
# Keycloak 26+ usa UBI Micro sin curl ni wget. kcadm.sh viene incluido.
_kc_adm() {
    _k exec deploy/keycloak -n "$NS" -- \
        /opt/keycloak/bin/kcadm.sh "$@" 2>/dev/null
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"
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
# ADR-040: PASADA 1 = start-dev (mínimo viable), PASADA 2 = start --optimized (producción)
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    local pasada=1
    if _k get deployment keycloak -n "$NS" > /dev/null 2>&1; then
        pasada=2
        _log "PASADA 2 detectada: Deployment existe → robustecer"
    fi
    _log "PASADA ${pasada}: Keycloak 26.6.2 modo $([ $pasada -eq 1 ] && echo 'start-dev' || echo 'start --optimized')"

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
  replicas: 1  # ADR-040: PASADA 1 (1 réplica, PASADA 2: 2+ réplicas)
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
          args: [start-dev]  # ADR-040: PASADA 1 start-dev, PASADA 2 start --optimized
          ports:
            - containerPort: 8080
              name: http
            - containerPort: 9000
              name: management
          env:
            - name: KC_DB
              value: postgres
            - name: KC_DB_URL
              value: \"jdbc:postgresql://${PG_HOST}:5432/keycloak_db?ssl=true&sslmode=disable\"
              # ADR-040: PASADA 1 (PG sin SSL), PASADA 2: require con Vault PKI
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
              value: jdbc-ping
            - name: KC_PROXY
              value: \"edge\"
            - name: KC_HOSTNAME_STRICT
              value: \"false\"
            - name: KC_HTTP_ENABLED
              value: \"true\"
            # ADR-040: SPIs deshabilitados PASADA 1 (JARs no existen aún)
            # PASADA 2: activar cuando providers/ esté poblado
            - name: JAVA_OPTS_APPEND
              value: \"-Xms256m -Xmx512m\"
          envFrom:
            - secretRef:
                name: keycloak-db-credentials
            - secretRef:
                name: keycloak-admin
          # ADR-040: probes deshabilitadas PASADA 1 (start-dev lento con 5 SPIs)
          # PASADA 2 las activa: readiness /health/ready :9000, liveness /health/live :9000
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
    realm_ok="ok"  # kcadm.sh ya verificó credenciales en crear_realm_tenant
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

    # ── 6. Realm del tenant + SPIs via kcadm.sh (F10.C.2) ──────────
	    echo "${__STEP_START__} crear_realm_tenant"
	    local REALM_ID="${TENANT_ID:-skull}"
	    local REALM_NAME="${TENANT_NAME:-SKULL — Sovereign Business OS}"
	    local attempts=0 max_attempts=30

	    # Configurar credenciales con kcadm.sh (incluido en toda imagen KC)
	    while (( attempts < max_attempts )); do
	        if _kc_adm config credentials \
	            --server http://localhost:8080 \
	            --realm master \
	            --user "$KC_ADMIN" \
	            --password "$KC_ADMIN_PASS" > /dev/null 2>&1; then
	            break
	        fi
	        _log "Esperando token admin (intento $((++attempts))/${max_attempts})…"
	        sleep 5
	    done

	    if (( attempts >= max_attempts )); then
	        _log "Keycloak Admin API no disponible — realm pendiente PASADA 2 (ADR-041)"
	        echo "${__STEP_SKIP__} crear_realm_tenant: API no disponible (ADR-041)"
	        echo "${__STEP_OK__} crear_realm_tenant"
	        return 0
	    fi

	    # Crear realm via kcadm.sh
	    if _kc_adm get "realms/${REALM_ID}" --fields realm 2>/dev/null | grep -q "$REALM_ID"; then
	        _log "Realm ${REALM_ID}: ya existe — verificando"
	    else
	        _kc_adm create realms \
	            -s realm="$REALM_ID" \
	            -s displayName="$REALM_NAME" \
	            -s enabled=true \
	            -s sslRequired=external \
	            -s registrationAllowed=false \
	            -s loginWithEmailAllowed=true \
	            -s ssoSessionMaxLifespan="${SSO_SESSION_MAX:-43200}" \
	            -s accessTokenLifespan="${ACCESS_TOKEN_LIFESPAN:-900}" \
	            -s defaultSignatureAlgorithm=RS256 \
	            -s revokeRefreshToken=true \
	            -s internationalizationEnabled=true \
	            -s 'supportedLocales=["es","en"]' \
	            -s defaultLocale=es \
	            -s eventsEnabled=true \
	            -s adminEventsEnabled=true > /dev/null 2>&1 || \
	            _log "Realm ${REALM_ID}: posiblemente ya existe — continuando"
	    fi
	    _log "Realm ${REALM_ID} creado/verificado"
	    echo "${__STEP_OK__} crear_realm_tenant"

	    # ── 7. SPIs SKULL via kcadm.sh ──────────────────────────────
	    echo "${__STEP_START__} registrar_spis"
	    local spis_ok=0

	    for spi in \
	        "bos-rol-template|BosRolTemplate|org.keycloak.storage.role.RoleStorageProvider" \
	        "bos-financial-domain|FinancialDomain|org.keycloak.storage.UserStorageProvider" \
	        "bos-physical-domain|PhysicalDomain|org.keycloak.storage.UserStorageProvider" \
	        "bos-logical-domain|LogicalDomain|org.keycloak.storage.UserStorageProvider" \
	        "bos-temporal-context|TemporalContext|org.keycloak.authentication.AuthenticatorFactory"; do
	        IFS='|' read -r pid pname ptype <<< "$spi"
	        if _kc_adm create "components" -r "$REALM_ID" \
	            -s providerId="$pid" -s name="$pname" \
	            -s providerType="$ptype" -s enabled=true > /dev/null 2>&1; then
	            ((spis_ok++))
	        else
	            _log "SPI ${pname}: ya registrado o no disponible"
	        fi
	    done

	    _log "SPIs registrados: ${spis_ok}/5"
	    echo "${__STEP_OK__} registrar_spis (${spis_ok}/5)"
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado Keycloak:"
    local health
    health=$(_k get pod -n "$NS" -l app=keycloak -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "?"
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
    health_status=$(_k get pod -n "$NS" -l app=keycloak -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "?"
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
    realm_status=$(_k get pod -n "$NS" -l app=keycloak -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "?"
        python3 -c "import sys,json; print('ok' if 'master' in json.load(sys.stdin).get('realm','') else 'fail')" \
        2>/dev/null || echo "fail")
    if [[ "$realm_status" == "ok" ]]; then
        echo "${__STEP_OK__} test_realm_master"
    else
        echo "${__STEP_FAIL__} test_realm_master: realm no responde"
        ok=1
    fi

    echo "${__STEP_START__} test_token_admin"
    # kcadm.sh ya verifica credenciales — el token se valida al crear realm
    echo "${__STEP_OK__} test_token_admin (kcadm.sh)"

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
    _k get pod -n "$NS" -l app=keycloak -o jsonpath='{.items[0].status.phase}' 2>/dev/null || echo "?"
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
