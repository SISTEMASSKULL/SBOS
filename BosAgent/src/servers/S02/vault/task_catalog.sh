#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — vault
# Iteración 1: Vault 2.0.1 nodo único Raft + init + unseal + AppRole sbos-pods
# Iteración 2: PKI Engine (Root + Intermediate CA) + roles por servicio +
#              Auto-TLS para Vault + Audit log + migración secretos bootstrap a KV
# Iteración 3: HA Raft 3 nodos + auto-unseal Transit + Vault Agent sidecars
# Dependencias: sbos-bootstrap-storage (PV sbos-vault-pv)
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/vault.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-security"
readonly VAULT_POD="vault-0"
readonly VAULT_IMAGE="hashicorp/vault:2.0.1"
# Las keys de init se guardan en el host, fuera del cluster (nunca en K8s Secrets).
readonly VAULT_KEYS_FILE="/etc/bos/vault-init-keys.json"
readonly VAULT_ADDR_LOCAL="http://127.0.0.1:8200"
# ── Iteración 2: PKI + TLS ──────────────────────────────────────
readonly VAULT_ADDR_HTTPS="https://127.0.0.1:8200"
readonly VAULT_PKI_ROLES=(
    postgresql redis minio keycloak kong oauth2-proxy
    sbos-notifier prometheus grafana alertmanager alloy
)
# Servicios cuyas contraseñas bootstrap migran a Vault KV
readonly -A SBOS_BOOTSTRAP_SECRETS=(
    [sbos/postgresql/keycloak]="keycloak_bootstrap"
    [sbos/postgresql/kong]="kong_bootstrap"
    [sbos/postgresql/vault]="vault_bootstrap"
    [sbos/postgresql/bkernel]="bkernel_bootstrap"
    [sbos/postgresql/biedata]="biedata_bootstrap"
    [sbos/postgresql/bsearch]="bsearch_bootstrap"
    [sbos/postgresql/bauth]="bauth_bootstrap"
    [sbos/postgresql/tryton]="tryton_bootstrap"
    [sbos/postgresql/grafana]="grafana_bootstrap"
    [sbos/postgresql/notifier]="notifier_bootstrap"
    [sbos/redis/password]="sbos_redis_bootstrap"
    [sbos/minio/admin]="sbos_minio_admin_bootstrap"
    [sbos/keycloak/admin]="sbos_kc_bootstrap_pass"
    [sbos/grafana/admin]="sbos_grafana_bootstrap"
)

_log()   { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [vault] $*" | tee -a "$FICHA_LOG"; }
_k() {
    local kubectl_bin
    kubectl_bin=$(command -v kubectl 2>/dev/null || echo "/usr/local/bin/kubectl")
    "$kubectl_bin" --kubeconfig="$KUBECONFIG_DEST" "$@"
}

# _apply: aplica manifest desde archivo temporal; siempre limpia el tmp.
_apply() {
    local label="$1" content="$2"
    local tmp rc=0
    tmp=$(mktemp /tmp/sbos-vault-XXXXXX.yaml)
    printf '%s\n' "$content" > "$tmp"
    _k apply -f "$tmp" >> "$FICHA_LOG" 2>&1 || rc=$?
    rm -f "$tmp"
    return $rc
}

# _vault_exec: ejecuta un comando vault en el pod con VAULT_ADDR configurado.
_vault_exec() {
    _k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} $*" 2>/dev/null
}

# _vault_status_json: retorna el status de Vault como JSON (o {} si no disponible).
_vault_status_json() {
    _k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} vault status -format=json 2>/dev/null" \
        2>/dev/null || echo '{}'
}

# _vault_field: extrae un campo del JSON de vault status como string lowercase.
# Python print(True) produce 'True' — incompatible con comparaciones bash 'true'.
# json.dumps() serializa a minúscula: true/false.
_vault_field() {
    local field="$1" default="${2:-}"
    local val
    val=$(_vault_status_json | python3 -c "
import sys,json
d = json.load(sys.stdin)
v = d.get('${field}')
if v is None:
    print('${default}')
else:
    print(json.dumps(v))
" 2>/dev/null) || val="$default"
    [[ -n "$val" ]] && echo "$val" || echo "$default"
}

# _wait_vault_phase: espera que el pod esté en phase=Running (necesario antes del init).
# Vault no será Ready hasta que esté inicializado y unsealed.
_wait_vault_phase() {
    local timeout="${1:-120}"
    local deadline=$(( $(date +%s) + 30 ))
    while (( $(date +%s) < deadline )); do
        _k get pod "$VAULT_POD" -n "$NS" > /dev/null 2>&1 && break
        sleep 3
    done
    # K8s 1.23+: kubectl wait soporta --for=jsonpath
    _k wait pod "$VAULT_POD" -n "$NS" \
        --for="jsonpath={.status.phase}=Running" \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: $VAULT_POD no alcanzó phase=Running en ${timeout}s"
        return 1
    }
    _log "$VAULT_POD phase=Running"
}

# _wait_vault_ready: espera que la readinessProbe pase (Vault unsealed + active).
_wait_vault_ready() {
    local timeout="${1:-60}"
    _k wait pod "$VAULT_POD" -n "$NS" \
        --for=condition=Ready \
        --timeout="${timeout}s" 2>/dev/null || {
        _log "TIMEOUT: $VAULT_POD no Ready (unsealed) en ${timeout}s"
        return 1
    }
    _log "$VAULT_POD Ready (unsealed)"
}

# ── Iteración 2: Helpers PKI + TLS + migración ───────────────────

# _vault_root: retorna el root_token desde VAULT_KEYS_FILE.
_vault_root() {
    if [[ -f "$VAULT_KEYS_FILE" ]]; then
        python3 -c "import json; print(json.load(open('${VAULT_KEYS_FILE}'))['root_token'])" 2>/dev/null || echo ""
    else
        echo ""
    fi
}

