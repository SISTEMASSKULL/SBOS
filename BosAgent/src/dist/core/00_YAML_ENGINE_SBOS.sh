#!/usr/bin/env bash
# ============================================================================
# 00_YAML_ENGINE_SBOS.sh — Declarative interpreter for SBOS IAM Installer
#
# Wraps yq to parse the architecture registry (00_ARCHITECTURE_SBOS.yml),
# dispatches tasks to bash functions, and enforces architectural principles.
#
# P1:  sbos_k8s_core() is the ONLY kubectl apply dispatch point.
# P7:  Absorb / Execute / Release lifecycle — load, run, clean.
# P10: --dry-run before every kubectl apply.
# P14: diagnosis_first — repair MUST run diagnosis before acting.
# ============================================================================

set -euo pipefail

readonly SBOS_YAML_ENGINE_VERSION="1.0.0"

# ── Dependencies ─────────────────────────────────────────────────

if ! command -v yq &>/dev/null; then
    echo "FATAL: yq (https://github.com/mikefarah/yq) is required by 00_YAML_ENGINE_SBOS.sh"
    exit 99
fi

# ── Configuration ────────────────────────────────────────────────

readonly SBOS_ARCHITECTURE_YML="${SBOS_ARCHITECTURE_YML:-/etc/bos/core/00_ARCHITECTURE_SBOS.yml}"
readonly SBOS_YAML_STRICT="${SBOS_YAML_STRICT:-true}"

# ═══════════════════════════════════════════════════════════════════
# Schema validation
# ═══════════════════════════════════════════════════════════════════

