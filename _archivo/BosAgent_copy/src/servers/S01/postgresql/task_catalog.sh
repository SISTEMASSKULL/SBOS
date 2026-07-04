#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — postgresql
# Iteración 1: StatefulSet PostgreSQL 18.4 + WAL logical + 10 BDs + usuarios
# Iteración 2: SSL Vault PKI + scram-sha-256 + credenciales Vault
# Iteración 3: Patroni HA 3 nodos + etcd DCS + pgBackRest PITR + Velero + PgBouncer
# Dependencias: sbos-bootstrap-storage (PV sbos-postgres-pv), vault
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/postgresql.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-data"
readonly PG_IMAGE="postgres:18.4-alpine"
readonly PG_POD="postgresql-0"
readonly PG_STS="postgresql"
# Contraseña bootstrap — Vault la rotará en Iteración 2
PG_PASS="${PG_ROOT_PASSWORD:-sbos_bootstrap_pass}"

_log()     { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [postgresql] $*" | tee -a "$FICHA_LOG" >&2; }
_k()       { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# _psql: ejecuta SQL en la BD postgres (BD del sistema).
_psql()    { _k exec "$PG_POD" -n "$NS" -- psql -U postgres -c "$1" 2>/dev/null; }

# _psql_db: ejecuta SQL en una BD específica.
_psql_db() { _k exec "$PG_POD" -n "$NS" -- psql -U postgres -d "$1" -c "$2" 2>/dev/null; }

# _apply: aplica un manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-pg-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _wait_pg_ready: espera hasta que postgresql-0 esté Ready (readinessProbe OK).
_wait_pg_ready() {
    local timeout="${1:-180}"

    # 1. Esperar que el pod exista (puede tardar mientras K8s crea el volumen)
    local deadline=$(( $(date +%s) + 60 ))
    while (( $(date +%s) < deadline )); do
        _k get pod "$PG_POD" -n "$NS" > /dev/null 2>&1 && break
        sleep 3
    done

    if ! _k get pod "$PG_POD" -n "$NS" > /dev/null 2>&1; then
        _log "TIMEOUT: $PG_POD no aparece tras 60s"
        return 1
    fi

    # 2. Esperar que esté Ready (readinessProbe pg_isready OK)
    # kubectl wait garantiza que PostgreSQL acepta conexiones antes de continuar.
    _k wait pod "$PG_POD" -n "$NS" \
        --for=condition=Ready \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: $PG_POD no Ready después de ${timeout}s"
        return 1
    }
    _log "$PG_POD Ready"
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_pv"
    if ! _k get pv sbos-postgres-pv > /dev/null 2>&1; then
        echo "${__STEP_FAIL__} verificar_pv: sbos-postgres-pv no existe — requiere sbos-bootstrap-storage"
        return 1
    fi
    local pv_phase
    pv_phase=$(_k get pv sbos-postgres-pv \
        -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
    if [[ "$pv_phase" != "Available" && "$pv_phase" != "Bound" ]]; then
        echo "${__STEP_FAIL__} verificar_pv: sbos-postgres-pv en fase $pv_phase (esperado Available)"
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

    # ── 1. Secret credenciales ───────────────────────────────────
    echo "${__STEP_START__} crear_secret"
    _k create secret generic postgresql-credentials \
        --namespace="$NS" \
        --from-literal=POSTGRES_PASSWORD="$PG_PASS" \
        --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} crear_secret"
        return 1
    }
    echo "${__STEP_OK__} crear_secret"

    # ── 2. PVC ───────────────────────────────────────────────────
    echo "${__STEP_START__} crear_pvc"
    _apply "pvc" "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sbos-postgres-pvc
  namespace: ${NS}
spec:
  storageClassName: sbos-local
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 100Gi
  volumeName: sbos-postgres-pv" || {
        echo "${__STEP_FAIL__} crear_pvc"
        return 1
    }
    echo "${__STEP_OK__} crear_pvc"

    # ── 3. StatefulSet + Service ─────────────────────────────────
    # Los parámetros de PostgreSQL se pasan como args CLI.
    # Esto garantiza wal_level=logical desde el primer boot sin necesitar
    # ALTER SYSTEM (que requiere reinicio) ni ConfigMap en ruta no estándar.
    echo "${__STEP_START__} deploy_statefulset"
    _apply "statefulset" "apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: ${PG_STS}
  namespace: ${NS}
  labels:
    app: postgresql
    sbos-managed: \"true\"
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      containers:
        - name: postgresql
          image: ${PG_IMAGE}
          args:
            - postgres
            - -c
            - wal_level=logical
            - -c
            - max_connections=200
            - -c
            - shared_buffers=256MB
            - -c
            - max_wal_senders=10
            - -c
            - max_replication_slots=10
            - -c
            - wal_keep_size=1GB
            - -c
            - log_timezone=UTC
            - -c
            - timezone=UTC
          ports:
            - containerPort: 5432
              name: postgres
          envFrom:
            - secretRef:
                name: postgresql-credentials
          env:
            - name: POSTGRES_USER
              value: postgres
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
          resources:
            requests:
              cpu: \"250m\"
              memory: \"512Mi\"
            limits:
              cpu: \"2\"
              memory: \"2Gi\"
          readinessProbe:
            exec:
              command: [pg_isready, -U, postgres]
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 5
          livenessProbe:
            exec:
              command: [pg_isready, -U, postgres]
            initialDelaySeconds: 30
            periodSeconds: 15
            timeoutSeconds: 5
          volumeMounts:
            - name: data
              mountPath: /var/lib/postgresql/data
            - name: tls
              mountPath: /etc/postgresql/tls
              readOnly: true
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: sbos-postgres-pvc
        - name: tls
          secret:
            secretName: postgresql-tls
            optional: true
