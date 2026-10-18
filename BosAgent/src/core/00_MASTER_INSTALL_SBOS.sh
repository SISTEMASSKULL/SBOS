#!/usr/bin/env bash
# ============================================================================
# 00_MASTER_INSTALL_SBOS.sh — Entry point of the SBOS IAM Installer
#
# Receives: comando + ficha_id [+ version]
# Locates the ficha in servers/, absorbs its task_catalog.sh,
# executes the requested action, and releases functions.
#
# P1: sbos_k8s_core() is the ONLY kubectl apply in the system.
# P2: pre_install failure → ABORT immediately.
# P7: Absorb / Execute / Release cycle for every ficha operation.
# ============================================================================

set -euo pipefail

# ── Signals ───────────────────────────────────────────────────
# Standardized signals for communication between Bash engine and
# the Go daemon / Python modules via stdout/exit codes.

readonly __SBOS__STEP_START__="__SBOS__STEP_START__"
readonly __SBOS__STEP_OK__="__SBOS__STEP_OK__"
readonly __SBOS__STEP_FAIL__="__SBOS__STEP_FAIL__"
readonly __SBOS__STEP_SKIP__="__SBOS__STEP_SKIP__"
readonly __SBOS__CLEANUP_DONE__="__SBOS__CLEANUP_DONE__"
readonly __SBOS__ROLLBACK_START__="__SBOS__ROLLBACK_START__"

readonly SBOS_VERSION="${SBOS_VERSION:-1.0.0}"
readonly SBOS_SERVERS_DIR="${SBOS_SERVERS_DIR:-/etc/bos/blibs/servers}"
readonly SBOS_STATE_FILE="${SBOS_STATE_FILE:-/etc/bos/.sbos_state.json}"
readonly SBOS_KUBECONFIG="${SBOS_KUBECONFIG:-/etc/bos/.kube/config}"
export KUBECONFIG="${SBOS_KUBECONFIG}"

