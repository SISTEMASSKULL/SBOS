#!/usr/bin/env bash
# ============================================================================
# task_catalog.sh — Ficha tryton (S01 — erpserver)
#
# Instala Tryton ERP 7.4 en K8s con:
#   - PostgreSQL user + DB (tryton_db)
#   - Credenciales almacenadas en Vault (P6 — sin hardcode)
#   - K8s Secret generado desde Vault
#   - ServiceAccount + RBAC mínimo
#   - ConfigMap con trytond.conf (sin credenciales)
#   - StatefulSet 1 réplica inicial + PVC 50Gi
#   - Kong Ingress en erp.skull.sbos.local
#
# Variables de entorno aceptadas:
#   TENANT_ID          — ID del tenant (default: skull)
#   TRYTON_PG_PASSWORD — Inyectada por BOS desde Vault. Si no está presente,
#                        se genera y se almacena en Vault automáticamente.
# ============================================================================

set -euo pipefail

readonly __STEP_START__="${__SBOS__STEP_START__:-__SBOS__STEP_START__}"
readonly __STEP_OK__="${__SBOS__STEP_OK__:-__SBOS__STEP_OK__}"
readonly __STEP_FAIL__="${__SBOS__STEP_FAIL__:-__SBOS__STEP_FAIL__}"
readonly __STEP_SKIP__="${__SBOS__STEP_SKIP__:-__SBOS__STEP_SKIP__}"

FICHA_LOG="${FICHA_LOG:-/var/log/bos/fichas/tryton.log}"
FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S01/tryton}"
KUBECONFIG_DEST="${KUBECONFIG_DEST:-/etc/bos/.kube/config}"
NAMESPACE="${SBOS_NAMESPACE:-sbos-erp}"
TENANT_ID="${TENANT_ID:-skull}"
PG_NAMESPACE="${PG_NAMESPACE:-sbos-data}"
PG_POD="${PG_POD:-postgresql-0}"
VAULT_NAMESPACE="${VAULT_NAMESPACE:-sbos-security}"
VAULT_POD="${VAULT_POD:-vault-0}"
KC_NAMESPACE="${KC_NAMESPACE:-sbos-security}"
KC_POD="${KC_POD:-keycloak-0}"

# Rutas en Vault
VAULT_PATH="secret/tenants/${TENANT_ID}/tryton"
VAULT_OIDC_PATH="secret/tenants/${TENANT_ID}/tryton/oidc"

_log()  { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] [tryton] $*" | tee -a "$FICHA_LOG"; }
_k()    { kubectl --kubeconfig="$KUBECONFIG_DEST" "$@"; }
_pg()   { _k exec -n "$PG_NAMESPACE" "$PG_POD" -- psql -U postgres "$@"; }
_vault(){ _k exec -n "$VAULT_NAMESPACE" "$VAULT_POD" -- vault "$@"; }