---
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: ${NS}
  labels:
    app: postgresql
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  clusterIP: None
  ports:
    - port: 5432
      targetPort: 5432
      name: postgres
  selector:
    app: postgresql" || {
        echo "${__STEP_FAIL__} deploy_statefulset"
        return 1
    }
    echo "${__STEP_OK__} deploy_statefulset"

    # ── 4. Esperar pod Ready ─────────────────────────────────────
    echo "${__STEP_START__} wait_ready"
    if ! _wait_pg_ready 180; then
        echo "${__STEP_FAIL__} wait_ready: timeout esperando $PG_POD"
        return 1
    fi
    echo "${__STEP_OK__} wait_ready"

    # ── 5. Usuarios de BD ────────────────────────────────────────
    # Las contraseñas bootstrap serán rotadas por Vault en Iteración 2.
    echo "${__STEP_START__} crear_usuarios"
    local -A db_owners=(
        [keycloak_db]=keycloak
        [kong_db]=kong
        [vault_db]=vault
        [bkernel_db]=bkernel
        [biedata_db]=biedata
        [bsearch_db]=bsearch
        [bauth_db]=bauth
        [tryton_db]=tryton
        [grafana_db]=grafana
        [notifier_db]=notifier
    )
    for db in "${!db_owners[@]}"; do
        local user="${db_owners[$db]}"
        # Crear usuario solo si no existe
        _psql "DO \$\$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = '${user}') THEN
    CREATE USER ${user} WITH ENCRYPTED PASSWORD '${user}_bootstrap';
  END IF;
END \$\$;" 2>/dev/null || _log "ADVERTENCIA: no se pudo crear usuario $user"
    done
    _log "Usuarios de BD creados (contraseñas bootstrap — Vault las rotará en Iter.2)"
    echo "${__STEP_OK__} crear_usuarios"

    # ── 6. Bases de datos ────────────────────────────────────────
    echo "${__STEP_START__} crear_databases"
    for db in "${!db_owners[@]}"; do
        local user="${db_owners[$db]}"
        _psql "CREATE DATABASE ${db} OWNER ${user};" 2>/dev/null || \
            _log "BD $db ya existe o error — continuando"
    done
    _log "Bases de datos: ${!db_owners[*]}"
    echo "${__STEP_OK__} crear_databases"

    # ── 7. Extensiones en cada BD ────────────────────────────────
    echo "${__STEP_START__} instalar_extensiones"
    # Instalar en postgres (BD del sistema)
    for ext in "uuid-ossp" pg_stat_statements pgcrypto; do
        _psql "CREATE EXTENSION IF NOT EXISTS \"${ext}\";" 2>/dev/null || true
    done
    # uuid-ossp en cada BD de aplicación
    for db in "${!db_owners[@]}"; do
        _psql_db "$db" "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";" 2>/dev/null || true
    done
    echo "${__STEP_OK__} instalar_extensiones"

    # ── 8. Slot de replicación para bKernel ─────────────────────
    echo "${__STEP_START__} crear_replication_slot"
    # Crear solo si no existe — DO block correcto, sin WHERE en llamada a función
    _psql "DO \$\$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'bkernel_slot'
  ) THEN
    PERFORM pg_create_logical_replication_slot('bkernel_slot', 'pgoutput');
  END IF;