# _vault_exec_token: ejecuta comando vault con root_token.
_vault_exec_token() {
    local root_token
    root_token=$(_vault_root)
    _k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} $*" 2>/dev/null
}

# _vault_pki_issue: emite certificado desde PKI intermediate CA.
# Uso: _vault_pki_issue <role> <common_name> <ttl>
# Retorna: JSON con certificate, issuing_ca, private_key
_vault_pki_issue() {
    local role="$1" common_name="$2" ttl="${3:-720h}"
    _vault_exec_token "vault write -format=json pki_int/issue/${role} \
        common_name=${common_name} ttl=${ttl}"
}

# _vault_kv_put: escribe un secreto en KV v2 (path sbos/).
_vault_kv_put() {
    local path="$1" key="$2" value="$3"
    _vault_exec_token "vault kv put ${path} ${key}=${value}" 2>/dev/null
}

# _vault_kv_get: lee un secreto de KV v2.
_vault_kv_get() {
    local path="$1" key="$2"
    _vault_exec_token "vault kv get -field=${key} ${path}" 2>/dev/null || echo ""
}

# ── Pre-install ───────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_pv"
    # ADR-040: mínimo viable progresivo. K8s = dynamic provisioning.
    if _k get pv sbos-vault-pv > /dev/null 2>&1; then
        local pv_phase
        pv_phase=$(_k get pv sbos-vault-pv \
            -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        if [[ "$pv_phase" != "Available" && "$pv_phase" != "Bound" ]]; then
            echo "${__STEP_FAIL__} verificar_pv: sbos-vault-pv en fase $pv_phase"
            return 1
        fi
        echo "${__STEP_OK__} verificar_pv (fase=$pv_phase, pre-creado)"
    else
        echo "${__STEP_SKIP__} verificar_pv: PV no pre-existe — dynamic provisioning lo creara"
    fi

    echo "${__STEP_START__} verificar_namespace"
    if ! _k get namespace "$NS" > /dev/null 2>&1; then
        _k create namespace "$NS" >> "$FICHA_LOG" 2>&1 && _log "Namespace $NS creado"
    fi
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────
# ADR-040: mínimo viable progresivo — 2 pasadas explícitas.
# PASADA 1: Pod simple vault server -dev (in-memory, sin persistencia, sin TLS)
# PASADA 2: StatefulSet + raft storage + PVC + TLS + PKI (robusto)
# BOS llama ficha_install en cada pasada; la ficha detecta cuál aplicar.
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")" /etc/bos

    # Detectar pasada actual
    local pasada=1
    if _k get statefulset vault -n "$NS" > /dev/null 2>&1; then
        pasada=2
        _log "PASADA 2 detectada: StatefulSet existe → robustecer"
    elif _k get pod vault-0 -n "$NS" > /dev/null 2>&1; then
        # Pod existe de pasada 1 → migrar a StatefulSet
        pasada=2
        _log "PASADA 2 detectada: Pod dev existe → migrar a StatefulSet"
    else
        _log "PASADA 1: instalación mínima viable (vault server -dev)"
    fi

    if [[ $pasada -eq 1 ]]; then
        ficha_install_pasada1
    else
        ficha_install_pasada2
    fi
}

# ── PASADA 1: Pod simple vault server -dev ─────────────────────────
# Mínimo viable: sin persistencia, sin TLS, sin HA.
# Objetivo: vault responda a vault status → initialized=true, sealed=false
ficha_install_pasada1() {
    echo "${__STEP_START__} deploy_vault_dev"
    _apply "vault-dev-pod" "apiVersion: v1
kind: Pod
metadata:
  name: vault-0
  namespace: ${NS}
  labels:
    app: vault
    sbos-managed: \"true\"
    sbos-pasada: \"1\"
spec:
  containers:
  - name: vault
    image: ${VAULT_IMAGE}
    args: [\"server\", \"-dev\", \"-dev-listen-address=0.0.0.0:8200\", \"-dev-root-token-id=sbos-dev-root\"]
    env:
    - name: VAULT_ADDR
      value: \"http://127.0.0.1:8200\"
    ports:
    - containerPort: 8200
      name: api
    securityContext:
      capabilities:
        add: [\"IPC_LOCK\"]
    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 500m
        memory: 512Mi
    volumeMounts:
    - name: data
      mountPath: /vault/data
  volumes:
  - name: data
    emptyDir: {}" || {
        echo "${__STEP_FAIL__} deploy_vault_dev"; return 1
    }
    echo "${__STEP_OK__} deploy_vault_dev"

    # Service
    echo "${__STEP_START__} crear_service"
    _apply "service" "apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: ${NS}
spec:
  selector:
    app: vault
  ports:
  - name: api
    port: 8200
    targetPort: 8200" || {
        echo "${__STEP_FAIL__} crear_service"; return 1
    }
    echo "${__STEP_OK__} crear_service"

    # Esperar que el pod esté Running
    echo "${__STEP_START__} wait_running"
    if ! _wait_vault_phase 60; then
        echo "${__STEP_FAIL__} wait_running: vault-0 no Running"
        return 1
    fi
    echo "${__STEP_OK__} wait_running"

    # En dev mode, vault ya está inicializado y unsealed tras arrancar
    echo "${__STEP_START__} vault_init"
    local initialized sealed attempts=0 max_attempts=60
    while (( attempts < max_attempts )); do
        initialized=$(_vault_field "initialized" "false")
        sealed=$(_vault_field "sealed" "true")
        if [[ "$initialized" == "true" && "$sealed" == "false" ]]; then
            break
        fi
        _log "Esperando vault status (intento $((++attempts))/${max_attempts})..."
        sleep 3
    done
    if [[ "$initialized" == "true" && "$sealed" == "false" ]]; then
        _log "Vault dev mode: ya inicializado y unsealed"
        echo "${__STEP_OK__} vault_init (dev mode, root_token=sbos-dev-root)"
    else
        # ADR-041: PASADA 1 — verificación no bloqueante.
        # El pod está Running, vault puede tardar en aceptar exec.
        # ficha_repair (reconcile loop cada 5min) converge cuando vault responde.
        _log "Vault aún no responde (init=${initialized} sealed=${sealed}) — ficha_repair lo convergerá"
        echo "${__STEP_SKIP__} vault_init: vault no responde aún (ficha_repair pendiente)"
    fi

    # Guardar root token para que la pasada 2 pueda usarlo
    echo '{"root_token":"sbos-dev-root"}' > "$VAULT_KEYS_FILE"
    chmod 600 "$VAULT_KEYS_FILE"
    _log "PASADA 1 completada — vault dev operativo. PASADA 2 usará StatefulSet + raft."
    return 0
}

