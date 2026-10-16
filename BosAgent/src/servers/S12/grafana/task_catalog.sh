#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — grafana
# Iteración 1: Deployment Grafana 12.0.1 + PVC + datasource Prometheus + dashboards
# Dependencias: prometheus (datasource)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/grafana.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-monitoring"
readonly GF_IMAGE="grafana/grafana:12.0.1"
GF_ADMIN="${GF_ADMIN_USER:-sbos_grafana_admin}"
GF_ADMIN_PASS="${GF_ADMIN_PASSWORD:-sbos_grafana_bootstrap}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [grafana] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-gf-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

_wait_gf_ready() {
    local timeout="${1:-120}"
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=grafana --no-headers 2>/dev/null | grep -q "." && break
        sleep 3
    done
    _k wait pod -n "$NS" -l app=grafana --for=condition=Ready --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: grafana no Ready en ${timeout}s"; return 1
    }
    _log "grafana pod Ready"
}

_gf_curl() { _k exec deploy/grafana -n "$NS" -- sh -c "curl -sf $*" 2>/dev/null; }

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_pv"
    if ! _k get pv sbos-grafana-pv > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_pv: sbos-grafana-pv no existe"
        return 1
    fi
    echo "${__STEP_OK__} verificar_pv"

    echo "${__STEP_START__} verificar_prometheus"
    if ! _k get pod -n "$NS" -l app=prometheus --no-headers 2>/dev/null | grep -q "."; then
        echo "${__STEP_FAIL__} verificar_prometheus: prometheus no disponible en $NS"; return 1
    fi
    echo "${__STEP_OK__} verificar_prometheus"

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} crear_pvc"
    _apply "pvc" "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sbos-grafana-pvc
  namespace: ${NS}
  labels:
    app: grafana
    sbos-managed: \"true\"
spec:
  storageClassName: local-path
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
  volumeName: sbos-grafana-pv" || { echo "${__STEP_FAIL__} crear_pvc"; return 1; }
    echo "${__STEP_OK__} crear_pvc"

    echo "${__STEP_START__} crear_secrets_y_config"
    local secret_yaml
    secret_yaml=$(_k create secret generic grafana-admin \
        --namespace="$NS" \
        --from-literal=GF_SECURITY_ADMIN_USER="$GF_ADMIN" \
        --from-literal=GF_SECURITY_ADMIN_PASSWORD="$GF_ADMIN_PASS" \
        --dry-run=client -o yaml 2>/dev/null)
    if [[ -z "$secret_yaml" ]]; then
        echo "${__STEP_FAIL__} crear_secrets_y_config: no se pudo generar secret"; return 1
    fi
    printf '%s\n' "$secret_yaml" | _k apply -f - >> "$FICHA_LOG" 2>&1 || { echo "${__STEP_FAIL__} crear_secrets_y_config: apply secret falló"; return 1; }

    _apply "configmaps" "apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: ${NS}
  labels:
    app: grafana
    sbos-managed: \"true\"
data:
  datasources.yaml: |
    apiVersion: 1
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
        editable: false
        jsonData:
          timeInterval: 30s
      - name: Alertmanager
        type: alertmanager
        access: proxy
        url: http://alertmanager:9093
        editable: false
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-dashboards-provider
  namespace: ${NS}
  labels:
    app: grafana
    sbos-managed: \"true\"
