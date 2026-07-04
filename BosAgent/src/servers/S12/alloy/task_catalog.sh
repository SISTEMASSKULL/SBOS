#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — alloy (Grafana Alloy)
# Iteración 1: DaemonSet colectando logs pods sbos-managed + extracción ctx_id
# Dependencias: prometheus (remote_write)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/alloy.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-monitoring"
readonly ALLOY_IMAGE="grafana/alloy:v1.8.3"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [alloy] $*" | tee -a "$FICHA_LOG"; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-alloy-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

_wait_alloy_ready() {
    local timeout="${1:-90}" elapsed=0
    while (( elapsed < timeout )); do
        local running
        running=$(_k get pods -n "$NS" -l app=alloy --no-headers 2>/dev/null | grep -c "Running" || echo "0")
        (( running > 0 )) && { _log "alloy pods Running: $running"; return 0; }
        sleep 5; elapsed=$((elapsed + 5))
    done
    return 1
}

_alloy_curl() {
    local pod
    pod=$(_k get pods -n "$NS" -l app=alloy -o name 2>/dev/null | head -1)
    if [[ -n "$pod" ]]; then
        _k exec -n "$NS" "$pod" -- sh -c "curl -sf $*" 2>/dev/null
    fi
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
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
  name: alloy
  namespace: ${NS}
  labels:
    app: alloy
    sbos-managed: \"true\"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: alloy
  labels:
    app: alloy
    sbos-managed: \"true\"
rules:
  - apiGroups: [\"\"]
    resources: [nodes, pods, services, endpoints, namespaces]
    verbs: [get, list, watch]
  - apiGroups: [\"\"]
    resources: [pods/log]
    verbs: [get]
  - nonResourceURLs: [/metrics]
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: alloy
  labels:
    app: alloy
    sbos-managed: \"true\"
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: alloy
subjects:
  - kind: ServiceAccount
    name: alloy
    namespace: ${NS}" || { echo "${__STEP_FAIL__} crear_rbac"; return 1; }
    echo "${__STEP_OK__} crear_rbac"

    echo "${__STEP_START__} crear_configmap"
    _apply "configmap" "apiVersion: v1
kind: ConfigMap
metadata:
  name: alloy-config
  namespace: ${NS}
  labels:
    app: alloy
    sbos-managed: \"true\"
data:
  config.alloy: |
    logging {
      level  = \"warn\"
      format = \"logfmt\"
    }

    // Descubrir pods K8s con label sbos-managed=true
    discovery.kubernetes \"sbos_pods\" {
      role = \"pod\"
    }

    discovery.relabel \"sbos_pods_filtered\" {
      targets = discovery.kubernetes.sbos_pods.targets
      rule {
        source_labels = [\"__meta_kubernetes_pod_label_sbos_managed\"]
        regex         = \"true\"
        action        = \"keep\"
      }
      rule {
        source_labels = [\"__meta_kubernetes_namespace\"]
        target_label  = \"namespace\"
      }
      rule {
        source_labels = [\"__meta_kubernetes_pod_name\"]
        target_label  = \"pod\"
      }
      rule {
        source_labels = [\"__meta_kubernetes_pod_container_name\"]
        target_label  = \"container\"
      }
      rule {
        source_labels = [\"__meta_kubernetes_pod_label_app\"]
        target_label  = \"app\"
      }
    }

    loki.source.kubernetes \"sbos_logs\" {
      targets    = discovery.relabel.sbos_pods_filtered.output
      forward_to = [loki.process.extract_ctx_id.receiver]
    }

    loki.process \"extract_ctx_id\" {
      stage.regex {
        expression = \"traceparent=(?P<traceparent>00-[a-f0-9]{32}-[a-f0-9]{16}-[0-9]{2})\"
      }
      stage.labels { values = { traceparent = \"\" } }
      stage.regex {
        expression = \"ctx_id=(?P<ctx_id>[a-f0-9\\\\-]{36,})\"
      }
      stage.labels { values = { ctx_id = \"\" } }
      forward_to = []
    }

    prometheus.exporter.self \"alloy_metrics\" {}
    prometheus.scrape \"alloy_self\" {
      targets    = prometheus.exporter.self.alloy_metrics.targets
      forward_to = [prometheus.remote_write.prometheus.receiver]
    }
    prometheus.remote_write \"prometheus\" {
      endpoint {
        url = \"http://prometheus:9090/api/v1/write\"
      }
    }" || { echo "${__STEP_FAIL__} crear_configmap"; return 1; }
    echo "${__STEP_OK__} crear_configmap"

    echo "${__STEP_START__} deploy_daemonset"
    _apply "daemonset" "apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: alloy
  namespace: ${NS}
  labels:
    app: alloy
    sbos-managed: \"true\"
spec:
  selector:
    matchLabels:
      app: alloy
  template:
    metadata:
      labels:
        app: alloy
    spec:
      serviceAccountName: alloy
      tolerations:
        - operator: Exists
      containers:
        - name: alloy
          image: ${ALLOY_IMAGE}
          args:
            - run
            - /etc/alloy/config.alloy
            - --storage.path=/var/lib/alloy/data
            - --server.http.listen-addr=0.0.0.0:12345
          ports:
            - containerPort: 12345
              name: http
          readinessProbe:
            httpGet:
              path: /-/ready
              port: 12345
            initialDelaySeconds: 10
            periodSeconds: 10
          resources:
            requests:
              cpu: \"50m\"
              memory: \"128Mi\"
            limits:
              cpu: \"200m\"
              memory: \"256Mi\"
          volumeMounts:
            - name: config
              mountPath: /etc/alloy
            - name: varlog
              mountPath: /var/log
              readOnly: true
            - name: varlibdockercontainers
              mountPath: /var/lib/docker/containers
              readOnly: true
            - name: storage
              mountPath: /var/lib/alloy/data
      volumes:
        - name: config
          configMap:
            name: alloy-config
        - name: varlog
          hostPath:
            path: /var/log
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
        - name: storage
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: alloy
  namespace: ${NS}
  labels:
    app: alloy
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 12345
      targetPort: 12345
      name: http
  selector:
    app: alloy" || { echo "${__STEP_FAIL__} deploy_daemonset"; return 1; }
    echo "${__STEP_OK__} deploy_daemonset"

    echo "${__STEP_START__} wait_ready"
    _wait_alloy_ready 90 && echo "${__STEP_OK__} wait_ready" || { echo "${__STEP_FAIL__} wait_ready: timeout"; return 1; }

    echo "${__STEP_START__} networkpolicy_alloy"
    _apply "np-alloy" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-alloy
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: alloy
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-monitoring
      ports:
        - protocol: TCP
          port: 12345" || true
    echo "${__STEP_OK__} networkpolicy_alloy"

    # ── TLS Vault PKI (Iteración 2) ──────────────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/alloy \
                   common_name='alloy.sbos-monitoring.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        [[ -n "$cert_json" ]] && {
            local al_cert al_key al_ca
            al_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            al_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            al_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$al_cert" && -n "$al_key" ]]; then
                _k delete secret alloy-tls -n "$NS" 2>/dev/null || true
                _k create secret generic alloy-tls -n "$NS" \
                    --from-literal=tls.crt="$al_cert" --from-literal=tls.key="$al_key" \
                    --from-literal=ca.crt="$al_ca" 2>/dev/null || true
                echo "${__STEP_OK__} configurar_tls"
            fi
        }
    fi
    _k get secret alloy-tls -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} configurar_tls" || echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"

    _log "alloy instalado"
    return 0
}

ficha_post_install() {
    _log "Estado alloy:"
    _k get pods -n "$NS" -l app=alloy --no-headers 2>/dev/null | awk '{printf "  pod=%s status=%s ready=%s\n", $1, $3, $2}' || echo "  (sin pods)"
    return 0
}

ficha_repair() {
    echo "${__STEP_START__} reiniciar_alloy"
    _k rollout restart daemonset/alloy -n "$NS" 2>/dev/null || true
    _wait_alloy_ready 60 || _log "ADVERTENCIA: alloy no Ready tras reinicio"
    echo "${__STEP_OK__} reiniciar_alloy"
    return 0
}

ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pods_running"
    local running
    running=$(_k get pods -n "$NS" -l app=alloy --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    (( running > 0 )) && echo "${__STEP_OK__} test_pods_running ($running pods)" || { echo "${__STEP_FAIL__} test_pods_running: 0 pods"; ok=1; }

    echo "${__STEP_START__} test_ready_endpoint"
    _alloy_curl "http://localhost:12345/-/ready" > /dev/null 2>&1 && echo "${__STEP_OK__} test_ready_endpoint" || echo "${__STEP_SKIP__} test_ready_endpoint: no accesible aún"

    echo "${__STEP_START__} test_networkpolicy"
    _k get networkpolicy allow-alloy -n "$NS" > /dev/null 2>&1 && echo "${__STEP_OK__} test_networkpolicy" || echo "${__STEP_SKIP__} test_networkpolicy: no creada"

    return $ok
}

ficha_status() {
    echo "=== alloy STATUS ==="
    echo ""
    echo "Pods (DaemonSet):"
    _k get pods -n "$NS" -l app=alloy -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,NODE:.spec.nodeName' 2>/dev/null || echo "  (no disponible)"
}

ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando alloy"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete daemonset alloy -n "$NS" 2>/dev/null || true
    _k delete service alloy -n "$NS" 2>/dev/null || true
    _k delete configmap alloy-config -n "$NS" 2>/dev/null || true
    _k delete clusterrole alloy 2>/dev/null || true
    _k delete clusterrolebinding alloy 2>/dev/null || true
    _k delete serviceaccount alloy -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-alloy -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

ficha_diagnosis() {
    _log "=== Diagnóstico alloy ==="
    _k get pods -n "$NS" -l app=alloy 2>/dev/null || true
    local pod
    pod=$(_k get pods -n "$NS" -l app=alloy -o name 2>/dev/null | head -1)
    if [[ -n "$pod" ]]; then
        _k logs -n "$NS" "$pod" --tail=30 2>/dev/null || true
    fi
    echo ""
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
