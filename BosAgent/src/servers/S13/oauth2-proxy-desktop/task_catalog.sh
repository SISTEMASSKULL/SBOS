#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — oauth2-proxy-desktop (S13/sbos-vdi)
# SSO para Fedora KDE Desktop via Keycloak realm skull.
# Flujo: nginx /desktop/ → oauth2-proxy:4180 → fedora-kde:80
# Dependencias: keycloak (sbos-security), fedora-kde (sbos-vdi)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/oauth2-proxy-desktop.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"

readonly NS="sbos-vdi"
readonly NS_KC="sbos-security"
readonly OAUTH2_IMAGE="quay.io/oauth2-proxy/oauth2-proxy:v7.8.0"
readonly KC_HOST="http://keycloak.${NS_KC}.svc.cluster.local:8080"
readonly DESKTOP_SVC="http://fedora-kde.${NS}.svc.cluster.local:80"
readonly CLIENT_ID="${DESKTOP_CLIENT_ID:-sbos-desktop}"
readonly KC_REALM="${KC_REALM:-skull}"
readonly PUBLIC_URL="${SBOS_PUBLIC_URL:-https://13.140.128.230}"
readonly REDIRECT_URL="${PUBLIC_URL}/desktop/oauth2/callback"
readonly KC_INTERNAL_URL="http://keycloak.${NS_KC}.svc.cluster.local:8080"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [oauth2-proxy-desktop] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }
_kexec() { _k exec -n "$NS_KC" deploy/keycloak -- "$@"; }