# ── Configuración del cliente — bos-install.toml ──────────────
# Exportar variables de configuración del cliente para que todas
# las fichas las reciban sin necesidad de pasarlas manualmente.
# Prioridad: env var existente > bos-install.toml > default vacío.
_load_bos_install_config() {
    local toml="${BOS_INSTALL_TOML:-/etc/bos/bos-install.toml}"
    [[ ! -f "$toml" ]] && return 0
    while IFS=' = ' read -r key value; do
        [[ "$key" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$key" ]] && continue
        value="${value//\"/}"
        value="${value//\'/}"
        value="${value## }"
        value="${value%% }"
        case "$key" in
            # Identidad de la empresa cliente
            client_domain)   [[ -z "${BOS_DOMAIN:-}" ]]              && export BOS_DOMAIN="$value" ;;
            org_name)        [[ -z "${BOS_ORG_NAME:-}" ]]            && export BOS_ORG_NAME="$value" ;;
            org_short)       [[ -z "${BOS_ORG_SHORT:-}" ]]           && export BOS_ORG_SHORT="$value" ;;
            server_ip)       [[ -z "${BOS_SERVER_IP:-}" ]]           && export BOS_SERVER_IP="$value" ;;
            tenant_id)       [[ -z "${TENANT_ID:-}" ]]               && export TENANT_ID="$value" ;;
            # Superusuario del primer tenant
            admin_email)     [[ -z "${SBOS_ADMIN_EMAIL:-}" ]]        && export SBOS_ADMIN_EMAIL="$value" ;;
            admin_user)      [[ -z "${SBOS_ADMIN_USER:-}" ]]         && export SBOS_ADMIN_USER="$value" ;;
            admin_name)      [[ -z "${SBOS_ADMIN_NAME:-}" ]]         && export SBOS_ADMIN_NAME="$value" ;;
            admin_password)  [[ -z "${SBOS_ADMIN_PASSWORD:-}" ]]     && export SBOS_ADMIN_PASSWORD="$value" ;;
            # Localización
            timezone)        [[ -z "${SBOS_TIMEZONE:-}" ]]           && export SBOS_TIMEZONE="$value" ;;
            country)         [[ -z "${SBOS_COUNTRY:-}" ]]            && export SBOS_COUNTRY="$value" ;;
            language)        [[ -z "${SBOS_LANGUAGE:-}" ]]           && export SBOS_LANGUAGE="$value" ;;
            # Correo saliente externo (pre-mailserver)
            smtp_host)       [[ -z "${SBOS_SMTP_HOST:-}" ]]          && export SBOS_SMTP_HOST="$value" ;;
            smtp_port)       [[ -z "${SBOS_SMTP_PORT:-}" ]]          && export SBOS_SMTP_PORT="$value" ;;
            smtp_user)       [[ -z "${SBOS_SMTP_USER:-}" ]]          && export SBOS_SMTP_USER="$value" ;;
            smtp_password)   [[ -z "${SBOS_SMTP_PASSWORD:-}" ]]      && export SBOS_SMTP_PASSWORD="$value" ;;
            # Recursos del cluster
            pg_password)     [[ -z "${SBOS_PG_PASSWORD:-}" ]]        && export SBOS_PG_PASSWORD="$value" ;;
            pg_namespace)    [[ -z "${SBOS_PG_NS:-}" ]]              && export SBOS_PG_NS="$value" ;;
            redis_namespace) [[ -z "${SBOS_REDIS_NS:-}" ]]           && export SBOS_REDIS_NS="$value" ;;
            channel)         [[ -z "${SBOS_CHANNEL:-}" ]]            && export SBOS_CHANNEL="$value" ;;
            # Overrides opcionales: servidor de correo
            mail_hostname)              [[ -z "${SBOS_MAIL_HOSTNAME:-}" ]]        && export SBOS_MAIL_HOSTNAME="$value" ;;
            mail_postmaster)            [[ -z "${SBOS_MAIL_POSTMASTER:-}" ]]      && export SBOS_MAIL_POSTMASTER="$value" ;;
            mail_postmaster_password)   [[ -z "${SBOS_MAIL_POSTMASTER_PASS:-}" ]] && export SBOS_MAIL_POSTMASTER_PASS="$value" ;;
            mail_initial_accounts)      [[ -z "${SBOS_MAIL_ACCOUNTS:-}" ]]        && export SBOS_MAIL_ACCOUNTS="$value" ;;
            mail_aliases)               [[ -z "${SBOS_MAIL_ALIASES:-}" ]]         && export SBOS_MAIL_ALIASES="$value" ;;
            mail_relay_host)            [[ -z "${SBOS_MAIL_RELAY_HOST:-}" ]]      && export SBOS_MAIL_RELAY_HOST="$value" ;;
            mail_relay_user)            [[ -z "${SBOS_MAIL_RELAY_USER:-}" ]]      && export SBOS_MAIL_RELAY_USER="$value" ;;
            mail_relay_password)        [[ -z "${SBOS_MAIL_RELAY_PASSWORD:-}" ]]  && export SBOS_MAIL_RELAY_PASSWORD="$value" ;;
            mail_send_limit_hour)       [[ -z "${SBOS_MAIL_SEND_LIMIT:-}" ]]      && export SBOS_MAIL_SEND_LIMIT="$value" ;;
            # Overrides opcionales: Keycloak
            keycloak_admin_password)         [[ -z "${SBOS_KC_ADMIN_PASSWORD:-}" ]]  && export SBOS_KC_ADMIN_PASSWORD="$value" ;;
            keycloak_realm_display_name)     [[ -z "${SBOS_KC_REALM_DISPLAY:-}" ]]   && export SBOS_KC_REALM_DISPLAY="$value" ;;
            keycloak_session_timeout)        [[ -z "${SBOS_KC_SESSION_TIMEOUT:-}" ]] && export SBOS_KC_SESSION_TIMEOUT="$value" ;;
            keycloak_access_token_lifespan)  [[ -z "${SBOS_KC_TOKEN_LIFESPAN:-}" ]]  && export SBOS_KC_TOKEN_LIFESPAN="$value" ;;
            # Overrides opcionales: Tryton ERP
            tryton_company_name)    [[ -z "${SBOS_TRYTON_COMPANY:-}" ]]      && export SBOS_TRYTON_COMPANY="$value" ;;
            tryton_tax_id)          [[ -z "${SBOS_TRYTON_TAX_ID:-}" ]]       && export SBOS_TRYTON_TAX_ID="$value" ;;
            tryton_account_plan)    [[ -z "${SBOS_TRYTON_ACCOUNT_PLAN:-}" ]] && export SBOS_TRYTON_ACCOUNT_PLAN="$value" ;;
            tryton_currency)        [[ -z "${SBOS_CURRENCY:-}" ]]             && export SBOS_CURRENCY="$value" ;;
            tryton_modules)         [[ -z "${SBOS_TRYTON_MODULES:-}" ]]      && export SBOS_TRYTON_MODULES="$value" ;;
            tryton_fiscal_year_start)[[ -z "${SBOS_TRYTON_FY_START:-}" ]]    && export SBOS_TRYTON_FY_START="$value" ;;
            # Overrides opcionales: aplicaciones
            orangehrm_company_name)     [[ -z "${SBOS_OHR_COMPANY:-}" ]]      && export SBOS_OHR_COMPANY="$value" ;;
            orangehrm_country)          [[ -z "${SBOS_OHR_COUNTRY:-}" ]]      && export SBOS_OHR_COUNTRY="$value" ;;
            gnuhealth_institution_name) [[ -z "${SBOS_GH_INSTITUTION:-}" ]]   && export SBOS_GH_INSTITUTION="$value" ;;
            gnuhealth_specialties)      [[ -z "${SBOS_GH_SPECIALTIES:-}" ]]   && export SBOS_GH_SPECIALTIES="$value" ;;
            nextcloud_default_quota)    [[ -z "${SBOS_NC_QUOTA:-}" ]]         && export SBOS_NC_QUOTA="$value" ;;
            nextcloud_apps)             [[ -z "${SBOS_NC_APPS:-}" ]]          && export SBOS_NC_APPS="$value" ;;
            paperless_ocr_languages)    [[ -z "${SBOS_PAPERLESS_OCR:-}" ]]    && export SBOS_PAPERLESS_OCR="$value" ;;
            trilium_password)           [[ -z "${SBOS_TRILIUM_PASSWORD:-}" ]] && export SBOS_TRILIUM_PASSWORD="$value" ;;
            elasticsearch_heap)         [[ -z "${SBOS_ES_HEAP:-}" ]]          && export SBOS_ES_HEAP="$value" ;;
            monitoring_alert_email)     [[ -z "${SBOS_MONITORING_EMAIL:-}" ]] && export SBOS_MONITORING_EMAIL="$value" ;;
            grafana_admin_password)     [[ -z "${SBOS_GRAFANA_PASSWORD:-}" ]] && export SBOS_GRAFANA_PASSWORD="$value" ;;
        esac
    done < "$toml"
}