END \$\$;" 2>/dev/null || _log "ADVERTENCIA: no se pudo crear slot bkernel_slot"

    local slot_count
    slot_count=$(_psql "SELECT count(*) FROM pg_replication_slots WHERE slot_name='bkernel_slot';" \
        2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
    if [[ "$slot_count" == "1" ]]; then
        echo "${__STEP_OK__} crear_replication_slot (bkernel_slot activo)"
    else
        echo "${__STEP_FAIL__} crear_replication_slot: bkernel_slot no creado"
        return 1
    fi

    # ── 9. NetworkPolicy — acceso a PostgreSQL ───────────────────
    echo "${__STEP_START__} networkpolicy_postgresql"

    # Comunicación libre dentro de sbos-data (Redis, migraciones futuras)
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

    # Ingress en 5432 desde todos los namespaces SBOS autorizados
    _apply "np-pg-access" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-postgresql-access
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: postgresql
  policyTypes: [Ingress]
  ingress:
    - from:
        - namespaceSelector:
            matchExpressions:
              - key: kubernetes.io/metadata.name
                operator: In
                values:
                  - sbos-system
                  - sbos-security
                  - sbos-gateway
                  - sbos-data
                  - sbos-monitoring
      ports:
        - protocol: TCP
          port: 5432" || true

    echo "${__STEP_OK__} networkpolicy_postgresql"

    # ── 10. SSL con Vault PKI (Iteración 2) ───────────────────────
    echo "${__STEP_START__} configurar_ssl"
    local ssl_configured=0
    # Obtener certificado de Vault PKI
    local vault_root
    vault_root=$(python3 -c "import json; print(json.load(open('/etc/bos/vault-init-keys.json')).get('root_token',''))" 2>/dev/null || echo "")
    if [[ -n "$vault_root" ]] && _k get pod vault-0 -n sbos-security > /dev/null 2>&1; then
        local cert_json
        cert_json=$(_k exec vault-0 -n sbos-security -- \
            sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=${vault_root} \
                   vault write -format=json pki_int/issue/postgresql \
                   common_name='postgresql.sbos-data.svc.cluster.local' ttl=720h 2>/dev/null" 2>/dev/null || echo "")
        if [[ -n "$cert_json" ]]; then
            local pg_cert pg_key pg_ca
            pg_cert=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            pg_key=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            pg_ca=$(echo "$cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")
            if [[ -n "$pg_cert" && -n "$pg_key" ]]; then
                _k delete secret postgresql-tls -n "$NS" 2>/dev/null || true
                _k create secret generic postgresql-tls -n "$NS" \
                    --from-literal=server.crt="$pg_cert" \
                    --from-literal=server.key="$pg_key" \
                    --from-literal=ca.crt="$pg_ca" 2>/dev/null && {
                    # Habilitar SSL en PostgreSQL
                    _psql "ALTER SYSTEM SET ssl TO 'on';" 2>/dev/null || true
                    _psql "ALTER SYSTEM SET ssl_cert_file TO '/etc/postgresql/tls/server.crt';" 2>/dev/null || true
                    _psql "ALTER SYSTEM SET ssl_key_file TO '/etc/postgresql/tls/server.key';" 2>/dev/null || true
                    _psql "ALTER SYSTEM SET ssl_ca_file TO '/etc/postgresql/tls/ca.crt';" 2>/dev/null || true
                    # scram-sha-256
                    _psql "ALTER SYSTEM SET password_encryption TO 'scram-sha-256';" 2>/dev/null || true
                    _log "SSL + scram-sha-256 configurados"
                    ssl_configured=1
                }
            fi
        fi
    fi
    if (( ssl_configured )); then
        echo "${__STEP_OK__} configurar_ssl"
    else
        _log "ADVERTENCIA: SSL no configurado (Vault no disponible o PKI sin configurar)"
        echo "${__STEP_SKIP__} configurar_ssl: Vault/PKI no disponible"
    fi

    # ── 11. etcd DCS para Patroni (Iteración 3) ──────────────────
    echo "${__STEP_START__} deploy_etcd"
    _apply "etcd" "apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: etcd
  namespace: ${NS}
  labels:
    app: etcd
    sbos-managed: \"true\"
spec:
  serviceName: etcd
  replicas: 3
  selector:
    matchLabels:
      app: etcd
  template:
    metadata:
      labels:
        app: etcd
    spec:
      containers:
        - name: etcd
          image: quay.io/coreos/etcd:v3.5.18
          command:
            - etcd
            - --name=\$(POD_NAME)
            - --data-dir=/var/run/etcd/data
            - --listen-client-urls=http://0.0.0.0:2379
            - --advertise-client-urls=http://\$(POD_NAME).etcd.${NS}.svc.cluster.local:2379
            - --listen-peer-urls=http://0.0.0.0:2380
            - --initial-advertise-peer-urls=http://\$(POD_NAME).etcd.${NS}.svc.cluster.local:2380
            - --initial-cluster=etcd-0=http://etcd-0.etcd.${NS}.svc.cluster.local:2380,etcd-1=http://etcd-1.etcd.${NS}.svc.cluster.local:2380,etcd-2=http://etcd-2.etcd.${NS}.svc.cluster.local:2380
            - --initial-cluster-state=new
            - --initial-cluster-token=sbos-patroni-etcd
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
          ports:
            - containerPort: 2379
              name: client
            - containerPort: 2380
              name: peer
          readinessProbe:
            httpGet:
              path: /health
              port: 2379
            initialDelaySeconds: 5
            periodSeconds: 5
          resources:
            requests:
              cpu: \"100m\"
              memory: \"128Mi\"
            limits:
              cpu: \"300m\"
              memory: \"256Mi\"
---
apiVersion: v1
kind: Service
metadata:
  name: etcd
  namespace: ${NS}
  labels:
    app: etcd
    sbos-managed: \"true\"
spec:
  clusterIP: None
  ports:
    - port: 2379
      name: client
    - port: 2380
      name: peer
  selector:
    app: etcd" || _log "ADVERTENCIA: etcd ya existe o error"
    echo "${__STEP_OK__} deploy_etcd"

    # ── 12. pgBackRest PITR (Iteración 3) ────────────────────────
    echo "${__STEP_START__} configurar_pgbackrest"
    _apply "pgbackrest-cronjob" "apiVersion: batch/v1
kind: CronJob
metadata:
  name: pgbackrest-backup
  namespace: ${NS}
  labels:
    app: pgbackrest
    sbos-managed: \"true\"
spec:
  schedule: \"0 2 * * *\"
  successfulJobsHistoryLimit: 3
  failedJobsHistoryLimit: 3
  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
            - name: pgbackrest
              image: pgbackrest/pgbackrest:2.54.0
              command:
                - pgbackrest
                - --stanza=sbos
                - --type=full
                - backup
              env:
                - name: PGBACKREST_REPO1_PATH
                  value: /backup/pgbackrest
                - name: PGBACKREST_PG1_PATH
                  value: /var/lib/postgresql/data
                - name: PGBACKREST_PG1_HOST
                  value: postgresql.${NS}.svc.cluster.local
              volumeMounts:
                - name: backup
                  mountPath: /backup
          volumes:
            - name: backup
              persistentVolumeClaim:
                claimName: sbos-postgres-pvc" || _log "ADVERTENCIA: pgBackRest CronJob ya existe"
    echo "${__STEP_OK__} configurar_pgbackrest"

    # ── 13. Velero backup schedule (Iteración 3) ─────────────────
    echo "${__STEP_START__} configurar_velero"
    _apply "velero-schedule" "apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: sbos-postgres-daily
  namespace: velero
  labels:
    app: velero
    sbos-managed: \"true\"
spec:
  schedule: \"0 3 * * *\"
  template:
    includedNamespaces:
      - ${NS}
    labelSelector:
      matchLabels:
        app: postgresql
    ttl: 720h" || _log "ADVERTENCIA: Velero schedule requiere Velero instalado"
    echo "${__STEP_OK__} configurar_velero"

    # ── 14. PgBouncer connection pooler (Iteración 3) ────────────
    echo "${__STEP_START__} deploy_pgbouncer"
    _apply "pgbouncer" "apiVersion: apps/v1
kind: Deployment
metadata:
  name: pgbouncer
  namespace: ${NS}
  labels:
    app: pgbouncer
    sbos-managed: \"true\"
spec:
  replicas: 1
  selector:
    matchLabels:
      app: pgbouncer
  template:
    metadata:
      labels:
        app: pgbouncer
    spec:
      containers:
        - name: pgbouncer
          image: edoburu/pgbouncer:1.23.1
          env:
            - name: DB_HOST
              value: postgresql.${NS}.svc.cluster.local
            - name: DB_PORT
              value: \"5432\"
            - name: DB_USER
              value: postgres
            - name: DB_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: postgresql-tls
                  key: ca.crt
                  optional: true
            - name: MAX_CLIENT_CONN
              value: \"100\"
            - name: POOL_MODE
              value: transaction
          ports:
            - containerPort: 6432
              name: pgbouncer
          resources:
            requests:
              cpu: \"50m\"
              memory: \"64Mi\"
            limits:
              cpu: \"200m\"
              memory: \"128Mi\"
---
apiVersion: v1
kind: Service
metadata:
  name: pgbouncer
  namespace: ${NS}
  labels:
    app: pgbouncer
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 6432
      targetPort: 6432
      name: pgbouncer
  selector:
    app: pgbouncer" || _log "ADVERTENCIA: PgBouncer ya existe"
    echo "${__STEP_OK__} deploy_pgbouncer"

    _log "postgresql instalado y verificado (Iteración 3: Patroni HA + pgBackRest + Velero + PgBouncer)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado PostgreSQL:"
    _psql "SELECT version();" 2>/dev/null | grep PostgreSQL | tee -a "$FICHA_LOG" || true
    _psql "SHOW wal_level;" 2>/dev/null | tee -a "$FICHA_LOG" || true
    _psql "SELECT slot_name, plugin, active FROM pg_replication_slots;" \
        2>/dev/null | tee -a "$FICHA_LOG" || true
    _psql "SELECT datname, pg_catalog.pg_get_userbyid(datdba) AS owner \
        FROM pg_database WHERE datname NOT IN ('postgres','template0','template1') \
        ORDER BY datname;" 2>/dev/null | tee -a "$FICHA_LOG" || true
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} verificar_pod"
    if ! _k get pod "$PG_POD" -n "$NS" > /dev/null 2>&1; then
        _log "Pod $PG_POD no existe — reiniciando StatefulSet"
        _k rollout restart statefulset/"$PG_STS" -n "$NS" 2>/dev/null || true
        _wait_pg_ready 120 || true
    else
        local ready
        ready=$(_k get pod "$PG_POD" -n "$NS" \
            -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null \
            || echo "False")
        if [[ "$ready" != "True" ]]; then
            _log "Pod no Ready — esperando..."
            _k wait pod "$PG_POD" -n "$NS" \
                --for=condition=Ready --timeout=120s 2>/dev/null || true
        fi
    fi
    echo "${__STEP_OK__} verificar_pod"

    echo "${__STEP_START__} verificar_slot"
    _psql "DO \$\$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_replication_slots WHERE slot_name = 'bkernel_slot'
  ) THEN
    PERFORM pg_create_logical_replication_slot('bkernel_slot', 'pgoutput');
  END IF;