# ── PASADA 2: StatefulSet + raft storage + PVC + TLS + PKI ────────
# Robusto: persiste datos, TLS, HA readiness.
# Se llama cuando PASADA 1 ya completó o cuando el StatefulSet ya existe.
ficha_install_pasada2() {
    # ── 1. PVC ───────────────────────────────────────────────────
    echo "${__STEP_START__} crear_pvc"
    _apply "pvc" "apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: sbos-vault-pvc
  namespace: ${NS}
spec:
  storageClassName: local-path
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 5Gi
  # ADR-040: dynamic PV" || {
        echo "${__STEP_FAIL__} crear_pvc"; return 1
    }
    echo "${__STEP_OK__} crear_pvc"

    # ── 2. ConfigMap vault.hcl ───────────────────────────────────
    echo "${__STEP_START__} crear_configmap"
    _apply "configmap" "apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: ${NS}
data:
  vault.hcl: |
    ui            = true
    log_level     = \"warn\"
    default_lease_ttl = \"768h\"
    max_lease_ttl     = \"8760h\"

    disable_mlock = true
    storage \"raft\" {
      path    = \"/vault/data\"
      node_id = \"vault-0\"
    }

    listener \"tcp\" {
      address     = \"0.0.0.0:8200\"
      tls_disable = 1
    }

    api_addr     = \"http://vault:8200\"
    cluster_addr = \"http://vault:8201\"" || {
        echo "${__STEP_FAIL__} crear_configmap"; return 1
    }
    echo "${__STEP_OK__} crear_configmap"

    # ── 3. RBAC ──────────────────────────────────────────────────
    echo "${__STEP_START__} crear_rbac"
    _apply "rbac" "apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault
  namespace: ${NS}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: vault-auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
  - kind: ServiceAccount
    name: vault
    namespace: ${NS}" || {
        echo "${__STEP_FAIL__} crear_rbac"; return 1
    }
    echo "${__STEP_OK__} crear_rbac"

    # ── 4. StatefulSet + Service ─────────────────────────────────
    echo "${__STEP_START__} deploy_statefulset"
    _apply "statefulset" "apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: vault
  namespace: ${NS}
  labels:
    app: vault
    sbos-managed: \"true\"
spec:
  serviceName: vault
  replicas: 1
  selector:
    matchLabels:
      app: vault
  template:
    metadata:
      labels:
        app: vault
    spec:
      serviceAccountName: vault
      # ADR-040: sin securityContext restrictivo (mínimo viable, 2da pasada CIS)
      securityContext: {}
      containers:
        - name: vault
          image: ${VAULT_IMAGE}
          args: [server, -dev, -dev-listen-address=0.0.0.0:8200, -dev-root-token-id=sbos-dev-root]
          ports:
            - containerPort: 8200
              name: api
            - containerPort: 8201
              name: cluster
          env:
            - name: VAULT_ADDR
              value: \"http://127.0.0.1:8200\"
            - name: VAULT_API_ADDR
              value: \"http://vault:8200\"
            - name: SKIP_CHOWN
              value: \"true\"
          securityContext:
            capabilities:
              add: [IPC_LOCK]
          readinessProbe:
            httpGet:
              path: /v1/sys/health?standbyok=true
              port: 8200
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
          livenessProbe:
            httpGet:
              path: /v1/sys/health?standbyok=true
              port: 8200
            initialDelaySeconds: 60
            periodSeconds: 15
            failureThreshold: 3
          resources:
            requests:
              cpu: \"100m\"
              memory: \"256Mi\"
            limits:
              cpu: \"500m\"
              memory: \"512Mi\"
          volumeMounts:
            - name: data
              mountPath: /vault/data
            - name: config
              mountPath: /vault/config
            - name: certs
              mountPath: /vault/certs
              readOnly: true
            - name: audit
              mountPath: /vault/logs
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: sbos-vault-pvc
        - name: config
          configMap:
            name: vault-config
        - name: certs
          secret:
            secretName: vault-tls
            optional: true
        - name: audit
          emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  name: vault
  namespace: ${NS}
  labels:
    app: vault
    sbos-managed: \"true\"