# _derive_sbos_config: calcula TODAS las variables derivadas a partir de las base.
# Regla: si ya tiene valor (del toml o env) no se sobreescribe.
# Llamar DESPUÉS de _load_bos_install_config.
_derive_sbos_config() {
    local domain="${BOS_DOMAIN:-}"
    local pass="${SBOS_ADMIN_PASSWORD:-}"

    # ── Identidad ─────────────────────────────────────────────────────────────
    [[ -z "${TENANT_ID:-}" ]] && export TENANT_ID="${BOS_ORG_SHORT:-${domain%%.*}}"
    # admin_email deriva del dominio: admin@${client_domain}
    [[ -z "${SBOS_ADMIN_EMAIL:-}" && -n "$domain" ]] && export SBOS_ADMIN_EMAIL="admin@${domain}"
    [[ -z "${SBOS_ADMIN_USER:-}" && -n "${SBOS_ADMIN_EMAIL:-}" ]] \
        && export SBOS_ADMIN_USER="${SBOS_ADMIN_EMAIL%%@*}"

    # ── Servidor de correo — todo deriva del dominio ──────────────────────────
    [[ -z "${SBOS_MAIL_HOSTNAME:-}" ]]        && export SBOS_MAIL_HOSTNAME="mail.${domain}"
    [[ -z "${SBOS_MAIL_POSTMASTER:-}" ]]      && export SBOS_MAIL_POSTMASTER="postmaster@${domain}"
    [[ -z "${SBOS_MAIL_POSTMASTER_PASS:-}" ]] && export SBOS_MAIL_POSTMASTER_PASS="${pass}"
    [[ -z "${SBOS_MAIL_SEND_LIMIT:-}" ]]      && export SBOS_MAIL_SEND_LIMIT="500"
    if [[ -z "${SBOS_MAIL_ACCOUNTS:-}" ]]; then
        export SBOS_MAIL_ACCOUNTS="soporte@${domain}:${pass},info@${domain}:${pass}"
    fi
    if [[ -z "${SBOS_MAIL_ALIASES:-}" ]]; then
        export SBOS_MAIL_ALIASES="noreply@${domain}:${SBOS_ADMIN_EMAIL:-admin@${domain}},abuse@${domain}:${SBOS_MAIL_POSTMASTER}"
    fi

    # ── Keycloak ──────────────────────────────────────────────────────────────
    [[ -z "${SBOS_KC_ADMIN_PASSWORD:-}" ]]  && export SBOS_KC_ADMIN_PASSWORD="${pass}"
    [[ -z "${SBOS_KC_REALM_DISPLAY:-}" ]]   && export SBOS_KC_REALM_DISPLAY="${BOS_ORG_NAME:-${TENANT_ID}}"
    [[ -z "${SBOS_KC_SESSION_TIMEOUT:-}" ]] && export SBOS_KC_SESSION_TIMEOUT="480"
    [[ -z "${SBOS_KC_TOKEN_LIFESPAN:-}" ]]  && export SBOS_KC_TOKEN_LIFESPAN="300"

    # ── Tryton ERP — plan contable y moneda según country ────────────────────
    [[ -z "${SBOS_TRYTON_COMPANY:-}" ]]     && export SBOS_TRYTON_COMPANY="${BOS_ORG_NAME:-}"
    [[ -z "${SBOS_TRYTON_FY_START:-}" ]]    && export SBOS_TRYTON_FY_START="01-01"
    if [[ -z "${SBOS_CURRENCY:-}" ]]; then
        case "${SBOS_COUNTRY:-}" in
            BO) export SBOS_CURRENCY="BOB" ;;
            MX) export SBOS_CURRENCY="MXN" ;;
            ES) export SBOS_CURRENCY="EUR" ;;
            AR) export SBOS_CURRENCY="ARS" ;;
            CO) export SBOS_CURRENCY="COP" ;;
            EC) export SBOS_CURRENCY="USD" ;;
            PE) export SBOS_CURRENCY="PEN" ;;
            CL) export SBOS_CURRENCY="CLP" ;;
            *)  export SBOS_CURRENCY="USD" ;;
        esac
    fi
    if [[ -z "${SBOS_TRYTON_ACCOUNT_PLAN:-}" ]]; then
        case "${SBOS_COUNTRY:-}" in
            BO) export SBOS_TRYTON_ACCOUNT_PLAN="account_bo" ;;
            MX) export SBOS_TRYTON_ACCOUNT_PLAN="account_mx" ;;
            ES) export SBOS_TRYTON_ACCOUNT_PLAN="account_es" ;;
            AR) export SBOS_TRYTON_ACCOUNT_PLAN="account_ar" ;;
            CO) export SBOS_TRYTON_ACCOUNT_PLAN="account_co" ;;
            EC) export SBOS_TRYTON_ACCOUNT_PLAN="account_ec" ;;
            PE) export SBOS_TRYTON_ACCOUNT_PLAN="account_pe" ;;
            *)  export SBOS_TRYTON_ACCOUNT_PLAN="account_generic" ;;
        esac
    fi
    if [[ -z "${SBOS_TRYTON_MODULES:-}" ]]; then
        local base="account_invoice,account_payment,account_statement,sale_crm,project,timesheet,hr,stock_lot"
        case "${SBOS_COUNTRY:-}" in
            BO) export SBOS_TRYTON_MODULES="${base},account_bo_invoice" ;;  # facturas SIN Bolivia
            MX) export SBOS_TRYTON_MODULES="${base},account_mx_cfdi" ;;     # CFDI México
            ES) export SBOS_TRYTON_MODULES="${base},account_es_aeat" ;;     # AEAT España
            *)  export SBOS_TRYTON_MODULES="${base}" ;;
        esac
    fi

    # ── OrangeHRM ─────────────────────────────────────────────────────────────
    [[ -z "${SBOS_OHR_COMPANY:-}" ]] && export SBOS_OHR_COMPANY="${BOS_ORG_NAME:-}"
    [[ -z "${SBOS_OHR_COUNTRY:-}" ]] && export SBOS_OHR_COUNTRY="${SBOS_COUNTRY:-}"

    # ── GNU Health ────────────────────────────────────────────────────────────
    [[ -z "${SBOS_GH_INSTITUTION:-}" ]]  && export SBOS_GH_INSTITUTION="${BOS_ORG_NAME:-}"
    [[ -z "${SBOS_GH_SPECIALTIES:-}" ]]  && export SBOS_GH_SPECIALTIES="general,laboratory,pharmacy"

    # ── Nextcloud ─────────────────────────────────────────────────────────────
    [[ -z "${SBOS_NC_QUOTA:-}" ]] && export SBOS_NC_QUOTA="10240"
    [[ -z "${SBOS_NC_APPS:-}" ]]  && export SBOS_NC_APPS="calendar,contacts,tasks,mail,talk,deck,forms"

    # ── Paperless-NGX — idiomas OCR según language ────────────────────────────
    if [[ -z "${SBOS_PAPERLESS_OCR:-}" ]]; then
        case "${SBOS_LANGUAGE:-es}" in
            es) export SBOS_PAPERLESS_OCR="spa+eng" ;;
            fr) export SBOS_PAPERLESS_OCR="fra+eng" ;;
            pt) export SBOS_PAPERLESS_OCR="por+eng" ;;
            de) export SBOS_PAPERLESS_OCR="deu+eng" ;;
            it) export SBOS_PAPERLESS_OCR="ita+eng" ;;
            *)  export SBOS_PAPERLESS_OCR="eng" ;;
        esac
    fi

    # ── Trilium ───────────────────────────────────────────────────────────────
    [[ -z "${SBOS_TRILIUM_PASSWORD:-}" ]] && export SBOS_TRILIUM_PASSWORD="${pass}"

    # ── Elasticsearch — heap = 25% de RAM (mín 512m, máx 4g) ─────────────────
    if [[ -z "${SBOS_ES_HEAP:-}" ]]; then
        local ram_mb
        ram_mb=$(free -m 2>/dev/null | awk '/^Mem:/{v=int($2/4); if(v<512)v=512; if(v>4096)v=4096; print v}' || echo "512")
        export SBOS_ES_HEAP="${ram_mb}m"
    fi

    # ── Monitoreo ─────────────────────────────────────────────────────────────
    [[ -z "${SBOS_MONITORING_EMAIL:-}" ]]  && export SBOS_MONITORING_EMAIL="${SBOS_ADMIN_EMAIL:-}"
    [[ -z "${SBOS_GRAFANA_PASSWORD:-}" ]]  && export SBOS_GRAFANA_PASSWORD="${pass}"

    # ── URLs públicas derivadas del dominio ───────────────────────────────────
    # Disponibles en TODOS los task_catalog.sh sin necesidad de calcularlas.
    export SBOS_URL_BASE="https://${domain}"
    export SBOS_URL_AUTH="https://auth.${domain}"
    export SBOS_URL_MAIL="https://mail.${domain}"
    export SBOS_URL_ERP="https://erp.${domain}"
    export SBOS_URL_RRHH="https://rrhh.${domain}"
    export SBOS_URL_HEALTH="https://salud.${domain}"
    export SBOS_URL_DOCS="https://docs.${domain}"
    export SBOS_URL_NOTES="https://notas.${domain}"
    export SBOS_URL_DRIVE="https://drive.${domain}"
    export SBOS_URL_MONITOR="https://monitor.${domain}"
    export SBOS_URL_VAULT="https://vault.${domain}"
    export SBOS_URL_API="https://api.${domain}"
    export SBOS_URL_STATUS="https://status.${domain}"
}

