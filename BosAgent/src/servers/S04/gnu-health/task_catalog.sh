#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — gnu-health
# GNU Health 4.4 — EHR/HIS soberano basado en Tryton.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/gnu-health.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-erp"
GH_VERSION="${GH_VERSION:-4.4}"
DOMAIN="${BOS_DOMAIN:-sksistemas.com}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [gnu-health] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_deploy_ready() {
    local d="$1" n="$2" t="${3:-240}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment "$d" -n "$n" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 8; e=$((e+8)); (( e % 40 == 0 )) && _log "Esperando $d... ${e}/${t}s"
    done; return 1
}

ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespace"
    _k get namespace "$NS" > /dev/null 2>&1 || {
        echo "${__STEP_FAIL__} verificar_namespace: namespace $NS no existe"
        return 1
    }
    echo "${__STEP_OK__} verificar_namespace"
}

ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /data/gnu-health

    local ready
    ready=$(_k get deployment gnu-health -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} gnu_health_install: ya Ready — skip"
        return 0
    fi

    # Crear BD gnu-health si no existe
    echo "${__STEP_START__} crear_db_gnuhealth"
    local pg_pod
    pg_pod=$(kubectl --kubeconfig="$KUBECONFIG_DEST" get pod -n sbos-data -l app=postgresql \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "postgresql-0")
    kubectl --kubeconfig="$KUBECONFIG_DEST" exec -n sbos-data "$pg_pod" -- bash -c "
        psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname='gnuhealth'\" | grep -q 1 ||
        psql -U postgres -c \"CREATE DATABASE gnuhealth OWNER postgres;\"
    " >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} crear_db_gnuhealth"

    echo "${__STEP_START__} aplicar_manifests_gnuhealth"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sbos-gnuhealth-pv
  labels:
    sbos.app/managed-by: bos
spec:
  capacity:
    storage: 20Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /data/gnu-health
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    namespace: ${NS}
    name: gnuhealth-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: gnuhealth-data
  namespace: ${NS}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests:
      storage: 20Gi
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: gnuhealth-config
  namespace: ${NS}
data:
  trytond.conf: |
    [database]
    uri = postgresql://postgres@postgresql.sbos-data.svc.cluster.local:5432/
    path = /var/lib/tryton
    [web]
    listen = 0.0.0.0:8000
    [bus]
    long_polling_timeout = 300
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gnu-health
  namespace: ${NS}
  labels:
    app: gnu-health
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: gnu-health
  template:
    metadata:
      labels:
        app: gnu-health
    spec:
      initContainers:
        - name: wait-tryton
          image: busybox:1.36
          command: ['sh', '-c', 'until nc -z tryton.sbos-erp.svc.cluster.local 8000; do sleep 5; done']
      containers:
        - name: gnu-health
          image: gnuhealth/gnuhealth:${GH_VERSION}
          env:
            - name: DB_HOST
              value: "postgresql.sbos-data.svc.cluster.local"
            - name: DB_PORT
              value: "5432"
            - name: DB_NAME
              value: "gnuhealth"
            - name: DB_USER
              value: "postgres"
          ports:
            - containerPort: 8000
          volumeMounts:
            - name: data
              mountPath: /var/lib/tryton
            - name: config
              mountPath: /etc/tryton
          resources:
            requests:
              cpu: "200m"
              memory: "512Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /
              port: 8000
            initialDelaySeconds: 60
            periodSeconds: 15
            failureThreshold: 15
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: gnuhealth-data
        - name: config
          configMap:
            name: gnuhealth-config
---
apiVersion: v1
kind: Service
metadata:
  name: gnu-health
  namespace: ${NS}
spec:
  selector:
    app: gnu-health
  ports:
    - name: http
      port: 8000
      targetPort: 8000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gnu-health-ingress
  namespace: ${NS}
  annotations:
    konghq.com/strip-path: "false"
    konghq.com/protocols: "https"
spec:
  ingressClassName: kong
  rules:
    - host: "salud.${DOMAIN}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: gnu-health
                port:
                  number: 8000
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-gnuhealth-ingress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: gnu-health
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
      ports:
        - port: 8000
EOF
    echo "${__STEP_OK__} aplicar_manifests_gnuhealth"

    echo "${__STEP_START__} esperar_gnuhealth_ready"
    _wait_deploy_ready gnu-health "$NS" 240 || {
        echo "${__STEP_FAIL__} esperar_gnuhealth_ready: timeout 240s"
        return 1
    }
    echo "${__STEP_OK__} esperar_gnuhealth_ready"
    return 0
}

ficha_repair() {
    _log "Repair gnu-health: verificando deployment"
    local ready
    ready=$(_k get deployment gnu-health -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready < 1 )); then
        _log "gnu-health caído — re-ejecutando install"
        ficha_install
    else
        _log "gnu-health OK (ready=$ready)"
    fi
}

ficha_status() {
    local ready
    ready=$(_k get deployment gnu-health -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    echo "gnu-health ready=$ready"
}

ficha_remove() {
    _log "Eliminando gnu-health"
    _k delete deployment,service,ingress -l app=gnu-health -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} gnu_health_remove"
}
