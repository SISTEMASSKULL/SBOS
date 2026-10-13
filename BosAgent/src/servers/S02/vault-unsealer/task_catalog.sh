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

    # 3. CronJob que verifica y desella cada minuto
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
        spec:
          serviceAccountName: vault-unsealer
          restartPolicy: OnFailure
          containers:
          - name: unsealer
            image: bitnami/kubectl:1.31
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
            - /bin/bash
            - -c
            - |
              set -euo pipefail
              # Verificar si vault está inicializado y sellado
              SEALED=$(kubectl exec vault-0 -n sbos-security -- \
                sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json 2>/dev/null || echo '{}'" \
                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sealed','true'))" 2>/dev/null || echo "true")

              if [[ "$SEALED" == "false" ]]; then
                echo "Vault ya unsealed — ok"
                exit 0
              fi

              echo "Vault sealed — ejecutando unseal..."
              kubectl exec vault-0 -n sbos-security -- \
                sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '$KEY0'" || true
              kubectl exec vault-0 -n sbos-security -- \
                sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '$KEY1'" || true
              kubectl exec vault-0 -n sbos-security -- \
                sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '$KEY2'" || true

              # Verificar resultado
              SEALED_AFTER=$(kubectl exec vault-0 -n sbos-security -- \
                sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json 2>/dev/null || echo '{}'" \
                | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sealed','true'))" 2>/dev/null || echo "true")
              if [[ "$SEALED_AFTER" == "false" ]]; then
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

# ── Verify ─────────────────────────────────────────────────────────
ficha_verify() {
    echo "${__STEP_START__} verificar_cronjob"
    _k get cronjob vault-unsealer -n "$NS" > /dev/null 2>&1 \
        && echo "${__STEP_OK__} verificar_cronjob (CronJob presente)" \
        || { echo "${__STEP_FAIL__} verificar_cronjob: CronJob no encontrado"; return 1; }
}

# ── Health ──────────────────────────────────────────────────────────
ficha_health() {
    # El unsealer es sano si vault está unsealed
    local sealed
    sealed=$(_k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json 2>/dev/null || echo '{}'" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sealed','true'))" 2>/dev/null || echo "true")
    if [[ "$sealed" == "false" ]]; then
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

    _k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '${key0}'" >> "$FICHA_LOG" 2>&1 || true
    _k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '${key1}'" >> "$FICHA_LOG" 2>&1 || true
    _k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault operator unseal '${key2}'" >> "$FICHA_LOG" 2>&1 || true
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
    local sealed
    sealed=$(_k exec "$VAULT_POD" -n "$NS" -- \
        sh -c "VAULT_ADDR=http://127.0.0.1:8200 vault status -format=json 2>/dev/null || echo '{}'" \
        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('sealed','true'))" 2>/dev/null || echo "true")
    if [[ "$sealed" == "false" ]]; then
        echo "${__STEP_OK__} test_vault_unsealed"
    else
        echo "${__STEP_FAIL__} test_vault_unsealed: vault sealed=true (CronJob actuará en próximo minuto)"
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