_load_bos_install_config
_derive_sbos_config

# ── Usage ─────────────────────────────────────────────────────

usage() {
    cat <<'HELP'
IAM Installer — SBOS Control Plane

Usage:
  bosctl <comando> <ficha_id> [version]

Commands:
  install   Install a ficha (validate → pre_install → install → post_install → verify)
  update    Update a ficha to a new version (backup → update → verify → rollback on fail)
  repair    Diagnose and repair a degraded ficha (diagnosis_first → repair → verify)
  remove    Uninstall a ficha (governance check → uninstall → cleanup)
  status    Show status of a ficha or all fichas
  probe     Dry-run all steps without applying changes
  lint      Validate ficha contracts against SBOS schema

Exit codes:
  0  Success
  1  Validation failure (ficha contract broken)
  2  Pre-install check failure (system requirements not met)
  3  Runtime failure (operation failed, rollback executed)
  4  Governance denied (insufficient approvals for Category 3)
  5  Timeout (operation exceeded time limit)
HELP
    exit "${1:-1}"
}

# ── Engine dependency bootstrap ───────────────────────────────
# Instala curl, jq, python3 y yq antes de cargar los módulos del motor.
# yq es requerido en tiempo de carga por 00_YAML_ENGINE_SBOS.sh.

bos_bootstrap_deps() {
    echo "=== BOS: bootstrapping engine dependencies ==="
    export DEBIAN_FRONTEND=noninteractive

    local pkgs=()
    for p in curl jq python3 wget; do
        command -v "$p" > /dev/null 2>&1 || pkgs+=("$p")
    done
    if (( ${#pkgs[@]} > 0 )); then
        apt-get update -qq 2>/dev/null || true
        apt-get install -y -qq "${pkgs[@]}" 2>/dev/null || true
    fi

    if ! command -v yq > /dev/null 2>&1; then
        local YQ_VER="v4.53.2"
        local YQ_BIN="/usr/local/bin/yq"
        local arch
        arch=$(uname -m)
        local yq_arch="amd64"
        [[ "$arch" == "aarch64" ]] && yq_arch="arm64"
        local url="https://github.com/mikefarah/yq/releases/download/${YQ_VER}/yq_linux_${yq_arch}"
        if wget -q -O "$YQ_BIN" "$url" 2>/dev/null || curl -sSL -o "$YQ_BIN" "$url" 2>/dev/null; then
            chmod +x "$YQ_BIN"
        fi
    fi

    echo "BOS engine dependencies ready:"
    for tool in curl jq python3 yq; do
        local path
        path=$(command -v "$tool" 2>/dev/null || echo "MISSING")
        printf "  %-9s %s\n" "${tool}:" "$path"
    done
}

# ── Source helpers ────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/00_TASK_CATALOG_SBOS.sh" ]]; then
    source "$SCRIPT_DIR/00_TASK_CATALOG_SBOS.sh"
else
    echo "FATAL: 00_TASK_CATALOG_SBOS.sh not found in $SCRIPT_DIR"
    exit 99
fi

# Instalar dependencias del motor (curl, jq, python3, yq) ANTES de sourcear
# 00_YAML_ENGINE_SBOS.sh, que requiere yq en tiempo de carga.
bos_bootstrap_deps

if [[ -f "$SCRIPT_DIR/00_YAML_ENGINE_SBOS.sh" ]]; then
    source "$SCRIPT_DIR/00_YAML_ENGINE_SBOS.sh"
fi

# ── Command dispatch ──────────────────────────────────────────

main() {
    local cmd="${1:-}"
    local ficha_id="${2:-}"
    local version="${3:-latest}"

    case "$cmd" in
        install|update|repair|remove|status|probe|lint)
            ;;
        -h|--help|help|"")
            usage 0
            ;;
        *)
            echo "ERROR: Unknown command: $cmd"
            usage 1
            ;;
    esac

    if [[ -z "$ficha_id" && "$cmd" != "status" ]]; then
        echo "ERROR: ficha_id is required for command: $cmd"
        usage 1
    fi

    # Locate ficha directory
    local ficha_dir=""
    if [[ -n "$ficha_id" ]]; then
        ficha_dir=$(find "$SBOS_SERVERS_DIR" -maxdepth 4 -type d -name "$ficha_id" 2>/dev/null | head -1)
        if [[ -z "$ficha_dir" ]]; then
            echo "ERROR: Ficha '$ficha_id' not found under $SBOS_SERVERS_DIR"
            exit 1
        fi
    fi

    # Absorb: load ficha-specific task catalog if it exists
    local ficha_tasks=""
    if [[ -n "$ficha_dir" && -f "$ficha_dir/task_catalog.sh" ]]; then
        ficha_tasks="$ficha_dir/task_catalog.sh"
        # shellcheck source=/dev/null
        source "$ficha_tasks"
    fi

    # Execute command
    case "$cmd" in
        install)  cmd_install "$ficha_id" "$ficha_dir" "$version" ;;
        update)   cmd_update "$ficha_id" "$ficha_dir" "$version" ;;
        repair)   cmd_repair "$ficha_id" "$ficha_dir" ;;
        remove)   cmd_remove "$ficha_id" "$ficha_dir" ;;
        status)   cmd_status "$ficha_id" ;;
        probe)    cmd_probe "$ficha_id" "$ficha_dir" ;;
        lint)     cmd_lint "$ficha_id" "$ficha_dir" ;;
    esac

    # Release: unset ficha-specific functions to avoid cross-ficha pollution (P7)
    if [[ -n "$ficha_tasks" ]]; then
        unset -f $(compgen -A function | grep '^ficha_') 2>/dev/null || true
    fi
}