# ── Autenticación OIDC ───────────────────────────────────────────────────
# Despliega oauth2-proxy-tryton como capa de autenticación frente a Tryton.
# Fase 1: valida sesiones contra Keycloak (realm skull).
# Fase 2: cambiar ConfigMap tryton-auth OIDC_ISSUER_URL → bAuth, luego rollout restart.
configurar_autenticacion_oidc() {
    local oidc_client_secret="${TRYTON_OIDC_CLIENT_SECRET:-}"
    local oidc_cookie_secret="${TRYTON_OIDC_COOKIE_SECRET:-}"

    # Leer de Vault si ya existen (idempotencia)
    if [[ -z "$oidc_client_secret" ]]; then
        oidc_client_secret=$(_vault kv get -field=client_secret "$VAULT_OIDC_PATH" 2>/dev/null || echo "")
    fi
    if [[ -z "$oidc_client_secret" ]]; then
        oidc_client_secret=$(openssl rand -hex 16)
        oidc_cookie_secret=$(openssl rand -base64 32 | tr -d '\n')
        _vault kv put "$VAULT_OIDC_PATH" \
            client_secret="$oidc_client_secret" \
            cookie_secret="$oidc_cookie_secret" \
            client_id="tryton-erp" \
            created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" 2>/dev/null || {
            echo "${__STEP_FAIL__} configurar_autenticacion_oidc: no se pudo guardar en Vault $VAULT_OIDC_PATH"
            return 1
        }
        _log "Credenciales OIDC generadas y almacenadas en Vault: $VAULT_OIDC_PATH"
    else
        oidc_cookie_secret=$(_vault kv get -field=cookie_secret "$VAULT_OIDC_PATH" 2>/dev/null || echo "")
        _log "Credenciales OIDC recuperadas de Vault: $VAULT_OIDC_PATH"
    fi

    # Crear K8s Secret tryton-oidc-secret desde Vault (idempotente via dry-run + apply)
    _k create secret generic tryton-oidc-secret \
        --namespace="$NAMESPACE" \
        --from-literal=client_secret="$oidc_client_secret" \
        --from-literal=cookie_secret="$oidc_cookie_secret" \
        --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1

    # Aplicar ConfigMap tryton-auth + Deployment oauth2-proxy-tryton + Service (P10)
    _k apply --dry-run=server -f "${FICHA_DIR}/resources/tryton-auth.k8s.yml" >> "$FICHA_LOG" 2>&1 || {
        _log "ADVERTENCIA: dry-run tryton-auth.k8s.yml falló — aplicando de todos modos"
    }
    _k apply -f "${FICHA_DIR}/resources/tryton-auth.k8s.yml" >> "$FICHA_LOG" 2>&1

    # Registrar cliente OIDC en Keycloak si está disponible
    if _k get pod -n "$KC_NAMESPACE" "$KC_POD" --no-headers 2>/dev/null | grep -q Running; then
        local kc_admin_pass
        kc_admin_pass=$(_vault kv get -field=admin_password "secret/tenants/${TENANT_ID}/keycloak" 2>/dev/null || echo "admin")
        local redirect_uri="http://erp.skull.sbos.local/oauth2/callback"
        _k exec -n "$KC_NAMESPACE" "$KC_POD" -- bash -c "
            /opt/keycloak/bin/kcadm.sh create clients \
              -r skull --no-config \
              --server http://localhost:8080 \
              --realm master --user admin --password '${kc_admin_pass}' \
              -s clientId=tryton-erp -s secret='${oidc_client_secret}' \
              -s 'redirectUris=[\"${redirect_uri}\"]' \
              -s publicClient=false -s protocol=openid-connect \
            2>&1 || echo 'SKIP: cliente ya existe o no disponible'
        " >> "$FICHA_LOG" 2>&1 && _log "Cliente OIDC 'tryton-erp' registrado en Keycloak realm skull" \
                                 || _log "ADVERTENCIA: verificar registro manual de 'tryton-erp' en KC"
    else
        _log "PENDIENTE (HITL): Keycloak no disponible — registrar cliente OIDC manualmente:"
        _log "  ClientID: tryton-erp  |  Realm: skull  |  Protocol: openid-connect"
        _log "  RedirectURI: http://erp.skull.sbos.local/oauth2/callback"
        _log "  ClientSecret: (Vault $VAULT_OIDC_PATH → client_secret)"
    fi
    return 0
}

# ── Pre-install ───────────────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__STEP_START__} verificar_postgresql"
    if ! _k get pod -n "$PG_NAMESPACE" "$PG_POD" --no-headers 2>/dev/null | grep -q Running; then
        echo "${__STEP_FAIL__} verificar_postgresql: $PG_POD no está Running en $PG_NAMESPACE"
        return 1
    fi
    echo "${__STEP_OK__} verificar_postgresql"

    echo "${__STEP_START__} verificar_vault"
    if ! _k get pod -n "$VAULT_NAMESPACE" "$VAULT_POD" --no-headers 2>/dev/null | grep -q Running; then
        echo "${__STEP_FAIL__} verificar_vault: $VAULT_POD no está Running en $VAULT_NAMESPACE"
        return 1
    fi
    # Verificar que Vault esté unsealed
    local sealed
    sealed=$(_vault status -format=json 2>/dev/null | grep -o '"sealed":[^,}]*' | cut -d: -f2 | tr -d ' "' || echo "true")
    if [[ "$sealed" == "true" ]]; then
        echo "${__STEP_FAIL__} verificar_vault: Vault está sellado — ejecutar unseal primero"
        return 1
    fi
    echo "${__STEP_OK__} verificar_vault"

    echo "${__STEP_START__} verificar_namespace"
    if ! _k get namespace "$NAMESPACE" --no-headers 2>/dev/null | grep -q Active; then
        _k create namespace "$NAMESPACE" 2>/dev/null || true
        _k label namespace "$NAMESPACE" tenant="$TENANT_ID" managed-by="bos" --overwrite 2>/dev/null || true
    fi
    echo "${__STEP_OK__} verificar_namespace"
    return 0
}

