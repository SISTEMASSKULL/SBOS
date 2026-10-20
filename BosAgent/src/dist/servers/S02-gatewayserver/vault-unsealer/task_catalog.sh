#!/usr/bin/env bash
# task_catalog.sh — vault-unsealer
# CronJob que monitorea Vault cada 30s y lo desella automáticamente cuando está sealed.
# Las unseal keys se leen de /etc/bos/vault-init-keys.json y se guardan en un
# K8s Secret dentro del cluster (acceso restringido a sbos-security namespace).
# Sin intervención manual — cumple ADR-022 y P15.
set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/vault-unsealer.log}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
readonly NS="sbos-security"
readonly VAULT_KEYS_FILE="/etc/bos/vault-init-keys.json"
readonly VAULT_POD="vault-0"
readonly VAULT_ADDR="http://vault.sbos-security.svc.cluster.local:8200"

_log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [vault-unsealer] $*" | tee -a "$FICHA_LOG"; }
_k()   { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }

# ── Pre-install ────────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_keys_file"
    if [[ ! -f "$VAULT_KEYS_FILE" ]]; then
        echo "${__STEP_FAIL__} vault-init-keys.json no encontrado en $VAULT_KEYS_FILE"
        echo "${__STEP_FAIL__} vault-unsealer requiere que vault haya sido inicializado primero"
        return 1
    fi
    local key_count
    key_count=$(python3 -c \
        "import json; d=json.load(open('${VAULT_KEYS_FILE}')); print(len(d.get('unseal_keys_b64',[])))" \
        2>/dev/null || echo "0")
    if (( key_count < 3 )); then
        echo "${__STEP_FAIL__} keys insuficientes en vault-init-keys.json (encontradas: ${key_count}, requeridas: 3)"
        return 1
    fi
    echo "${__STEP_OK__} verificar_keys_file ($key_count keys disponibles)"
}