# ── Command implementations ───────────────────────────────────

cmd_install() {
    local ficha_id="$1" ficha_dir="$2" version="$3"
    local timeout_sec=$((30 * 60))  # 30 min for install

    echo "${__SBOS__STEP_START__} install $ficha_id"

    # 1. Validate ficha contract
    echo "${__SBOS__STEP_START__} validate"
    if ! validate_ficha_contract "$ficha_dir"; then
        echo "${__SBOS__STEP_FAIL__} validate: contract violation"
        exit 1
    fi
    echo "${__SBOS__STEP_OK__} validate"

    # 2. Dependency check
    echo "${__SBOS__STEP_START__} dependencies"
    if ! check_dependencies "$ficha_dir"; then
        echo "${__SBOS__STEP_FAIL__} dependencies: unsatisfied"
        exit 1
    fi
    echo "${__SBOS__STEP_OK__} dependencies"

    # 3. Motor de puertos del host (SBOS-050) — solo fichas que declaran host_ports
    echo "${__SBOS__STEP_START__} motor_puertos"
    if ! check_host_ports "$ficha_dir"; then
        echo "${__SBOS__STEP_FAIL__} motor_puertos: puertos del host bloqueados (ver log)"
        exit 2
    fi
    echo "${__SBOS__STEP_OK__} motor_puertos"

    # 4. Pre-install (P2: failure → ABORT)
    echo "${__SBOS__STEP_START__} pre_install"
    if declare -f ficha_pre_install > /dev/null 2>&1; then
        if ! ficha_pre_install; then
            echo "${__SBOS__STEP_FAIL__} pre_install"
            exit 2
        fi
    else
        if ! pre_install_generic "$ficha_id" "$ficha_dir"; then
            echo "${__SBOS__STEP_FAIL__} pre_install"
            exit 2
        fi
    fi
    echo "${__SBOS__STEP_OK__} pre_install"

    # 5. Install (P1: sbos_k8s_core is the ONLY kubectl apply)
    echo "${__SBOS__STEP_START__} install"
    if declare -f ficha_install > /dev/null 2>&1; then
        if ! ficha_install; then
            echo "${__SBOS__STEP_FAIL__} install — rolling back"
            cmd_rollback_install "$ficha_id" "$ficha_dir"
            exit 3
        fi
    else
        if ! install_generic "$ficha_id" "$ficha_dir"; then
            echo "${__SBOS__STEP_FAIL__} install — rolling back"
            cmd_rollback_install "$ficha_id" "$ficha_dir"
            exit 3
        fi
    fi
    echo "${__SBOS__STEP_OK__} install"

    # 6. Post-install
    echo "${__SBOS__STEP_START__} post_install"
    if declare -f ficha_post_install > /dev/null 2>&1; then
        ficha_post_install || true
    else
        post_install_generic "$ficha_id" "$ficha_dir" || true
    fi
    echo "${__SBOS__STEP_OK__} post_install"

    # 7. Verify
    echo "${__SBOS__STEP_START__} verify"
    if ! verify_ficha_health "$ficha_id"; then
        echo "${__SBOS__STEP_FAIL__} verify: health check failed"
        exit 3
    fi
    echo "${__SBOS__STEP_OK__} verify"

    echo "${__SBOS__STEP_OK__} install $ficha_id"
}