yaml_validate_schema() {
    local arch_file="${1:-$SBOS_ARCHITECTURE_YML}"

    if [[ ! -f "$arch_file" ]]; then
        echo "ERROR: Architecture registry not found: $arch_file"
        return 1
    fi

    local errors=0

    # Required top-level keys
    for key in version principios lifecycle fichas signals; do
        if ! yq -e ".${key}" "$arch_file" &>/dev/null; then
            echo "ERROR: Missing required key '${key}' in $arch_file"
            errors=$((errors + 1))
        fi
    done

    # version must be semver-like
    local ver
    ver=$(yq '.version' "$arch_file" 2>/dev/null)
    if [[ ! "$ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "ERROR: version must be semver (X.Y.Z), got: $ver"
        errors=$((errors + 1))
    fi

    # principios must be a map
    if ! yq -e '.principios | type == "!!map"' "$arch_file" &>/dev/null; then
        echo "ERROR: 'principios' must be a map"
        errors=$((errors + 1))
    fi

    # lifecycle must have at least install phase
    if ! yq -e '.lifecycle.install' "$arch_file" &>/dev/null; then
        echo "ERROR: lifecycle.install is required"
        errors=$((errors + 1))
    fi

    # fichas must be a map or array
    local fichas_type
    fichas_type=$(yq '.fichas | type' "$arch_file" 2>/dev/null)
    if [[ "$fichas_type" != "!!map" && "$fichas_type" != "!!seq" ]]; then
        echo "ERROR: 'fichas' must be a map or sequence, got: $fichas_type"
        errors=$((errors + 1))
    fi

    # signals must be a map
    if ! yq -e '.signals | type == "!!map"' "$arch_file" &>/dev/null; then
        echo "ERROR: 'signals' must be a map"
        errors=$((errors + 1))
    fi

    if (( errors > 0 )); then
        echo "Schema validation FAILED: $errors error(s)"
        return 1
    fi

    return 0
}

# ═══════════════════════════════════════════════════════════════════
# Principle enforcement
# ═══════════════════════════════════════════════════════════════════

yaml_check_principle() {
    local principle_id="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    local active
    active=$(yq ".principios.${principle_id}.activo" "$arch_file" 2>/dev/null)
    if [[ "$active" == "true" ]]; then
        return 0
    fi
    return 1
}

yaml_get_principle_description() {
    local principle_id="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"
    yq ".principios.${principle_id}.descripcion" "$arch_file" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════
# Lifecycle phase resolution
# ═══════════════════════════════════════════════════════════════════

yaml_get_lifecycle_phases() {
    local command="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    local path=".lifecycle.${command}"
    local phases
    phases=$(yq "${path}[]" "$arch_file" 2>/dev/null)
    if [[ -z "$phases" ]]; then
        echo "ERROR: No lifecycle defined for command: $command"
        return 1
    fi
    echo "$phases"
}

yaml_get_phase_handler() {
    local phase="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    yq ".lifecycle.phases.${phase}.handler" "$arch_file" 2>/dev/null
}

yaml_get_phase_timeout() {
    local phase="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    local timeout
    timeout=$(yq ".lifecycle.phases.${phase}.timeout_sec" "$arch_file" 2>/dev/null)
    echo "${timeout:-300}"
}

yaml_get_phase_exit_code() {
    local phase="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    local code
    code=$(yq ".lifecycle.phases.${phase}.exit_code" "$arch_file" 2>/dev/null)
    echo "${code:-3}"
}

# ═══════════════════════════════════════════════════════════════════
# Ficha registry queries
# ═══════════════════════════════════════════════════════════════════

yaml_ficha_exists() {
    local ficha_id="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    yq -e ".fichas[\"${ficha_id}\"]" "$arch_file" &>/dev/null
}

yaml_get_ficha_field() {
    local ficha_id="$1"
    local field="$2"
    local arch_file="${3:-$SBOS_ARCHITECTURE_YML}"

    yq ".fichas[\"${ficha_id}\"].${field}" "$arch_file" 2>/dev/null
}

yaml_get_ficha_dependencies() {
    local ficha_id="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    yq ".fichas[\"${ficha_id}\"].dependencias[]" "$arch_file" 2>/dev/null
}

yaml_get_ficha_category() {
    local ficha_id="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    local cat
    cat=$(yq ".fichas[\"${ficha_id}\"].categoria" "$arch_file" 2>/dev/null)
    echo "${cat:-1}"
}

yaml_list_fichas() {
    local arch_file="${1:-$SBOS_ARCHITECTURE_YML}"
    yq '.fichas | keys[]' "$arch_file" 2>/dev/null
}

yaml_list_fichas_by_category() {
    local category="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    yq ".fichas | to_entries[] | select(.value.categoria == ${category}) | .key" "$arch_file" 2>/dev/null
}

# ═══════════════════════════════════════════════════════════════════
# Dependency resolution (topological sort via yq)
# ═══════════════════════════════════════════════════════════════════

yaml_resolve_dependencies() {
    local ficha_id="$1"
    local arch_file="${2:-$SBOS_ARCHITECTURE_YML}"

    local deps
    deps=$(yq ".fichas[\"${ficha_id}\"].dependencias[]" "$arch_file" 2>/dev/null)
    if [[ -n "$deps" ]]; then
        echo "$deps"
    fi
}

yaml_validate_dependencies_satisfied() {
    local ficha_id="$1"
    local state_file="${2:-$SBOS_STATE_FILE}"
    local arch_file="${3:-$SBOS_ARCHITECTURE_YML}"

    local unsatisfied=0
    local deps
    deps=$(yaml_resolve_dependencies "$ficha_id" "$arch_file")

    if [[ -z "$deps" ]]; then
        return 0
    fi

    while IFS= read -r dep; do
        [[ -z "$dep" ]] && continue
        local dep_state
        dep_state=$(jq -r --arg id "$dep" '.fichas[$id].state // "NOT_INSTALLED"' "$state_file" 2>/dev/null)
        if [[ "$dep_state" != "installed" && "$dep_state" != "operativo" ]]; then
            echo "ERROR: Dependency '$dep' is not installed (state: $dep_state)"
            unsatisfied=$((unsatisfied + 1))
        fi
    done <<< "$deps"

    if (( unsatisfied > 0 )); then
        echo "Dependency check FAILED: $unsatisfied unsatisfied"
        return 1
    fi
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# Dispatch: architecture YAML → bash function (P7 Absorb/Execute/Release)
# ═══════════════════════════════════════════════════════════════════

yaml_dispatch() {
    local task_name="$1"
    local ficha_id="${2:-}"
    local arch_file="${3:-$SBOS_ARCHITECTURE_YML}"

    # Resolve handler from the architecture registry
    local handler
    handler=$(yq ".signals[\"${task_name}\"]" "$arch_file" 2>/dev/null)

    if [[ -z "$handler" || "$handler" == "null" ]]; then
        echo "ERROR: No handler registered for task: $task_name"
        return 1
    fi

    # Check if handler is a bash function
    if ! declare -f "$handler" &>/dev/null; then
        echo "ERROR: Handler '$handler' for task '$task_name' is not a defined function"
        return 1
    fi

    # P7: Absorb — task is already loaded via 00_TASK_CATALOG_SBOS.sh sourcing
    echo "${__SBOS__STEP_START__} ${task_name}"

    # Execute
    if [[ -n "$ficha_id" ]]; then
        "$handler" "$ficha_id"
    else
        "$handler"
    fi
    local rc=$?

    if (( rc != 0 )); then
        echo "${__SBOS__STEP_FAIL__} ${task_name} (exit=$rc)"
        return "$rc"
    fi

    echo "${__SBOS__STEP_OK__} ${task_name}"
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# P1 enforcement: sbos_k8s_core as sole kubectl apply
# ═══════════════════════════════════════════════════════════════════

yaml_enforce_p1() {
    # This function is the ONLY place kubectl apply can be dispatched.
    # All K8s operations must route through here, which delegates to
    # sbos_k8s_core() in 00_TASK_CATALOG_SBOS.sh
    #
    # If any other function calls kubectl directly, it is a P1 violation.

    local manifest_file="$1"
    local namespace="${2:-}"
    local dry_run="${3:-true}"

    # P10: --dry-run before every apply
    if [[ "$dry_run" == "true" ]]; then
        echo "P10: dry-run validation for $manifest_file"
        if ! sbos_k8s_core "$manifest_file" "$namespace" "true"; then
            echo "ERROR: dry-run failed for $manifest_file"
            return 1
        fi
    fi

    sbos_k8s_core "$manifest_file" "$namespace" "false"
}

# ═══════════════════════════════════════════════════════════════════
# P14 enforcement: diagnosis_first
# ═══════════════════════════════════════════════════════════════════

yaml_enforce_p14() {
    local ficha_id="$1"
    local ficha_dir="$2"

    # P14: diagnosis MUST run before any repair action
    echo "P14: diagnosis_first — running diagnosis before repair of $ficha_id"

    if declare -f ficha_diagnosis &>/dev/null; then
        ficha_diagnosis || true
    else
        diagnosis_generic "$ficha_id" || true
    fi

    echo "Diagnosis complete — proceeding to repair"
    return 0
}

# ═══════════════════════════════════════════════════════════════════
# YAML-driven saga execution
# ═══════════════════════════════════════════════════════════════════

yaml_execute_saga() {
    local command="$1"
    local ficha_id="$2"
    local ficha_dir="$3"
    local arch_file="${4:-$SBOS_ARCHITECTURE_YML}"

    echo "${__SBOS__STEP_START__} saga ${command} ${ficha_id}"

    # Read the lifecycle phases for this command from the architecture registry
    local phases
    phases=$(yaml_get_lifecycle_phases "$command" "$arch_file") || {
        echo "${__SBOS__STEP_FAIL__} saga ${command}: no lifecycle defined"
        return 1
    }

    local saga_ok=true
    while IFS= read -r phase; do
        [[ -z "$phase" ]] && continue

        local phase_name
        phase_name=$(yq ".lifecycle.phases.${phase}.name" "$arch_file" 2>/dev/null)
        local handler
        handler=$(yq ".lifecycle.phases.${phase}.handler" "$arch_file" 2>/dev/null)
        local timeout
        timeout=$(yaml_get_phase_timeout "$phase" "$arch_file")

        echo "${__SBOS__STEP_START__} ${phase_name}"

        # Dispatch to the appropriate handler
        local phase_rc=0
        if declare -f "ficha_${handler}" &>/dev/null; then
            "ficha_${handler}" "$ficha_id" "$ficha_dir" || phase_rc=$?
        elif declare -f "${handler}_generic" &>/dev/null; then
            "${handler}_generic" "$ficha_id" "$ficha_dir" || phase_rc=$?
        elif declare -f "$handler" &>/dev/null; then
            "$handler" "$ficha_id" "$ficha_dir" || phase_rc=$?
        else
            echo "WARNING: No handler found for phase '${phase}' (tried ficha_${handler}, ${handler}_generic, ${handler})"
        fi

        if (( phase_rc != 0 )); then
            echo "${__SBOS__STEP_FAIL__} ${phase_name} (exit=$phase_rc)"
            saga_ok=false
            break
        fi

        echo "${__SBOS__STEP_OK__} ${phase_name}"
    done <<< "$phases"

    if [[ "$saga_ok" == "true" ]]; then
        echo "${__SBOS__STEP_OK__} saga ${command} ${ficha_id}"
        return 0
    fi

    # Trigger compensation if defined
    local compensator
    compensator=$(yq ".lifecycle.${command}_compensacion[]" "$arch_file" 2>/dev/null)
    if [[ -n "$compensator" ]]; then
        echo "${__SBOS__ROLLBACK_START__} ${ficha_id}"
        while IFS= read -r comp_phase; do
            [[ -z "$comp_phase" ]] && continue
            local comp_handler
            comp_handler=$(yq ".lifecycle.phases.${comp_phase}.handler" "$arch_file" 2>/dev/null)
            if declare -f "ficha_${comp_handler}" &>/dev/null; then
                "ficha_${comp_handler}" "$ficha_id" "$ficha_dir" || true
            elif declare -f "${comp_handler}_generic" &>/dev/null; then
                "${comp_handler}_generic" "$ficha_id" "$ficha_dir" || true
            fi
        done <<< "$compensator"
        echo "${__SBOS__CLEANUP_DONE__}"
    fi

    echo "${__SBOS__STEP_FAIL__} saga ${command} ${ficha_id}"
    return 1
}

# ═══════════════════════════════════════════════════════════════════
# Architecture registry integrity
# ═══════════════════════════════════════════════════════════════════

yaml_verify_registry_integrity() {
    local arch_file="${1:-$SBOS_ARCHITECTURE_YML}"

    local errors=0

    # Every signal must resolve to a defined bash function
    local signals
    signals=$(yq '.signals | keys[]' "$arch_file" 2>/dev/null)
    while IFS= read -r sig; do
        [[ -z "$sig" ]] && continue
        local handler
        handler=$(yq ".signals[\"${sig}\"]" "$arch_file" 2>/dev/null)
        if ! declare -f "$handler" &>/dev/null; then
            echo "INTEGRITY: signal '${sig}' → handler '${handler}' is not defined"
            errors=$((errors + 1))
        fi
    done <<< "$signals"

    # Every ficha must have a valid category (1, 2, or 3)
    local fichas
    fichas=$(yq '.fichas | keys[]' "$arch_file" 2>/dev/null)
    while IFS= read -r fid; do
        [[ -z "$fid" ]] && continue
        local cat
        cat=$(yq ".fichas[\"${fid}\"].categoria" "$arch_file" 2>/dev/null)
        if [[ ! "$cat" =~ ^[1-3]$ ]]; then
            echo "INTEGRITY: ficha '${fid}' has invalid category: $cat"
            errors=$((errors + 1))
        fi
    done <<< "$fichas"

    if (( errors > 0 )); then
        echo "Registry integrity FAILED: $errors error(s)"
        return 1
    fi
    return 0
}

yaml_show_registry_summary() {
    local arch_file="${1:-$SBOS_ARCHITECTURE_YML}"

    echo "=== SBOS Architecture Registry ==="
    echo "Version: $(yq '.version' "$arch_file")"
    echo "Principles: $(yq '.principios | keys | length' "$arch_file")"
    echo "Lifecycle phases: $(yq '.lifecycle.phases | keys | length' "$arch_file")"
    echo "Fichas registered: $(yq '.fichas | keys | length' "$arch_file")"
    echo "Signals mapped: $(yq '.signals | keys | length' "$arch_file")"
    echo ""
    echo "Fichas by category:"
    for cat in 1 2 3; do
        local count
        count=$(yq ".fichas | to_entries[] | select(.value.categoria == ${cat}) | .key" "$arch_file" 2>/dev/null | wc -l)
        echo "  Cat.${cat} (governance level ${cat}): ${count}"
    done
}
