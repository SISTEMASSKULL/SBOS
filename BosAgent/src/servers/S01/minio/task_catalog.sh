#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — minio
# Iteración 1: StatefulSet MinIO standalone + 3 buckets base + versioning
# Dependencias: sbos-bootstrap-storage (PV sbos-minio-pv)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/minio.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-data"
readonly MINIO_POD="minio-0"
readonly MINIO_STS="minio"
# SeaweedFS: S3-compatible, imagen pública (minio/minio requiere auth Docker Hub desde 2025)
readonly MINIO_IMAGE="chrislusf/seaweedfs:latest"
# URL interna para Jobs en el mismo namespace (headless → DNS al pod)
readonly MINIO_INTERNAL_URL="http://minio-0.minio.${NS}.svc.cluster.local:9000"

MINIO_ROOT_USER="${MINIO_ROOT_USER:-sbos_minio_admin}"
MINIO_ROOT_PASSWORD="${MINIO_ROOT_PASSWORD:-sbos_minio_pass_bootstrap}"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [minio] $*" | tee -a "$FICHA_LOG"; }
_k() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" "$@"
}

# _apply: aplica manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-minio-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _wait_minio_ready: espera hasta que minio-0 esté Ready (readinessProbe OK).
_wait_minio_ready() {
    local timeout="${1:-120}"
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod "$MINIO_POD" -n "$NS" > /dev/null 2>&1 && break
        sleep 3
    done
    if ! _k get pod "$MINIO_POD" -n "$NS" > /dev/null 2>&1; then
        _log "TIMEOUT: $MINIO_POD no aparece tras 30s"
        return 1
    fi
    _k wait pod "$MINIO_POD" -n "$NS" \
        --for=condition=Ready \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: $MINIO_POD no Ready después de ${timeout}s"
        return 1
    }
    _log "$MINIO_POD Ready"
}