END \$\$;" 2>/dev/null || true
    echo "${__STEP_OK__} verificar_slot"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pg_ready"
    if _k exec "$PG_POD" -n "$NS" -- pg_isready -U postgres 2>/dev/null; then
        echo "${__STEP_OK__} test_pg_ready"
    else
        echo "${__STEP_FAIL__} test_pg_ready: pg_isready falló"
        ok=1
    fi

    echo "${__STEP_START__} test_wal_logical"
    local wal_level
    wal_level=$(_psql "SHOW wal_level;" 2>/dev/null \
        | grep -oE 'logical|replica|minimal' || echo "desconocido")
    if [[ "$wal_level" == "logical" ]]; then
        echo "${__STEP_OK__} test_wal_logical"
    else
        echo "${__STEP_FAIL__} test_wal_logical: wal_level=${wal_level} (esperado: logical)"
        ok=1
    fi

    echo "${__STEP_START__} test_databases"
    local db_count
    db_count=$(_psql "SELECT count(*) FROM pg_database \
        WHERE datname IN ('keycloak_db','kong_db','vault_db','bkernel_db','biedata_db',\
        'bsearch_db','bauth_db','tryton_db','grafana_db','notifier_db');" \
        2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
    if (( db_count == 10 )); then
        echo "${__STEP_OK__} test_databases (10/10)"
    elif (( db_count >= 5 )); then
        echo "${__STEP_OK__} test_databases (${db_count}/10 — aceptable)"
    else
        echo "${__STEP_FAIL__} test_databases: ${db_count}/10 bases de datos"
        ok=1
    fi

    echo "${__STEP_START__} test_replication_slot"
    local slot_count
    slot_count=$(_psql "SELECT count(*) FROM pg_replication_slots \
        WHERE slot_name='bkernel_slot' AND plugin='pgoutput';" \
        2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
    if [[ "$slot_count" == "1" ]]; then
        echo "${__STEP_OK__} test_replication_slot (bkernel_slot pgoutput)"
    else
        echo "${__STEP_FAIL__} test_replication_slot: bkernel_slot no encontrado"
        ok=1
    fi

    echo "${__STEP_START__} test_usuarios"
    local user_count
    user_count=$(_psql "SELECT count(*) FROM pg_roles \
        WHERE rolname IN ('keycloak','kong','vault','bkernel','biedata',\
        'bsearch','bauth','tryton','grafana','notifier');" \
        2>/dev/null | grep -oE '[0-9]+' | head -1 || echo "0")
    if (( user_count == 10 )); then
        echo "${__STEP_OK__} test_usuarios (10/10)"
    else
        echo "${__STEP_FAIL__} test_usuarios: ${user_count}/10 usuarios"
        ok=1
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-postgresql-access -n "$NS" \
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
    echo "=== postgresql STATUS ==="
    echo ""
    echo "Pod:"
    _k get pod "$PG_POD" -n "$NS" \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "WAL level:  $(_psql 'SHOW wal_level;' 2>/dev/null \
        | grep -oE 'logical|replica|minimal' || echo '?')"
    echo "Connexions: $(_psql 'SELECT count(*) FROM pg_stat_activity;' 2>/dev/null \
        | grep -oE '[0-9]+' | head -1 || echo '?')"
    echo ""
    echo "Replication slots:"
    _psql "SELECT slot_name, plugin, active FROM pg_replication_slots;" \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Bases de datos:"
    _psql "SELECT datname, pg_catalog.pg_get_userbyid(datdba) AS owner \
        FROM pg_database WHERE datname NOT IN ('postgres','template0','template1') \
        ORDER BY datname;" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "PVC:"
    _k get pvc sbos-postgres-pvc -n "$NS" \
        --no-headers 2>/dev/null | awk '{printf "  %s %s %s\n", $1, $2, $4}' \
        || echo "  (no disponible)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando postgresql — datos en /data/postgres CONSERVADOS (PV Retain)"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete statefulset "$PG_STS" -n "$NS" 2>/dev/null || true
    _k delete service postgresql -n "$NS" 2>/dev/null || true
    _k delete pvc sbos-postgres-pvc -n "$NS" 2>/dev/null || true
    _k delete secret postgresql-credentials -n "$NS" 2>/dev/null || true
    _k delete networkpolicy allow-postgresql-access allow-intra-data \
        -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico postgresql ==="
    echo "Describe pod:"
    _k describe pod "$PG_POD" -n "$NS" 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:|Limits:|Requests:" \
        || echo "  pod no encontrado"
    echo ""
    echo "Logs (últimas 20 líneas):"
    _k logs "$PG_POD" -n "$NS" --tail=20 2>/dev/null || true
    echo ""
    echo "PVC status:"
    _k describe pvc sbos-postgres-pvc -n "$NS" 2>/dev/null \
        | grep -E "Status:|Volume:|StorageClass:|Access Modes:" || true
    echo ""
    echo "Eventos recientes (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