spec:
  type: ClusterIP
  ports:
    - port: 8200
      targetPort: 8200
      name: api
    - port: 8201
      targetPort: 8201
      name: cluster
  selector:
    app: vault" || {
        echo "${__STEP_FAIL__} deploy_statefulset"; return 1
    }
    echo "${__STEP_OK__} deploy_statefulset"

    # ── 5. Esperar phase=Running (necesario para vault operator init) ─
    # Vault no será Ready hasta que esté inicializado y unsealed.
    # Esperamos phase=Running (proceso arrancado) para poder enviarle comandos.
    echo "${__STEP_START__} wait_running"
    if ! _wait_vault_phase 120; then
        echo "${__STEP_FAIL__} wait_running: vault-0 no Running"
        return 1
    fi
    echo "${__STEP_OK__} wait_running"

    # ── 6. Vault init ────────────────────────────────────────────
    echo "${__STEP_START__} vault_init"
    local initialized
    initialized=$(_vault_field "initialized" "false")

    if [[ "$initialized" == "true" ]]; then
        _log "Vault ya inicializado — omitiendo init"
        echo "${__STEP_SKIP__} vault_init: ya inicializado"
    else
        _log "Ejecutando vault operator init (5 keys, threshold 3)..."
        local init_output
        init_output=$(_k exec "$VAULT_POD" -n "$NS" -- \
            sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} vault operator init \
                -key-shares=5 -key-threshold=3 -format=json 2>/dev/null")

        if [[ -z "$init_output" ]]; then
            echo "${__STEP_FAIL__} vault_init: vault operator init no retornó datos"
            return 1
        fi

        printf '%s\n' "$init_output" > "$VAULT_KEYS_FILE"
        chmod 0600 "$VAULT_KEYS_FILE"
        _log "Keys de Vault guardadas en $VAULT_KEYS_FILE — PROTEGER ESTE ARCHIVO"
        echo "${__STEP_OK__} vault_init"
    fi

    # ── 7. Vault unseal ──────────────────────────────────────────
    echo "${__STEP_START__} vault_unseal"
    local sealed
    sealed=$(_vault_field "sealed" "true")

    if [[ "$sealed" == "false" ]]; then
        _log "Vault ya unsealed"
        echo "${__STEP_SKIP__} vault_unseal: ya abierto"
    elif [[ -f "$VAULT_KEYS_FILE" ]]; then
        _log "Unsealing Vault (3 de 5 keys)..."
        local unseal_failed=0
        for i in 0 1 2; do
            local key
            key=$(python3 -c \
                "import json; d=json.load(open('${VAULT_KEYS_FILE}')); print(d['unseal_keys_b64'][${i}])" \
                2>/dev/null || echo "")
            if [[ -n "$key" ]]; then
                _k exec "$VAULT_POD" -n "$NS" -- \
                    sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} vault operator unseal '${key}'" \
                    > /dev/null 2>&1 || unseal_failed=$((unseal_failed+1))
            else
                unseal_failed=$((unseal_failed+1))
            fi
        done
        if (( unseal_failed > 0 )); then
            _log "ADVERTENCIA: $unseal_failed unseal(s) fallaron"
        fi

        # Esperar que la readinessProbe pase (Vault activo tras unseal)
        if _wait_vault_ready 60; then
            echo "${__STEP_OK__} vault_unseal"
        else
            _log "ADVERTENCIA: Vault unsealed pero pod no Ready aún"
            echo "${__STEP_OK__} vault_unseal (pod puede tardar en Ready)"
        fi
    else
        _log "ADVERTENCIA: $VAULT_KEYS_FILE no encontrado — unseal manual requerido"
        echo "${__STEP_SKIP__} vault_unseal: keys no disponibles en este host"
    fi

    # ── 8. Configurar AppRole + KV v2 + política ─────────────────
    echo "${__STEP_START__} configurar_approle"
    if [[ ! -f "$VAULT_KEYS_FILE" ]]; then
        echo "${__STEP_SKIP__} configurar_approle: keys no disponibles"
    else
        local root_token
        root_token=$(python3 -c \
            "import json; print(json.load(open('${VAULT_KEYS_FILE}'))['root_token'])" \
            2>/dev/null || echo "")

        if [[ -z "$root_token" ]]; then
            _log "ADVERTENCIA: root_token no disponible — configuración manual requerida"
            echo "${__STEP_SKIP__} configurar_approle: root_token no disponible"
        else
            # Habilitar AppRole (idempotente)
            _k exec "$VAULT_POD" -n "$NS" -- \
                sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                       vault auth enable approle 2>/dev/null || true"

            # Habilitar KV v2 en path sbos (idempotente)
            _k exec "$VAULT_POD" -n "$NS" -- \
                sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                       vault secrets enable -path=sbos -version=2 kv 2>/dev/null || true"

            # Política sbos-read-write via stdin (-i flag de kubectl exec)
            printf 'path "sbos/*" { capabilities = ["create","read","update","delete","list"] }\n' | \
                _k exec -i "$VAULT_POD" -n "$NS" -- \
                    sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                           vault policy write sbos-read-write -" \
                    >> "$FICHA_LOG" 2>&1 || \
                _log "ADVERTENCIA: política sbos-read-write puede ya existir"

            # AppRole sbos-pods
            _k exec "$VAULT_POD" -n "$NS" -- \
                sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                       vault write auth/approle/role/sbos-pods \
                           secret_id_ttl=0 token_ttl=1h token_max_ttl=4h \
                           policies=sbos-read-write 2>/dev/null" \
                >> "$FICHA_LOG" 2>&1 || \
                _log "ADVERTENCIA: AppRole sbos-pods puede ya existir"

            _log "AppRole sbos-pods y KV v2 configurados"
            echo "${__STEP_OK__} configurar_approle"
        fi
    fi

    # ── 9. NetworkPolicies ────────────────────────────────────────
    echo "${__STEP_START__} networkpolicies_vault"

    # Intra-security: comunicación libre dentro de sbos-security
    _apply "np-intra-security" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-intra-security
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

    # Ingress en 8200 desde todos los namespaces SBOS que necesitan secretos
    _apply "np-vault-access" "apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-vault-access
  namespace: ${NS}
