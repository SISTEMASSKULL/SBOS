#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha sbos-bootstrap-monitoring
# Iteración 1: node-exporter (DaemonSet) + kube-state-metrics (Deployment)
# Dependencias: sbos-bootstrap-k8s, sbos-bootstrap-cni, sbos-bootstrap-storage
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-bootstrap-monitoring.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NAMESPACE="sbos-monitoring"
NODE_EXPORTER_VERSION="${NODE_EXPORTER_VERSION:-1.8.2}"
KSM_VERSION="${KSM_VERSION:-2.13.0}"

_log()     { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-bootstrap-monitoring] $*" | tee -a "$FICHA_LOG" >&2; }
_kubectl() { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _apply: aplica un manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-mon-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _kubectl apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

_wait_rollout() {
    local kind="$1" name="$2" ns="$3" timeout="${4:-120}"
    _kubectl rollout status "${kind}/${name}" -n "$ns" \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "ADVERTENCIA: rollout ${kind}/${name} no completó en ${timeout}s"
        return 1
    }
}

_pods_running() {
    local label="$1" ns="$2"
    _kubectl get pods -n "$ns" -l "$label" --no-headers 2>/dev/null \
        | awk '{print $3}' | grep -c "^Running$" || echo "0"
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    if ! _kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_namespace: $NAMESPACE no existe — requiere sbos-bootstrap-k8s"
        return 1
    fi
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. RBAC ──────────────────────────────────────────────────
    echo "${__STEP_START__} crear_rbac"
    _apply "rbac" "apiVersion: v1
kind: ServiceAccount
metadata:
  name: sbos-monitoring
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: sbos-monitoring-reader
rules:
  - apiGroups: [\"\"]
    resources: [nodes, nodes/metrics, services, endpoints, pods, configmaps, namespaces]
    verbs: [get, list, watch]
  - apiGroups: [apps]
    resources: [deployments, daemonsets, replicasets, statefulsets]
    verbs: [get, list, watch]
  - nonResourceURLs: [/metrics, /metrics/cadvisor]
    verbs: [get]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: sbos-monitoring-reader
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: sbos-monitoring-reader
subjects:
  - kind: ServiceAccount
    name: sbos-monitoring
    namespace: ${NAMESPACE}" || {
        echo "${__STEP_FAIL__} crear_rbac: kubectl apply falló"
        return 1
    }
    echo "${__STEP_OK__} crear_rbac"

    # ── 2. node-exporter (DaemonSet) ─────────────────────────────
    echo "${__STEP_START__} desplegar_node_exporter"
    if _kubectl get daemonset prometheus-node-exporter -n "$NAMESPACE" > /dev/null 2>&1; then
        _log "node-exporter ya existe — omitiendo"
        echo "${__STEP_SKIP__} desplegar_node_exporter: ya existe"
    else
        # NOTA: el argumento mount-points-exclude usa \$ para producir $ literal
        # en el heredoc sin comillas. $$ sin escape sería expandido por bash como PID.
        _apply "node-exporter" "apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: prometheus-node-exporter
  namespace: ${NAMESPACE}
  labels:
    app: prometheus-node-exporter
    sbos-managed: \"true\"
spec:
  selector:
    matchLabels:
      app: prometheus-node-exporter
  template:
    metadata:
      labels:
        app: prometheus-node-exporter
      annotations:
        prometheus.io/scrape: \"true\"
        prometheus.io/port: \"9100\"
    spec:
      serviceAccountName: sbos-monitoring
      hostNetwork: true
      hostPID: true
      tolerations:
        - operator: Exists
      containers:
        - name: node-exporter
          image: prom/node-exporter:v${NODE_EXPORTER_VERSION}
          args:
            - --path.procfs=/host/proc
            - --path.sysfs=/host/sys
            - --path.rootfs=/host/root
            - --collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)(\$|/)
          ports:
            - containerPort: 9100
              hostPort: 9100
              name: metrics
          resources:
            requests:
              cpu: 10m
              memory: 32Mi
            limits:
              cpu: 100m
              memory: 64Mi
          readinessProbe:
            httpGet:
              path: /
              port: 9100
            initialDelaySeconds: 5
            timeoutSeconds: 5
          livenessProbe:
            httpGet:
              path: /
              port: 9100
            initialDelaySeconds: 10
            timeoutSeconds: 5
          volumeMounts:
            - name: proc
              mountPath: /host/proc
              readOnly: true
            - name: sys
              mountPath: /host/sys
              readOnly: true
            - name: root
              mountPath: /host/root
              mountPropagation: HostToContainer
              readOnly: true
      volumes:
        - name: proc
          hostPath:
            path: /proc
        - name: sys
          hostPath:
            path: /sys
        - name: root
          hostPath:
            path: /
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus-node-exporter
  namespace: ${NAMESPACE}
  labels:
    app: prometheus-node-exporter
    sbos-managed: \"true\"
  annotations:
    prometheus.io/scrape: \"true\"
    prometheus.io/port: \"9100\"
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - name: metrics
      port: 9100
      targetPort: 9100
  selector:
    app: prometheus-node-exporter" || {
            echo "${__STEP_FAIL__} desplegar_node_exporter: kubectl apply falló"
            return 1
        }
        _log "node-exporter DaemonSet aplicado"

        if ! _wait_rollout daemonset prometheus-node-exporter "$NAMESPACE" 120; then
            _log "ADVERTENCIA: node-exporter no completó rollout (puede necesitar imagen)"
        fi
        echo "${__STEP_OK__} desplegar_node_exporter"
    fi

    # ── 3. kube-state-metrics (Deployment) ───────────────────────
    echo "${__STEP_START__} desplegar_kube_state_metrics"
    if _kubectl get deployment kube-state-metrics -n "$NAMESPACE" > /dev/null 2>&1; then
        _log "kube-state-metrics ya existe — omitiendo"
        echo "${__STEP_SKIP__} desplegar_kube_state_metrics: ya existe"
    else
        _apply "kube-state-metrics" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: kube-state-metrics
  namespace: ${NAMESPACE}
  labels:
    app: kube-state-metrics
    sbos-managed: \"true\"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: kube-state-metrics
  template:
    metadata:
      labels:
        app: kube-state-metrics
    spec:
      serviceAccountName: sbos-monitoring
      containers:
        - name: kube-state-metrics
          image: registry.k8s.io/kube-state-metrics/kube-state-metrics:v${KSM_VERSION}
          ports:
            - containerPort: 8080
              name: http-metrics
            - containerPort: 8081
              name: telemetry
          readinessProbe:
            httpGet:
              path: /
              port: 8081
            initialDelaySeconds: 5
            timeoutSeconds: 5
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 5
            timeoutSeconds: 5
          resources:
            requests:
              cpu: 10m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