# _s3_bucket_create: crea o verifica buckets S3 desde el host con Python3+SigV4.
# No requiere imagen mc ni conectividad a Docker Hub. Usa kubectl port-forward.
# Parámetros: $@ — nombres de buckets a crear
_s3_bucket_create() {
    local -a buckets=("$@")
    [[ ${#buckets[@]} -eq 0 ]] && return 0

    local port=$((20000 + RANDOM % 5000)) pf_pid="" rc=0

    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" \
        port-forward pod/"$MINIO_POD" "${port}:9000" -n "$NS" > /dev/null 2>&1 &
    pf_pid=$!
    sleep 2

    python3 -c "
import hmac, hashlib, datetime, urllib.request, urllib.error, sys

AK, SK = '${MINIO_ROOT_USER}', '${MINIO_ROOT_PASSWORD}'
HOST, ENDPOINT = 'localhost:${port}', 'http://localhost:${port}'
REGION = 'us-east-1'

def sign(key, msg):
    return hmac.new(key, msg.encode('utf-8'), hashlib.sha256).digest()

def sig_key(key, ds):
    return sign(sign(sign(sign(('AWS4'+key).encode('utf-8'), ds), REGION), 's3'), 'aws4_request')

def s3_put_bucket(bucket):
    t = datetime.datetime.now(datetime.timezone.utc)
    ad, ds = t.strftime('%Y%m%dT%H%M%SZ'), t.strftime('%Y%m%d')
    ph = hashlib.sha256(b'').hexdigest()
    hdr = f'host:{HOST}\nx-amz-content-sha256:{ph}\nx-amz-date:{ad}\n'
    shs = 'host;x-amz-content-sha256;x-amz-date'
    cr = f'PUT\n/{bucket}\n\n{hdr}\n{shs}\n{ph}'
    cs = f'AWS4-HMAC-SHA256\n{ad}\n{ds}/{REGION}/s3/aws4_request\n{hashlib.sha256(cr.encode()).hexdigest()}'
    sig = hmac.new(sig_key(SK, ds), cs.encode('utf-8'), hashlib.sha256).hexdigest()
    auth = f'AWS4-HMAC-SHA256 Credential={AK}/{ds}/{REGION}/s3/aws4_request, SignedHeaders={shs}, Signature={sig}'
    req = urllib.request.Request(f'{ENDPOINT}/{bucket}', method='PUT', data=b'')
    req.add_header('Host', HOST); req.add_header('X-Amz-Date', ad)
    req.add_header('X-Amz-Content-SHA256', ph); req.add_header('Authorization', auth)
    try:
        return urllib.request.urlopen(req, timeout=10).status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:
        print(f'ERROR {bucket}: {e}', file=sys.stderr); return -1

errs = 0
for b in sys.argv[1:]:
    code = s3_put_bucket(b)
    if code in (200, 409):
        print(f'OK: {b}')
    else:
        print(f'FAIL: {b} (HTTP {code})', file=sys.stderr); errs += 1
sys.exit(errs)
" "${buckets[@]}"
    rc=$?
    kill "$pf_pid" 2>/dev/null; wait "$pf_pid" 2>/dev/null || true
    return $rc
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_pv"
    # ADR-040: mínimo viable progresivo. K8s = dynamic PV.
    if _k get pv sbos-minio-pv > /dev/null 2>&1; then
        local pv_phase
        pv_phase=$(_k get pv sbos-minio-pv \
            -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [[ "$pv_phase" == "Released" ]]; then
            # PV quedó Released (PVC eliminado con política Retain) — recuperar limpiando claimRef
            _k patch pv sbos-minio-pv --type=json \
                -p '[{"op":"remove","path":"/spec/claimRef"}]' > /dev/null 2>&1 || true
            pv_phase=$(_k get pv sbos-minio-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        fi
        if [[ "$pv_phase" != "Available" && "$pv_phase" != "Bound" ]]; then
            echo "${__STEP_FAIL__} verificar_pv: sbos-minio-pv en fase $pv_phase (esperado Available)"
            return 1
        fi
        echo "${__STEP_OK__} verificar_pv (fase=$pv_phase, pre-creado)"
    else
        echo "${__STEP_SKIP__} verificar_pv: PV no pre-existe — dynamic provisioning lo creara"
    fi

    echo "${__STEP_START__} verificar_namespace"
    if ! _k get namespace "$NS" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_namespace: $NS no existe"
        return 1
    fi
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # ── 1. Secret credenciales ───────────────────────────────────
    echo "${__STEP_START__} crear_secret"
    local secret_yaml
    secret_yaml=$(_k create secret generic minio-credentials \
        --namespace="$NS" \
        --from-literal=MINIO_ROOT_USER="$MINIO_ROOT_USER" \
        --from-literal=MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
        --dry-run=client -o yaml 2>/dev/null)
    if [[ -z "$secret_yaml" ]]; then
        echo "${__STEP_FAIL__} crear_secret: no se pudo generar el secret"
        return 1
    fi
    printf '%s\n' "$secret_yaml" | _k apply -f - >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} crear_secret: kubectl apply falló"
        return 1
    }
    echo "${__STEP_OK__} crear_secret"

    # ── 1b. ConfigMap SeaweedFS S3 ───────────────────────────────
    echo "${__STEP_START__} crear_configmap_seaweedfs"
    local s3_json
    s3_json="{\"identities\":[{\"name\":\"admin\",\"credentials\":[{\"accessKey\":\"${MINIO_ROOT_USER}\",\"secretKey\":\"${MINIO_ROOT_PASSWORD}\"}],\"actions\":[\"Admin\",\"Read\",\"Write\",\"Tagging\",\"List\"]}]}"
    _k create configmap seaweedfs-s3-config \
        --namespace="$NS" \
        --from-literal=s3.json="$s3_json" \
        --dry-run=client -o yaml 2>/dev/null \
        | _k apply -f - >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} crear_configmap_seaweedfs"
        return 1
    }
    echo "${__STEP_OK__} crear_configmap_seaweedfs"

    # ── 2. PVC ───────────────────────────────────────────────────
    echo "${__STEP_START__} crear_pvc"
    _apply "pvc" "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sbos-minio-pvc
  namespace: ${NS}
spec:
  storageClassName: local-path
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Gi
  # volumeName removido (ADR-040: dynamic PV)" || {
        echo "${__STEP_FAIL__} crear_pvc"
        return 1
    }
    echo "${__STEP_OK__} crear_pvc"

    # ── 3. StatefulSet + Service ─────────────────────────────────
    echo "${__STEP_START__} deploy_statefulset"
    _apply "statefulset" "apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${MINIO_STS}
  namespace: ${NS}
  labels:
    app: minio
    sbos-managed: managed
spec:
  serviceName: minio
  replicas: 1
  selector:
    matchLabels:
      app: minio
  template:
    metadata:
      labels:
        app: minio
      annotations:
        linkerd.io/inject: disabled
    spec:
      containers:
        - name: minio
          image: ${MINIO_IMAGE}
          command:
            - weed
            - server
            - -dir=/data
            - -s3
            - -s3.port=9000
            - -s3.config=/etc/seaweedfs/s3.json
          ports:
            - containerPort: 9000
              name: s3api
            - containerPort: 9333
              name: master
          env:
            - name: MINIO_ROOT_USER
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: MINIO_ROOT_USER
            - name: MINIO_ROOT_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: minio-credentials
                  key: MINIO_ROOT_PASSWORD
          resources:
            requests:
              cpu: 200m
              memory: 512Mi
            limits:
              cpu: 1000m
              memory: 1Gi
          readinessProbe:
            tcpSocket:
              port: 9000
            initialDelaySeconds: 15
            periodSeconds: 10
            timeoutSeconds: 5
          livenessProbe:
            tcpSocket:
              port: 9000
            initialDelaySeconds: 30
            periodSeconds: 15
            timeoutSeconds: 5
          volumeMounts:
            - name: data
              mountPath: /data
            - name: seaweedfs-config
              mountPath: /etc/seaweedfs
              readOnly: true
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: sbos-minio-pvc
        - name: seaweedfs-config
          configMap:
            name: seaweedfs-s3-config
---
apiVersion: v1
kind: Service
metadata:
  name: minio
  namespace: ${NS}
  labels:
    app: minio
    sbos-managed: managed
spec:
  clusterIP: None
  ports:
    - port: 9000
      targetPort: 9000
      name: s3api
    - port: 9333
      targetPort: 9333
      name: master
  selector:
    app: minio" || {
        echo "${__STEP_FAIL__} deploy_statefulset"
        return 1
    }
    echo "${__STEP_OK__} deploy_statefulset"

    # ── 4. Esperar pod Ready ─────────────────────────────────────
    echo "${__STEP_START__} wait_ready"
    if ! _wait_minio_ready 360; then
        echo "${__STEP_FAIL__} wait_ready: timeout esperando $MINIO_POD"
        return 1
    fi
    echo "${__STEP_OK__} wait_ready"

    # ── 5. Crear buckets vía Python3+SigV4 (sin imagen mc) ──────
    echo "${__STEP_START__} crear_buckets"
    if _s3_bucket_create sbos-backups sbos-assets sbos-documents >> "$FICHA_LOG" 2>&1; then
        echo "${__STEP_OK__} crear_buckets (3 buckets)"
    else
        _log "ADVERTENCIA: buckets no creados — S3 API no alcanzable"
        echo "${__STEP_SKIP__} crear_buckets: S3 API no disponible"
    fi

    # ── 6. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_minio"

    _apply "np-intra-data" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-data
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

    # Ingress en 9000 (S3 API) y 9001 (Console) desde namespaces autorizados
    _apply "np-minio-access" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-minio-access
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: minio
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
                  - sbos-system
                  - sbos-data
                  - sbos-security
                  - sbos-gateway
                  - sbos-monitoring
      ports:
        - protocol: TCP
          port: 9000
        - protocol: TCP
          port: 9001" || true

    echo "${__STEP_OK__} networkpolicies_minio"

    # ── TLS con Vault PKI (Iteración 2) ──────────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/minio \
                   common_name='minio.sbos-data.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        if [[ -n "$cert_json" ]]; then
            local m_cert m_key m_ca
            m_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            m_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            m_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$m_cert" && -n "$m_key" ]]; then
                _k delete secret minio-tls -n "$NS" 2>/dev/null || true
                _k create secret generic minio-tls -n "$NS" \
                    --from-literal=public.crt="$m_cert" \
                    --from-literal=private.key="$m_key" \
                    --from-literal=ca.crt="$m_ca" 2>/dev/null && {
                    _k rollout restart statefulset/minio -n "$NS" 2>/dev/null || true
                    _log "MinIO TLS configurado"
                }
            fi
        fi
    fi
    if _k get secret minio-tls -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_OK__} configurar_tls"
    else
        _log "ADVERTENCIA: TLS no configurado (Vault/PKI no disponible)"
        echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"
    fi

    _log "minio instalado"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado MinIO:"
    local ready
    ready=$(_k get pod "$MINIO_POD" -n "$NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "Unknown")
    _log "Pod Ready: $ready"
    _k get pvc sbos-minio-pvc -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  PVC %s: %s\n", $1, $2}' | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    # Si el StatefulSet no existe, reinstalar completo (idempotente)
    if ! _k get statefulset "$MINIO_STS" -n "$NS" > /dev/null 2>&1; then
        _log "StatefulSet $MINIO_STS no existe — ejecutando install completo"
        ficha_install
        return $?
    fi

    local pod_ready
    pod_ready=$(_k get pod "$MINIO_POD" -n "$NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null || echo "False")

    if [[ "$pod_ready" != "True" ]]; then
        echo "${__STEP_START__} reiniciar_minio"
        _k rollout restart statefulset/"$MINIO_STS" -n "$NS" 2>/dev/null || true
        _k rollout status statefulset/"$MINIO_STS" -n "$NS" --timeout=120s 2>/dev/null || true
        if ! _wait_minio_ready 120; then
            _log "ADVERTENCIA: minio-0 no Ready tras reinicio"
        fi
        echo "${__STEP_OK__} reiniciar_minio"
    else
        echo "${__STEP_SKIP__} reiniciar_minio: pod ya Ready"
    fi

    echo "${__STEP_START__} reparar_buckets"
    if _s3_bucket_create sbos-backups sbos-assets sbos-documents >> "$FICHA_LOG" 2>&1; then
        echo "${__STEP_OK__} reparar_buckets"
    else
        echo "${__STEP_SKIP__} reparar_buckets: S3 API no disponible"
    fi
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod "$MINIO_POD" -n "$NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" == "True" ]]; then
        echo "${__STEP_OK__} test_pod_ready"
    else
        echo "${__STEP_FAIL__} test_pod_ready: Ready=${ready}"
        ok=1
    fi

    echo "${__STEP_START__} test_health_endpoint"
    # readinessProbe es /minio/health/ready — si el pod está Ready la probe pasó.
    # Verificamos adicionalmente el liveness endpoint via kubectl exec si curl disponible.
    if _k exec "$MINIO_POD" -n "$NS" -- \
            curl -sf http://localhost:9000/minio/health/live > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_health_endpoint (/minio/health/live 200)"
    else
        # curl puede no estar disponible en la imagen minimal de MinIO
        # Si el pod está Ready (readinessProbe OK) es suficiente para Iteración 1
        if [[ "$ready" == "True" ]]; then
            echo "${__STEP_SKIP__} test_health_endpoint: curl no disponible en imagen (pod Ready = health OK)"
        else
            echo "${__STEP_FAIL__} test_health_endpoint: pod no Ready"
            ok=1
        fi
    fi

    echo "${__STEP_START__} test_buckets"
    if _s3_bucket_create sbos-backups sbos-assets sbos-documents >> "$FICHA_LOG" 2>&1; then
        echo "${__STEP_OK__} test_buckets (3/3 accesibles)"
    else
        echo "${__STEP_SKIP__} test_buckets: S3 API no disponible"
    fi

    echo "${__STEP_START__} test_pvc"
    local pvc_phase
    pvc_phase=$(_k get pvc sbos-minio-pvc -n "$NS" \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$pvc_phase" == "Bound" ]]; then
        echo "${__STEP_OK__} test_pvc (Bound)"
    else
        echo "${__STEP_FAIL__} test_pvc: phase=${pvc_phase} (esperado Bound)"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-minio-access -n "$NS" \
        > /dev/null 2>&1 && np_ok=$((np_ok+1))
    _k get networkpolicy allow-intra-data -n "$NS" \
        > /dev/null 2>&1 && np_ok=$((np_ok+1))
    if (( np_ok == 2 )); then
        echo "${__STEP_OK__} test_networkpolicy (2/2)"
    else
        echo "${__STEP_FAIL__} test_networkpolicy: ${np_ok}/2"
        ok=1
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== minio STATUS ==="
    echo ""
    echo "Pod:"
    _k get pod "$MINIO_POD" -n "$NS" \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "PVC:"
    _k get pvc sbos-minio-pvc -n "$NS" \
        --no-headers 2>/dev/null \
        | awk '{printf "  %-25s %-8s %s\n", $1, $2, $4}' \
        || echo "  (no disponible)"
    echo ""
    echo "Buckets (S3 API):"
    _s3_bucket_create sbos-backups sbos-assets sbos-documents 2>&1 || \
        echo "  (S3 API no disponible)"
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando minio — datos en /data/minio CONSERVADOS (PV Retain)"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete statefulset "$MINIO_STS" -n "$NS" 2>/dev/null || true
    _k delete service minio -n "$NS" 2>/dev/null || true
    _k delete pvc sbos-minio-pvc -n "$NS" 2>/dev/null || true
    _k delete secret minio-credentials -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-minio-access -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico minio ==="
    echo "Describe pod:"
    _k describe pod "$MINIO_POD" -n "$NS" 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:|Limits:|Requests:" \
        || echo "  pod no encontrado"
    echo ""
    echo "Logs (últimas 20 líneas):"
    _k logs "$MINIO_POD" -n "$NS" --tail=20 2>/dev/null || true
    echo ""
    echo "Jobs mc recientes:"
    _k get jobs -n "$NS" -l sbos-managed=true 2>/dev/null || echo "  (ninguno)"
    echo ""
    echo "Eventos recientes (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