cmd_update() {
    local ficha_id="$1" ficha_dir="$2" version="$3"
    local timeout_sec=$((15 * 60))

    echo "${__SBOS__STEP_START__} update $ficha_id"

    # 1. Backup current state
    echo "${__SBOS__STEP_START__} backup"
    if ! backup_ficha_resources "$ficha_id"; then
        echo "${__SBOS__STEP_FAIL__} backup"
        exit 3
    fi
    echo "${__SBOS__STEP_OK__} backup"

    # 2. Validate new version
    echo "${__SBOS__STEP_START__} validate"
    if ! validate_ficha_contract "$ficha_dir"; then
        echo "${__SBOS__STEP_FAIL__} validate"
        exit 1
    fi
    echo "${__SBOS__STEP_OK__} validate"

    # 3. Execute update
    echo "${__SBOS__STEP_START__} update"
    if declare -f ficha_update > /dev/null 2>&1; then
        if ! ficha_update "$version"; then
            echo "${__SBOS__STEP_FAIL__} update — rolling back"
            restore_ficha_resources "$ficha_id"
            exit 3
        fi
    else
        if ! update_generic "$ficha_id" "$ficha_dir" "$version"; then
            echo "${__SBOS__STEP_FAIL__} update — rolling back"
            restore_ficha_resources "$ficha_id"
            exit 3
        fi
    fi
    echo "${__SBOS__STEP_OK__} update"

    # 4. Verify
    echo "${__SBOS__STEP_START__} verify"
    if ! verify_ficha_health "$ficha_id"; then
        echo "${__SBOS__STEP_FAIL__} verify — rolling back"
        restore_ficha_resources "$ficha_id"
        exit 3
    fi
    echo "${__SBOS__STEP_OK__} verify"

    echo "${__SBOS__STEP_OK__} update $ficha_id"
}