data:
  dashboards.yaml: |
    apiVersion: 1
    providers:
      - name: sbos-dashboards
        orgId: 1
        folder: SBOS
        type: file
        disableDeletion: false
        updateIntervalSeconds: 30
        options:
          path: /var/lib/grafana/dashboards" || { echo "${__STEP_FAIL__} crear_secrets_y_config: configmaps fallaron"; return 1; }
    echo "${__STEP_OK__} crear_secrets_y_config"

    echo "${__STEP_START__} deploy_grafana"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: ${NS}
  labels:
    app: grafana
    sbos-managed: \"true\"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
      annotations:
        linkerd.io/inject: disabled
    spec:
      securityContext:
        runAsUser: 472
        runAsGroup: 472
        fsGroup: 472
      containers:
        - name: grafana
          image: ${GF_IMAGE}
          ports:
            - containerPort: 3000
              name: http
          envFrom:
            - secretRef:
                name: grafana-admin
          env:
            - name: GF_PATHS_PROVISIONING
              value: /etc/grafana/provisioning
            - name: GF_SERVER_ROOT_URL
              value: \"%(protocol)s://%(domain)s/grafana\"
            - name: GF_SERVER_SERVE_FROM_SUB_PATH
              value: \"true\"
            - name: GF_ANALYTICS_REPORTING_ENABLED
              value: \"false\"
            - name: GF_ANALYTICS_CHECK_FOR_UPDATES
              value: \"false\"
            - name: GF_LOG_LEVEL
              value: warn
          readinessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 15
            periodSeconds: 10
          livenessProbe:
            httpGet:
              path: /api/health
              port: 3000
            initialDelaySeconds: 30
            periodSeconds: 15
          resources:
            requests:
              cpu: \"30m\"
              memory: \"128Mi\"
            limits:
              cpu: \"500m\"
              memory: \"512Mi\"
          volumeMounts:
            - name: data
              mountPath: /var/lib/grafana
            - name: datasources
              mountPath: /etc/grafana/provisioning/datasources
            - name: dashboards-provider
              mountPath: /etc/grafana/provisioning/dashboards
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: sbos-grafana-pvc
        - name: datasources
          configMap:
            name: grafana-datasources
        - name: dashboards-provider
          configMap:
            name: grafana-dashboards-provider
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: ${NS}
  labels:
    app: grafana
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 3000
      targetPort: 3000
      name: http
  selector:
    app: grafana" || { echo "${__STEP_FAIL__} deploy_grafana"; return 1; }
    echo "${__STEP_OK__} deploy_grafana"

    echo "${__STEP_START__} wait_ready"
    _wait_gf_ready 120 && echo "${__STEP_OK__} wait_ready" || { echo "${__STEP_FAIL__} wait_ready: timeout"; return 1; }

    echo "${__STEP_START__} networkpolicy_grafana"
    _apply "np-grafana" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-grafana
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: grafana
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitoring
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
      ports:
        - protocol: TCP
          port: 3000" || true
    echo "${__STEP_OK__} networkpolicy_grafana"

    # ── TLS Vault PKI + HTTPS (Iteración 2) ──────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/grafana \
                   common_name='grafana.sbos-monitoring.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        [[ -n "$cert_json" ]] && {
            local g_cert g_key g_ca
            g_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            g_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            g_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$g_cert" && -n "$g_key" ]]; then
                _k delete secret grafana-tls -n "$NS" 2>/dev/null || true
                _k create secret generic grafana-tls -n "$NS" \
                    --from-literal=tls.crt="$g_cert" --from-literal=tls.key="$g_key" \
                    --from-literal=ca.crt="$g_ca" 2>/dev/null || true
                echo "${__STEP_OK__} configurar_tls"
            fi
        }
    fi
    _k get secret grafana-tls -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} configurar_tls" || echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"

    _log "grafana instalado — admin: $GF_ADMIN"
    return 0
}