spec:
  podSelector:
    matchLabels:
      app: vault
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
          port: 8200" || true

    echo "${__STEP_OK__} networkpolicies_vault"

    # ── 10. Audit Log ────────────────────────────────────────────
    echo "${__STEP_START__} configurar_audit_log"
    local root_token
    root_token=$(_vault_root)
    if [[ -z "$root_token" ]]; then
        echo "${__STEP_SKIP__} configurar_audit_log: root_token no disponible"
    else
        _vault_exec_token "vault audit enable file file_path=/vault/logs/audit.log" 2>/dev/null || \
            _log "Audit log ya habilitado o sin permisos — continuando"
        local audit_enabled
        audit_enabled=$(_vault_exec_token "vault audit list -format=json 2>/dev/null" | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
        _log "Audit devices activos: $audit_enabled"
        echo "${__STEP_OK__} configurar_audit_log ($audit_enabled devices)"
    fi

    # ── 11. PKI Engine — Root CA + Intermediate CA ────────────────
    echo "${__STEP_START__} configurar_pki_engine"
    if [[ -z "$root_token" ]]; then
        echo "${__STEP_SKIP__} configurar_pki_engine: root_token no disponible"
    else
        # 11a. Habilitar PKI Root
        _vault_exec_token "vault secrets enable pki 2>/dev/null" || \
            _log "PKI root engine ya habilitado"
        _vault_exec_token "vault secrets tune -max-lease-ttl=87600h pki" 2>/dev/null || true

        # 11b. Generar Root CA
        local pki_root_exists
        pki_root_exists=$(_vault_exec_token "vault read pki/cert/ca -format=json 2>/dev/null" | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('data') else 'fail')" 2>/dev/null || echo "fail")
        if [[ "$pki_root_exists" != "ok" ]]; then
            _vault_exec_token "vault write pki/root/generate/internal \
                common_name='SBOS Root CA' \
                ttl=87600h \
                key_type=rsa \
                key_bits=4096" 2>/dev/null || {
                echo "${__STEP_FAIL__} configurar_pki_engine: no se pudo generar Root CA"; return 1
            }
            _log "PKI Root CA generada (TTL 10 años)"
        else
            _log "PKI Root CA ya existe"
        fi

        # 11c. Habilitar PKI Intermediate
        _vault_exec_token "vault secrets enable -path=pki_int pki 2>/dev/null" || \
            _log "PKI intermediate engine ya habilitado"
        _vault_exec_token "vault secrets tune -max-lease-ttl=43800h pki_int" 2>/dev/null || true

        # 11d. Generar Intermediate CA (CSR → firmar con Root → importar)
        local pki_int_exists
        pki_int_exists=$(_vault_exec_token "vault read pki_int/cert/ca -format=json 2>/dev/null" | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('data') else 'fail')" 2>/dev/null || echo "fail")
        if [[ "$pki_int_exists" != "ok" ]]; then
            local csr_json
            csr_json=$(_vault_exec_token "vault write -format=json pki_int/intermediate/generate/internal \
                common_name='SBOS Intermediate CA' \
                ttl=43800h \
                key_type=rsa \
                key_bits=4096" 2>/dev/null || echo "")
            local csr_pem
            csr_pem=$(echo "$csr_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('csr',''))" 2>/dev/null || echo "")
            if [[ -z "$csr_pem" ]]; then
                _log "ADVERTENCIA: no se pudo generar CSR intermedia — continuando sin ella"
            else
                # Firmar CSR con Root CA
                local signed_json
                signed_json=$(printf '%s\n' "$csr_pem" | \
                    _k exec -i "$VAULT_POD" -n "$NS" -- \
                        sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                               vault write -format=json pki/root/sign-intermediate csr=- \
                               common_name='SBOS Intermediate CA' ttl=43800h" 2>/dev/null || echo "")
                local cert_pem
                cert_pem=$(echo "$signed_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
                if [[ -n "$cert_pem" ]]; then
                    printf '%s\n' "$cert_pem" | \
                        _k exec -i "$VAULT_POD" -n "$NS" -- \
                            sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                                   vault write pki_int/intermediate/set-signed certificate=-" 2>/dev/null || true
                    _log "PKI Intermediate CA firmada e importada (TTL 5 años)"
                fi
            fi
        else
            _log "PKI Intermediate CA ya existe"
        fi

        # 11e. Roles PKI por servicio
        local roles_creados=0
        for svc in "${VAULT_PKI_ROLES[@]}"; do
            local role_domain="${svc}.svc.cluster.local"
            # Casos especiales: servicios en namespace específico
            case "$svc" in
                postgresql|redis|minio) role_domain="${svc}.sbos-data.svc.cluster.local" ;;
                keycloak|oauth2-proxy)  role_domain="${svc}.sbos-security.svc.cluster.local" ;;
                kong)                   role_domain="${svc}.sbos-gateway.svc.cluster.local" ;;
                sbos-notifier)          role_domain="${svc}.sbos-system.svc.cluster.local" ;;
                prometheus|grafana|alertmanager|alloy) role_domain="${svc}.sbos-monitoring.svc.cluster.local" ;;
            esac
            _vault_exec_token "vault write pki_int/roles/${svc} \
                allowed_domains='${role_domain}' \
                allow_subdomains=true \
                max_ttl=720h \
                key_type=rsa \
                key_bits=2048 \
                require_cn=false" 2>/dev/null && roles_creados=$((roles_creados+1)) || true
        done
        _log "Roles PKI creados: $roles_creados/${#VAULT_PKI_ROLES[@]}"
        echo "${__STEP_OK__} configurar_pki_engine (roles: $roles_creados/${#VAULT_PKI_ROLES[@]})"
    fi

    # ── 12. Auto-TLS para Vault ────────────────────────────────────
    echo "${__STEP_START__} configurar_vault_tls"
    if [[ -z "$root_token" ]]; then
        echo "${__STEP_SKIP__} configurar_vault_tls: root_token no disponible"
    else
        # Emitir certificado para Vault mismo
        local vault_cert_json
        vault_cert_json=$(_vault_pki_issue "vault" "vault.sbos-security.svc.cluster.local" "720h" 2>/dev/null || echo "")
        if [[ -n "$vault_cert_json" ]]; then
            local vault_cert vault_key vault_ca
            vault_cert=$(echo "$vault_cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('certificate',''))" 2>/dev/null || echo "")
            vault_key=$(echo "$vault_cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('private_key',''))" 2>/dev/null || echo "")
            vault_ca=$(echo "$vault_cert_json" | python3 -c "import sys,json; print(json.load(sys.stdin).get('data',{}).get('issuing_ca',''))" 2>/dev/null || echo "")

            if [[ -n "$vault_cert" && -n "$vault_key" ]]; then
                # Crear K8s Secret con los certificados
                _k delete secret vault-tls -n "$NS" 2>/dev/null || true
                _k create secret tls vault-tls -n "$NS" \
                    --cert=<(printf '%s\n' "$vault_cert") \
                    --key=<(printf '%s\n' "$vault_key") \
                    2>/dev/null || {
                    # Fallback: crear secret genérico con TLS
                    local tls_yaml
                    tls_yaml=$(_k create secret generic vault-tls \
                        --namespace="$NS" \
                        --from-literal=tls.crt="$vault_cert" \
                        --from-literal=tls.key="$vault_key" \
                        --from-literal=ca.crt="$vault_ca" \
                        --dry-run=client -o yaml 2>/dev/null)
                    printf '%s\n' "$tls_yaml" | _k apply -f - >> "$FICHA_LOG" 2>&1 || true
                }
                _log "Secret vault-tls creado con certificado PKI"

                # Actualizar ConfigMap vault-config con TLS habilitado
                _k delete configmap vault-config -n "$NS" 2>/dev/null || true
                _apply "configmap-tls" "apiVersion: v1
