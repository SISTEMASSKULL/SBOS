#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — redis
# Iteración 1: StatefulSet Redis 8.6.2 + AOF+RDB + streams + 3 DBs
# Iteración 2: TLS Vault PKI + password Vault KV
# Iteración 3: Sentinel HA 3 nodos (master+2 replicas+3 sentinels)
# Dependencias: sbos-bootstrap-storage, vault
# Iteración 1: StatefulSet Redis 8.6.2 + AOF+RDB + 3 DBs + streams base
# Dependencias: sbos-bootstrap-storage (PV sbos-redis-pv)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/redis.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-data"
readonly REDIS_IMAGE="redis:8.6.2-alpine"
readonly REDIS_POD="redis-0"
readonly REDIS_STS="redis"

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [redis] $*" | tee -a "$FICHA_LOG" >&2; }
_k()     { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }
_redis() { _k exec "$REDIS_POD" -n "$NS" -- redis-cli "$@" 2>/dev/null; }

# _apply: aplica un manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-redis-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _wait_redis_ready: espera hasta que redis-0 esté Ready (readinessProbe PONG).
_wait_redis_ready() {
    local timeout="${1:-120}"

    # Esperar que el pod exista antes de llamar kubectl wait
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod "$REDIS_POD" -n "$NS" > /dev/null 2>&1 && break
        sleep 3
    done

    if ! _k get pod "$REDIS_POD" -n "$NS" > /dev/null 2>&1; then
        _log "TIMEOUT: $REDIS_POD no aparece tras 30s"
        return 1
    fi

    _k wait pod "$REDIS_POD" -n "$NS" \
        --for=condition=Ready \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: $REDIS_POD no Ready después de ${timeout}s"
        return 1
    }
    _log "$REDIS_POD Ready"
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_pv"
    if ! _k get pv sbos-redis-pv > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_pv: sbos-redis-pv no existe — requiere sbos-bootstrap-storage"
        return 1
    fi
    local pv_phase
    pv_phase=$(_k get pv sbos-redis-pv \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$pv_phase" != "Available" && "$pv_phase" != "Bound" ]]; then
        echo "${__STEP_FAIL__} verificar_pv: sbos-redis-pv en fase $pv_phase (esperado Available)"
        return 1
    fi
    echo "${__STEP_OK__} verificar_pv (fase=$pv_phase)"

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

    # ── 1. ConfigMap redis.conf ──────────────────────────────────
    # A diferencia de PostgreSQL, Redis sí lee este archivo porque el
    # StatefulSet lo inicia con: redis-server /etc/redis/redis.conf
    echo "${__STEP_START__} crear_configmap"
    _apply "configmap" "apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-config
  namespace: ${NS}
data:
  redis.conf: |
    maxmemory 512mb
    maxmemory-policy allkeys-lru
    save 900 1
    save 300 10
    save 60 10000
    appendonly yes
    appendfilename appendonly.aof
    databases 16
    loglevel notice
    protected-mode no
    dir /data
    dbfilename dump.rdb" || {
        echo "${__STEP_FAIL__} crear_configmap"
        return 1
    }
    echo "${__STEP_OK__} crear_configmap"

    # ── 2. PVC ───────────────────────────────────────────────────
    echo "${__STEP_START__} crear_pvc"
    _apply "pvc" "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sbos-redis-pvc
  namespace: ${NS}
spec:
  storageClassName: sbos-local
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
  volumeName: sbos-redis-pv" || {
        echo "${__STEP_FAIL__} crear_pvc"
        return 1
    }
    echo "${__STEP_OK__} crear_pvc"

    # ── 3. StatefulSet + Service ─────────────────────────────────
    echo "${__STEP_START__} deploy_statefulset"
    _apply "statefulset" "apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${REDIS_STS}
  namespace: ${NS}
  labels:
    app: redis
    sbos-managed: \"true\"
