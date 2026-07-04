#!/usr/bin/env bash
# task_catalog.sh — SBOS Lifecycle Manager
# Ficha 03 — Instala bos.service como daemon systemd
# Orden topológico: 15 (SBOS-049 §3.1)
# R16: sin hardcode de paths

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/sbos-lifecycle}"
readonly UNIT_SRC="${SBOS_FICHA_DIR}/bos.service"
readonly UNIT_DST="/etc/systemd/system/bos.service"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "Verifying systemd availability..."

    if ! command -v systemctl &>/dev/null; then
        echo "ERROR: systemctl not found — systemd required"
        echo "${__SBOS__STEP_FAIL__} pre_install"
        return 1
    fi

    echo "systemd: $(systemctl --version | head -1)"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    echo "Deploying bos.service to systemd..."

    if [[ ! -f "$UNIT_SRC" ]]; then
        echo "ERROR: bos.service not found at $UNIT_SRC"
        echo "${__SBOS__STEP_FAIL__} install"
        return 1
    fi

    cp "$UNIT_SRC" "$UNIT_DST"
    echo "  Unit file installed to $UNIT_DST"

    systemctl daemon-reload
    echo "  systemd daemon-reload OK"

    systemctl enable bos.service
    echo "  bos.service enabled"

    echo "BOS lifecycle service installed"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"

    local errors=0

    if [[ -f "$UNIT_DST" ]]; then
        echo "  Unit file: present OK"
    else
        echo "  ERROR: Unit file missing"
        errors=$((errors + 1))
    fi

    if grep -q 'Type=notify' "$UNIT_DST" 2>/dev/null; then
        echo "  Type=notify: OK"
    else
        echo "  ERROR: Type=notify missing"
        errors=$((errors + 1))
    fi

    if (( errors > 0 )); then
        echo "${__SBOS__STEP_FAIL__} post_install"
        return 1
    fi

    echo "Post-install verification passed"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    echo "Updating bos.service unit file..."

    if [[ ! -f "$UNIT_SRC" ]]; then
        echo "ERROR: source unit not found at $UNIT_SRC"
        echo "${__SBOS__STEP_FAIL__} update"
        return 1
    fi

    cp "$UNIT_SRC" "$UNIT_DST"
    systemctl daemon-reload
    echo "  Unit file updated and daemon-reload done"

    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    echo "Repairing bos.service deployment..."

    if [[ ! -f "$UNIT_SRC" ]]; then
        echo "ERROR: source unit not found at $UNIT_SRC"
        echo "${__SBOS__STEP_FAIL__} repair"
        return 1
    fi

    cp "$UNIT_SRC" "$UNIT_DST"
    systemctl daemon-reload
    systemctl enable bos.service 2>/dev/null || true
    echo "  Unit file reinstalled and enabled"

    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    echo "Removing bos.service from systemd..."

    systemctl disable bos.service 2>/dev/null || echo "  Service already disabled"
    rm -f "$UNIT_DST"
    systemctl daemon-reload
    echo "  Unit file removed"

    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"

    local errors=0

    if [[ ! -f "$UNIT_DST" ]]; then
        echo "bos.service: unit file MISSING"
        errors=$((errors + 1))
    else
        echo "bos.service: unit file PRESENT"
    fi

    if ! systemctl is-enabled --quiet bos.service 2>/dev/null; then
        echo "bos.service: NOT ENABLED"
        errors=$((errors + 1))
    else
        echo "bos.service: ENABLED"
    fi

    if (( errors > 0 )); then
        echo "Lifecycle health: $errors error(s)"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi

    echo "Lifecycle health: unit deployed and enabled"
    echo "${__SBOS__STEP_OK__} health"
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== SBOS Lifecycle Manager Diagnosis ==="
    echo "Unit file: $([[ -f "$UNIT_DST" ]] && echo PRESENT || echo MISSING)"
    echo "systemctl is-active: $(systemctl is-active bos.service 2>/dev/null || echo unknown)"
    echo "systemctl is-enabled: $(systemctl is-enabled bos.service 2>/dev/null || echo unknown)"
    echo "WatchdogSec: $(grep -oP 'WatchdogSec=\K.*' "$UNIT_DST" 2>/dev/null || echo N/A)"
    echo "TimeoutStopSec: $(grep -oP 'TimeoutStopSec=\K.*' "$UNIT_DST" 2>/dev/null || echo N/A)"
}