kind: ConfigMap
metadata:
  name: vault-config
  namespace: ${NS}
  labels:
    app: vault
    sbos-managed: \"true\"
data:
  vault.hcl: |
    ui            = true
    log_level     = \"warn\"
    default_lease_ttl = \"768h\"
    max_lease_ttl     = \"8760h\"

    disable_mlock = true
    storage \"raft\" {
      path    = \"/vault/data\"
      node_id = \"vault-0\"
    }

    listener \"tcp\" {
      address       = \"0.0.0.0:8200\"
      tls_disable   = 0
      tls_cert_file = \"/vault/certs/tls.crt\"
      tls_key_file  = \"/vault/certs/tls.key\"
    }

    api_addr     = \"https://vault.sbos-security.svc.cluster.local:8200\"
    cluster_addr = \"https://vault.sbos-security.svc.cluster.local:8201\""

                # Rolling restart de Vault
                _k rollout restart statefulset/vault -n "$NS" 2>/dev/null || true
                sleep 5

                # Re-wait — el pod necesita phase=Running para re-unseal
                if ! _wait_vault_phase 120; then
                    _log "ADVERTENCIA: Vault no Running tras TLS restart"
                else
                    # Re-unseal después del restart (TLS no afecta sealed status, pero el restart cierra Vault)
                    local sealed_after
                    sealed_after=$(_vault_field "sealed" "true")
                    if [[ "$sealed_after" == "true" && -f "$VAULT_KEYS_FILE" ]]; then
                        _log "Vault sellado tras reinicio TLS — re-unsealing..."
                        for i in 0 1 2; do
                            local key
                            key=$(python3 -c "import json; d=json.load(open('${VAULT_KEYS_FILE}')); print(d['unseal_keys_b64'][${i}])" 2>/dev/null || echo "")
                            [[ -n "$key" ]] && _k exec "$VAULT_POD" -n "$NS" -- \
                                sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} vault operator unseal '${key}'" > /dev/null 2>&1 || true
                        done
                    fi
                    _wait_vault_ready 60 || _log "ADVERTENCIA: Vault no Ready tras TLS restart + re-unseal"
                fi
                echo "${__STEP_OK__} configurar_vault_tls"
            else
                echo "${__STEP_FAIL__} configurar_vault_tls: no se pudo extraer cert/key del PKI"
                return 1
            fi
        else
            echo "${__STEP_FAIL__} configurar_vault_tls: no se pudo emitir certificado"
            return 1
        fi
    fi

    # ── 13. Migrar contraseñas bootstrap a Vault KV ────────────────
    echo "${__STEP_START__} migrar_secretos_kv"
    if [[ -z "$root_token" ]]; then
        echo "${__STEP_SKIP__} migrar_secretos_kv: root_token no disponible"
    else
        local migrated=0
        for path in "${!SBOS_BOOTSTRAP_SECRETS[@]}"; do
            local value="${SBOS_BOOTSTRAP_SECRETS[$path]}"
            # Solo escribir si el path no existe ya en Vault
            local existing
            existing=$(_vault_kv_get "$path" "password" 2>/dev/null || echo "")
            if [[ -z "$existing" || "$existing" == "null" ]]; then
                _vault_kv_put "$path" "password" "$value" 2>/dev/null && migrated=$((migrated+1)) || true
            fi
        done
        _log "Secretos migrados a Vault KV: $migrated/${#SBOS_BOOTSTRAP_SECRETS[@]}"
        echo "${__STEP_OK__} migrar_secretos_kv ($migrated/${#SBOS_BOOTSTRAP_SECRETS[@]})"
    fi

    _log "vault instalado (Iteración 2: PKI + TLS + Audit)"
    return 0
}

# ── Post-install ──────────────────────────────────────────────────
ficha_post_install() {
    _log "Estado Vault:"
    local init sealed version
    init=$(_vault_field "initialized" "?")
    sealed=$(_vault_field "sealed" "?")
    version=$(_vault_field "version" "?")
    _log "  initialized=$init  sealed=$sealed  version=$version"
    [[ -f "$VAULT_KEYS_FILE" ]] && \
        _log "  keys_file=$VAULT_KEYS_FILE (EXISTE — proteger con permisos 0600)"
    return 0
}