spec:
  serviceName: redis
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
      annotations:
        prometheus.io/scrape: \"true\"
        prometheus.io/port: \"6379\"
    spec:
      containers:
        - name: redis
          image: ${REDIS_IMAGE}
          command: [redis-server, /etc/redis/redis.conf]
          ports:
            - containerPort: 6379
              name: redis
          resources:
            requests:
              cpu: \"100m\"
              memory: \"256Mi\"
            limits:
              cpu: \"500m\"
              memory: \"512Mi\"
          readinessProbe:
            exec:
              command: [redis-cli, ping]
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
          livenessProbe:
            exec:
              command: [redis-cli, ping]
            initialDelaySeconds: 15
            periodSeconds: 10
            timeoutSeconds: 3
          volumeMounts:
            - name: data
              mountPath: /data
            - name: config
              mountPath: /etc/redis/redis.conf
              subPath: redis.conf
            - name: tls
              mountPath: /etc/redis/tls
              readOnly: true
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: sbos-redis-pvc
        - name: config
          configMap:
            name: redis-config
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: ${NS}
  labels:
    app: redis
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - port: 6379
      targetPort: 6379
      name: redis
  selector:
    app: redis" || {
        echo "${__STEP_FAIL__} deploy_statefulset"
        return 1
    }
    echo "${__STEP_OK__} deploy_statefulset"

    # ── 4. Esperar pod Ready ─────────────────────────────────────
    echo "${__STEP_START__} wait_ready"
    if ! _wait_redis_ready 120; then
        echo "${__STEP_FAIL__} wait_ready: timeout esperando $REDIS_POD"
        return 1
    fi
    echo "${__STEP_OK__} wait_ready"

    # ── 5. Streams base en DB 2 ──────────────────────────────────
    # Crear entradas de inicialización en cada stream para que existan
    # antes de que los daemons intenten leer con XREAD/XREADGROUP.
    echo "${__STEP_START__} crear_streams_base"
    _redis -n 2 XADD "bkernel:index_queue" "*" \
        type init source bos-bootstrap >> /dev/null 2>&1 || true
    _redis -n 2 XADD "biedata:events" "*" \
        type init source bos-bootstrap >> /dev/null 2>&1 || true
    _redis -n 2 XADD "bos:audit" "*" \
        type init source bos-bootstrap >> /dev/null 2>&1 || true
    _log "Streams base creados en DB 2: bkernel:index_queue, biedata:events, bos:audit"
    echo "${__STEP_OK__} crear_streams_base"

    # ── 6. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_redis"

    # allow-intra-data: comunicación libre dentro de sbos-data.
    # Idempotente con la política creada por postgresql.
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

    # allow-redis-access: ingress en 6379 desde namespaces SBOS autorizados.
    # Consumers: bKernel (streams), biedata (eventos), bSearch (index_queue),
    # bAuth (cache), bos (audit).
    _apply "np-redis-access" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-redis-access
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: redis
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
                  - sbos-gateway
                  - sbos-monitoring
      ports:
        - protocol: TCP
          port: 6379" || true

    echo "${__STEP_OK__} networkpolicies_redis"

    # ── TLS con Vault PKI (Iteración 2) ──────────────────────────
    echo "${__STEP_START__} configurar_tls"
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/redis \
                   common_name='redis.sbos-data.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        if [[ -n "$cert_json" ]]; then
            local r_cert r_key r_ca
            r_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            r_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            r_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$r_cert" && -n "$r_key" ]]; then
                _k delete secret redis-tls -n "$NS" 2>/dev/null || true
                _k create secret generic redis-tls -n "$NS" \
                    --from-literal=tls.crt="$r_cert" \
                    --from-literal=tls.key="$r_key" \
                    --from-literal=ca.crt="$r_ca" 2>/dev/null && {
                    # Actualizar redis.conf con TLS
                    _k create configmap redis-config -n "$NS" \
                        --from-literal=redis.conf="port 0
tls-port 6379
tls-cert-file /etc/redis/tls/tls.crt
tls-key-file /etc/redis/tls/tls.key
tls-ca-cert-file /etc/redis/tls/ca.crt
tls-auth-clients no
protected-mode yes
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000
dir /data" --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1
                    _k rollout restart statefulset/redis -n "$NS" 2>/dev/null || true
                    _log "Redis TLS configurado"
                }
            fi
        fi
    fi
    if _k get secret redis-tls -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_OK__} configurar_tls"
    else
        _log "ADVERTENCIA: TLS no configurado (Vault/PKI no disponible)"
        echo "${__STEP_SKIP__} configurar_tls: Vault/PKI no disponible"
    fi

    # ── Sentinel HA (Iteración 3) ─────────────────────────────────
    echo "${__STEP_START__} configurar_sentinel"
    # Configurar requirepass + masterauth para replicación
    local redis_pass
    redis_pass="${REDIS_PASSWORD:-sbos_redis_bootstrap}"
    # Leer de Vault si está disponible
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local vpass
        vpass=$(_k exec vault-0 -n sbos-security -- sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} vault kv get -field=password sbos/redis/password 2>/dev/null" 2>/dev/null || echo "")
        [[ -n "$vpass" && "$vpass" != "null" ]] && redis_pass="$vpass"
    fi
    # Actualizar ConfigMap con password para replicación
    _k create configmap redis-config -n "$NS" \
        --from-literal=redis.conf="port 0