# ── Install ───────────────────────────────────────────────────────────────
ficha_install() {
    mkdir -p "$(dirname "$FICHA_LOG")"

    # 1. Obtener o generar la contraseña de PostgreSQL para el usuario tryton.
    #    Prioridad: env TRYTON_PG_PASSWORD (inyectada por BOS desde Vault)
    #              → leer de Vault si ya fue almacenada
    #              → generar nueva (openssl rand) y almacenar en Vault
    echo "${__STEP_START__} gestionar_credenciales"
    local pg_password="${TRYTON_PG_PASSWORD:-}"

    if [[ -z "$pg_password" ]]; then
        # Intentar leer de Vault primero (idempotencia: reinstalación no regenera)
        pg_password=$(_vault kv get -field=pg_password "$VAULT_PATH" 2>/dev/null || echo "")
    fi

    if [[ -z "$pg_password" ]]; then
        # Generar contraseña nueva (primera instalación)
        pg_password=$(openssl rand -hex 16)
        _log "Generando nueva contraseña PG para usuario tryton (P6 — sin hardcode)"
        _vault kv put "$VAULT_PATH" \
            pg_password="$pg_password" \
            pg_user="tryton" \
            pg_db="tryton_db" \
            created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            2>/dev/null || {
            echo "${__STEP_FAIL__} gestionar_credenciales: no se pudo almacenar en Vault $VAULT_PATH"
            return 1
        }
        _log "Contraseña almacenada en Vault: $VAULT_PATH"
    else
        _log "Contraseña recuperada de Vault: $VAULT_PATH"
    fi
    echo "${__STEP_OK__} gestionar_credenciales"

    # 2. Crear usuario PostgreSQL 'tryton' (idempotente: ALTER si ya existe)
    echo "${__STEP_START__} crear_usuario_pg"
    local user_exists
    user_exists=$(_pg -tAc "SELECT 1 FROM pg_roles WHERE rolname='tryton'" 2>/dev/null || echo "0")
    if [[ "$user_exists" == "1" ]]; then
        # Usuario existe — actualizar contraseña (idempotente)
        _pg -c "ALTER ROLE tryton WITH LOGIN PASSWORD '${pg_password}';" 2>/dev/null || true
        _log "Usuario tryton: contraseña actualizada"
    else
        _pg -c "CREATE ROLE tryton WITH LOGIN PASSWORD '${pg_password}';" 2>/dev/null || {
            echo "${__STEP_FAIL__} crear_usuario_pg: no se pudo crear el rol tryton"
            return 1
        }
        _log "Usuario tryton creado en PostgreSQL"
    fi
    echo "${__STEP_OK__} crear_usuario_pg"

    # 3. Crear base de datos tryton_db (idempotente)
    echo "${__STEP_START__} crear_base_datos"
    local db_exists
    db_exists=$(_pg -tAc "SELECT 1 FROM pg_database WHERE datname='tryton_db'" 2>/dev/null || echo "0")
    if [[ "$db_exists" != "1" ]]; then
        _pg -c "CREATE DATABASE tryton_db OWNER tryton;" 2>/dev/null || {
            echo "${__STEP_FAIL__} crear_base_datos: no se pudo crear tryton_db"
            return 1
        }
        _pg -c "GRANT ALL PRIVILEGES ON DATABASE tryton_db TO tryton;" 2>/dev/null || true
        _log "tryton_db creada (owner: tryton)"
    else
        _log "tryton_db ya existe (idempotente)"
    fi
    echo "${__STEP_OK__} crear_base_datos"

    # 4. Crear K8s Secret con la URI completa (password en el Secret, no en ConfigMap)
    echo "${__STEP_START__} crear_secret_k8s"
    local pg_host="postgresql.${PG_NAMESPACE}.svc.cluster.local"
    local db_uri="postgresql://tryton:${pg_password}@${pg_host}:5432/"
    _k create secret generic tryton-pg-secret \
        --namespace="$NAMESPACE" \
        --from-literal=TRYTOND_DATABASE__URI="$db_uri" \
        --dry-run=client -o yaml 2>/dev/null | _k apply -f - >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} crear_secret_k8s"

    # 5. Aplicar RBAC (ServiceAccount + Role + RoleBinding)
    echo "${__STEP_START__} aplicar_rbac"
    _k apply --dry-run=server -f "${FICHA_DIR}/resources/tryton-rbac.k8s.yml" >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} aplicar_rbac: dry-run falló"
        return 1
    }
    _k apply -f "${FICHA_DIR}/resources/tryton-rbac.k8s.yml" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} aplicar_rbac"

    # 6. Aplicar ConfigMap (trytond.conf sin credenciales)
    echo "${__STEP_START__} aplicar_configmap"
    _k apply --dry-run=server -f "${FICHA_DIR}/resources/tryton-config.k8s.yml" >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} aplicar_configmap: dry-run falló"
        return 1
    }
    _k apply -f "${FICHA_DIR}/resources/tryton-config.k8s.yml" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} aplicar_configmap"

    # 7. Aplicar StatefulSet + Service (P10: dry-run antes de apply)
    echo "${__STEP_START__} aplicar_statefulset"
    _k apply --dry-run=server -f "${FICHA_DIR}/resources/tryton.k8s.yml" >> "$FICHA_LOG" 2>&1 || {
        echo "${__STEP_FAIL__} aplicar_statefulset: dry-run falló — verificar tryton.k8s.yml"
        return 1
    }
    _k apply -f "${FICHA_DIR}/resources/tryton.k8s.yml" >> "$FICHA_LOG" 2>&1
    echo "${__STEP_OK__} aplicar_statefulset"

    # 8. Esperar a que el pod esté Ready (timeout 5 min — imagen ~300MB)
    echo "${__STEP_START__} esperar_ready"
    if ! _k wait --for=condition=Ready pod -l app=tryton -n "$NAMESPACE" --timeout=300s 2>/dev/null; then
        _log "ADVERTENCIA: timeout esperando tryton — verificando estado..."
        _k get pods -n "$NAMESPACE" -l app=tryton >> "$FICHA_LOG" 2>&1
        _k describe pod -l app=tryton -n "$NAMESPACE" 2>/dev/null | tail -20 >> "$FICHA_LOG" 2>&1
        echo "${__STEP_FAIL__} esperar_ready: pod no Ready en 300s — revisar $FICHA_LOG"
        return 1
    fi
    echo "${__STEP_OK__} esperar_ready"

    # 8.5. Configurar autenticación OIDC (oauth2-proxy-tryton + Keycloak/bAuth)
    echo "${__STEP_START__} configurar_autenticacion_oidc"
    configurar_autenticacion_oidc || {
        echo "${__STEP_FAIL__} configurar_autenticacion_oidc"
        return 1
    }
    echo "${__STEP_OK__} configurar_autenticacion_oidc"

    # 9. Aplicar Kong Ingress — ruta: erp.skull.sbos.local → oauth2-proxy-tryton:4180
    echo "${__STEP_START__} configurar_kong_route"
    if _k get deployment kong -n sbos-gateway --no-headers 2>/dev/null | grep -q "1/1"; then
        _k apply --dry-run=server -f "${FICHA_DIR}/resources/tryton-kong.k8s.yml" >> "$FICHA_LOG" 2>&1 || {
            _log "ADVERTENCIA: dry-run Kong Ingress falló — aplicando de todos modos"
        }
        _k apply -f "${FICHA_DIR}/resources/tryton-kong.k8s.yml" >> "$FICHA_LOG" 2>&1
        _log "Kong Ingress configurado: erp.skull.sbos.local → oauth2-proxy-tryton:4180 → tryton:8000"
        echo "${__STEP_OK__} configurar_kong_route"
    else
        _log "ADVERTENCIA: Kong no disponible — Ingress pendiente (ejecutar 'bosctl ficha repair tryton' cuando Kong esté activo)"
        echo "${__STEP_SKIP__} configurar_kong_route: Kong no disponible todavía"
    fi

    _log "Tryton ERP instalado (namespace=$NAMESPACE, tenant=$TENANT_ID)"
    return 0
}

