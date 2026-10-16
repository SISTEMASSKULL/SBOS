#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — postfixadmin
# Imagen: postfixadmin/postfixadmin:3.3.15
# Namespace: sbos-comms
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/postfixadmin.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-comms"
DOMAIN="${BOS_DOMAIN:-empresa.com}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [postfixadmin] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_ready() {
    local t="${1:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment postfixadmin -n "$NS" \
            -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5))
        (( e % 30 == 0 )) && _log "Esperando postfixadmin Ready... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
        _log "Namespace $NS creado"
    }
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    local r
    r=$(_k get deployment postfixadmin -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_SKIP__} postfixadmin_install: ya Ready — skip"
        return 0
    fi

    echo "${__STEP_START__} aplicar_manifest_postfixadmin"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'K8SEOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postfixadmin
  namespace: sbos-comms
  labels:
    app: postfixadmin
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postfixadmin
  template:
    metadata:
      labels:
        app: postfixadmin
    spec:
      containers:
        - name: postfixadmin
          image: hardware/postfixadmin:latest
          ports:
            - containerPort: 80
          env:
            - name: DBTYPE
              value: "pgsql"
            - name: DBHOST
              value: "postgresql.sbos-data.svc.cluster.local"
            - name: DBPORT
              value: "5432"
            - name: DBUSER
              value: "postgres"
            - name: DBPASS
              value: "sbos_bootstrap_pass"
            - name: DBNAME
              value: "postfixadmin_db"
            - name: ADMIN_PASSWD
              value: "sbos_postfixadmin_setup_pass"
          resources:
            requests:
              cpu: "100m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
K8SEOF
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'SVCINNER'
apiVersion: v1
kind: Service
metadata:
  name: postfixadmin
  namespace: sbos-comms
spec:
  selector:
    app: postfixadmin
  ports:
    - port: 80
      targetPort: 80
SVCINNER
    echo "${__STEP_OK__} aplicar_manifest_postfixadmin"

    echo "${__STEP_START__} registrar_ingress_postfixadmin"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: postfixadmin-ingress
  namespace: ${NS}
  annotations:
    konghq.com/strip-path: "false"
    konghq.com/protocols: "https"
spec:
  ingressClassName: kong
  rules:
    - host: "mail.${DOMAIN}"
      http:
        paths:
          - path: /postfixadmin
            pathType: Prefix
            backend:
              service:
                name: postfixadmin
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postfixadmin-ingress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: postfixadmin
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
      ports:
        - port: 80
EOF
    echo "${__STEP_OK__} registrar_ingress_postfixadmin"

    echo "${__STEP_START__} esperar_postfixadmin_ready"
    _wait_ready 180 || { echo "${__STEP_FAIL__} esperar_postfixadmin_ready: timeout 180s"; return 1; }
    echo "${__STEP_OK__} esperar_postfixadmin_ready"
    return 0
}

ficha_verify() {
    echo "${__STEP_START__} verificar_postfixadmin"
    local r
    r=$(_k get deployment postfixadmin -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) || { echo "${__STEP_FAIL__} verificar_postfixadmin: ${r}/1"; return 1; }
    echo "${__STEP_OK__} verificar_postfixadmin (${r}/1)"
    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment postfixadmin -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: postfixadmin ${r}/1"
    return 1
}

ficha_post_install() {
    local kc_ns="sbos-security"
    local secret_name="sbos-postfixadmin-oidc"
    local realm="${TENANT_ID:-${BOS_ORG_SHORT:-tenant}}"

    echo "${__STEP_START__} configurar_oidc_postfixadmin"
    if ! _k get secret -n "$kc_ns" "$secret_name" &>/dev/null; then
        echo "${__STEP_SKIP__} configurar_oidc_postfixadmin: secret $secret_name no disponible"
        return 0
    fi
    local client_id client_secret issuer
    client_id=$(_k get secret -n "$kc_ns" "$secret_name" -o jsonpath='{.data.client_id}' 2>/dev/null | base64 -d || echo "")
    client_secret=$(_k get secret -n "$kc_ns" "$secret_name" -o jsonpath='{.data.client_secret}' 2>/dev/null | base64 -d || echo "")
    issuer=$(_k get secret -n "$kc_ns" "$secret_name" -o jsonpath='{.data.issuer}' 2>/dev/null | base64 -d || echo "")
    if [[ -z "$client_id" || -z "$client_secret" ]]; then
        echo "${__STEP_SKIP__} configurar_oidc_postfixadmin: credenciales no disponibles"
        return 0
    fi
    # Verificar idempotencia: env var ya seteada
    local cur
    cur=$(_k get deployment postfixadmin -n "$NS" \
        -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="OIDC_CLIENT_ID")].value}' 2>/dev/null || echo "")
    if [[ "$cur" == "$client_id" ]]; then
        echo "${__STEP_SKIP__} configurar_oidc_postfixadmin: ya configurado"
        return 0
    fi
    _k patch deployment postfixadmin -n "$NS" --type=json -p="[
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"OIDC_ENABLED\",\"value\":\"true\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"OIDC_CLIENT_ID\",\"value\":\"${client_id}\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"OIDC_CLIENT_SECRET\",\"value\":\"${client_secret}\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"OIDC_DISCOVERY_URL\",\"value\":\"${issuer}/.well-known/openid-configuration\"}}
    ]" >> "$FICHA_LOG" 2>&1 && \
        _log "  OIDC Keycloak configurado en postfixadmin" || \
        _log "  ADVERTENCIA: no se pudo configurar OIDC en postfixadmin"
    echo "${__STEP_OK__} configurar_oidc_postfixadmin"
    return 0
}

ficha_repair() {
    _log "ficha_repair: re-aplicando manifests postfixadmin (kubectl apply idempotente)"
    ficha_install
    ficha_post_install 2>/dev/null || true
}

ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_pod_running"
    local r
    r=$(_k get deployment postfixadmin -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( r >= 1 )); then
        echo "${__STEP_OK__} test_pod_running (${r}/1)"
    else
        echo "${__STEP_FAIL__} test_pod_running: ${r}/1"
        ok=1
    fi

    echo "${__STEP_START__} test_http_responde"
    local clusterip
    clusterip=$(_k get service postfixadmin -n "$NS" \
        -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [[ -n "$clusterip" ]]; then
        local code
        code=$(curl -sk --max-time 5 -o /dev/null -w "%{http_code}" "http://${clusterip}/postfixadmin/" 2>/dev/null || echo "000")
        if [[ "$code" == "200" || "$code" == "302" ]]; then
            echo "${__STEP_OK__} test_http_responde (HTTP ${code})"
        else
            echo "${__STEP_FAIL__} test_http_responde: HTTP ${code}"
            ok=1
        fi
    else
        echo "${__STEP_FAIL__} test_http_responde: ClusterIP no encontrada"
        ok=1
    fi
    return $ok
}

ficha_remove() {
    echo "${__STEP_START__} eliminar_postfixadmin"
    _k delete deployment postfixadmin -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete service postfixadmin -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_postfixadmin"
    return 0
}
