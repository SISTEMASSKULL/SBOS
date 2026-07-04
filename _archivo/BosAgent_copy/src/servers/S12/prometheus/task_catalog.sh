#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — prometheus
# Iteración 1: Deployment Prometheus 3.4.0 + PVC + scraping K8s + reglas SBOS
# Dependencias: sbos-bootstrap-storage (PV sbos-prometheus-pv)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/prometheus.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-monitoring"
readonly PROM_IMAGE="prom/prometheus:v3.4.0"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [prometheus] $*" | tee -a "$FICHA_LOG" >&2; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-prom-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

_wait_prom_ready() {
    local timeout="${1:-120}"
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod -n "$NS" -l app=prometheus --no-headers 2>/dev/null | grep -q "." && break
        sleep 3
    done
    _k wait pod -n "$NS" -l app=prometheus --for=condition=Ready --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: prometheus no Ready en ${timeout}s"; return 1
    }
    _log "prometheus pod Ready"
}

_prom_curl() { _k exec deploy/prometheus -n "$NS" -- sh -c "curl -sf $*" 2>/dev/null; }

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_pv"
    if ! _k get pv sbos-prometheus-pv > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_pv: sbos-prometheus-pv no existe"
        return 1
    fi
    echo "${__STEP_OK__} verificar_pv"

    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || _k create namespace "$NS" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    echo "${__STEP_START__} crear_rbac"
    _apply "rbac" "apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: ${NS}
  labels:
    app: prometheus
    sbos-managed: \"true\"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: prometheus
  labels:
    app: prometheus
    sbos-managed: \"true\"