cmd_repair() {
    local ficha_id="$1" ficha_dir="$2"

    echo "${__SBOS__STEP_START__} repair $ficha_id"

    # P14: diagnosis_first — diagnose before acting
    echo "${__SBOS__STEP_START__} diagnosis"
    if declare -f ficha_diagnosis > /dev/null 2>&1; then
        ficha_diagnosis || true
    else
        diagnosis_generic "$ficha_id" || true
    fi
    echo "${__SBOS__STEP_OK__} diagnosis"

    # Execute repair
    echo "${__SBOS__STEP_START__} repair"
    if declare -f ficha_repair > /dev/null 2>&1; then
        ficha_repair || true
    else
        repair_generic "$ficha_id" "$ficha_dir" || true
    fi
    echo "${__SBOS__STEP_OK__} repair"

    # Verify
    echo "${__SBOS__STEP_START__} verify"
    if ! verify_ficha_health "$ficha_id"; then
        echo "${__SBOS__STEP_FAIL__} verify: ficha still degraded after repair"
        exit 3
    fi
    echo "${__SBOS__STEP_OK__} verify"

    echo "${__SBOS__STEP_OK__} repair $ficha_id"
}

cmd_remove() {
    local ficha_id="$1" ficha_dir="$2"

    echo "${__SBOS__STEP_START__} remove $ficha_id"

    # Governance check (Cat.3 requires dual approval)
    if ! check_governance_uninstall "$ficha_id" "$ficha_dir"; then
        echo "${__SBOS__STEP_FAIL__} governance: uninstall denied"
        exit 4
    fi

    # Check no dependents
    if ! check_no_dependents "$ficha_id"; then
        echo "${__SBOS__STEP_FAIL__} dependencies: other fichas depend on $ficha_id"
        exit 1
    fi

    # Execute uninstall
    if declare -f ficha_uninstall > /dev/null 2>&1; then
        ficha_uninstall
    else
        uninstall_generic "$ficha_id" "$ficha_dir"
    fi

    echo "${__SBOS__CLEANUP_DONE__}"
    echo "${__SBOS__STEP_OK__} remove $ficha_id"
}

