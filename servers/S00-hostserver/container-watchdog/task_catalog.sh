#!/usr/bin/env bash
# task_catalog.sh — SBOS Container Watchdog task handlers
# Ficha · Order 20 · Host · Critical
# Monitorea procesos core dentro del contenedor sbos-greenfield
# R16: no hardcoded paths. All paths from env vars with defaults.

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/S00-hostserver/container-watchdog}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    # Garantizar que bos arranque en el próximo boot (enable).
    # NO hacer systemctl start: esta ficha es ejecutada POR el daemon bos —
    # arrancarlo desde aquí lo mataría con un reinicio de systemd (P15, ADR-022).
    systemctl enable bos 2>/dev/null || true
    # Verificar que el daemon ya está activo (es quien ejecuta este script).
    if ! systemctl is-active bos >/dev/null 2>&1; then
        echo "WARN: bos.service no activo — esto es anómalo si este script corre dentro de bos"
    fi
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    # Verify bos is active after install
    systemctl is-active bos || echo "WARN: bos not yet active"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    systemctl restart bos 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    systemctl restart bos 2>/dev/null || true
    sleep 3
    systemctl is-active bos || echo "WARN: bos repair — still not active"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    systemctl stop bos 2>/dev/null || true
    systemctl disable bos 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    systemctl is-active bos
    echo "${__SBOS__STEP_OK__} health"
}
