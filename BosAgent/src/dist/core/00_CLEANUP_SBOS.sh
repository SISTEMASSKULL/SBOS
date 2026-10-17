#!/usr/bin/env bash
# 00_CLEANUP_SBOS.sh — Cleanup script for bos-agent staging
# Elimina TODOS los artefactos de una instalación fallida:
# contenedores, servicios, archivos de estado, puertos, volúmenes, redes
# Principio: dejar el sistema exactamente como estaba antes de la instalación.
# SKULL · SBOS · bos-agent · 2026-05-13
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

STAGING_PREFIX="bos-staging"
COREUI_PREFIX="core-ui-staging"
NETWORK="sbos-staging"
BUILD_NETWORK="sbos-build"

CLEANED=0
SKIPPED=0
ERRORS=0

log_clean() { echo -e "${GREEN}[CLEAN]${NC} $1"; ((CLEANED++)); }
log_skip() { echo -e "${YELLOW}[SKIP]${NC}  $1"; ((SKIPPED++)); }
log_error(){ echo -e "${RED}[ERROR]${NC} $1"; ((ERRORS++)); }

main() {
    echo "============================================"
    echo "  SBOS bos-agent CLEANUP"
    echo "  $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "============================================"
    echo ""

    clean_containers
    clean_pods
    clean_state_files
    clean_sockets
    clean_ports
    clean_volumes
    clean_temp_files
    clean_binaries
    verify_clean_state

    echo ""
    echo "============================================"
    echo "  CLEANUP COMPLETE"
    echo "  Cleaned: $CLEANED | Skipped: $SKIPPED | Errors: $ERRORS"
    echo "============================================"

    if [ "$ERRORS" -gt 0 ]; then
        return 1
    fi
}

# ── Step 1: Stop and remove all bos staging containers ──────────
clean_containers() {
    echo "── Containers ──────────────────────────────"

    local containers
    containers=$(podman ps -a --filter "name=${STAGING_PREFIX}" --format '{{.Names}}' 2>/dev/null || true)
    containers="$containers $(podman ps -a --filter "name=${COREUI_PREFIX}" --format '{{.Names}}' 2>/dev/null || true)"

    for c in $containers; do
        [ -z "$c" ] && continue
        echo "  Stopping: $c"
        podman stop "$c" 2>/dev/null || true
        echo "  Removing: $c"
        podman rm "$c" 2>/dev/null || true
        log_clean "Contenedor $c"
    done

    if [ -z "$containers" ] || [ "$containers" = " " ]; then
        log_skip "Sin contenedores bos staging"
    fi
}

# ── Step 2: Remove pods (if any were created) ───────────────────
clean_pods() {
    echo "── Pods ────────────────────────────────────"

    local pods
    pods=$(podman pod ls --filter "name=${STAGING_PREFIX}" --format '{{.Name}}' 2>/dev/null || true)

    for p in $pods; do
        [ -z "$p" ] && continue
        echo "  Removing pod: $p"
        podman pod rm -f "$p" 2>/dev/null || true
        log_clean "Pod $p"
    done

    if [ -z "$pods" ] || [ "$pods" = " " ]; then
        log_skip "Sin pods bos staging"
    fi
}

# ── Step 3: Remove state files ─────────────────────────────────
clean_state_files() {
    echo "── State Files ─────────────────────────────"

    local state_files=(
        "/etc/bos/.sbos_state.json"
        "/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/staging/state/.sbos_state.json"
        "/run/bos/bos.sock"
    )

    for f in "${state_files[@]}"; do
        if [ -f "$f" ]; then
            rm -f "$f"
            log_clean "File $f"
        else
            log_skip "File $f (no existe)"
        fi
    done

    # Remove state directory if empty
    [ -d "/run/bos" ] && rmdir /run/bos 2>/dev/null || true
    [ -d "/etc/bos" ] && rmdir /etc/bos 2>/dev/null || true
}

# ── Step 4: Remove Unix sockets ────────────────────────────────
clean_sockets() {
    echo "── Sockets ─────────────────────────────────"

    local sockets=(
        "/run/bos/bos.sock"
        "/tmp/bos.sock"
    )

    for s in "${sockets[@]}"; do
        if [ -S "$s" ]; then
            rm -f "$s"
            log_clean "Socket $s"
        else
            log_skip "Socket $s (no existe)"
        fi
    done

    # Clean stale socket directories
    if [ -d "/run/bos" ]; then
        rmdir /run/bos 2>/dev/null && log_clean "Dir /run/bos (vacío)" || log_skip "Dir /run/bos (no vacío o no existe)"
    fi
}