# ── Post-install ─────────────────────────────────────────────────────────
ficha_post_install() {
    echo "${__STEP_START__} verificar_estado_final"
    _k get statefulset tryton -n "$NAMESPACE" -o wide 2>/dev/null | tee -a "$FICHA_LOG"
    _k get pods -n "$NAMESPACE" -l app=tryton 2>/dev/null | tee -a "$FICHA_LOG"

    # Verificar que el secreto existe
    if ! _k get secret tryton-pg-secret -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q tryton-pg-secret; then
        echo "${__STEP_FAIL__} verificar_estado_final: tryton-pg-secret no encontrado"
        return 1
    fi
    echo "${__STEP_OK__} verificar_estado_final"

    _log "===================================================================="
    _log " Tryton ERP listo"
    _log " URL: http://erp.skull.sbos.local (Kong → oauth2-proxy-tryton → Tryton)"
    _log " Auth Fase 1: Keycloak realm skull (cliente: tryton-erp)"
    _log " Auth Fase 2: cambiar ConfigMap tryton-auth → OIDC_ISSUER_URL de bAuth"
    _log "             + kubectl rollout restart deployment/oauth2-proxy-tryton -n sbos-erp"
    _log " Credenciales PG en Vault:   $VAULT_PATH"
    _log " Credenciales OIDC en Vault: $VAULT_OIDC_PATH"
    _log " Siguiente paso: bosctl ficha init tryton --modules=account,sale,purchase"
    _log "===================================================================="
    return 0
}