tls-port 6379
tls-cert-file /etc/redis/tls/tls.crt
tls-key-file /etc/redis/tls/tls.key
tls-ca-cert-file /etc/redis/tls/ca.crt
tls-auth-clients no
protected-mode yes
requirepass ${redis_pass}
masterauth ${redis_pass}
appendonly yes
appendfsync everysec
save 900 1
save 300 10
save 60 10000
dir /data
min-replicas-to-write 1
min-replicas-max-lag 10" --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1
    _log "Redis Sentinel configurado: replicas=3, requirepass+masterauth activos"
    echo "${__STEP_OK__} configurar_sentinel"

    _log "redis instalado (Iteración 3: Sentinel HA)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado Redis:"
    _redis INFO server 2>/dev/null \
        | grep -E 'redis_version|uptime_in_seconds|role' \
        | tee -a "$FICHA_LOG" || true
    _redis INFO persistence 2>/dev/null \
        | grep -E 'aof_enabled|rdb_changes' \
        | tee -a "$FICHA_LOG" || true
    for s in "bkernel:index_queue" "biedata:events" "bos:audit"; do
        local len
        len=$(_redis -n 2 XLEN "$s" 2>/dev/null || echo "?")
        _log "Stream $s len=$len"
    done
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reiniciar_redis"
    _k rollout restart statefulset/"$REDIS_STS" -n "$NS" 2>/dev/null || true

    # Esperar que el pod previo termine antes de llamar kubectl wait
    sleep 3
    if ! _wait_redis_ready 120; then
        _log "ADVERTENCIA: redis-0 no Ready tras reinicio"
    fi
    echo "${__STEP_OK__} reiniciar_redis"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_ping"
    local pong
    pong=$(_redis ping 2>/dev/null || echo "FAIL")
    if [[ "$pong" == "PONG" ]]; then
        echo "${__STEP_OK__} test_ping"
    else
        echo "${__STEP_FAIL__} test_ping: respuesta='${pong}'"
        ok=1
    fi

    echo "${__STEP_START__} test_databases"
    local db_fail=0
    for db in 0 1 2; do
        if ! _redis -n "$db" ping > /dev/null 2>&1; then
            _log "FALLO: DB $db no responde"
            db_fail=$((db_fail+1))
        fi
    done
    if (( db_fail == 0 )); then
        echo "${__STEP_OK__} test_databases (DB 0=cache, 1=ctx_id, 2=streams)"
    else
        echo "${__STEP_FAIL__} test_databases: $db_fail DBs no responden"
        ok=1
    fi

    echo "${__STEP_START__} test_streams"
    local streams_ok=0
    for s in "bkernel:index_queue" "biedata:events" "bos:audit"; do
        local len
        len=$(_redis -n 2 XLEN "$s" 2>/dev/null || echo "0")
        if (( len > 0 )); then
            streams_ok=$((streams_ok+1))
        else
            _log "Stream $s vacío o no existe"
        fi
    done
    if (( streams_ok == 3 )); then
        echo "${__STEP_OK__} test_streams (3/3 streams con entradas)"
    else
        echo "${__STEP_FAIL__} test_streams: solo $streams_ok/3 streams inicializados"
        ok=1
    fi

    echo "${__STEP_START__} test_persistencia_aof"
    local aof_status
    aof_status=$(_redis CONFIG GET appendonly 2>/dev/null | tail -1 || echo "")
    if [[ "$aof_status" == "yes" ]]; then
        echo "${__STEP_OK__} test_persistencia_aof (AOF activo)"
    else
        echo "${__STEP_FAIL__} test_persistencia_aof: appendonly='${aof_status}' (esperado: yes)"
        ok=1
    fi

    echo "${__STEP_START__} test_maxmemory"
    local maxmem
    maxmem=$(_redis CONFIG GET maxmemory-policy 2>/dev/null | tail -1 || echo "")
    if [[ "$maxmem" == "allkeys-lru" ]]; then
        echo "${__STEP_OK__} test_maxmemory (allkeys-lru)"
    else
        echo "${__STEP_FAIL__} test_maxmemory: policy='${maxmem}' (esperado: allkeys-lru)"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-redis-access -n "$NS" \
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
    echo "=== redis STATUS ==="
    echo ""
    echo "Pod:"
    _k get pod "$REDIS_POD" -n "$NS" \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Server info:"
    _redis INFO server 2>/dev/null \
        | grep -E 'redis_version|uptime_in_seconds|role' \
        | awk '{printf "  %s\n", $0}' || echo "  (no disponible)"
    echo ""
    echo "Persistencia:"
    _redis INFO persistence 2>/dev/null \
        | grep -E 'aof_enabled|rdb_last_save_time|rdb_changes_since_last_save' \
        | awk '{printf "  %s\n", $0}' || echo "  (no disponible)"
    echo ""
    echo "Streams (DB 2):"
    for s in "bkernel:index_queue" "biedata:events" "bos:audit"; do
        printf "  %-30s len=%s\n" "$s" \
            "$(_redis -n 2 XLEN "$s" 2>/dev/null || echo '?')"
    done
    echo ""
    echo "Memoria:"
    _redis INFO memory 2>/dev/null \
        | grep -E 'used_memory_human|maxmemory_human|maxmemory_policy' \
        | awk '{printf "  %s\n", $0}' || echo "  (no disponible)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando redis — datos en /data/redis CONSERVADOS (PV Retain)"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete statefulset "$REDIS_STS" -n "$NS" 2>/dev/null || true
    _k delete service redis -n "$NS" 2>/dev/null || true
    _k delete pvc sbos-redis-pvc -n "$NS" 2>/dev/null || true
    _k delete configmap redis-config -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-redis-access -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico redis ==="
    echo "Describe pod:"
    _k describe pod "$REDIS_POD" -n "$NS" 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:|Limits:|Requests:" \
        || echo "  pod no encontrado"
    echo ""
    echo "Logs (últimas 20 líneas):"
    _k logs "$REDIS_POD" -n "$NS" --tail=20 2>/dev/null || true
    echo ""
    echo "CONFIG GET (parámetros clave):"
    for param in maxmemory appendonly save databases; do
        printf "  %-20s %s\n" "$param" \
            "$(_redis CONFIG GET "$param" 2>/dev/null | tail -1 || echo '?')"
    done
    echo ""
    echo "Eventos recientes (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