# _kc_admin: ejecuta kcadm.sh dentro del pod keycloak.
_kc_admin() {
    local KC_ADMIN_USER KC_ADMIN_PASS
    KC_ADMIN_USER=$(_k get secret -n "$NS_KC" keycloak-admin \
        -o jsonpath='{.data.KEYCLOAK_ADMIN}' 2>/dev/null | base64 -d)
    KC_ADMIN_PASS=$(_k get secret -n "$NS_KC" keycloak-admin \
        -o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' 2>/dev/null | base64 -d)

    _kexec /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 --realm master \
        --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASS" \
        2>/dev/null

    _kexec /opt/keycloak/bin/kcadm.sh "$@"
}

# _crear_cliente_keycloak: crea o verifica el cliente OIDC sbos-desktop en realm skull.
# Exporta KC_CLIENT_SECRET con el secret del cliente.
KC_CLIENT_SECRET=""
_crear_cliente_keycloak() {
    local KC_ADMIN_USER KC_ADMIN_PASS client_uuid

    KC_ADMIN_USER=$(_k get secret -n "$NS_KC" keycloak-admin \
        -o jsonpath='{.data.KEYCLOAK_ADMIN}' 2>/dev/null | base64 -d)
    KC_ADMIN_PASS=$(_k get secret -n "$NS_KC" keycloak-admin \
        -o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' 2>/dev/null | base64 -d)

    # Login admin (escribe config en el pod, no localmente)
    _kexec /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 --realm master \
        --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASS" \
        >> "$FICHA_LOG" 2>&1

    # Buscar cliente existente
    client_uuid=$(_kexec /opt/keycloak/bin/kcadm.sh get clients \
        -r "$KC_REALM" --fields clientId,id 2>/dev/null | \
        python3 -c "
import sys, json
d = json.load(sys.stdin)
for c in d:
    if c.get('clientId') == '${CLIENT_ID}':
        print(c['id'])
        break
" 2>/dev/null || true)

    if [[ -z "$client_uuid" ]]; then
        _log "Creando cliente OIDC '${CLIENT_ID}' en realm '${KC_REALM}'..."
        _kexec /opt/keycloak/bin/kcadm.sh create clients -r "$KC_REALM" \
            -s "clientId=${CLIENT_ID}" \
            -s enabled=true \
            -s publicClient=false \
            -s standardFlowEnabled=true \
            -s serviceAccountsEnabled=false \
            -s "redirectUris=[\"${REDIRECT_URL}\"]" \
            -s "webOrigins=[\"${PUBLIC_URL}\"]" \
            -s 'attributes={"access.token.lifespan":"3600"}' \
            >> "$FICHA_LOG" 2>&1

        client_uuid=$(_kexec /opt/keycloak/bin/kcadm.sh get clients \
            -r "$KC_REALM" --fields clientId,id 2>/dev/null | \
            python3 -c "
import sys, json
d = json.load(sys.stdin)
for c in d:
    if c.get('clientId') == '${CLIENT_ID}':
        print(c['id'])
        break
" 2>/dev/null)
        _log "Cliente creado uuid=${client_uuid}"
    else
        _log "Cliente '${CLIENT_ID}' ya existe uuid=${client_uuid}"
        # Actualizar redirect URI por si cambió la IP pública
        _kexec /opt/keycloak/bin/kcadm.sh update clients/"$client_uuid" \
            -r "$KC_REALM" \
            -s "redirectUris=[\"${REDIRECT_URL}\"]" \
            -s "webOrigins=[\"${PUBLIC_URL}\"]" \
            >> "$FICHA_LOG" 2>&1
    fi

    # Obtener o regenerar client_secret
    KC_CLIENT_SECRET=$(_kexec /opt/keycloak/bin/kcadm.sh get \
        clients/"$client_uuid"/client-secret -r "$KC_REALM" 2>/dev/null | \
        python3 -c "import sys,json; d=json.load(sys.stdin); print(d['value'])" 2>/dev/null || true)

    if [[ -z "$KC_CLIENT_SECRET" || "$KC_CLIENT_SECRET" == "null" ]]; then
        _kexec /opt/keycloak/bin/kcadm.sh create \
            clients/"$client_uuid"/client-secret -r "$KC_REALM" \
            >> "$FICHA_LOG" 2>&1
        KC_CLIENT_SECRET=$(_kexec /opt/keycloak/bin/kcadm.sh get \
            clients/"$client_uuid"/client-secret -r "$KC_REALM" 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(d['value'])" 2>/dev/null)
    fi

    _log "client_secret obtenido (${#KC_CLIENT_SECRET} chars)"
}

# _apply: aplica YAML desde variable (crea tmp, apply, limpia).
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-oauth2d-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _cookie_secret: genera secreto de 32 bytes base64 para oauth2-proxy.
_cookie_secret() {
    python3 -c "import secrets,base64,sys; sys.stdout.write(base64.urlsafe_b64encode(secrets.token_bytes(32)).decode())" 2>/dev/null || \
        printf 'c2Jvc19kZXNrdG9wX2Nvb2tpZV9zZWNyZXRfMzJiX3BhZA=='
}

# ── Pre-install ───────────────────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_keycloak"
    if ! _k get pod -n "$NS_KC" -l app=keycloak --no-headers 2>/dev/null | grep -q "Running"; then
        echo "${__STEP_FAIL__} verificar_keycloak: pod keycloak no Running en ${NS_KC}"
        return 1
    fi
    echo "${__STEP_OK__} verificar_keycloak"

    echo "${__STEP_START__} verificar_fedora_kde"
    if ! _k get svc -n "$NS" fedora-kde --no-headers 2>/dev/null | grep -q "."; then
        echo "${__STEP_FAIL__} verificar_fedora_kde: svc fedora-kde no existe en ${NS}"
        return 1
    fi
    echo "${__STEP_OK__} verificar_fedora_kde"
}

# ── Install ───────────────────────────────────────────────────────────────────
ficha_install() {
    # ── 0. Configurar realm skull para HTTP + redirects públicos ─────────────
    # sslRequired=none: KC acepta HTTP (no TLS entre pods)
    # frontendUrl: browser recibe URLs públicas en los redirects OIDC
    echo "${__STEP_START__} configurar_realm_skull"
    _kexec /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 --realm master \
        --user "$(kubectl --kubeconfig="$KUBECONFIG_DEST" get secret -n "$NS_KC" keycloak-admin \
            -o jsonpath='{.data.KEYCLOAK_ADMIN}' 2>/dev/null | base64 -d)" \
        --password "$(kubectl --kubeconfig="$KUBECONFIG_DEST" get secret -n "$NS_KC" keycloak-admin \
            -o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' 2>/dev/null | base64 -d)" \
        >> "$FICHA_LOG" 2>&1
    _kexec /opt/keycloak/bin/kcadm.sh update "realms/${KC_REALM}" \
        -s sslRequired=none \
        -s "attributes.frontendUrl=${PUBLIC_URL}" \
        >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} configurar_realm_skull"

    # ── 1. Crear cliente OIDC en Keycloak ────────────────────────────────────
    echo "${__STEP_START__} crear_cliente_keycloak"
    _crear_cliente_keycloak || {
        echo "${__STEP_FAIL__} crear_cliente_keycloak"
        return 1
    }
    echo "${__STEP_OK__} crear_cliente_keycloak (client_id=${CLIENT_ID})"

    # ── 1b. Audience mapper + emailVerified para usuario admin ───────────────
    # El Audience mapper agrega client_id al aud del id_token (oauth2-proxy lo verifica)
    # emailVerified=true es requerido por oauth2-proxy para aceptar el token
    echo "${__STEP_START__} configurar_kc_audience_y_usuario"
    local client_uuid
    client_uuid=$(_kexec /opt/keycloak/bin/kcadm.sh get clients \
        -r "$KC_REALM" --fields clientId,id 2>/dev/null | \
        python3 -c "
import sys, json
d = json.load(sys.stdin)
for c in d:
    if c.get('clientId') == '${CLIENT_ID}':
        print(c['id'])
        break
" 2>/dev/null || true)

    if [[ -n "$client_uuid" ]]; then
        # Verificar si el mapper ya existe
        local mapper_exists
        mapper_exists=$(_kexec /opt/keycloak/bin/kcadm.sh get \
            clients/"$client_uuid"/protocol-mappers/models \
            -r "$KC_REALM" --fields name 2>/dev/null | \
            grep -c 'audience-sbos-desktop' 2>/dev/null || echo "0")
        if [[ "$mapper_exists" -eq 0 ]]; then
            _kexec sh -c "cat > /tmp/aud-mapper.json << 'ENDJSON'
{\"name\":\"audience-sbos-desktop\",\"protocol\":\"openid-connect\",\"protocolMapper\":\"oidc-audience-mapper\",\"config\":{\"included.client.audience\":\"${CLIENT_ID}\",\"access.token.claim\":\"true\",\"id.token.claim\":\"true\"}}
ENDJSON
/opt/keycloak/bin/kcadm.sh create clients/${client_uuid}/protocol-mappers/models -r ${KC_REALM} -f /tmp/aud-mapper.json" \
                >> "$FICHA_LOG" 2>&1 || true
        fi
    fi

    # Marcar emailVerified para usuarios existentes en el realm
    _kexec /opt/keycloak/bin/kcadm.sh get users -r "$KC_REALM" --fields id 2>/dev/null | \
        python3 -c "
import sys, json, subprocess
users = json.load(sys.stdin)
for u in users:
    uid = u['id']
    print(uid)
" 2>/dev/null | while read -r uid; do
        _kexec /opt/keycloak/bin/kcadm.sh update users/"$uid" \
            -r "$KC_REALM" -s emailVerified=true \
            >> "$FICHA_LOG" 2>&1 || true
    done
    echo "${__STEP_OK__} configurar_kc_audience_y_usuario"

    # ── 2. Secret con credenciales oauth2-proxy ───────────────────────────────
    echo "${__STEP_START__} crear_secret_oauth2"
    local cookie_secret
    # Preservar cookie_secret si ya existe (no rota las sesiones activas)
    cookie_secret=$(_k get secret -n "$NS" oauth2-proxy-desktop-secret \
        -o jsonpath='{.data.cookie-secret}' 2>/dev/null | base64 -d || \
        _cookie_secret)

    _apply "secret_oauth2" "
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-desktop-secret
  namespace: ${NS}
type: Opaque
stringData:
  client-id: \"${CLIENT_ID}\"
  client-secret: \"${KC_CLIENT_SECRET}\"
  cookie-secret: \"${cookie_secret}\"
"
    echo "${__STEP_OK__} crear_secret_oauth2"

    # ── 3. Deployment oauth2-proxy-desktop ───────────────────────────────────
    echo "${__STEP_START__} deployment_oauth2_proxy"
    # Usar ClusterIP directa del svc fedora-kde para evitar resolución DNS lenta
    local fedora_ip
    fedora_ip=$(_k get svc -n "$NS" fedora-kde -o jsonpath='{.spec.clusterIP}' 2>/dev/null || true)
    local upstream_url="http://${fedora_ip:-fedora-kde.${NS}.svc.cluster.local}:80"
    _apply "deployment_oauth2" "
apiVersion: apps/v1
kind: Deployment
metadata:
  name: oauth2-proxy-desktop
  namespace: ${NS}
  labels:
    app: oauth2-proxy-desktop
    sbos.io/ficha: oauth2-proxy-desktop
spec:
  replicas: 1
  selector:
    matchLabels:
      app: oauth2-proxy-desktop
  template:
    metadata:
      labels:
        app: oauth2-proxy-desktop
    spec:
      containers:
      - name: oauth2-proxy
        image: ${OAUTH2_IMAGE}
        args:
        - --provider=keycloak-oidc
        - --http-address=0.0.0.0:4180
        - --upstream=${upstream_url}
        - --oidc-issuer-url=${KC_INTERNAL_URL}/realms/${KC_REALM}
        - --redirect-url=${REDIRECT_URL}
        - --proxy-prefix=/desktop/oauth2
        - --cookie-path=/desktop
        - --cookie-name=_sbos_desktop
        - --cookie-secure=false
        - --email-domain=*
        - --skip-provider-button=true
        - --pass-access-token=true
        - --set-xauthrequest=true
        - --pass-user-headers=true
        - --reverse-proxy=true
        - --real-client-ip-header=X-Real-IP
        - --insecure-oidc-skip-issuer-verification=true
        - --ssl-insecure-skip-verify=true
        env:
        - name: OAUTH2_PROXY_CLIENT_ID
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-desktop-secret
              key: client-id
        - name: OAUTH2_PROXY_CLIENT_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-desktop-secret
              key: client-secret
        - name: OAUTH2_PROXY_COOKIE_SECRET
          valueFrom:
            secretKeyRef:
              name: oauth2-proxy-desktop-secret
              key: cookie-secret
        ports:
        - containerPort: 4180
          name: http
        readinessProbe:
          httpGet:
            path: /ping
            port: 4180
          initialDelaySeconds: 5
          periodSeconds: 10
          failureThreshold: 3
        livenessProbe:
          httpGet:
            path: /ping
            port: 4180
          initialDelaySeconds: 10
          periodSeconds: 30
        resources:
          requests:
            memory: \"64Mi\"
            cpu: \"50m\"
          limits:
            memory: \"256Mi\"
            cpu: \"200m\"
"
    echo "${__STEP_OK__} deployment_oauth2_proxy"

    # ── 4. Service oauth2-proxy-desktop ──────────────────────────────────────
    echo "${__STEP_START__} service_oauth2_proxy"
    _apply "service_oauth2" "
apiVersion: v1
kind: Service
metadata:
  name: oauth2-proxy-desktop
  namespace: ${NS}
  labels:
    app: oauth2-proxy-desktop
spec:
  selector:
    app: oauth2-proxy-desktop
  ports:
  - port: 4180
    targetPort: 4180
    protocol: TCP
    name: http
"
    echo "${__STEP_OK__} service_oauth2_proxy"

    # ── 5. NetworkPolicy ─────────────────────────────────────────────────────
    echo "${__STEP_START__} network_policy"
    # Ingress: nginx y cualquier cliente interno pueden llegar al proxy
    _apply "netpol_oauth2_ingress" "
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-oauth2-desktop-ingress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: oauth2-proxy-desktop
  policyTypes:
  - Ingress
  ingress:
  - {}
"
    # Egress: oauth2-proxy necesita llegar a Keycloak (sbos-security) y fedora-kde
    _apply "netpol_oauth2_egress" "
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-oauth2-desktop-egress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: oauth2-proxy-desktop
  policyTypes:
  - Egress
  egress:
  - {}
"
    # Ingress en sbos-security: permite que oauth2-proxy-desktop llegue a Keycloak
    # La NetworkPolicy default en sbos-security bloquea tráfico desde sbos-vdi
    _apply "netpol_keycloak_from_vdi" "
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-oauth2-desktop-to-keycloak
  namespace: ${NS_KC}
spec:
  podSelector:
    matchLabels:
      app: keycloak
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          kubernetes.io/metadata.name: ${NS}
      podSelector:
        matchLabels:
          app: oauth2-proxy-desktop
    ports:
    - port: 8080
      protocol: TCP
"
    # Ingress en fedora-kde: permite que oauth2-proxy llegue al pod (targetPort=6901)
    # NetworkPolicy aplica al puerto del POD, no al del Service (port:80→targetPort:6901)
    _apply "netpol_fedorakde_from_o2" "
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-oauth2-to-fedora-kde
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: fedora-kde
  policyTypes:
  - Ingress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: oauth2-proxy-desktop
    ports:
    - port: 6901
      protocol: TCP
"
    echo "${__STEP_OK__} network_policy"

    # ── 6. Esperar pod Ready ─────────────────────────────────────────────────
    echo "${__STEP_START__} esperar_pod_ready"
    local deadline=$(( $(date +%s) + 90 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=oauth2-proxy-desktop --no-headers 2>/dev/null \
            | grep -q "." && break
        sleep 3
    done
    _k wait pod -n "$NS" -l app=oauth2-proxy-desktop \
        --for=condition=Ready --timeout=90s >> "$FICHA_LOG" 2>&1 || {
        _log "TIMEOUT: pod oauth2-proxy-desktop no Ready"
        _k describe pod -n "$NS" -l app=oauth2-proxy-desktop >> "$FICHA_LOG" 2>&1 || true
        echo "${__STEP_FAIL__} esperar_pod_ready"
        return 1
    }
    echo "${__STEP_OK__} esperar_pod_ready"

    # ── 7. Verificar /ping ───────────────────────────────────────────────────
    echo "${__STEP_START__} verificar_ping"
    local cluster_ip
    cluster_ip=$(_k get svc -n "$NS" oauth2-proxy-desktop \
        -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' \
        "http://${cluster_ip}:4180/ping" --max-time 5 2>/dev/null || echo "000")
    if [[ "$http_code" == "200" ]]; then
        echo "${__STEP_OK__} verificar_ping (HTTP ${http_code})"
    else
        echo "${__STEP_FAIL__} verificar_ping: HTTP ${http_code} desde ${cluster_ip}:4180/ping"
        return 1
    fi
}

# ── Verify ────────────────────────────────────────────────────────────────────
ficha_verify() {
    echo "${__STEP_START__} verify_pod"
    _k get pod -n "$NS" -l app=oauth2-proxy-desktop --no-headers 2>/dev/null | \
        grep -q "Running" || {
        echo "${__STEP_FAIL__} verify_pod: no Running"
        return 1
    }
    echo "${__STEP_OK__} verify_pod"

    echo "${__STEP_START__} verify_ping"
    local cluster_ip
    cluster_ip=$(_k get svc -n "$NS" oauth2-proxy-desktop \
        -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
    local http_code
    http_code=$(curl -s -o /dev/null -w '%{http_code}' \
        "http://${cluster_ip}:4180/ping" --max-time 5 2>/dev/null || echo "000")
    [[ "$http_code" == "200" ]] && echo "${__STEP_OK__} verify_ping" || \
        { echo "${__STEP_FAIL__} verify_ping HTTP ${http_code}"; return 1; }
}

# ── Repair ────────────────────────────────────────────────────────────────────
ficha_repair() {
    # Re-aplicar configuración del realm (idempotente — sobrescribe si cambió)
    echo "${__STEP_START__} repair_realm_skull"
    _kexec /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 --realm master \
        --user "$(_k get secret -n "$NS_KC" keycloak-admin \
            -o jsonpath='{.data.KEYCLOAK_ADMIN}' 2>/dev/null | base64 -d)" \
        --password "$(_k get secret -n "$NS_KC" keycloak-admin \
            -o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' 2>/dev/null | base64 -d)" \
        >> "$FICHA_LOG" 2>&1
    _kexec /opt/keycloak/bin/kcadm.sh update "realms/${KC_REALM}" \
        -s sslRequired=none \
        -s "attributes.frontendUrl=${PUBLIC_URL}" \
        >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} repair_realm_skull"

    # Verificar si hay que re-crear el cliente Keycloak
    echo "${__STEP_START__} repair_verificar_cliente_keycloak"
    local KC_ADMIN_USER KC_ADMIN_PASS
    KC_ADMIN_USER=$(_k get secret -n "$NS_KC" keycloak-admin \
        -o jsonpath='{.data.KEYCLOAK_ADMIN}' 2>/dev/null | base64 -d)
    KC_ADMIN_PASS=$(_k get secret -n "$NS_KC" keycloak-admin \
        -o jsonpath='{.data.KEYCLOAK_ADMIN_PASSWORD}' 2>/dev/null | base64 -d)

    _kexec /opt/keycloak/bin/kcadm.sh config credentials \
        --server http://localhost:8080 --realm master \
        --user "$KC_ADMIN_USER" --password "$KC_ADMIN_PASS" >> "$FICHA_LOG" 2>&1

    local client_exists
    client_exists=$(_kexec /opt/keycloak/bin/kcadm.sh get clients \
        -r "$KC_REALM" --fields clientId 2>/dev/null | \
        grep -c "\"${CLIENT_ID}\"" 2>/dev/null || echo "0")

    if [[ "$client_exists" -eq 0 ]]; then
        _log "Cliente ${CLIENT_ID} no existe — re-creando"
        _crear_cliente_keycloak
        # Actualizar el secret con el nuevo client_secret
        local cookie_secret
        cookie_secret=$(_k get secret -n "$NS" oauth2-proxy-desktop-secret \
            -o jsonpath='{.data.cookie-secret}' 2>/dev/null | base64 -d || _cookie_secret)
        _apply "secret_oauth2_repair" "
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-desktop-secret
  namespace: ${NS}
type: Opaque
stringData:
  client-id: \"${CLIENT_ID}\"
  client-secret: \"${KC_CLIENT_SECRET}\"
  cookie-secret: \"${cookie_secret}\"
"
    fi
    echo "${__STEP_OK__} repair_verificar_cliente_keycloak"

    # Reiniciar deployment si pod no Ready
    echo "${__STEP_START__} repair_pod"
    if ! _k get pod -n "$NS" -l app=oauth2-proxy-desktop --no-headers 2>/dev/null | grep -q "Running"; then
        _k rollout restart deployment/oauth2-proxy-desktop -n "$NS" >> "$FICHA_LOG" 2>&1
        _k wait pod -n "$NS" -l app=oauth2-proxy-desktop \
            --for=condition=Ready --timeout=90s >> "$FICHA_LOG" 2>&1 || true
    fi
    echo "${__STEP_OK__} repair_pod"

    ficha_verify
}

# ── Remove ────────────────────────────────────────────────────────────────────
ficha_remove() {
    _log "Eliminando oauth2-proxy-desktop..."
    _k delete deployment,service,secret,networkpolicy \
        -n "$NS" -l app=oauth2-proxy-desktop --ignore-not-found=true \
        >> "$FICHA_LOG" 2>&1
    _k delete secret oauth2-proxy-desktop-secret -n "$NS" --ignore-not-found=true \
        >> "$FICHA_LOG" 2>&1
    _log "oauth2-proxy-desktop eliminado"
}

# ── Dispatcher ────────────────────────────────────────────────────────────────
case "${1:-install}" in
    pre_install)  ficha_pre_install ;;
    install)      ficha_pre_install && ficha_install ;;
    verify)       ficha_verify ;;
    repair)       ficha_repair ;;
    remove)       ficha_remove ;;
    *)            echo "Uso: $0 {pre_install|install|verify|repair|remove}"; exit 1 ;;
esac