# ── Install ────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # Idempotencia: si el CronJob ya existe y está Running, no reinstalar
    local existing
    existing=$(_k get cronjob vault-unsealer -n "$NS" \
        -o jsonpath='{.metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$existing" ]]; then
        echo "${__STEP_SKIP__} vault-unsealer ya desplegado — skip"
        return 0
    fi

    # 1. Leer las 3 primeras unseal keys y crear K8s Secret
    echo "${__STEP_START__} crear_secret_unseal_keys"
    local key0 key1 key2
    key0=$(python3 -c \
        "import json; d=json.load(open('${VAULT_KEYS_FILE}')); print(d['unseal_keys_b64'][0])" \
        2>/dev/null || echo "")
    key1=$(python3 -c \
        "import json; d=json.load(open('${VAULT_KEYS_FILE}')); print(d['unseal_keys_b64'][1])" \
        2>/dev/null || echo "")
    key2=$(python3 -c \
        "import json; d=json.load(open('${VAULT_KEYS_FILE}')); print(d['unseal_keys_b64'][2])" \
        2>/dev/null || echo "")

    if [[ -z "$key0" || -z "$key1" || -z "$key2" ]]; then
        echo "${__STEP_FAIL__} no se pudieron leer las unseal keys"
        return 1
    fi

    # Crear o actualizar el Secret (idempotente con apply)
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<SECRETEOF
apiVersion: v1
kind: Secret
metadata:
  name: vault-unseal-keys
  namespace: ${NS}
  labels:
    app: vault-unsealer
    sbos.app/managed-by: bos
type: Opaque
stringData:
  key0: "${key0}"
  key1: "${key1}"
  key2: "${key2}"
SECRETEOF
    echo "${__STEP_OK__} crear_secret_unseal_keys"

    # 2. RBAC: ServiceAccount + Role para que el pod pueda leer el Secret y
    #    hacer exec en el pod de vault
    echo "${__STEP_START__} crear_rbac_unsealer"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<RBACEOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vault-unsealer
  namespace: ${NS}
  labels:
    app: vault-unsealer
    sbos.app/managed-by: bos
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: vault-unsealer
  namespace: ${NS}
rules:
- apiGroups: [""]
  resources: ["secrets"]
  resourceNames: ["vault-unseal-keys"]
  verbs: ["get"]
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
- apiGroups: [""]
  resources: ["pods/exec"]
  verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: vault-unsealer
  namespace: ${NS}
subjects:
- kind: ServiceAccount
  name: vault-unsealer
  namespace: ${NS}
roleRef:
  kind: Role
  name: vault-unsealer
  apiGroup: rbac.authorization.k8s.io
RBACEOF
    echo "${__STEP_OK__} crear_rbac_unsealer"

    # 2b. NetworkPolicy: egress al vault HTTP API (no necesita kube-apiserver)
    echo "${__STEP_START__} crear_networkpolicy_unsealer"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<NPEOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-vault-unsealer-egress
  namespace: ${NS}
  labels:
    sbos.app/managed-by: bos
spec:
  podSelector:
    matchLabels:
      app: vault-unsealer
  policyTypes: [Egress]
  egress:
    - to:
        - podSelector:
            matchLabels:
              app: vault
      ports:
        - protocol: TCP
          port: 8200
    - ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
NPEOF
    echo "${__STEP_OK__} crear_networkpolicy_unsealer"

    # 3. CronJob que verifica y desella cada minuto via API REST de Vault (sin kubectl)
    echo "${__STEP_START__} crear_cronjob_unsealer"
    _k apply -f - >> "$FICHA_LOG" 2>&1 <<CJEOF
apiVersion: batch/v1
kind: CronJob
metadata:
  name: vault-unsealer
  namespace: ${NS}
  labels:
    app: vault-unsealer
    sbos.app/managed-by: bos
spec:
  schedule: "* * * * *"
  concurrencyPolicy: Forbid
  successfulJobsHistoryLimit: 2
  failedJobsHistoryLimit: 2
  jobTemplate:
    spec:
      template:
        metadata:
          labels:
            app: vault-unsealer
          annotations:
            linkerd.io/inject: disabled
        spec:
          serviceAccountName: vault-unsealer
          restartPolicy: OnFailure
          containers:
          - name: unsealer
            image: busybox:1.36
            env:
            - name: VAULT_ADDR
              value: "http://vault.${NS}.svc.cluster.local:8200"
            - name: KEY0
              valueFrom:
                secretKeyRef:
                  name: vault-unseal-keys
                  key: key0
            - name: KEY1
              valueFrom:
                secretKeyRef:
                  name: vault-unseal-keys
                  key: key1
            - name: KEY2
              valueFrom:
                secretKeyRef:
                  name: vault-unseal-keys
                  key: key2
            command:
            - /bin/sh
            - -c
            - |
              set -eu
              # Verificar si vault está sellado via API REST (no necesita kubectl ni python3)
              STATUS=\$(wget -qO- "\$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo '{}')
              if echo "\$STATUS" | grep -q '"sealed":false'; then
                echo "Vault ya unsealed — ok"
                exit 0
              fi
              echo "Vault sealed — ejecutando unseal via API REST..."
              wget -qO- --post-data "{\"key\":\"\$KEY0\"}" "\$VAULT_ADDR/v1/sys/unseal" 2>/dev/null || true
              wget -qO- --post-data "{\"key\":\"\$KEY1\"}" "\$VAULT_ADDR/v1/sys/unseal" 2>/dev/null || true
              wget -qO- --post-data "{\"key\":\"\$KEY2\"}" "\$VAULT_ADDR/v1/sys/unseal" 2>/dev/null || true
              STATUS2=\$(wget -qO- "\$VAULT_ADDR/v1/sys/health" 2>/dev/null || echo '{}')
              if echo "\$STATUS2" | grep -q '"sealed":false'; then
                echo "Vault unsealed exitosamente"
              else
                echo "ERROR: vault sigue sellado tras unseal"
                exit 1
              fi
            resources:
              requests:
                cpu: "10m"
                memory: "32Mi"
              limits:
                cpu: "100m"
                memory: "64Mi"
CJEOF
    echo "${__STEP_OK__} crear_cronjob_unsealer"
    _log "vault-unsealer desplegado — vault se desellará automáticamente en el próximo ciclo de 1 minuto"
}

# ── Post-install ──────────────────────────────────────────────────
# vault-unsealer es un CronJob — no tiene pods corriendo permanentemente.
# post_install_generic esperaría indefinidamente. Esta función lo evita.
ficha_post_install() { return 0; }

# ── Verify ─────────────────────────────────────────────────────────
ficha_verify() {
    echo "${__STEP_START__} verificar_cronjob"
    _k get cronjob vault-unsealer -n "$NS" > /dev/null 2>&1 \
        && echo "${__STEP_OK__} verificar_cronjob (CronJob presente)" \
        || { echo "${__STEP_FAIL__} verificar_cronjob: CronJob no encontrado"; return 1; }
}

# ── Health ──────────────────────────────────────────────────────────
ficha_health() {
    # Verificar via API REST de Vault (sin kubectl exec ni python3)
    local status
    status=$(curl -sf "http://vault.${NS}.svc.cluster.local:8200/v1/sys/health" 2>/dev/null || echo '{}')
    if echo "$status" | grep -q '"sealed":false'; then
        echo "HEALTHY"
        return 0
    fi
    echo "DEGRADED: vault sellado — esperando próximo ciclo del CronJob"
    return 1
}

# ── Repair ──────────────────────────────────────────────────────────
ficha_repair() {
    _log "ficha_repair: re-aplicando vault-unsealer (idempotente)"
    # Forzar unseal inmediato sin esperar al CronJob
    echo "${__STEP_START__} unseal_inmediato"
    local key0 key1 key2
    key0=$(_k get secret vault-unseal-keys -n "$NS" -o jsonpath='{.data.key0}' 2>/dev/null | base64 -d || echo "")
    key1=$(_k get secret vault-unseal-keys -n "$NS" -o jsonpath='{.data.key1}' 2>/dev/null | base64 -d || echo "")
    key2=$(_k get secret vault-unseal-keys -n "$NS" -o jsonpath='{.data.key2}' 2>/dev/null | base64 -d || echo "")

    if [[ -z "$key0" ]]; then
        _log "Secret vault-unseal-keys no encontrado — re-instalando"
        ficha_install
        return $?
    fi

    # Unseal via API REST (sin kubectl exec)
    local vault_url="http://vault.${NS}.svc.cluster.local:8200"
    curl -sf -X POST -d "{\"key\":\"${key0}\"}" "${vault_url}/v1/sys/unseal" >> "$FICHA_LOG" 2>&1 || true
    curl -sf -X POST -d "{\"key\":\"${key1}\"}" "${vault_url}/v1/sys/unseal" >> "$FICHA_LOG" 2>&1 || true
    curl -sf -X POST -d "{\"key\":\"${key2}\"}" "${vault_url}/v1/sys/unseal" >> "$FICHA_LOG" 2>&1 || true
    echo "${__STEP_OK__} unseal_inmediato"
}

# ── Test ────────────────────────────────────────────────────────────
ficha_test() {
    local ok=0
    echo "${__STEP_START__} test_cronjob_existe"
    _k get cronjob vault-unsealer -n "$NS" > /dev/null 2>&1 \
        && echo "${__STEP_OK__} test_cronjob_existe" \
        || { echo "${__STEP_FAIL__} test_cronjob_existe"; ok=1; }

    echo "${__STEP_START__} test_secret_existe"
    _k get secret vault-unseal-keys -n "$NS" > /dev/null 2>&1 \
        && echo "${__STEP_OK__} test_secret_existe" \
        || { echo "${__STEP_FAIL__} test_secret_existe"; ok=1; }

    echo "${__STEP_START__} test_vault_unsealed"
    local status
    status=$(curl -sf "http://vault.${NS}.svc.cluster.local:8200/v1/sys/health" 2>/dev/null || echo '{}')
    if echo "$status" | grep -q '"sealed":false'; then
        echo "${__STEP_OK__} test_vault_unsealed"
    else
        echo "${__STEP_FAIL__} test_vault_unsealed: vault sealed (CronJob actuará en próximo minuto)"
        ok=1
    fi
    return $ok
}

# ── Remove ──────────────────────────────────────────────────────────
ficha_remove() {
    echo "${__STEP_START__} eliminar_vault_unsealer"
    _k delete cronjob vault-unsealer -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete rolebinding vault-unsealer -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete role vault-unsealer -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    _k delete serviceaccount vault-unsealer -n "$NS" --ignore-not-found=true >> "$FICHA_LOG" 2>&1
    # NO eliminar el Secret vault-unseal-keys — son datos críticos para recovery
    _log "ADVERTENCIA: Secret vault-unseal-keys conservado intencionalmente"
    echo "${__STEP_OK__} eliminar_vault_unsealer"
}

export -f ficha_pre_install ficha_install ficha_verify ficha_health ficha_repair ficha_test ficha_remove