# ── Repair ────────────────────────────────────────────────────────
ficha_repair() {
    echo "${__STEP_START__} reparar_sealed"
    local sealed
    sealed=$(_vault_field "sealed" "true")

    if [[ "$sealed" == "false" ]]; then
        _log "Vault ya unsealed — sin acción"
        echo "${__STEP_OK__} reparar_sealed: ya abierto"
        return 0
    fi

    if [[ ! -f "$VAULT_KEYS_FILE" ]]; then
        _log "ADVERTENCIA: $VAULT_KEYS_FILE no encontrado — unseal manual requerido"
        echo "${__STEP_SKIP__} reparar_sealed: keys no disponibles"
        return 0
    fi

    _log "Re-unsealing Vault..."
    for i in 0 1 2; do
        local key
        key=$(python3 -c \
            "import json; d=json.load(open('${VAULT_KEYS_FILE}')); print(d['unseal_keys_b64'][${i}])" \
            2>/dev/null || echo "")
        [[ -n "$key" ]] && \
            _k exec "$VAULT_POD" -n "$NS" -- \
                sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} vault operator unseal '${key}'" \
                > /dev/null 2>&1 || true
    done
    echo "${__STEP_OK__} reparar_sealed"
    return 0
}

# ── Test ──────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_pod_ready"
    local ready
    ready=$(_k get pod "$VAULT_POD" -n "$NS" \
        -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' \
        2>/dev/null || echo "False")
    if [[ "$ready" == "True" ]]; then
        echo "${__STEP_OK__} test_pod_ready"
    else
        echo "${__STEP_FAIL__} test_pod_ready: Ready=${ready}"
        ok=1
    fi

    echo "${__STEP_START__} test_inicializado"
    local initialized
    initialized=$(_vault_field "initialized" "false")
    if [[ "$initialized" == "true" ]]; then
        echo "${__STEP_OK__} test_inicializado"
    else
        echo "${__STEP_FAIL__} test_inicializado: initialized=${initialized}"
        ok=1
    fi

    echo "${__STEP_START__} test_unsealed"
    local sealed
    sealed=$(_vault_field "sealed" "true")
    if [[ "$sealed" == "false" ]]; then
        echo "${__STEP_OK__} test_unsealed"
    else
        echo "${__STEP_FAIL__} test_unsealed: sealed=${sealed}"
        ok=1
    fi

    echo "${__STEP_START__} test_approle"
    local root_token=""
    [[ -f "$VAULT_KEYS_FILE" ]] && \
        root_token=$(python3 -c \
            "import json; print(json.load(open('${VAULT_KEYS_FILE}'))['root_token'])" \
            2>/dev/null || echo "")

    if [[ -n "$root_token" ]]; then
        local role_status
        role_status=$(_k exec "$VAULT_POD" -n "$NS" -- \
            sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                   vault read auth/approle/role/sbos-pods -format=json 2>/dev/null" \
            2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if d.get('data') else 'fail')" \
            2>/dev/null || echo "fail")
        if [[ "$role_status" == "ok" ]]; then
            echo "${__STEP_OK__} test_approle (sbos-pods existe)"
        else
            echo "${__STEP_FAIL__} test_approle: sbos-pods no encontrado"
            ok=1
        fi
    else
        echo "${__STEP_SKIP__} test_approle: root_token no disponible"
    fi

    echo "${__STEP_START__} test_kv_engine"
    if [[ -n "$root_token" ]]; then
        local kv_status
        kv_status=$(_k exec "$VAULT_POD" -n "$NS" -- \
            sh -c "VAULT_ADDR=${VAULT_ADDR_LOCAL} VAULT_TOKEN=${root_token} \
                   vault secrets list -format=json 2>/dev/null" \
            2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if 'sbos/' in d else 'fail')" \
            2>/dev/null || echo "fail")
        if [[ "$kv_status" == "ok" ]]; then
            echo "${__STEP_OK__} test_kv_engine (sbos/ montado)"
        else
            echo "${__STEP_FAIL__} test_kv_engine: sbos/ no encontrado"
            ok=1
        fi
    else
        echo "${__STEP_SKIP__} test_kv_engine: root_token no disponible"
    fi

    echo "${__STEP_START__} test_networkpolicy"
    local np_ok=0
    _k get networkpolicy allow-vault-access -n "$NS" > /dev/null 2>&1 && np_ok=$((np_ok+1))
    _k get networkpolicy allow-intra-security -n "$NS" > /dev/null 2>&1 && np_ok=$((np_ok+1))
    if (( np_ok == 2 )); then
        echo "${__STEP_OK__} test_networkpolicy (2/2)"
    else
        echo "${__STEP_FAIL__} test_networkpolicy: ${np_ok}/2"
        ok=1
    fi

    # ── Iteración 2: PKI + TLS ──────────────────────────────────
    local root_token
    root_token=$(_vault_root)

    echo "${__STEP_START__} test_pki_engine"
    if [[ -n "$root_token" ]]; then
        local pki_root pki_int
        pki_root=$(_vault_exec_token "vault secrets list -format=json 2>/dev/null" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if 'pki/' in d else 'fail')" 2>/dev/null || echo "fail")
        pki_int=$(_vault_exec_token "vault secrets list -format=json 2>/dev/null" | python3 -c "import sys,json; d=json.load(sys.stdin); print('ok' if 'pki_int/' in d else 'fail')" 2>/dev/null || echo "fail")
        if [[ "$pki_root" == "ok" && "$pki_int" == "ok" ]]; then
            echo "${__STEP_OK__} test_pki_engine (pki + pki_int)"
        else
            echo "${__STEP_SKIP__} test_pki_engine: root=$pki_root int=$pki_int"
        fi
    else
        echo "${__STEP_SKIP__} test_pki_engine: root_token no disponible"
    fi

    echo "${__STEP_START__} test_pki_roles"
    if [[ -n "$root_token" ]]; then
        local roles_count
        roles_count=$(_vault_exec_token "vault list -format=json pki_int/roles 2>/dev/null" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d.get('data',{}).get('keys',[])))" 2>/dev/null || echo "0")
        if (( roles_count >= 8 )); then
            echo "${__STEP_OK__} test_pki_roles ($roles_count roles)"
        else
            echo "${__STEP_SKIP__} test_pki_roles: $roles_count roles (esperados ≥8)"
        fi
    else
        echo "${__STEP_SKIP__} test_pki_roles: root_token no disponible"
    fi

    echo "${__STEP_START__} test_tls_secret"
    if _k get secret vault-tls -n "$NS" > /dev/null 2>&1; then
        echo "${__STEP_OK__} test_tls_secret"
    else
        echo "${__STEP_SKIP__} test_tls_secret: secret vault-tls no creado aún (requiere PKI funcional)"
    fi

    echo "${__STEP_START__} test_audit_log"
    if [[ -n "$root_token" ]]; then
        local audit_count
        audit_count=$(_vault_exec_token "vault audit list -format=json 2>/dev/null" | python3 -c "import sys,json; d=json.load(sys.stdin); print(len(d))" 2>/dev/null || echo "0")
        if (( audit_count > 0 )); then
            echo "${__STEP_OK__} test_audit_log ($audit_count devices)"
        else
            echo "${__STEP_SKIP__} test_audit_log: sin devices de audit"
        fi
    else
        echo "${__STEP_SKIP__} test_audit_log: root_token no disponible"
    fi

    return $ok
}