cmd_status() {
    local ficha_id="${1:-}"
    if [[ -n "$ficha_id" ]]; then
        echo "Status for: $ficha_id"
        if [[ -f "$SBOS_STATE_FILE" ]]; then
            jq --arg id "$ficha_id" '.fichas[$id] // "NOT_FOUND"' "$SBOS_STATE_FILE"
        fi
    else
        echo "All fichas:"
        if [[ -f "$SBOS_STATE_FILE" ]]; then
            jq '.fichas | to_entries[] | "\(.key): \(.value.state) [\(.value.health_status)]"' "$SBOS_STATE_FILE" -r
        fi
    fi
}

cmd_probe() {
    local ficha_id="$1" ficha_dir="$2"
    echo "${__SBOS__STEP_START__} probe $ficha_id"
    echo "Dry-run: validating without applying changes..."

    if ! validate_ficha_contract "$ficha_dir"; then
        echo "${__SBOS__STEP_FAIL__} probe: contract validation failed"
        exit 1
    fi
    if ! check_dependencies "$ficha_dir"; then
        echo "${__SBOS__STEP_FAIL__} probe: dependency check failed"
        exit 1
    fi
    echo "${__SBOS__STEP_OK__} probe: all checks passed (dry-run)"
}

cmd_lint() {
    local ficha_id="$1" ficha_dir="$2"
    echo "${__SBOS__STEP_START__} lint $ficha_id"

    local errors=0
    # Verify manifest.yml exists
    if [[ ! -f "$ficha_dir/manifest.yml" ]]; then
        echo "  ERROR: manifest.yml not found"
        errors=$((errors + 1))
    fi
    # Verify task_catalog.sh exists
    if [[ ! -f "$ficha_dir/task_catalog.sh" ]]; then
        echo "  ERROR: task_catalog.sh not found"
        errors=$((errors + 1))
    fi
    # ShellCheck task_catalog.sh
    if ! shellcheck "$ficha_dir/task_catalog.sh" 2>/dev/null; then
        errors=$((errors + 1))
    fi

    if (( errors > 0 )); then
        echo "${__SBOS__STEP_FAIL__} lint: $errors errors found"
        exit 1
    fi
    echo "${__SBOS__STEP_OK__} lint"
}

# ── Rollback ──────────────────────────────────────────────────

cmd_rollback_install() {
    local ficha_id="$1" ficha_dir="$2"
    echo "${__SBOS__ROLLBACK_START__} $ficha_id"

    if declare -f ficha_uninstall > /dev/null 2>&1; then
        ficha_uninstall || true
    else
        uninstall_generic "$ficha_id" "$ficha_dir" || true
    fi
    echo "${__SBOS__CLEANUP_DONE__}"
}

# ── Entry ─────────────────────────────────────────────────────

main "$@"