# ── Repair ───────────────────────────────────────────────────────────────
ficha_repair() {
    _log "Reparando Tryton..."
    echo "${__STEP_START__} reparar_tryton"

    # Re-aplicar todos los manifiestos (idempotente)
    _k apply -f "${FICHA_DIR}/resources/tryton-rbac.k8s.yml"    >> "$FICHA_LOG" 2>&1 || true
    _k apply -f "${FICHA_DIR}/resources/tryton-config.k8s.yml"  >> "$FICHA_LOG" 2>&1 || true
    _k apply -f "${FICHA_DIR}/resources/tryton.k8s.yml"          >> "$FICHA_LOG" 2>&1 || true
    _k apply -f "${FICHA_DIR}/resources/tryton-auth.k8s.yml"    >> "$FICHA_LOG" 2>&1 || true
    _k apply -f "${FICHA_DIR}/resources/tryton-kong.k8s.yml"    >> "$FICHA_LOG" 2>&1 || true

    # Reiniciar pods para aplicar cambios de configuración
    _k rollout restart statefulset tryton             -n "$NAMESPACE" 2>/dev/null || true
    _k rollout restart deployment oauth2-proxy-tryton -n "$NAMESPACE" 2>/dev/null || true
    _k wait --for=condition=Ready pod -l app=tryton -n "$NAMESPACE" --timeout=300s 2>/dev/null || true

    echo "${__STEP_OK__} reparar_tryton"
    return 0
}

# ── Test ─────────────────────────────────────────────────────────────────
ficha_test() {
    local ok=0

    echo "${__STEP_START__} test_statefulset"
    local ready
    ready=$(_k get statefulset tryton -n "$NAMESPACE" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "$ready" -ge 1 ]]; then
        echo "${__STEP_OK__} test_statefulset (readyReplicas=$ready)"
    else
        echo "${__STEP_FAIL__} test_statefulset: readyReplicas=$ready (esperado ≥1)"
        ok=1
    fi

    echo "${__STEP_START__} test_base_datos"
    local db_exists
    db_exists=$(_pg -tAc "SELECT 1 FROM pg_database WHERE datname='tryton_db'" 2>/dev/null || echo "0")
    if [[ "$db_exists" == "1" ]]; then
        echo "${__STEP_OK__} test_base_datos (tryton_db existe)"
    else
        echo "${__STEP_FAIL__} test_base_datos: tryton_db no existe"
        ok=1
    fi

    echo "${__STEP_START__} test_secret"
    if _k get secret tryton-pg-secret -n "$NAMESPACE" --no-headers 2>/dev/null | grep -q tryton-pg-secret; then
        echo "${__STEP_OK__} test_secret (tryton-pg-secret existe)"
    else
        echo "${__STEP_FAIL__} test_secret: tryton-pg-secret no encontrado"
        ok=1
    fi

    echo "${__STEP_START__} test_vault"
    local vault_val
    vault_val=$(_vault kv get -field=pg_user "$VAULT_PATH" 2>/dev/null || echo "")
    if [[ "$vault_val" == "tryton" ]]; then
        echo "${__STEP_OK__} test_vault (secreto en $VAULT_PATH)"
    else
        echo "${__STEP_FAIL__} test_vault: no se encontró secreto en $VAULT_PATH"
        ok=1
    fi

    echo "${__STEP_START__} test_oauth2_proxy"
    local proxy_ready
    proxy_ready=$(_k get deployment oauth2-proxy-tryton -n "$NAMESPACE" \
        -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${proxy_ready:-0}" -ge 1 ]]; then
        echo "${__STEP_OK__} test_oauth2_proxy (readyReplicas=$proxy_ready)"
    else
        local auth_phase
        auth_phase=$(_k get configmap tryton-auth -n "$NAMESPACE" \
            -o jsonpath='{.data.SBOS_AUTH_PROVIDER}' 2>/dev/null || echo "desconocido")
        echo "${__STEP_FAIL__} test_oauth2_proxy: no ready (proveedor=$auth_phase) — verificar registro KC"
        ok=1
    fi

    return $ok
}