---
apiVersion: v1
kind: Service
metadata:
  name: kube-state-metrics
  namespace: ${NAMESPACE}
  labels:
    app: kube-state-metrics
    sbos-managed: \"true\"
  annotations:
    prometheus.io/scrape: \"true\"
    prometheus.io/port: \"8080\"
spec:
  type: ClusterIP
  ports:
    - name: http-metrics
      port: 8080
      targetPort: 8080
    - name: telemetry
      port: 8081
      targetPort: 8081
  selector:
    app: kube-state-metrics" || {
            echo "${__STEP_FAIL__} desplegar_kube_state_metrics: kubectl apply falló"
            return 1
        }
        _log "kube-state-metrics Deployment aplicado"

        if ! _wait_rollout deployment kube-state-metrics "$NAMESPACE" 120; then
            _log "ADVERTENCIA: kube-state-metrics no completó rollout (puede necesitar imagen)"
        fi
        echo "${__STEP_OK__} desplegar_kube_state_metrics"
    fi

    # ── 4. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_monitoring"

    # allow-intra-monitoring: comunicación libre dentro del namespace.
    # Necesaria porque sbos-bootstrap-hard aplicará default-deny-all luego;
    # sin esta política prometheus no puede scrapear node-exporter ni KSM.
    _apply "np-intra" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-monitoring
  namespace: ${NAMESPACE}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${NAMESPACE}
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${NAMESPACE}" || true

    # allow-monitoring-scrape: permite que prometheus scrape exporters
    # en otros namespaces (bkernel, bauth, etc. cuando existan).
    _apply "np-scrape" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring-scrape
  namespace: ${NAMESPACE}
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: ${NAMESPACE}
      ports:
        - protocol: TCP
          port: 9100
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 8081" || true

    echo "${__STEP_OK__} networkpolicies_monitoring"

    _log "sbos-bootstrap-monitoring instalado"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado final del monitoring:"
    _kubectl get pods -n "$NAMESPACE" -l sbos-managed=true \
        --no-headers 2>/dev/null \
        | awk '{printf "  %-45s %s\n", $1, $3}' \
        | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reiniciar_componentes"
    _kubectl rollout restart daemonset/prometheus-node-exporter \
        -n "$NAMESPACE" 2>/dev/null || true
    _kubectl rollout restart deployment/kube-state-metrics \
        -n "$NAMESPACE" 2>/dev/null || true
    _wait_rollout daemonset prometheus-node-exporter "$NAMESPACE" 120 || true
    _wait_rollout deployment kube-state-metrics "$NAMESPACE" 120 || true
    echo "${__STEP_OK__} reiniciar_componentes"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_rbac"
    local rbac_ok=0
    _kubectl get serviceaccount sbos-monitoring -n "$NAMESPACE" > /dev/null 2>&1 && \
        rbac_ok=$((rbac_ok+1))
    _kubectl get clusterrole sbos-monitoring-reader > /dev/null 2>&1 && \
        rbac_ok=$((rbac_ok+1))
    _kubectl get clusterrolebinding sbos-monitoring-reader > /dev/null 2>&1 && \
        rbac_ok=$((rbac_ok+1))
    if (( rbac_ok == 3 )); then
        echo "${__STEP_OK__} test_rbac (SA + ClusterRole + ClusterRoleBinding)"
    else
        echo "${__STEP_FAIL__} test_rbac: $rbac_ok/3 recursos RBAC presentes"
        ok=1
    fi

    echo "${__STEP_START__} test_node_exporter"
    local ne_pods
    ne_pods=$(_pods_running "app=prometheus-node-exporter" "$NAMESPACE")
    if (( ne_pods > 0 )); then
        echo "${__STEP_OK__} test_node_exporter (${ne_pods} pod(s) Running)"
    else
        echo "${__STEP_FAIL__} test_node_exporter: 0 pods Running"
        ok=1
    fi

    echo "${__STEP_START__} test_kube_state_metrics"
    local ksm_pods
    ksm_pods=$(_pods_running "app=kube-state-metrics" "$NAMESPACE")
    if (( ksm_pods > 0 )); then
        echo "${__STEP_OK__} test_kube_state_metrics (${ksm_pods} pod(s) Running)"
    else
        echo "${__STEP_FAIL__} test_kube_state_metrics: 0 pods Running"
        ok=1
    fi

    echo "${__STEP_START__} test_services"
    local svc_count
    svc_count=$(_kubectl get svc -n "$NAMESPACE" -l sbos-managed=true \
        --no-headers 2>/dev/null | wc -l)
    if (( svc_count >= 2 )); then
        echo "${__STEP_OK__} test_services (${svc_count} servicios)"
    else
        echo "${__STEP_FAIL__} test_services: ${svc_count} < 2 servicios"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicies"
    local np_ok=0
    _kubectl get networkpolicy allow-intra-monitoring \
        -n "$NAMESPACE" > /dev/null 2>&1 && np_ok=$((np_ok+1))
    _kubectl get networkpolicy allow-monitoring-scrape \
        -n "$NAMESPACE" > /dev/null 2>&1 && np_ok=$((np_ok+1))
    if (( np_ok == 2 )); then
        echo "${__STEP_OK__} test_networkpolicies (intra-monitoring + scrape)"
    else
        echo "${__STEP_FAIL__} test_networkpolicies: $np_ok/2 presentes"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== sbos-bootstrap-monitoring STATUS ==="
    echo ""
    echo "Pods (${NAMESPACE}):"
    _kubectl get pods -n "$NAMESPACE" -l sbos-managed=true \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready,IMAGE:.spec.containers[0].image' \
        2>/dev/null || echo "  (ninguno)"
    echo ""
    echo "Services:"
    _kubectl get svc -n "$NAMESPACE" -l sbos-managed=true \
        --no-headers 2>/dev/null \
        | awk '{printf "  %-35s %-10s %s\n", $1, $2, $5}' \
        || echo "  (ninguno)"
    echo ""
    echo "NetworkPolicies:"
    _kubectl get networkpolicy -n "$NAMESPACE" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__STEP_START__} eliminar_componentes"
    _kubectl delete daemonset prometheus-node-exporter \
        -n "$NAMESPACE" 2>/dev/null || true
    _kubectl delete deployment kube-state-metrics \
        -n "$NAMESPACE" 2>/dev/null || true
    _kubectl delete service prometheus-node-exporter kube-state-metrics \
        -n "$NAMESPACE" 2>/dev/null || true
    _kubectl delete networkpolicy allow-intra-monitoring allow-monitoring-scrape \
        -n "$NAMESPACE" 2>/dev/null || true
    _kubectl delete clusterrole sbos-monitoring-reader 2>/dev/null || true
    _kubectl delete clusterrolebinding sbos-monitoring-reader 2>/dev/null || true
    _kubectl delete serviceaccount sbos-monitoring \
        -n "$NAMESPACE" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_componentes"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico sbos-bootstrap-monitoring ==="
    echo "Pods en ${NAMESPACE}:"
    _kubectl get pods -n "$NAMESPACE" -o wide 2>/dev/null || true
    echo ""
    echo "DaemonSet node-exporter:"
    _kubectl describe daemonset prometheus-node-exporter \
        -n "$NAMESPACE" 2>/dev/null | grep -E "Desired|Ready|Available|Image:" || true
    echo ""
    echo "Deployment kube-state-metrics:"
    _kubectl describe deployment kube-state-metrics \
        -n "$NAMESPACE" 2>/dev/null | grep -E "Desired|Ready|Available|Image:" || true
    echo ""
    echo "Eventos recientes (${NAMESPACE}):"
    _kubectl get events -n "$NAMESPACE" \
        --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