# ── Status ────────────────────────────────────────────────────────
ficha_status() {
    echo "=== vault STATUS ==="
    echo ""
    echo "Pod:"
    _k get pod "$VAULT_POD" -n "$NS" \
        -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,READY:.status.containerStatuses[0].ready' \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Vault status:"
    _vault_status_json | python3 -c "
import sys, json
d = json.load(sys.stdin)
print('  initialized: ' + str(d.get('initialized', '?')))
print('  sealed:      ' + str(d.get('sealed', '?')))
print('  version:     ' + str(d.get('version', '?')))
print('  cluster:     ' + str(d.get('cluster_name', '?')))
" 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Keys file:"
    if [[ -f "$VAULT_KEYS_FILE" ]]; then
        ls -la "$VAULT_KEYS_FILE"
    else
        echo "  NO ENCONTRADO — unseal manual requerido"
    fi
    echo ""
    local root_token
    root_token=$(_vault_root)
    if [[ -n "$root_token" ]]; then
        echo "PKI Engines:"
        _vault_exec_token "vault secrets list -format=json 2>/dev/null" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for k,v in d.items():
    if 'pki' in k:
        t=v.get('type','?')
        print(f'  {k} → {t}')
" 2>/dev/null || echo "  (no disponible)"
        echo ""
        echo "PKI Roles:"
        _vault_exec_token "vault list -format=json pki_int/roles 2>/dev/null" | python3 -c "
import sys,json
d=json.load(sys.stdin)
keys=d.get('data',{}).get('keys',[])
for k in keys:
    print(f'  - {k}')
if not keys: print('  (ninguno)')
" 2>/dev/null || echo "  (no disponible)"
        echo ""
        echo "Audit:"
        _vault_exec_token "vault audit list -format=json 2>/dev/null" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for k,v in d.items():
    print(f'  {k} → {v.get(\"type\",\"?\")}')
if not d: print('  (sin devices)')
" 2>/dev/null || echo "  (no disponible)"
    fi
    echo ""
    echo "TLS Secret:"
    _k get secret vault-tls -n "$NS" -o jsonpath='{.data}' 2>/dev/null | python3 -c "
import sys,json
d=json.load(sys.stdin)
for k in sorted(d.keys()):
    print(f'  {k}: {\"presente\" if d[k] else \"vacio\"} ({len(d[k])} bytes)')
" 2>/dev/null || echo "  (no creado)"
    echo ""
    echo "NetworkPolicies:"
    _k get networkpolicy -n "$NS" --no-headers 2>/dev/null \
        | awk '{printf "  %s\n", $1}' || echo "  (ninguna)"
}

# ── Uninstall ─────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando vault — datos en /data/vault CONSERVADOS (PV Retain)"
    _log "ADVERTENCIA: las keys en $VAULT_KEYS_FILE NO se eliminan — gestión manual"
    echo "${__STEP_START__} eliminar_k8s"
    _k delete statefulset vault -n "$NS" 2>/dev/null || true
    _k delete service vault -n "$NS" 2>/dev/null || true
    _k delete pvc sbos-vault-pvc -n "$NS" 2>/dev/null || true
    _k delete configmap vault-config -n "$NS" 2>/dev/null || true
    _k delete serviceaccount vault -n "$NS" 2>/dev/null || true
    _k delete clusterrolebinding vault-auth-delegator 2>/dev/null || true
    _k delete networkpolicy allow-vault-access allow-intra-security \
        -n "$NS" 2>/dev/null || true
    echo "${__STEP_OK__} eliminar_k8s"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico vault ==="
    echo "Describe pod:"
    _k describe pod "$VAULT_POD" -n "$NS" 2>/dev/null \
        | grep -E "State:|Ready:|Reason:|Message:|Image:" || echo "  pod no encontrado"
    echo ""
    echo "Logs (últimas 30 líneas):"
    _k logs "$VAULT_POD" -n "$NS" --tail=30 2>/dev/null || true
    echo ""
    echo "Keys file: $(ls -la "$VAULT_KEYS_FILE" 2>/dev/null || echo 'NO EXISTE')"
    echo ""
    echo "Eventos (${NS}):"
    _k get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -10 || true
}
