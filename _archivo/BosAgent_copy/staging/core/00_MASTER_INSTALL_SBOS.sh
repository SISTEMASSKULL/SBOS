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
# P15: Podman rootful exclusivo (ADR-027) — verificado al inicio.
# ============================================================================

set -euo pipefail

# ── Rootful Guard (ADR-027) ──────────────────────────────────────
# SBOS requires Podman rootful exclusively. Abort if not rootful.

check_podman_rootful() {
    # Verify we are running as root (EUID 0)
    if [[ $EUID -ne 0 ]]; then
        echo "FATAL: SBOS requires root privileges (Podman rootful)."
        echo "Run with: sudo podman run ..."
        exit 99
    fi

    # Tier 1 — true rootful Podman: host_uid == 0
    local uid_map_line1
    uid_map_line1=$(head -1 /proc/1/uid_map 2>/dev/null || echo "")
    if [[ -n "$uid_map_line1" ]]; then
        local host_uid
        host_uid=$(echo "$uid_map_line1" | awk '{print $2}')
        if [[ "$host_uid" == "0" ]]; then
            return 0
        fi
    fi

    # Tier 2 — privileged container: EUID=0 + CAP_SYS_ADMIN effective
    # In a --privileged podman container, uid_map shows user namespace but
    # the container has full capabilities. Check CapEff for CAP_SYS_ADMIN (bit 21).
    # CAP_SYS_ADMIN = 1 << 21 = 0x200000
    local capeff
    capeff=$(grep -i '^CapEff:' /proc/1/status 2>/dev/null | awk '{print $2}' || echo "0")
    if (( 0x$capeff & 0x200000 )); then
        echo "BOS: privileged container detected (CAP_SYS_ADMIN effective) — proceeding"
        return 0
    fi

    # Neither tier satisfied — abort
    echo "FATAL: Podman rootful required."
    echo "  host_uid=${host_uid:-?} (need 0)"
    echo "  CapEff=${capeff:-?} (need CAP_SYS_ADMIN)"
    echo "Use: sudo podman run ... or --privileged container"
    exit 99
}

check_podman_rootful

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

# ── BOS Bootstrap Dependencies ──────────────────────────────────
# Installed ONCE before any ficha runs. These are the BOS engine's own
# runtime dependencies — not part of any ficha's domain.

bos_bootstrap_deps() {
    echo "=== BOS: bootstrapping engine dependencies ==="

    apt-get update -qq
    apt-get install -y -qq curl jq python3 wget 2>&1 | tail -3

    if ! command -v yq &>/dev/null; then
        echo "Installing yq from official binary..."
        wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
        chmod +x /usr/local/bin/yq
    fi

    echo "BOS engine dependencies ready:"
    echo "  curl:    $(command -v curl)"
    echo "  jq:      $(command -v jq)"
    echo "  python3: $(command -v python3)"
    echo "  yq:      $(command -v yq) ($(yq --version 2>&1))"
}

bos_bootstrap_deps

# ── Source helpers ────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/00_TASK_CATALOG_SBOS.sh" ]]; then
    source "$SCRIPT_DIR/00_TASK_CATALOG_SBOS.sh"
else
    echo "FATAL: 00_TASK_CATALOG_SBOS.sh not found in $SCRIPT_DIR"
    exit 99
fi

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

    # 3. Pre-install (P2: failure → ABORT)
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

    # 4. Install (P1: sbos_k8s_core is the ONLY kubectl apply)
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

    # 5. Post-install
    echo "${__SBOS__STEP_START__} post_install"
    if declare -f ficha_post_install > /dev/null 2>&1; then
        ficha_post_install || true
    else
        post_install_generic "$ficha_id" "$ficha_dir" || true
    fi
    echo "${__SBOS__STEP_OK__} post_install"

    # 6. Verify — use ficha-specific health if available
    echo "${__SBOS__STEP_START__} verify"
    local verify_ok=false
    if declare -f ficha_health > /dev/null 2>&1; then
        ficha_health && verify_ok=true || verify_ok=false
    elif declare -f "ficha_${ficha_id}_health" > /dev/null 2>&1; then
        "ficha_${ficha_id}_health" && verify_ok=true || verify_ok=false
    else
        verify_ficha_health "$ficha_id" && verify_ok=true || verify_ok=false
    fi
    if [[ "$verify_ok" != "true" ]]; then
        echo "${__SBOS__STEP_FAIL__} verify: health check failed"
        exit 3
    fi
    echo "${__SBOS__STEP_OK__} verify"

    # Persist state after successful install (P16)
    update_sbos_state "$ficha_id" "installed" "HEALTHY"

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

    # 4. Verify — use ficha-specific health if available
    echo "${__SBOS__STEP_START__} verify"
    local verify_ok=false
    if declare -f ficha_health > /dev/null 2>&1; then
        ficha_health && verify_ok=true || verify_ok=false
    elif declare -f "ficha_${ficha_id}_health" > /dev/null 2>&1; then
        "ficha_${ficha_id}_health" && verify_ok=true || verify_ok=false
    else
        verify_ficha_health "$ficha_id" && verify_ok=true || verify_ok=false
    fi
    if [[ "$verify_ok" != "true" ]]; then
        echo "${__SBOS__STEP_FAIL__} verify — rolling back"
        restore_ficha_resources "$ficha_id"
        exit 3
    fi
    echo "${__SBOS__STEP_OK__} verify"

    update_sbos_state "$ficha_id" "installed" "HEALTHY"

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

    # Verify — use ficha-specific health if available
    echo "${__SBOS__STEP_START__} verify"
    local verify_ok=false
    if declare -f ficha_health > /dev/null 2>&1; then
        ficha_health && verify_ok=true || verify_ok=false
    elif declare -f "ficha_${ficha_id}_health" > /dev/null 2>&1; then
        "ficha_${ficha_id}_health" && verify_ok=true || verify_ok=false
    else
        verify_ficha_health "$ficha_id" && verify_ok=true || verify_ok=false
    fi
    if [[ "$verify_ok" != "true" ]]; then
        echo "${__SBOS__STEP_FAIL__} verify: ficha still degraded after repair"
        exit 3
    fi
    echo "${__SBOS__STEP_OK__} verify"

    update_sbos_state "$ficha_id" "installed" "HEALTHY"

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

    update_sbos_state "$ficha_id" "removed" "N/A"

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

# ── State persistence ────────────────────────────────────────

update_sbos_state() {
    local ficha_id="$1" state="$2" health_status="${3:-UNKNOWN}"
    # P8: STATE_MANAGER (Go) is the sole writer of .sbos_state.json.
    # The bash engine must NOT write to the state file directly — doing
    # so replaces the inode and breaks the Go STATE_MANAGER's open fd + flock.
    # State transitions are handled by the Go observer loop after each saga.
    echo "  [STATE] $ficha_id -> $state ($health_status) — delegado a Go STATE_MANAGER" >&2
    return 0
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