# ── Step 5: Verify ports are released ──────────────────────────
clean_ports() {
    echo "── Ports ───────────────────────────────────"

    local ports=(9443 8543 9100)

    for port in "${ports[@]}"; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            local pid
            pid=$(ss -tlnp 2>/dev/null | grep ":${port} " | grep -oP 'pid=\K\d+' | head -1)
            if [ -n "$pid" ] && [ "$pid" -gt 1 ] 2>/dev/null; then
                echo "  Killing process $pid on port $port"
                kill "$pid" 2>/dev/null || true
                sleep 1
            fi
        fi

        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            log_error "Port $port still in use after cleanup attempt"
        else
            log_clean "Port $port free"
        fi
    done
}

# ── Step 6: Remove volumes ─────────────────────────────────────
clean_volumes() {
    echo "── Volumes ─────────────────────────────────"

    local volumes
    volumes=$(podman volume ls --filter "name=${STAGING_PREFIX}" --format '{{.Name}}' 2>/dev/null || true)
    volumes="$volumes $(podman volume ls --filter "name=bos-" --format '{{.Name}}' 2>/dev/null || true)"

    for v in $volumes; do
        [ -z "$v" ] && continue
        echo "  Removing volume: $v"
        podman volume rm "$v" 2>/dev/null || true
        log_clean "Volume $v"
    done

    if [ -z "$volumes" ] || [ "$volumes" = " " ]; then
        log_skip "Sin volúmenes bos staging"
    fi
}

# ── Step 7: Remove temp files ──────────────────────────────────
clean_temp_files() {
    echo "── Temp Files ──────────────────────────────"

    # Remove bos-related temp files
    local tmp_files
    tmp_files=$(find /tmp -maxdepth 1 -name "bos-*" -o -name "bosctl-*" 2>/dev/null || true)

    for f in $tmp_files; do
        [ -z "$f" ] && continue
        rm -rf "$f"
        log_clean "Temp $f"
    done

    if [ -z "$tmp_files" ] || [ "$tmp_files" = " " ]; then
        log_skip "Sin archivos temporales bos"
    fi

    # Clean staging temp files
    local staging_tmp="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/staging"
    if [ -d "$staging_tmp" ]; then
        rm -rf "${staging_tmp:?}/state" 2>/dev/null || true
        rm -rf "${staging_tmp:?}/run" 2>/dev/null || true
        log_clean "Staging temp dirs"
    fi
}

# ── Step 8: Remove built binaries from staging ─────────────────
clean_binaries() {
    echo "── Binaries ────────────────────────────────"

    local bin_dir="/opt/skull/orquestador/proyectos/desarrollo/sbos/BosAgent/src/bin"
    if [ -d "$bin_dir" ]; then
        # Keep the directory, remove binaries
        rm -f "$bin_dir/bos" 2>/dev/null && log_clean "Binary bos"
        rm -f "$bin_dir/bosctl" 2>/dev/null && log_clean "Binary bosctl"
    fi
}

# ── Step 9: Verify clean state ─────────────────────────────────
verify_clean_state() {
    echo "── Final Verification ──────────────────────"

    local issues=0

    # Check no containers
    if podman ps -a --filter "name=${STAGING_PREFIX}" --format '{{.Names}}' 2>/dev/null | grep -q .; then
        log_error "Containers bos-staging still present"
        ((issues++))
    else
        log_clean "No bos-staging containers"
    fi

    # Check ports free
    for port in 9443 8543; do
        if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
            log_error "Port $port still in use"
            ((issues++))
        fi
    done

    # Check no sockets
    if [ -S /run/bos/bos.sock ]; then
        log_error "Socket /run/bos/bos.sock still exists"
        ((issues++))
    else
        log_clean "No bos sockets"
    fi

    if [ "$issues" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}  System is CLEAN — ready for fresh install${NC}"
    else
        echo ""
        log_error "$issues issues remain — manual intervention may be required"
    fi
}

# ── Entry point ────────────────────────────────────────────────
main "$@"