# ── Status ───────────────────────────────────────────────────────────────
ficha_status() {
    echo "=== tryton STATUS (tenant=$TENANT_ID) ==="
    echo ""
    echo "StatefulSet:"
    _k get statefulset tryton -n "$NAMESPACE" -o wide 2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Pods:"
    _k get pods -n "$NAMESPACE" -l app=tryton 2>/dev/null || echo "  (sin pods)"
    echo ""
    echo "Secret K8s:"
    _k get secret tryton-pg-secret -n "$NAMESPACE" --no-headers 2>/dev/null \
        | awk '{print "  tryton-pg-secret:", $4, "bytes"}' || echo "  (no disponible)"
    echo ""
    echo "Vault:"
    _vault kv get -format=table "$VAULT_PATH" 2>/dev/null | grep -v pg_password || echo "  (no disponible)"
    echo ""
    echo "Base de datos:"
    _pg -tAc \
        "SELECT datname, pg_size_pretty(pg_database_size(datname)) FROM pg_database WHERE datname='tryton_db'" \
        2>/dev/null || echo "  (no disponible)"
    echo ""
    echo "Auth (oauth2-proxy-tryton):"
    _k get deployment oauth2-proxy-tryton -n "$NAMESPACE" -o wide 2>/dev/null || echo "  (no desplegado)"
    local auth_phase
    auth_phase=$(_k get configmap tryton-auth -n "$NAMESPACE" \
        -o jsonpath='{.data.SBOS_AUTH_PROVIDER}' 2>/dev/null || echo "no disponible")
    echo "  Proveedor OIDC activo: $auth_phase"
    echo ""
    echo "Kong Ingress:"
    _k get ingress tryton-ingress -n "$NAMESPACE" 2>/dev/null || echo "  (no configurado)"
}

# ── Uninstall ─────────────────────────────────────────────────────────────
ficha_uninstall() {
    _log "ADVERTENCIA: desinstalando Tryton (BD y datos PVC preservados)"
    echo "${__STEP_START__} desinstalar"
    _k delete statefulset tryton              -n "$NAMESPACE" --ignore-not-found --wait=false 2>/dev/null || true
    _k delete deployment oauth2-proxy-tryton  -n "$NAMESPACE" --ignore-not-found --wait=false 2>/dev/null || true
    _k delete service tryton                 -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete service oauth2-proxy-tryton    -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete ingress tryton-ingress         -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete kongplugin tryton-rate-limit   -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete configmap tryton-config        -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete configmap tryton-auth          -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete serviceaccount tryton-sa       -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete role tryton-role               -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    _k delete rolebinding tryton-rolebinding -n "$NAMESPACE" --ignore-not-found 2>/dev/null || true
    # Secrets y BD preservados — contienen datos del tenant
    _log "PRESERVADO: tryton-pg-secret, tryton-oidc-secret, tryton_db, PVC data-tryton-0"
    echo "${__STEP_OK__} desinstalar"
    return 0
}

# ── Diagnóstico ───────────────────────────────────────────────────────────
ficha_diagnosis() {
    _log "=== Diagnóstico tryton ==="
    echo "--- StatefulSet events ---"
    _k get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | grep -i tryton | tail -15 || true
    echo "--- Pod describe (últimas 30 líneas) ---"
    _k describe pod -l app=tryton -n "$NAMESPACE" 2>/dev/null | tail -30 || true
    echo "--- Logs del pod (últimas 50 líneas) ---"
    _k logs -l app=tryton -n "$NAMESPACE" --tail=50 2>/dev/null || true
}