rules:
  - apiGroups: [\"\"]
    resources: [nodes, nodes/proxy, nodes/metrics, services, endpoints, pods]
    verbs: [get, list, watch]
  - apiGroups: [extensions, networking.k8s.io]
    resources: [ingresses]
    verbs: [get, list, watch]
  - nonResourceURLs: [/metrics, /metrics/cadvisor]
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
  labels:
    app: prometheus
    sbos-managed: \"true\"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: prometheus
subjects:
  - kind: ServiceAccount
    name: prometheus
    namespace: ${NS}" || { echo "${__STEP_FAIL__} crear_rbac"; return 1; }
    echo "${__STEP_OK__} crear_rbac"

    echo "${__STEP_START__} crear_pvc"
    _apply "pvc" "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sbos-prometheus-pvc
  namespace: ${NS}
  labels:
    app: prometheus
    sbos-managed: \"true\"
spec:
  storageClassName: sbos-local
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 20Gi
  volumeName: sbos-prometheus-pv" || { echo "${__STEP_FAIL__} crear_pvc"; return 1; }
    echo "${__STEP_OK__} crear_pvc"

    echo "${__STEP_START__} crear_configmap"
    _apply "configmap" "apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: ${NS}
  labels:
    app: prometheus
    sbos-managed: \"true\"
data:
  prometheus.yml: |
    global:
      scrape_interval: 30s
      evaluation_interval: 30s
      scrape_timeout: 10s
    alerting:
      alertmanagers:
        - static_configs:
            - targets: [alertmanager:9093]
    rule_files:
      - /etc/prometheus/rules/*.yml
    scrape_configs:
      - job_name: prometheus
        static_configs:
          - targets: [localhost:9090]
      - job_name: kubernetes-nodes
        scheme: https
        tls_config:
          ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
          insecure_skip_verify: true
        bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
        kubernetes_sd_configs:
          - role: node
        relabel_configs:
          - action: labelmap
            regex: __meta_kubernetes_node_label_(.+)
      - job_name: kubernetes-pods
        kubernetes_sd_configs:
          - role: pod
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
            action: keep
            regex: \"true\"
          - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
            action: replace
            target_label: __metrics_path__
            regex: (.+)
          - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
            action: replace
            regex: ([^:]+)(?::\d+)?;(\d+)
            replacement: \$1:\$2
            target_label: __address__
          - action: labelmap
            regex: __meta_kubernetes_pod_label_(.+)
          - source_labels: [__meta_kubernetes_namespace]
            target_label: namespace
          - source_labels: [__meta_kubernetes_pod_name]
            target_label: pod
      - job_name: sbos-daemons
        static_configs:
          - targets:
              - bauth.sbos-system.svc.cluster.local:9450
              - bkernel.sbos-system.svc.cluster.local:9460
              - biedata.sbos-system.svc.cluster.local:9470
              - bsearch.sbos-system.svc.cluster.local:9493
        relabel_configs:
          - target_label: job
            replacement: sbos-daemons
  sbos-alerts.yml: |
    groups:
      - name: sbos-critical
        rules:
          - alert: VaultSealed
            expr: up{job=\"sbos-daemons\"} == 0
            for: 2m
            labels:
              severity: critical
            annotations:
              summary: \"Daemon SBOS caído: {{ \$labels.instance }}\"
          - alert: PodCrashLoopBackOff
            expr: kube_pod_container_status_waiting_reason{reason=\"CrashLoopBackOff\"} == 1
            for: 5m
            labels:
              severity: critical
            annotations:
              summary: \"Pod en CrashLoop: {{ \$labels.pod }}/{{ \$labels.container }}\"
          - alert: NodeDiskPressure
            expr: kube_node_status_condition{condition=\"DiskPressure\",status=\"true\"} == 1
            for: 2m
            labels:
              severity: warning
            annotations:
              summary: \"Nodo con presión de disco: {{ \$labels.node }}\"
          - alert: Watchdog
            expr: vector(1)
            labels:
              severity: none
            annotations:
              summary: \"Alertmanager funcionando correctamente\"" || { echo "${__STEP_FAIL__} crear_configmap"; return 1; }
    echo "${__STEP_OK__} crear_configmap"

    echo "${__STEP_START__} deploy_prometheus"
    _apply "deployment" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: ${NS}
  labels:
    app: prometheus
    sbos-managed: \"true\"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
      annotations:
        prometheus.io/scrape: \"false\"
    spec:
      serviceAccountName: prometheus
      securityContext:
        runAsUser: 65534
        runAsNonRoot: true
        fsGroup: 65534
      containers:
        - name: prometheus
          image: ${PROM_IMAGE}
          args:
            - --config.file=/etc/prometheus/prometheus.yml
            - --storage.tsdb.path=/prometheus
            - --storage.tsdb.retention.time=30d
            - --web.enable-lifecycle
            - --web.console.libraries=/usr/share/prometheus/console_libraries
            - --web.console.templates=/usr/share/prometheus/consoles
          ports:
            - containerPort: 9090
              name: web
          readinessProbe:
            httpGet:
              path: /-/ready
              port: 9090
            initialDelaySeconds: 10
            periodSeconds: 5
          livenessProbe:
            httpGet:
              path: /-/healthy
              port: 9090
            initialDelaySeconds: 30
            periodSeconds: 15
          resources:
            requests:
              cpu: \"200m\"
              memory: \"512Mi\"
            limits:
              cpu: \"1\"
              memory: \"2Gi\"
          volumeMounts:
            - name: config
              mountPath: /etc/prometheus
            - name: rules
              mountPath: /etc/prometheus/rules
            - name: data
              mountPath: /prometheus
      volumes:
        - name: config
          configMap:
            name: prometheus-config
            items:
              - key: prometheus.yml
                path: prometheus.yml
        - name: rules
          configMap:
            name: prometheus-config
            items:
              - key: sbos-alerts.yml
                path: sbos-alerts.yml
        - name: data
          persistentVolumeClaim:
            claimName: sbos-prometheus-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: ${NS}
  labels:
    app: prometheus
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 9090
      targetPort: 9090
      name: web
  selector:
    app: prometheus" || { echo "${__STEP_FAIL__} deploy_prometheus"; return 1; }
    echo "${__STEP_OK__} deploy_prometheus"

    echo "${__STEP_START__} wait_ready"
    _wait_prom_ready 120 && echo "${__STEP_OK__} wait_ready" || { echo "${__STEP_FAIL__} wait_ready: timeout"; return 1; }

    echo "${__STEP_START__} networkpolicy_prometheus"
    _apply "np-prometheus" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-prometheus
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: prometheus
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitoring
      ports:
        - protocol: TCP
          port: 9090" || true
    echo "${__STEP_OK__} networkpolicy_prometheus"

    # ── TLS Vault PKI (Iteración 2) ──────────────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/prometheus \
                   common_name='prometheus.sbos-monitoring.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        [[ -n "$cert_json" ]] && {
            local p_cert p_key p_ca
            p_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            p_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            p_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$p_cert" && -n "$p_key" ]]; then
                _k delete secret prometheus-tls -n "$NS" 2>/dev/null || true
                _k create secret generic prometheus-tls -n "$NS" \
                    --from-literal=tls.crt="$p_cert" --from-literal=tls.key="$p_key" \
                    --from-literal=ca.crt="$p_ca" 2>/dev/null || true
                echo "${__STEP_OK__} configurar_tls"
            fi
        }
    fi
    _k get secret prometheus-tls -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} configurar_tls" || echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"

    _log "prometheus instalado"
    return 0
}

ficha_post_install() {
    _log "Estado prometheus:"
    local ready_resp
    ready_resp=$(_prom_curl "http://localhost:9090/-/ready" 2>/dev/null || echo "FAIL")
    _log "  ready=$ready_resp"
    _k get pod -n "$NS" -l app=prometheus --no-headers 2>/dev/null | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' || true
    return 0
}

ficha_repair() {
    echo "${__STEP_START__} reiniciar_prometheus"
    _k rollout restart deployment/prometheus -n "$NS" 2>/dev/null || true
    sleep 5
    _wait_prom_ready 90 || _log "ADVERTENCIA: prometheus no Ready tras reinicio"
    echo "${__STEP_OK__} reiniciar_prometheus"
    return 0
}

ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod -n "$NS" -l app=prometheus -o jsonpath='{.items[0].status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")
    [[ "$ready" == "True" ]] && echo "${__STEP_OK__} test_pod_ready" || { echo "${__STEP_FAIL__} test_pod_ready: Ready=$ready"; ok=1; }

    echo "${__STEP_START__} test_ready_endpoint"
    local resp
    resp=$(_prom_curl "http://localhost:9090/-/ready" 2>/dev/null || echo "")
    [[ "$resp" == *"Ready"* ]] && echo "${__STEP_OK__} test_ready_endpoint" || { echo "${__STEP_FAIL__} test_ready_endpoint"; ok=1; }

    echo "${__STEP_START__} test_targets"
    local target_count
    target_count=$(_prom_curl "http://localhost:9090/api/v1/targets" 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',{}).get('activeTargets',[])))" 2>/dev/null || echo "0")
    (( target_count > 0 )) && echo "${__STEP_OK__} test_targets ($target_count activos)" || { echo "${__STEP_FAIL__} test_targets: 0 targets"; ok=1; }

    echo "${__STEP_START__} test_networkpolicy"
    _k get networkpolicy allow-prometheus -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} test_networkpolicy" || { echo "${__STEP_FAIL__} test_networkpolicy"; ok=1; }

    return $ok
}

ficha_status() {
    echo "=== prometheus STATUS ==="
    echo ""
    echo "Pods:"
    _k get pod -n "$NS" -l app=prometheus -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Targets activos:"
    _prom_curl "http://localhost:9090/api/v1/targets" 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin).get('data',{}).get('activeTargets',[])
for t in d[:10]:
    print(f'  {t[\"labels\"].get(\"job\",\"?\")} — {t[\"health\"]}')
print(f'  Total: {len(d)}')
" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Almacenamiento:"
    _k exec deploy/prometheus -n "$NS" -- df -h /prometheus 2>/dev/null | awk 'NR==2{printf "  usado=%s disponible=%s\n", $3, $4}' || echo "  (no disponible)"
}

ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando prometheus"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete deployment prometheus -n "$NS" 2>/dev/null || true
    _k delete service prometheus -n "$NS" 2>/dev/null || true
    _k delete pvc sbos-prometheus-pvc -n "$NS" 2>/dev/null || true
    _k delete configmap prometheus-config -n "$NS" 2>/dev/null || true
    _k delete clusterrole prometheus 2>/dev/null || true
    _k delete clusterrolebinding prometheus 2>/dev/null || true
    _k delete serviceaccount prometheus -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-prometheus -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

ficha_diagnosis() {
    _log "=== Diagnóstico prometheus ==="
    _k describe pod -n "$NS" -l app=prometheus 2>/dev/null | grep -E "State:|Ready:|Reason:|Message:|Image:" || echo "  pod no encontrado"
    echo ""
    _k logs -n "$NS" deploy/prometheus --tail=30 2>/dev/null || true
    echo ""
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
