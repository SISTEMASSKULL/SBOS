#!/usr/bin/env bash
# task_catalog.sh — SBOS Bootstrap OS
# Ficha 01 — Prepara el SO antes de instalar K8s
# Orden topológico: 1 (SBOS-049 §3.1)
# R16: sin hardcode de paths

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/sbos-bootstrap-os}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-installer}"

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "Checking system requirements for SBOS bootstrap..."

    local errors=0

    # Verify running as root
    if [[ $EUID -ne 0 ]]; then
        echo "ERROR: must run as root"
        errors=$((errors + 1))
    fi

    # Check RAM
    local ram_mb
    ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
    if (( ram_mb < 3500 )); then
        echo "ERROR: insufficient RAM: ${ram_mb}MB < 3500MB required"
        errors=$((errors + 1))
    else
        echo "RAM: ${ram_mb}MB OK"
    fi

    # Check CPU cores
    local cpus
    cpus=$(nproc 2>/dev/null || echo 0)
    if (( cpus < 2 )); then
        echo "ERROR: insufficient CPUs: $cpus < 2 required"
        errors=$((errors + 1))
    else
        echo "CPUs: $cpus OK"
    fi

    # Check disk space on /
    local disk_avail_gb
    disk_avail_gb=$(df -BG / 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/G//' || echo 0)
    if (( disk_avail_gb < 15 )); then
        echo "ERROR: insufficient disk: ${disk_avail_gb}GB < 15GB required"
        errors=$((errors + 1))
    else
        echo "Disk: ${disk_avail_gb}GB available OK"
    fi

    if (( errors > 0 )); then
        echo "Pre-flight FAILED: $errors error(s)"
        return 1
    fi

    echo "All pre-flight checks passed"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    echo "Preparing OS for Kubernetes..."

    # Load kernel modules
    echo "Loading kernel modules..."
    modprobe overlay 2>/dev/null || echo "  overlay: already loaded or unavailable"
    modprobe br_netfilter 2>/dev/null || echo "  br_netfilter: already loaded or unavailable"

    # Ensure modules load on boot
    cat > /etc/modules-load.d/sbos-k8s.conf <<'MODULES'
overlay
br_netfilter
MODULES

    # Set sysctl parameters
    echo "Configuring sysctl parameters..."
    cat > /etc/sysctl.d/99-sbos-k8s.conf <<'SYSCTL'
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
SYSCTL

    sysctl --system 2>/dev/null || true

    # Verify critical sysctls
    local sysctl_errors=0
    for param in net.bridge.bridge-nf-call-iptables net.ipv4.ip_forward; do
        local val
        val=$(sysctl -n "$param" 2>/dev/null || echo "0")
        if [[ "$val" != "1" ]]; then
            echo "ERROR: $param = $val (expected 1)"
            sysctl_errors=$((sysctl_errors + 1))
        else
            echo "  $param = 1 OK"
        fi
    done

    # Mount cgroup2 if available
    if mountpoint -q /sys/fs/cgroup 2>/dev/null; then
        echo "cgroup2 already mounted at /sys/fs/cgroup"
    else
        mount -t cgroup2 cgroup2 /sys/fs/cgroup 2>/dev/null || echo "  cgroup2 mount skipped (already mounted)"
    fi

    # Verify cgroup writability
    local test_dir="/sys/fs/cgroup/sbos-test-$$"
    if mkdir "$test_dir" 2>/dev/null; then
        rmdir "$test_dir" 2>/dev/null
        echo "cgroup2: writable OK"
    else
        echo "WARNING: cgroup2 not writable — pods may fail to start"
    fi

    # Create SBOS directories
    mkdir -p /opt/bos /etc/bos /run/bos /var/log/bos /etc/bos/blibs/servers

    # Mark bootstrap complete
    touch /etc/sbos/.bootstrapped 2>/dev/null || mkdir -p /etc/sbos && touch /etc/sbos/.bootstrapped

    echo "OS preparation complete"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"

    echo "Verifying OS bootstrap..."
    local errors=0

    # Verify kernel modules
    for mod in overlay br_netfilter; do
        if lsmod | grep -q "^$mod "; then
            echo "  module $mod: loaded OK"
        else
            echo "  module $mod: not loaded (non-critical)"
        fi
    done

    # Verify ip_forward
    local fwd
    fwd=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")
    echo "  net.ipv4.ip_forward = $fwd"

    if (( errors > 0 )); then
        echo "WARNING: $errors non-critical issue(s)"
    fi

    echo "OS bootstrap verification done"
    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    echo "OS bootstrap update: re-applying sysctls..."
    sysctl --system 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    echo "Repairing OS bootstrap..."
    modprobe overlay 2>/dev/null || true
    modprobe br_netfilter 2>/dev/null || true
    sysctl --system 2>/dev/null || true
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    echo "Removing OS bootstrap configuration..."
    rm -f /etc/modules-load.d/sbos-k8s.conf
    rm -f /etc/sysctl.d/99-sbos-k8s.conf
    rm -f /etc/sbos/.bootstrapped
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    if [[ -f /etc/sbos/.bootstrapped ]]; then
        echo "OS bootstrap: HEALTHY"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "OS bootstrap: NOT BOOTSTRAPPED"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== SBOS Bootstrap OS Diagnosis ==="
    echo "RAM: $(awk '/MemTotal/ {printf "%d MB", $2/1024}' /proc/meminfo)"
    echo "CPUs: $(nproc)"
    echo "Disk /: $(df -h / | awk 'NR==2 {print $4}') available"
    echo "Modules:"
    lsmod | grep -E "^overlay|^br_netfilter" || echo "  (none loaded)"
    echo "sysctl:"
    sysctl net.ipv4.ip_forward 2>/dev/null || echo "  (unavailable)"
    echo "cgroup: $(mount | grep cgroup || echo 'none')"
    echo "Bootstrapped: $([[ -f /etc/sbos/.bootstrapped ]] && echo YES || echo NO)"
}