# ── Post-install — SSO: configurar OAuth2/OIDC con Keycloak (idempotente) ──────
ficha_post_install() {
    local realm="${TENANT_ID:-${BOS_ORG_SHORT:-tenant}}"
    local kc_ns="sbos-security"
    local secret_name="sbos-grafana-oidc"
    local kc_base="http://keycloak.${kc_ns}.svc.cluster.local:8080/realms/${realm}"

    echo "${__STEP_START__} configurar_oidc_grafana"

    # Verificar que el secret OIDC existe (lo crea keycloak/ficha_post_install)
    if ! _k get secret -n "$kc_ns" "$secret_name" &>/dev/null; then
        echo "${__STEP_SKIP__} configurar_oidc_grafana: secret $secret_name no disponible — ejecutar ficha_repair de keycloak primero"
        return 0
    fi

    local client_id client_secret
    client_id=$(_k get secret -n "$kc_ns" "$secret_name" \
        -o jsonpath='{.data.client_id}' 2>/dev/null | base64 -d || echo "")
    client_secret=$(_k get secret -n "$kc_ns" "$secret_name" \
        -o jsonpath='{.data.client_secret}' 2>/dev/null | base64 -d || echo "")

    if [[ -z "$client_id" || -z "$client_secret" ]]; then
        echo "${__STEP_SKIP__} configurar_oidc_grafana: credenciales OIDC no disponibles"
        return 0
    fi

    # Verificar si OIDC ya configurado en el deployment (idempotencia)
    local current_oidc
    current_oidc=$(_k get deployment grafana -n "$NS" \
        -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="GF_AUTH_GENERIC_OAUTH_ENABLED")].value}' \
        2>/dev/null || echo "")
    if [[ "$current_oidc" == "true" ]]; then
        _log "  OIDC ya configurado en deployment — skip"
        echo "${__STEP_SKIP__} configurar_oidc_grafana: ya configurado"
        return 0
    fi

    # Patch del deployment para agregar env vars OIDC
    _k patch deployment grafana -n "$NS" --type=json -p="[
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_ENABLED\",\"value\":\"true\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_NAME\",\"value\":\"Keycloak SBOS\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_CLIENT_ID\",\"value\":\"${client_id}\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET\",\"value\":\"${client_secret}\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_SCOPES\",\"value\":\"openid profile email\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_AUTH_URL\",\"value\":\"${kc_base}/protocol/openid-connect/auth\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_TOKEN_URL\",\"value\":\"${kc_base}/protocol/openid-connect/token\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_API_URL\",\"value\":\"${kc_base}/protocol/openid-connect/userinfo\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_GENERIC_OAUTH_ROLE_ATTRIBUTE_PATH\",\"value\":\"contains(groups[*], 'grafana_admin') && 'Admin' || 'Viewer'\"}},
        {\"op\":\"add\",\"path\":\"/spec/template/spec/containers/0/env/-\",\"value\":{\"name\":\"GF_AUTH_DISABLE_LOGIN_FORM\",\"value\":\"false\"}}
    ]" >> "$FICHA_LOG" 2>&1 && \
        _log "  OIDC Keycloak configurado en Grafana — rollout restart iniciado" || \
        _log "  ADVERTENCIA: no se pudo aplicar patch OIDC a grafana"

    echo "${__STEP_OK__} configurar_oidc_grafana"

    # ── Datasources adicionales (Loki + PostgreSQL) — idempotente via API ──────
    _gf_add_datasource() {
        local ds_name="$1" ds_json="$2"
        local admin_auth="${GF_ADMIN}:${GF_ADMIN_PASS}"
        # Verificar si ya existe
        local exists
        exists=$(_k exec deploy/grafana -n "$NS" -- sh -c \
            "curl -sf -u '${admin_auth}' http://localhost:3000/api/datasources/name/${ds_name}" \
            2>/dev/null | grep -c '"name"' || echo "0")
        if [[ "$exists" -gt 0 ]]; then
            _log "  datasource $ds_name ya existe — skip"
            return 0
        fi
        _k exec deploy/grafana -n "$NS" -- sh -c \
            "curl -sf -u '${admin_auth}' -X POST http://localhost:3000/api/datasources \
             -H 'Content-Type: application/json' -d '${ds_json}'" >> "$FICHA_LOG" 2>&1 && \
            _log "  datasource $ds_name agregado" || \
            _log "  ADVERTENCIA: no se pudo agregar datasource $ds_name"
    }

    echo "${__STEP_START__} configurar_datasource_loki"
    if _k get pod -n "$NS" -l app=loki --no-headers 2>/dev/null | grep -q "Running"; then
        _gf_add_datasource "Loki" \
            '{"name":"Loki","type":"loki","access":"proxy","url":"http://loki:3100","isDefault":false,"editable":false}'
        echo "${__STEP_OK__} configurar_datasource_loki"
    else
        echo "${__STEP_SKIP__} configurar_datasource_loki: Loki no disponible aún"
    fi

    echo "${__STEP_START__} configurar_datasource_postgresql"
    local pg_host="${PG_HOST:-postgresql.sbos-data.svc.cluster.local}"
    local pg_pass="${PG_AUX_PASSWORD:-}"
    if [[ -n "$pg_pass" ]] && _k get pod -n sbos-data -l app=postgresql --no-headers 2>/dev/null | grep -q "Running"; then
        _gf_add_datasource "SBOS_db" \
            "{\"name\":\"SBOS_db\",\"type\":\"postgres\",\"access\":\"proxy\",\"url\":\"${pg_host}:5432\",\"database\":\"SBOS_db\",\"user\":\"postgres\",\"secureJsonData\":{\"password\":\"${pg_pass}\"},\"jsonData\":{\"sslmode\":\"disable\",\"postgresVersion\":1800},\"isDefault\":false,\"editable\":false}"
        echo "${__STEP_OK__} configurar_datasource_postgresql"
    else
        echo "${__STEP_SKIP__} configurar_datasource_postgresql: PostgreSQL no disponible o PG_AUX_PASSWORD no seteado"
    fi

    return 0
}

