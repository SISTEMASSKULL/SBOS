#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — orangehrm
# OrangeHRM 5.7 — sistema RRHH corporativo soberano.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/orangehrm.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NS="sbos-erp"
OHR_VERSION="${OHR_VERSION:-5.7}"
DOMAIN="${BOS_DOMAIN:-empresa.com}"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [orangehrm] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

_wait_deploy_ready() {
    local d="$1" n="$2" t="${3:-180}" e=0
    while (( e < t )); do
        local r
        r=$(_k get deployment "$d" -n "$n" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        (( r >= 1 )) && return 0
        sleep 5; e=$((e+5)); (( e % 30 == 0 )) && _log "Esperando $d... ${e}/${t}s"
    done; return 1
}

_get_pg_pod() {
    _k get pod -n sbos-data -l app=postgresql \
        -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "postgresql-0"
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
    mkdir -p "$(dirname "$FICHA_LOG")" /data/orangehrm

    local ready
    ready=$(_k get deployment orangehrm -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready >= 1 )); then
        echo "${__STEP_SKIP__} orangehrm_install: ya Ready — skip"
        return 0
    fi

    # Crear BD orangehrm si no existe
    echo "${__STEP_START__} crear_schema_orangehrm"
    local pg_pod
    pg_pod=$(_get_pg_pod)
    _k exec -n sbos-data "$pg_pod" -- bash -c "
        psql -U postgres -tc \"SELECT 1 FROM pg_database WHERE datname='orangehrm'\" | grep -q 1 ||
        psql -U postgres -c \"CREATE DATABASE orangehrm OWNER postgres;\"
    " >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} crear_schema_orangehrm"

    echo "${__STEP_START__} aplicar_manifests_orangehrm"
    local pg_svc
    pg_svc=$(_k get service postgresql -n sbos-data -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "postgresql.sbos-data.svc.cluster.local")

    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
---
apiVersion: v1
kind: PersistentVolume
metadata:
  name: sbos-orangehrm-pv
  labels:
    sbos.app/managed-by: bos
spec:
  capacity:
    storage: 15Gi
  accessModes: [ReadWriteOnce]
  persistentVolumeReclaimPolicy: Retain
  storageClassName: ""
  hostPath:
    path: /data/orangehrm
  claimRef:
    apiVersion: v1
    kind: PersistentVolumeClaim
    namespace: ${NS}
    name: orangehrm-data
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: orangehrm-data
  namespace: ${NS}
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: ""
  resources:
    requests:
      storage: 15Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orangehrm
  namespace: ${NS}
  labels:
    app: orangehrm
    sbos.app/managed-by: bos
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orangehrm
  template:
    metadata:
      labels:
        app: orangehrm
    spec:
      initContainers:
        - name: wait-db
          image: busybox:1.36
          command: ['sh', '-c', 'until nc -z postgresql.sbos-data.svc.cluster.local 5432; do sleep 3; done']
      containers:
        - name: orangehrm
          image: bitnami/orangehrm:${OHR_VERSION}
          env:
            - name: ORANGEHRM_DATABASE_HOST
              value: "postgresql.sbos-data.svc.cluster.local"
            - name: ORANGEHRM_DATABASE_PORT_NUMBER
              value: "5432"
            - name: ORANGEHRM_DATABASE_NAME
              value: "orangehrm"
            - name: ORANGEHRM_DATABASE_USER
              value: "postgres"
            - name: ORANGEHRM_DATABASE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: sbos-pg-secret
                  key: password
                  optional: true
            - name: ORANGEHRM_ADMIN_USER
              value: "${SBOS_ADMIN_USER:-admin}"
            - name: ORANGEHRM_SMTP_HOST
              value: "mailserver.sbos-comms.svc.cluster.local"
            - name: ORANGEHRM_SMTP_PORT
              value: "587"
          ports:
            - containerPort: 80
          volumeMounts:
            - name: data
              mountPath: /bitnami/orangehrm
          resources:
            requests:
              cpu: "50m"
              memory: "256Mi"
            limits:
              cpu: "1000m"
              memory: "1Gi"
          readinessProbe:
            httpGet:
              path: /
              port: 80
            initialDelaySeconds: 60
            periodSeconds: 15
            failureThreshold: 10
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: orangehrm-data
---
apiVersion: v1
kind: Service
metadata:
  name: orangehrm
  namespace: ${NS}
spec:
  selector:
    app: orangehrm
  ports:
    - name: http
      port: 80
      targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: orangehrm-ingress
  namespace: ${NS}
  annotations:
    konghq.com/strip-path: "false"
    konghq.com/protocols: "https"
spec:
  ingressClassName: kong
  rules:
    - host: "rrhh.${DOMAIN}"
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: orangehrm
                port:
                  number: 80
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-orangehrm-ingress
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: orangehrm
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: sbos-gateway
      ports:
        - port: 80
EOF
    echo "${__STEP_OK__} aplicar_manifests_orangehrm"

    echo "${__STEP_START__} esperar_orangehrm_ready"
    _wait_deploy_ready orangehrm "$NS" 180 || {
        echo "${__STEP_FAIL__} esperar_orangehrm_ready: timeout 180s"
        return 1
    }
    echo "${__STEP_OK__} esperar_orangehrm_ready"
    return 0
}

ficha_repair() {
    _log "Repair orangehrm: verificando deployment"
    local ready
    ready=$(_k get deployment orangehrm -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if (( ready < 1 )); then
        _log "orangehrm caído — re-ejecutando install"
        ficha_install
    else
        _log "orangehrm OK (ready=$ready)"
    fi
}

ficha_status() {
    local ready
    ready=$(_k get deployment orangehrm -n "$NS" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    echo "orangehrm ready=$ready"
}

ficha_remove() {
    _log "Eliminando orangehrm"
    _k delete deployment,service,ingress -l app=orangehrm -n "$NS" --ignore-not-found >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} orangehrm_remove"
}
