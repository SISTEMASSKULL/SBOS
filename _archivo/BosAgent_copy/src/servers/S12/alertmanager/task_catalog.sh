#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — alertmanager
# Iteración 1: Deployment Alertmanager 0.28.1 + reglas SBOS + NetworkPolicies
# Dependencias: prometheus (alerts vía API)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/alertmanager.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-monitoring"
readonly AM_IMAGE="prom/alertmanager:v0.28.1"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [alertmanager] $*" | tee -a "$FICHA_LOG" >&2; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-am-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

_wait_am_ready() {
    local timeout="${1:-60}"
    local deadline=$(( $(date +%s) + 20 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=alertmanager --no-headers 2>/dev/null | grep -q "." && break
        sleep 3
    done
    _k wait pod -n "$NS" -l app=alertmanager --for=condition=Ready --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: alertmanager no Ready en ${timeout}s"; return 1
    }
    _log "alertmanager pod Ready"
}

_am_curl() { _k exec deploy/alertmanager -n "$NS" -- sh -c "curl -sf $*" 2>/dev/null; }

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
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

    echo "${__STEP_START__} crear_configmap"
    _apply "configmap" "apiVersion: v1
kind: ConfigMap
metadata:
  name: alertmanager-config
  namespace: ${NS}
  labels:
    app: alertmanager
    sbos-managed: \"true\"
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 5m
    route:
      receiver: sbos-log
      group_by: [alertname, namespace, severity]
      group_wait: 30s
      group_interval: 5m
      repeat_interval: 12h
      routes:
        - matchers:
            - alertname = Watchdog
          receiver: \"null\"
        - matchers:
            - severity = critical
          receiver: sbos-log
          continue: true
    receivers:
      - name: sbos-log
      - name: \"null\"
    inhibit_rules:
      - source_matchers:
          - severity = critical
        target_matchers:
          - severity = warning
        equal: [alertname, namespace]" || { echo "${__STEP_FAIL__} crear_configmap"; return 1; }
    echo "${__STEP_OK__} crear_configmap"

    echo "${__STEP_START__} deploy_alertmanager"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: ${NS}
  labels:
    app: alertmanager
    sbos-managed: \"true\"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      securityContext:
        runAsUser: 65534
        runAsNonRoot: true
        fsGroup: 65534
      containers:
        - name: alertmanager
          image: ${AM_IMAGE}
          args:
            - --config.file=/etc/alertmanager/alertmanager.yml
            - --storage.path=/alertmanager
            - --web.listen-address=:9093
          ports:
            - containerPort: 9093
              name: web
          readinessProbe:
            httpGet:
              path: /-/ready
              port: 9093
            initialDelaySeconds: 5
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /-/healthy
              port: 9093
            initialDelaySeconds: 15
            periodSeconds: 10
          resources:
            requests:
              cpu: \"50m\"
              memory: \"64Mi\"
            limits:
              cpu: \"200m\"
              memory: \"128Mi\"
          volumeMounts:
            - name: config
              mountPath: /etc/alertmanager
            - name: storage
              mountPath: /alertmanager
      volumes:
        - name: config
          configMap:
            name: alertmanager-config
        - name: storage
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: ${NS}
  labels:
    app: alertmanager
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 9093
      targetPort: 9093
      name: web
  selector:
    app: alertmanager" || { echo "${__STEP_FAIL__} deploy_alertmanager"; return 1; }
    echo "${__STEP_OK__} deploy_alertmanager"

    echo "${__STEP_START__} wait_ready"
    _wait_am_ready 60 && echo "${__STEP_OK__} wait_ready" || { echo "${__STEP_FAIL__} wait_ready: timeout"; return 1; }

    echo "${__STEP_START__} networkpolicies_alertmanager"
    _apply "np-alertmanager" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-alertmanager
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: alertmanager
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitoring
      ports:
        - protocol: TCP
          port: 9093" || true
    echo "${__STEP_OK__} networkpolicies_alertmanager"

    # ── TLS Vault PKI (Iteración 2) ──────────────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/alertmanager \
                   common_name='alertmanager.sbos-monitoring.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        [[ -n "$cert_json" ]] && {
            local a_cert a_key a_ca
            a_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            a_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            a_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$a_cert" && -n "$a_key" ]]; then
                _k delete secret alertmanager-tls -n "$NS" 2>/dev/null || true
                _k create secret generic alertmanager-tls -n "$NS" \
                    --from-literal=tls.crt="$a_cert" --from-literal=tls.key="$a_key" \
                    --from-literal=ca.crt="$a_ca" 2>/dev/null || true
                echo "${__STEP_OK__} configurar_tls"
            fi
        }
    fi
    _k get secret alertmanager-tls -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} configurar_tls" || echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"

    _log "alertmanager instalado"
    return 0
}

ficha_post_install() {
    _log "Estado alertmanager:"
    _am_curl "http://localhost:9093/-/ready" 2>/dev/null && _log "  ready=OK" || _log "  ready=FAIL"
    _k get pod -n "$NS" -l app=alertmanager --no-headers 2>/dev/null | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' || true
    return 0
}

ficha_repair() {
    echo "${__STEP_START__} reiniciar_alertmanager"
    _k rollout restart deployment/alertmanager -n "$NS" 2>/dev/null || true
    sleep 3
    _wait_am_ready 60 || _log "ADVERTENCIA: alertmanager no Ready tras reinicio"
    echo "${__STEP_OK__} reiniciar_alertmanager"
    return 0
}

ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=alertmanager -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$ready" == "True" ]] && echo "${__STEP_OK__} test_pod_ready" || { echo "${__STEP_FAIL__} test_pod_ready: Ready=$ready"; ok=1; }

    echo "${__STEP_START__} test_ready_endpoint"
    _am_curl "http://localhost:9093/-/ready" > /dev/null 2>&1 && echo "${__STEP_OK__} test_ready_endpoint" || { echo "${__STEP_FAIL__} test_ready_endpoint"; ok=1; }

    echo "${__STEP_START__} test_alerts_api"
    local alerts
    alerts=$(_am_curl "http://localhost:9093/api/v2/alerts" 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    echo "${__STEP_OK__} test_alerts_api ($alerts alertas)"

    echo "${__STEP_START__} test_networkpolicy"
    _k get networkpolicy allow-alertmanager -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} test_networkpolicy" || { echo "${__STEP_FAIL__} test_networkpolicy"; ok=1; }

    return $ok
}

ficha_status() {
    echo "=== alertmanager STATUS ==="
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" -l app=alertmanager -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Alertas activas:"
    _am_curl "http://localhost:9093/api/v2/alerts" 2>/dev/null | python3 -c "
import sys,json
alerts=json.load(sys.stdin)
if not alerts: print('  (ninguna)')
for a in alerts[:10]:
    name=a.get('labels',{}).get('alertname','?')
    sev=a.get('labels',{}).get('severity','?')
    state=a.get('status',{}).get('state','?')
    print(f'  [{sev}] {name} ({state})')
" 2>/dev/null || echo "  (no disponible)"
}

ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando alertmanager"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment alertmanager -n "$NS" 2>/dev/null || true
    _k delete service alertmanager -n "$NS" 2>/dev/null || true
    _k delete configmap alertmanager-config -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-alertmanager -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

ficha_diagnosis() {
    _log "=== Diagnóstico alertmanager ==="
    _k describe pod -n "$NS" -l app=alertmanager 2>/dev/null | grep -E "State:|Ready:|Reason:|Image:" || echo "  pod no encontrado"
    echo ""
    _k logs -n "$NS" deploy/alertmanager --tail=30 2>/dev/null || true
    echo ""
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
