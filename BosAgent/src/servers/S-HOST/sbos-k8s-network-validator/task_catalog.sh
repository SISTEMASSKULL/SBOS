#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — sbos-k8s-network-validator
# Certifica tres condiciones antes de instalar PostgreSQL:
#   1. CoreDNS: kubernetes.default.svc.cluster.local resuelve
#   2. Pod-to-pod: dos pods en sbos-data se comunican por red
#   3. StorageClass: local-path provisiona un PVC 1Mi y lo binda
#
# Si cualquiera falla, PostgreSQL y el stack completo NO pueden instalarse.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/sbos-k8s-network-validator.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
TEST_NS="sbos-data"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [sbos-k8s-network-validator] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _wait_pod_running: espera hasta que un pod tenga STATUS=Running.
_wait_pod_running() {
    local pod="$1" ns="$2" timeout="${3:-60}" elapsed=0
    while (( elapsed < timeout )); do
        local phase
        phase=$(_k get pod "$pod" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        [[ "$phase" == "Running" ]] && return 0
        sleep 3; elapsed=$((elapsed + 3))
    done
    _log "TIMEOUT: pod $pod no Running después de ${timeout}s"
    return 1
}

# _cleanup_test_resources: elimina todos los recursos temporales de validación.
_cleanup_test_resources() {
    _k delete pod sbos-net-test-a sbos-net-test-b -n "$TEST_NS" --ignore-not-found=true > /dev/null 2>&1 || true
    _k delete pvc sbos-validator-pvc -n "$TEST_NS" --ignore-not-found=true > /dev/null 2>&1 || true
    _k delete pv sbos-validator-pv --ignore-not-found=true > /dev/null 2>&1 || true
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_namespaces"
    if ! _k get namespace "$TEST_NS" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_namespaces: namespace $TEST_NS no existe — ejecutar sbos-bootstrap-platform primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_namespaces"

    echo "${__STEP_START__} verificar_storageclass"
    if ! _k get storageclass local-path > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_storageclass: local-path no existe — ejecutar sbos-bootstrap-platform primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_storageclass"
    return 0
}

# ── Install (= validar) ───────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # Verificar si ya fue validado exitosamente (idempotencia)
    if _k get configmap sbos-network-validated -n "$TEST_NS" > /dev/null 2>&1; then
        local ts
        ts=$(_k get configmap sbos-network-validated -n "$TEST_NS" \
            -o jsonpath='{.data.validated_at}' 2>/dev/null || echo "?")
        echo "${__STEP_SKIP__} validacion_red: ya validado en ${ts} — skip"
        return 0
    fi

    # Limpiar recursos anteriores que puedan quedar de un intento fallido
    _cleanup_test_resources

    # ── TEST 1: CoreDNS ───────────────────────────────────────────
    echo "${__STEP_START__} test_coredns"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: sbos-net-test-a
  namespace: ${TEST_NS}
  labels:
    sbos.app/validator: "true"
spec:
  restartPolicy: Never
  containers:
    - name: net
      image: busybox:1.36
      command: ["sh", "-c", "nslookup kubernetes.default.svc.cluster.local && echo DNS_OK"]
EOF

    if ! _wait_pod_running sbos-net-test-a "$TEST_NS" 60; then
        echo "${__STEP_FAIL__} test_coredns: pod de prueba no arrancó en 60s"
        _cleanup_test_resources
        return 1
    fi

    local dns_elapsed=0
    while (( dns_elapsed < 30 )); do
        local dns_out
        dns_out=$(_k logs sbos-net-test-a -n "$TEST_NS" 2>/dev/null || echo "")
        if echo "$dns_out" | grep -q "DNS_OK"; then
            _log "CoreDNS OK"
            break
        fi
        local phase
        phase=$(_k get pod sbos-net-test-a -n "$TEST_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [[ "$phase" == "Succeeded" ]] || [[ "$phase" == "Failed" ]]; then
            break
        fi
        sleep 2; dns_elapsed=$((dns_elapsed + 2))
    done

    local final_out
    final_out=$(_k logs sbos-net-test-a -n "$TEST_NS" 2>/dev/null || echo "")
    if ! echo "$final_out" | grep -q "DNS_OK"; then
        _log "CoreDNS output: $final_out"
        echo "${__STEP_FAIL__} test_coredns: nslookup kubernetes.default no resolvió"
        _cleanup_test_resources
        return 1
    fi
    _k delete pod sbos-net-test-a -n "$TEST_NS" --ignore-not-found=true > /dev/null 2>&1 || true
    echo "${__STEP_OK__} test_coredns"

    # ── TEST 2: Pod-to-pod ────────────────────────────────────────
    echo "${__STEP_START__} test_pod_to_pod"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF_SERVER'
apiVersion: v1
kind: Pod
metadata:
  name: sbos-net-test-a
  namespace: sbos-data
  labels:
    sbos.app/validator: "true"
    sbos.app/validator-role: server
spec:
  restartPolicy: Never
  containers:
    - name: server
      image: busybox:1.36
      command: ["sh", "-c", "nc -lp 9999 -e echo PONG"]
EOF_SERVER

    if ! _wait_pod_running sbos-net-test-a "$TEST_NS" 60; then
        echo "${__STEP_FAIL__} test_pod_to_pod: pod servidor no arrancó"
        _cleanup_test_resources
        return 1
    fi

    local pod_a_ip
    pod_a_ip=$(_k get pod sbos-net-test-a -n "$TEST_NS" -o jsonpath='{.status.podIP}' 2>/dev/null || echo "")
    if [[ -z "$pod_a_ip" ]]; then
        echo "${__STEP_FAIL__} test_pod_to_pod: pod-a no tiene IP asignada"
        _cleanup_test_resources
        return 1
    fi
    _log "Pod-A IP: $pod_a_ip"

    _k run sbos-net-test-b \
        --image=busybox:1.36 \
        --restart=Never \
        --namespace="$TEST_NS" \
        --labels="sbos.app/validator=true" \
        --command -- sh -c "sleep 5 && echo PING | nc -w3 ${pod_a_ip} 9999 && echo P2P_OK" \
        >> "$FICHA_LOG" 2>&1

    if ! _wait_pod_running sbos-net-test-b "$TEST_NS" 60; then
        echo "${__STEP_FAIL__} test_pod_to_pod: pod cliente no arrancó"
        _cleanup_test_resources
        return 1
    fi

    local p2p_elapsed=0
    while (( p2p_elapsed < 30 )); do
        local p2p_out
        p2p_out=$(_k logs sbos-net-test-b -n "$TEST_NS" 2>/dev/null || echo "")
        if echo "$p2p_out" | grep -q "P2P_OK"; then
            _log "Pod-to-pod OK"
            break
        fi
        local phase
        phase=$(_k get pod sbos-net-test-b -n "$TEST_NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
        if [[ "$phase" == "Succeeded" ]] || [[ "$phase" == "Failed" ]]; then
            break
        fi
        sleep 2; p2p_elapsed=$((p2p_elapsed + 2))
    done

    local p2p_final
    p2p_final=$(_k logs sbos-net-test-b -n "$TEST_NS" 2>/dev/null || echo "")
    _k delete pod sbos-net-test-a sbos-net-test-b -n "$TEST_NS" --ignore-not-found=true > /dev/null 2>&1 || true
    if ! echo "$p2p_final" | grep -q "P2P_OK"; then
        _log "Pod-to-pod output: $p2p_final"
        echo "${__STEP_FAIL__} test_pod_to_pod: pods no pudieron comunicarse"
        return 1
    fi
    echo "${__STEP_OK__} test_pod_to_pod"

    # ── TEST 3: StorageClass dinámica ─────────────────────────────
    echo "${__STEP_START__} test_storageclass_dinamica"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF_PVC'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sbos-validator-pvc
  namespace: sbos-data
  labels:
    sbos.app/validator: "true"
spec:
  accessModes: [ReadWriteOnce]
  storageClassName: local-path
  resources:
    requests:
      storage: 1Mi
EOF_PVC

    # Necesitamos un pod consumidor para que WaitForFirstConsumer haga el bind
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<'EOF_CONSUMER'
apiVersion: v1
kind: Pod
metadata:
  name: sbos-net-test-a
  namespace: sbos-data
  labels:
    sbos.app/validator: "true"
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: busybox:1.36
      command: ["sh", "-c", "echo STORAGE_OK > /data/test && cat /data/test"]
      volumeMounts:
        - name: test-vol
          mountPath: /data
  volumes:
    - name: test-vol
      persistentVolumeClaim:
        claimName: sbos-validator-pvc
EOF_CONSUMER

    local sc_elapsed=0
    local sc_ok=0
    while (( sc_elapsed < 60 )); do
        local pvc_phase
        pvc_phase=$(_k get pvc sbos-validator-pvc -n "$TEST_NS" \
            -o jsonpath='{.status.phase}' 2>/dev/null || echo "Pending")
        if [[ "$pvc_phase" == "Bound" ]]; then
            sc_ok=1
            _log "PVC bound en ${sc_elapsed}s"
            break
        fi
        sleep 3; sc_elapsed=$((sc_elapsed + 3))
    done

    _cleanup_test_resources

    if (( sc_ok == 0 )); then
        echo "${__STEP_FAIL__} test_storageclass_dinamica: PVC no Bound en 60s (local-path provisioner fallo)"
        return 1
    fi
    echo "${__STEP_OK__} test_storageclass_dinamica"

    # ── Marcar validación exitosa ─────────────────────────────────
    echo "${__STEP_START__} registrar_validacion"
    local ts
    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    _k create configmap sbos-network-validated \
        -n "$TEST_NS" \
        --from-literal="validated_at=${ts}" \
        --from-literal="tests_passed=dns,pod_to_pod,storageclass" \
        >> "$FICHA_LOG" 2>&1 || \
    _k patch configmap sbos-network-validated \
        -n "$TEST_NS" \
        --type=merge \
        -p "{\"data\":{\"validated_at\":\"${ts}\",\"tests_passed\":\"dns,pod_to_pod,storageclass\"}}" \
        >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} registrar_validacion (ts=${ts})"

    _log "Validación completa: DNS ✓ | Pod-to-pod ✓ | StorageClass ✓"
    return 0
}

# ── Verify ────────────────────────────────────────────────────────
ficha_verify() {
    echo "${__STEP_START__} verificar_marker"
    if ! _k get configmap sbos-network-validated -n "$TEST_NS" > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_marker: ConfigMap sbos-network-validated no existe — red no validada"
        return 1
    fi
    local tests
    tests=$(_k get configmap sbos-network-validated -n "$TEST_NS" \
        -o jsonpath='{.data.tests_passed}' 2>/dev/null || echo "")
    echo "${__STEP_OK__} verificar_marker: tests_passed=${tests}"
    return 0
}

# ── Repair ───────────────────────────────────────────────────────
ficha_repair() {
    _log "ficha_repair: eliminando marker y re-ejecutando validación de red"
    _k delete configmap sbos-network-validated -n "$TEST_NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1 || true
    ficha_install
}

# ── Test ─────────────────────────────────────────────────────────
ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_marker_validacion"
    if _k get configmap sbos-network-validated -n "$TEST_NS" > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_marker_validacion (ConfigMap sbos-network-validated presente)"
    else
        echo "${__STEP_FAIL__} test_marker_validacion: ConfigMap no encontrado — red no validada"
        ok=1
    fi

    echo "${__STEP_START__} test_coredns_activo"
    local dns_pods
    dns_pods=$(_k get pods -n kube-system -l k8s-app=kube-dns --no-headers 2>/dev/null | grep -c Running || echo "0")
    if (( dns_pods >= 1 )); then
        echo "${__STEP_OK__} test_coredns_activo ($dns_pods pods Running)"
    else
        echo "${__STEP_FAIL__} test_coredns_activo: CoreDNS no disponible"; ok=1
    fi
    return $ok
}

# ── Health ────────────────────────────────────────────────────────
ficha_health() {
    if _k get configmap sbos-network-validated -n "$TEST_NS" > /dev/null 2>&1; then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: red no validada"
    return 1
}

# ── Remove ────────────────────────────────────────────────────────
ficha_remove() {
    echo "${__STEP_START__} eliminar_marker"
    _k delete configmap sbos-network-validated -n "$TEST_NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} eliminar_marker"
    return 0
}