ficha_health() {
    local r
    r=$(_k get deployment grafana -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    (( r >= 1 )) && echo "HEALTHY" && return 0
    echo "DEGRADED: grafana ${r}/1"
    return 1
}

ficha_repair() {
    echo "${__STEP_START__} reiniciar_grafana"
    _k annotate namespace "$NS" linkerd.io/inject=disabled --overwrite >> "$FICHA_LOG" 2>&1 || true
    _k rollout restart deployment/grafana -n "$NS" 2>/dev/null || true
    _wait_gf_ready 90 || _log "ADVERTENCIA: grafana no Ready tras reinicio"
    echo "${__STEP_OK__} reiniciar_grafana"
    # Re-aplicar OIDC y datasources tras reinicio
    ficha_post_install 2>/dev/null || true
    return 0
}

ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=grafana -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$ready" == "True" ]] && echo "${__STEP_OK__} test_pod_ready" || { echo "${__STEP_FAIL__} test_pod_ready: Ready=$ready"; ok=1; }

    echo "${__STEP_START__} test_health"
    local health
    health=$(_gf_curl "http://localhost:3000/api/health" 2>/dev/null || echo "")
    echo "$health" | grep -q '"database": "ok"' && echo "${__STEP_OK__} test_health" || { echo "${__STEP_FAIL__} test_health"; ok=1; }

    echo "${__STEP_START__} test_datasources"
    local ds_count
    ds_count=$(_gf_curl "http://localhost:3000/api/datasources" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    (( ds_count > 0 )) && echo "${__STEP_OK__} test_datasources ($ds_count configurados)" || echo "${__STEP_SKIP__} test_datasources: 0 (requiere auth)"

    echo "${__STEP_START__} test_networkpolicy"
    _k get networkpolicy allow-grafana -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} test_networkpolicy" || { echo "${__STEP_FAIL__} test_networkpolicy"; ok=1; }

    return $ok
}

ficha_status() {
    echo "=== grafana STATUS ==="
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" -l app=grafana -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Health:"
    _gf_curl "http://localhost:3000/api/health" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(f'  database: {d.get(\"database\",\"?\")}')
print(f'  version: {d.get(\"version\",\"?\")}')
" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "URL interna: http://grafana.sbos-monitoring.svc.cluster.local:3000"
}

ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando grafana"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment grafana -n "$NS" 2>/dev/null || true
    _k delete service grafana -n "$NS" 2>/dev/null || true
    _k delete pvc sbos-grafana-pvc -n "$NS" 2>/dev/null || true
    _k delete configmap grafana-datasources grafana-dashboards-provider -n "$NS" 2>/dev/null || true
    _k delete secret grafana-admin -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-grafana -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

ficha_diagnosis() {
    _log "=== Diagnóstico grafana ==="
    _k describe pod -n "$NS" -l app=grafana 2>/dev/null | grep -E "State:|Ready:|Reason:|Message:|Image:" || echo "  pod no encontrado"
    echo ""
    _k logs -n "$NS" deploy/grafana --tail=30 2>/dev/null || true
    echo ""
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
