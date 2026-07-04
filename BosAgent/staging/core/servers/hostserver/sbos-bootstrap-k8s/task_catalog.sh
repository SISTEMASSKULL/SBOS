#!/usr/bin/env bash
# task_catalog.sh — SBOS Bootstrap K8s
# Ficha 02 — kubeadm init + Calico CNI
# Orden topológico: 2 (SBOS-049 §3.1)
# R16: sin hardcode de paths

set -euo pipefail

export SBOS_FICHA_DIR="${SBOS_FICHA_DIR:-/etc/bos/blibs/servers/hostserver/sbos-bootstrap-k8s}"
export SBOS_NAMESPACE="${SBOS_NAMESPACE:-sbos-installer}"
export KUBECONFIG="${KUBECONFIG:-/etc/kubernetes/admin.conf}"

# ── helpers ────────────────────────────────────────────────────

_get_node_ip() {
    hostname -I | awk '{print $1}'
}

_detect_environment() {
    # Returns "container" if running inside Podman/Docker container,
    # "baremetal" if on physical host or VM.
    # Detection via /run/.containerenv (Podman's standard signal file)
    # and systemd-detect-virt as fallback.
    if [[ -f /run/.containerenv ]]; then
        echo "container"
        return 0
    fi
    if command -v systemd-detect-virt &>/dev/null; then
        local virt_type
        virt_type=$(systemd-detect-virt --container 2>/dev/null)
        if [[ -n "$virt_type" && "$virt_type" != "none" ]]; then
            echo "container"
            return 0
        fi
    fi
    echo "baremetal"
}

# P30: cgroup v2 controller delegation for rootless/nested containers.
# With --cgroupns=private, systemd inside the container only delegates memory + pids
# by default. The cpu controller is available in cgroup.controllers but NOT enabled
# in cgroup.subtree_control. This blocks runc from using cpu controller for pods.
# This function creates a oneshot service that enables cpu (and io/cpuset if present)
# in the root cgroup's subtree_control before containerd starts.
_setup_cgroup_delegation() {
    local env_type
    env_type=$(_detect_environment)

    # Only needed in container environments with cgroupns=private.
    # In bare-metal, systemd delegates all controllers by default.
    if [[ "$env_type" != "container" ]]; then
        echo "Bare-metal — cgroup delegation handled by host systemd"
        return 0
    fi

    # Check if cgroup v2 is in use
    if ! stat -f /sys/fs/cgroup 2>/dev/null | grep -q cgroup2fs; then
        echo "WARNING: cgroup v2 not detected — skipping delegation setup"
        return 0
    fi

    echo "Container environment — setting up cgroup v2 controller delegation..."

    # Check which controllers are available vs already delegated
    local available delegated missing
    available=$(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null | tr ' ' '\n' | sort)
    delegated=$(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null | tr ' ' '\n' | sort)

    # Controllers needed for Kubernetes pods: cpu io memory pids cpuset
    missing=""
    for ctrl in cpu cpuset io; do
        if echo "$available" | grep -qx "$ctrl" && ! echo "$delegated" | grep -qx "$ctrl"; then
            missing="$missing +$ctrl"
        fi
    done

    if [[ -z "$missing" ]]; then
        echo "All required controllers already delegated: $delegated"
        return 0
    fi

    echo "Missing controllers to delegate: $missing"
    echo "Creating systemd oneshot service to enable them at boot..."

    # Create service file that runs early (before containerd/kubelet)
    cat > /etc/systemd/system/cgroup-delegate-cpu.service << 'CEOF'
[Unit]
Description=Enable CPU/IO/cpuset controllers in root cgroup subtree_control
Before=containerd.service kubelet.service
DefaultDependencies=no
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash -c "\
    available=\$(cat /sys/fs/cgroup/cgroup.controllers 2>/dev/null); \
    delegated=\$(cat /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null); \
    for ctrl in cpu cpuset io; do \
        if echo \"\$available\" | grep -qw \"\$ctrl\" && ! echo \"\$delegated\" | grep -qw \"\$ctrl\"; then \
            echo \"+\$ctrl\" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null || true; \
        fi; \
    done; \
    echo \"cgroup delegation: \$(cat /sys/fs/cgroup/cgroup.subtree_control)\""

[Install]
WantedBy=multi-user.target
CEOF

    systemctl daemon-reload
    systemctl enable cgroup-delegate-cpu.service 2>/dev/null || true
    systemctl start cgroup-delegate-cpu.service 2>/dev/null || true

    echo "cgroup delegation service: $(systemctl is-active cgroup-delegate-cpu.service 2>/dev/null || echo unknown)"
    echo "Root subtree_control: $(cat /sys/fs/cgroup/cgroup.subtree_control)"
}

# P31: ensure cgroup controllers are propagated at every level of the hierarchy.
# In cgroup v2, controllers are NOT inherited automatically — they must be explicitly
# enabled at each level by writing to cgroup.subtree_control.
# When k8s.io was created before root had controllers in subtree_control,
# its cgroup.controllers is empty (one-time snapshot at creation time).
# We must remove and let containerd recreate it with proper inheritance.
# Source: kernel.org/doc/Documentation/admin-guide/cgroup-v2.rst
_ensure_cgroup_controllers() {
    local cgroup_root="/sys/fs/cgroup"
    local controllers
    controllers=$(cat "${cgroup_root}/cgroup.controllers" 2>/dev/null || echo "cpu memory pids")
    local enable_str
    enable_str=$(echo "$controllers" | tr ' ' '\n' | sed 's/^/+/' | tr '\n' ' ')

    # 1. Propagate at root level (always safe — these are available controllers)
    echo "$enable_str" > "${cgroup_root}/cgroup.subtree_control" 2>/dev/null || true
    echo "root subtree_control: $(cat ${cgroup_root}/cgroup.subtree_control 2>/dev/null)"

    # 2. Handle k8s.io: if it exists but has stale/empty controllers, clean it up
    if [ -d "${cgroup_root}/k8s.io" ]; then
        local k8s_controllers
        k8s_controllers=$(cat "${cgroup_root}/k8s.io/cgroup.controllers" 2>/dev/null || echo "")
        if [[ -z "$k8s_controllers" ]]; then
            echo "k8s.io has EMPTY cgroup.controllers — stale cgroup (created before root had controllers)"
            echo "Cleaning up k8s.io so containerd recreates it with proper inheritance..."
            # Migrate any remaining processes to root cgroup
            find "${cgroup_root}/k8s.io" -name cgroup.procs -exec sh -c '
                while IFS= read -r pid; do
                    [ -n "$pid" ] && echo "$pid" > /sys/fs/cgroup/cgroup.procs 2>/dev/null || true
                done < "$1"
            ' _ {} \;
            # Remove directories depth-first (cgroupfs requires rmdir, not rm)
            find "${cgroup_root}/k8s.io" -depth -type d -exec rmdir {} 2>/dev/null \; || true
            if [ -d "${cgroup_root}/k8s.io" ]; then
                echo "WARNING: could not fully remove k8s.io — controllers may not propagate"
            else
                echo "k8s.io removed — will be recreated with correct controllers on next pod create"
            fi
        else
            # Controllers are properly inherited — propagate them further
            echo "k8s.io cgroup.controllers: $k8s_controllers"
            echo "$enable_str" > "${cgroup_root}/k8s.io/cgroup.subtree_control" 2>/dev/null || true
            echo "k8s.io subtree_control: $(cat ${cgroup_root}/k8s.io/cgroup.subtree_control 2>/dev/null || echo FAILED)"

            # 3. Propagate to all existing pod subdirectories under k8s.io
            find "${cgroup_root}/k8s.io" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while read -r subdir; do
                echo "$enable_str" > "${subdir}/cgroup.subtree_control" 2>/dev/null || true
            done
        fi
    else
        echo "k8s.io does not exist yet — will be created by containerd with correct controllers"
    fi
}

# P18: adaptive CNI installation — kindnet for nested containers, Calico for bare-metal.
# Calico's install-cni init container requires writing to /host/opt/cni/bin which is
# impossible in rootless podman containers without host filesystem privileges.
# kindnet (Kubernetes SIG Testing) is designed for Kubernetes-in-container and
# uses no host bind-mounts.
# Reference: github.com/kubernetes-sigs/kindnet
_install_cni() {
    local env_type="$1"

    if [[ "$env_type" == "container" ]]; then
        echo "Container environment — installing kindnet (K8s-in-container CNI)"
        kubectl apply -f https://raw.githubusercontent.com/kubernetes-sigs/kindnet/refs/heads/main/install-kindnet.yaml 2>&1
    else
        echo "Bare-metal environment — installing Calico CNI"
        kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.29.3/manifests/calico.yaml 2>&1
    fi
}

# P18: detect best snapshotter for this environment
detect_snapshotter() {
    # Tier 1 — overlayfs if kernel supports it
    if grep -q overlay /proc/filesystems 2>/dev/null; then
        echo "overlayfs"
        return 0
    fi
    # Tier 2 — fuse-overlayfs if available (nested containers without kernel overlay)
    if command -v fuse-overlayfs &>/dev/null; then
        echo "fuse-overlayfs"
        return 0
    fi
    # Tier 3 — safe fallback
    echo "native"
}

# ── BOS cgroup ownership fix (P20) ──────────────────────────────
# After kubeadm init creates subdirectories under k8s.io, their
# ownership is container root (→ host subuid, e.g. 100999).
# In rootless podman, runc inside containerd needs them owned by
# the mapped host UID for cgroup.procs writes to succeed.
_ensure_cgroup_ownership() {
    local cg_path="${1:-/sys/fs/cgroup/k8s.io}"
    local cg_uid cg_gid

    if [[ -f /proc/self/uid_map ]]; then
        cg_uid=$(awk 'NR==1{print $2}' /proc/self/uid_map 2>/dev/null || echo 0)
    else
        cg_uid=0
    fi
    if [[ -f /proc/self/gid_map ]]; then
        cg_gid=$(awk 'NR==1{print $2}' /proc/self/gid_map 2>/dev/null || echo 0)
    else
        cg_gid=0
    fi

    if [[ "$cg_uid" -eq 0 ]]; then
        echo "BOS cgroup: rootful container — no ownership fix needed"
        return 0
    fi

    echo "BOS cgroup fix: correcting ownership via host namespace (nsenter)"
    nsenter -t 1 -m -u -i -n -p -- chown -R 1000:1000 "$cg_path" 2>/dev/null || true

    local fixed=0 failed=0
    for d in "$cg_path"/*/; do
        [[ -d "$d" ]] || continue
        local probe="${d}/.bos-probe-$$"
        if touch "$probe" 2>/dev/null; then
            rm -f "$probe" 2>/dev/null
            fixed=$((fixed + 1))
        else
            failed=$((failed + 1))
        fi
    done
    echo "BOS cgroup fix: $fixed subdirs writable, $failed locked (uid=$cg_uid gid=$cg_gid)"
    return 0
}

_get_kubeadm_config() {
    local ip="$1"
    cat <<YAML
apiVersion: kubeadm.k8s.io/v1beta4
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: "$ip"
nodeRegistration:
  criSocket: unix:///run/containerd/containerd.sock
  kubeletExtraArgs:
  - name: cgroup-driver
    value: cgroupfs
  - name: cgroups-per-qos
    value: "false"
  - name: enforce-node-allocatable
    value: ""
  - name: feature-gates
    value: KubeletInUserNamespace=true
  ignorePreflightErrors:
    - SystemVerification
    - FileExisting-ethtool
    - FileExisting-socat
---
apiVersion: kubeadm.k8s.io/v1beta4
kind: ClusterConfiguration
networking:
  podSubnet: 10.244.0.0/16
apiServer:
  certSANs:
    - "$ip"
---
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
cgroupDriver: cgroupfs
featureGates:
  KubeletInUserNamespace: true
YAML
}

# ── pre_install ────────────────────────────────────────────────
ficha_pre_install() {
    echo "${__SBOS__STEP_START__} pre_install"
    echo "Pre-flight checks for K8s bootstrap..."

    local errors=0

    # System-level checks only — package installation is handled by ficha_install
    local ram_mb
    ram_mb=$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0)
    if (( ram_mb < 1500 )); then
        echo "ERROR: insufficient RAM for K8s: ${ram_mb}MB < 1500MB"
        errors=$((errors + 1))
    else
        echo "RAM: ${ram_mb}MB OK"
    fi

    # ── Block 1: sudo NOPASSWD configuration ──────────────────
    # kubeadm init runs under sudo and needs passwordless operation.
    # R16: only configure for the user running the bootstrap.
    if ! command -v sudo &>/dev/null; then
        echo "Installing sudo..."
        apt-get install -y -qq sudo 2>&1 | tail -1
    fi
    local bootstrap_user="${SUDO_USER:-root}"
    if [[ "$bootstrap_user" != "root" ]]; then
        echo "$bootstrap_user ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-${bootstrap_user}-bos"
        chmod 440 "/etc/sudoers.d/90-${bootstrap_user}-bos"
        echo "sudo NOPASSWD configured for $bootstrap_user"
    fi
    # Always ensure root has NOPASSWD for kubeadm operations
    if ! grep -q '^root\s\+ALL=(ALL) NOPASSWD:ALL' /etc/sudoers 2>/dev/null; then
        echo "root ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/90-root-bos
        chmod 440 /etc/sudoers.d/90-root-bos
        echo "sudo NOPASSWD configured for root"
    fi

    # ── Block 2: /sys/fs/cgroup/k8s.io creation ───────────────
    # In nested containers, /sys/fs/cgroup is mounted from host as cgroup2.
    # runc (inside containerd) needs to create k8s.io cgroup subtree.
    # Detect uid/gid mapping for ownership correction.
    local cg_path="/sys/fs/cgroup/k8s.io"
    if [[ ! -d "$cg_path" ]]; then
        echo "Creating $cg_path for K8s cgroup subtree..."
        if ! mkdir -p "$cg_path" 2>/dev/null; then
            echo "ERROR: cannot create $cg_path — cgroup filesystem not writable"
            echo "  cgroup mount: $(mount | grep cgroup)"
            echo "  ls /sys/fs/cgroup/: $(ls -la /sys/fs/cgroup/ 2>/dev/null | head -5)"
            errors=$((errors + 1))
        else
            # Determine correct ownership from uid_map / gid_map
            local cg_uid=0
            local cg_gid=0
            if [[ -f /proc/self/uid_map ]]; then
                cg_uid=$(awk 'NR==1{print $2}' /proc/self/uid_map 2>/dev/null || echo 0)
            fi
            if [[ -f /proc/self/gid_map ]]; then
                cg_gid=$(awk 'NR==1{print $2}' /proc/self/gid_map 2>/dev/null || echo 0)
            fi
            chown "${cg_uid}:${cg_gid}" "$cg_path" 2>/dev/null || true
            chmod 755 "$cg_path" 2>/dev/null || true

            # Write probe: verify the directory is usable
            local probe_dir="${cg_path}/.bos-probe-$$"
            if mkdir "$probe_dir" 2>/dev/null; then
                rmdir "$probe_dir" 2>/dev/null
                echo "cgroup k8s.io: writable (uid=$cg_uid gid=$cg_gid)"
            else
                echo "WARNING: $cg_path created but not writable — kubelet may fail"
            fi
        fi
    else
        echo "cgroup k8s.io: already exists"
    fi

    if (( errors > 0 )); then
        echo "Pre-flight FAILED: $errors error(s)"
        return 1
    fi

    # P31: propagate cgroup controllers before kubeadm creates k8s.io
    _ensure_cgroup_controllers

    echo "All pre-flight checks passed"
    echo "${__SBOS__STEP_OK__} pre_install"
}

# ── install ────────────────────────────────────────────────────
ficha_install() {
    echo "${__SBOS__STEP_START__} install"
    echo "Installing Kubernetes runtime and tools..."

    # ── Step 1: Install containerd + system deps ────────────
    echo "Installing system dependencies..."
    apt-get update -qq
    apt-get install -y -qq containerd crun fuse-overlayfs iproute2 kmod ethtool socat conntrack \
        ipset ebtables 2>&1 | tail -3

    # ── Configure containerd with environment-adaptive snapshotter ──
    # P18: detect environment → adapt automatically
    # P24 (new): nested container overlay requires tmpfs-backed snapshotter
    mkdir -p /etc/containerd

    # Clean any stale containerd state from previous failed attempts.
    # Full wipe: umount tmpfs (if any), then delete everything. Stale blob
    # metadata causes "blob not found" errors even when overlay works.
    systemctl stop containerd 2>/dev/null || true
    umount -l /var/lib/containerd/io.containerd.snapshotter.v1.overlayfs 2>/dev/null || true
    rm -rf /var/lib/containerd/* 2>/dev/null || true
    mkdir -p /var/lib/containerd
    rm -rf /run/containerd/* 2>/dev/null || true
    rm -rf /var/lib/kubelet /var/lib/etcd 2>/dev/null || true

    # Auto-detect best snapshotter for this environment
    local snapshotter
    snapshotter=$(detect_snapshotter)
    echo "BOS: using snapshotter=$snapshotter"

    # In nested containers, the rootfs is overlay which can't nest another overlay.
    # Mount a tmpfs for containerd snapshotter data so its overlay has a clean backing store.
    # P18 + P24: detect environment, adapt storage backend.
    local env_type
    env_type=$(_detect_environment)
    if [[ "$env_type" == "container" ]] && [[ "$snapshotter" == "overlayfs" ]]; then
        local snap_root="/var/lib/containerd/io.containerd.snapshotter.v1.overlayfs"
        echo "Container detected — mounting tmpfs for containerd overlay snapshotter"
        mkdir -p "$snap_root"
        mount -t tmpfs tmpfs "$snap_root" 2>/dev/null || true
        echo "snapshotter backing store: $(df -T "$snap_root" 2>/dev/null | tail -1 | awk '{print $2}')"
    fi

    # Generate default config (provides full plugin definitions)
    containerd config default > /etc/containerd/config.toml 2>/dev/null || true
    # Keep SystemdCgroup = false (default) — use cgroupfs driver with cgroups-per-qos=false
    sed -i "s/^\s*snapshotter = .*/    snapshotter = '${snapshotter}'/" /etc/containerd/config.toml 2>/dev/null || true
    # P24: nested container requires NoPivotRoot=true (rootfs is overlay, can't pivot_root)
    sed -i 's/^\s*NoPivotRoot = false/            NoPivotRoot = true/' /etc/containerd/config.toml 2>/dev/null || true
    sed -i 's/^\s*NoPivotRoot = false/            NoPivotRoot = true/' /etc/containerd/config.toml 2>/dev/null || true
    # P26: rootless nested containers lack CAP_SYS_ADMIN in initial userns
    # NoNewKeyring=true prevents runc from trying to join session keyring (would kill nsexec)
    sed -i 's/^\s*NoNewKeyring = false/            NoNewKeyring = true/' /etc/containerd/config.toml 2>/dev/null || true
    sed -i 's/^\s*NoNewKeyring = false/            NoNewKeyring = true/' /etc/containerd/config.toml 2>/dev/null || true
    # P27: crun as OCI runtime
    sed -i "s|^\s*BinaryName = .*|            BinaryName = '/usr/bin/crun'|" /etc/containerd/config.toml 2>/dev/null || true
    sed -i "s|^\s*BinaryName = .*|            BinaryName = '/usr/bin/crun'|" /etc/containerd/config.toml 2>/dev/null || true
    # P29: restrict_oom_score_adj = true — solución oficial Kubernetes para user namespaces
    # (kubelet-in-userns). Contienenrd maneja el OOM score en lugar del OCI runtime,
    # evitando que crun/runc escriba /proc/self/oom_score_adj sin CAP_SYS_RESOURCE en initial userns.
    sed -i 's/^\s*restrict_oom_score_adj = false/            restrict_oom_score_adj = true/' /etc/containerd/config.toml 2>/dev/null || true
    sed -i 's/^\s*restrict_oom_score_adj = false/            restrict_oom_score_adj = true/' /etc/containerd/config.toml 2>/dev/null || true

    # P30: ensure cpu/io/cpuset controllers are delegated in cgroup v2 before containerd starts.
    # Required for --cgroupns=private containers where systemd only delegates memory+pids.
    _setup_cgroup_delegation

    systemctl enable containerd 2>/dev/null || true
    systemctl restart containerd 2>/dev/null || true
    sleep 2
    echo "containerd: $(systemctl is-active containerd 2>/dev/null || echo unknown)"
    echo "snapshotter: $(grep 'snapshotter =' /etc/containerd/config.toml | head -1)"

    # ── Step 2: Install K8s apt repo + packages ──────────────
    if ! command -v kubeadm &>/dev/null; then
        echo "Adding Kubernetes apt repository..."

        # Ensure gnupg is available for key import
        if ! command -v gpg &>/dev/null; then
            apt-get install -y -qq gnupg 2>&1 | tail -1
        fi

        local k8s_version="1.32"
        mkdir -p /etc/apt/keyrings
        curl -fsSL "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" \
            | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null

        if [[ -s /etc/apt/keyrings/kubernetes-apt-keyring.gpg ]]; then
            echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/ /" \
                > /etc/apt/sources.list.d/kubernetes.list
            apt-get update -qq
            apt-get install -y -qq kubeadm kubelet kubectl 2>&1 | tail -3
            apt-mark hold kubeadm kubelet kubectl 2>/dev/null || true
        else
            echo "ERROR: Failed to import Kubernetes signing key"
            return 1
        fi
    fi

    echo "kubeadm: $(kubeadm version -o short 2>/dev/null || echo 'available')"
    echo "kubelet: $(kubelet --version 2>/dev/null || echo 'available')"

    # Reset any previous failed init
    if [[ -f /etc/kubernetes/admin.conf ]]; then
        echo "Previous K8s cluster detected — resetting..."
        kubeadm reset -f 2>/dev/null || true
        rm -rf /etc/kubernetes/manifests/* 2>/dev/null || true
        rm -rf /var/lib/kubelet/* 2>/dev/null || true
        rm -f /etc/kubernetes/*.conf 2>/dev/null || true
    fi

    # ── Step 3: kubeadm init ─────────────────────────────────
    local ip
    ip=$(_get_node_ip)
    echo "Node IP: $ip"

    local config_file="/tmp/kubeadm-config.yaml"
    _get_kubeadm_config "$ip" > "$config_file"
    echo "Kubeadm config written to $config_file"

    systemctl enable kubelet 2>/dev/null || true

    # P29: Delegate=yes for kubelet — enables cgroup subtree delegation
    # Required in rootless containers so kubelet can manage pod cgroups.
    # Pattern from install.sh: Delegate=yes at every level (host→podman→container→kubelet).
    mkdir -p /etc/systemd/system/kubelet.service.d
    cat > /etc/systemd/system/kubelet.service.d/delegate.conf << 'DELCONF'
[Service]
Delegate=yes
DELCONF
    systemctl daemon-reload

    echo "Running kubeadm init (this may take several minutes)..."
    if ! kubeadm init --config "$config_file" 2>&1; then
        echo "ERROR: kubeadm init failed"
        echo "Checking kubelet status..."
        systemctl status kubelet 2>&1 || true
        echo "Checking kubelet logs..."
        journalctl -u kubelet --no-pager -n 20 2>&1 || true
        return 1
    fi

    # Copy kubeconfig for root and bos user
    mkdir -p /root/.kube /etc/bos/.kube
    cp /etc/kubernetes/admin.conf /root/.kube/config
    cp /etc/kubernetes/admin.conf /etc/bos/.kube/config
    export KUBECONFIG=/etc/kubernetes/admin.conf

    # Untaint control-plane node for single-node operation
    echo "Untainting control-plane node..."
    kubectl taint nodes --all node-role.kubernetes.io/control-plane- 2>/dev/null || true
    kubectl taint nodes --all node.kubernetes.io/not-ready- 2>/dev/null || true

    # ── BOS Step: fix cgroup subdirectory ownership (P20) ────────
    # kubeadm init creates pod cgroup dirs owned by container root.
    # In rootless podman, runc needs them owned by the mapped host UID.
    _ensure_cgroup_ownership "/sys/fs/cgroup/k8s.io"

    echo "Kubernetes cluster initialized successfully"
    echo "${__SBOS__STEP_OK__} install"
}

# ── post_install ───────────────────────────────────────────────
ficha_post_install() {
    echo "${__SBOS__STEP_START__} post_install"
    export KUBECONFIG=/etc/kubernetes/admin.conf

    # P31: propagate cgroup controllers at every hierarchy level after kubeadm
    # creates k8s.io and pod subdirectories (needed for cgroup v2 + cgroupns=private).
    _ensure_cgroup_controllers

    # P18: detect environment and install appropriate CNI (kindnet/Calico)
    local env_type
    env_type=$(_detect_environment)
    echo "Environment detected: $env_type"
    _install_cni "$env_type"

    # P31: re-propagate after CNI creates pod cgroup dirs
    _ensure_cgroup_controllers

    # P32: make /run a shared mount for CNI network namespace propagation.
    # Required in nested containers where /run is a tmpfs with private propagation.
    # Without this, kindnet/Calico CNI plugins cannot create network namespaces
    # that are visible across mount namespaces.
    if [[ "$env_type" == "container" ]]; then
        echo "Container environment — making /run a shared mount for CNI..."
        mount --make-shared /run 2>/dev/null || true
        echo "/run mount propagation: $(findmnt -no PROPAGATION /run 2>/dev/null || echo unknown)"
    fi

    # P33: kube-proxy conntrack fix for rootless containers.
    # In rootless podman, /sys/module/nf_conntrack/parameters/hashsize is owned
    # by nobody:nogroup and cannot be written. kube-proxy tries to adjust
    # nf_conntrack hashsize and crashes. Setting maxPerCore: 0 and min: 0
    # disables conntrack table adjustment entirely.
    if [[ "$env_type" == "container" ]]; then
        echo "Container environment — patching kube-proxy conntrack settings..."
        local proxy_configmap
        proxy_configmap=$(kubectl get configmap kube-proxy -n kube-system -o yaml 2>/dev/null)
        if [[ -n "$proxy_configmap" ]]; then
            echo "$proxy_configmap" | sed -E 's/maxPerCore: .*/maxPerCore: 0/' \
                | sed -E 's/min: .*/min: 0/' \
                | kubectl apply -f - 2>/dev/null || true
            kubectl rollout restart daemonset kube-proxy -n kube-system 2>/dev/null || true
            echo "kube-proxy conntrack: disabled (maxPerCore=0, min=0)"
        else
            echo "kube-proxy ConfigMap not found — conntrack fix skipped (may not be needed)"
        fi
    fi

    # Wait for node to become Ready
    echo "Waiting for node to become Ready..."
    local deadline=$(($(date +%s) + 300))
    while (( $(date +%s) < deadline )); do
        local ready
        ready=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || true)
        if (( ready >= 1 )); then
            echo "Node is Ready!"
            break
        fi
        echo "Waiting... $(kubectl get nodes --no-headers 2>/dev/null || echo 'API not ready')"
        sleep 10
    done

    # Show cluster status
    echo ""
    echo "=== Cluster Status ==="
    kubectl get nodes 2>/dev/null || echo "  Nodes: not available"
    kubectl get pods -A 2>/dev/null || echo "  Pods: not available"

    echo "${__SBOS__STEP_OK__} post_install"
}

# ── update ─────────────────────────────────────────────────────
ficha_update() {
    echo "${__SBOS__STEP_START__} update"
    echo "K8s update: kubeadm upgrade plan + apply..."
    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubeadm upgrade plan 2>/dev/null || echo "  No upgrades available"
    echo "${__SBOS__STEP_OK__} update"
}

# ── repair ─────────────────────────────────────────────────────
ficha_repair() {
    echo "${__SBOS__STEP_START__} repair"
    export KUBECONFIG=/etc/kubernetes/admin.conf

    # P31: ensure cgroup controllers before attempting repair
    _ensure_cgroup_controllers

    if ! kubectl cluster-info --request-timeout=3s &>/dev/null; then
        echo "API server unreachable — triggering full reinstall"
        ficha_install
        return $?
    fi
    echo "Repairing K8s control plane..."
    systemctl restart kubelet 2>/dev/null || true
    kubectl get nodes 2>/dev/null || echo "  Nodes not available"
    echo "${__SBOS__STEP_OK__} repair"
}

# ── uninstall ──────────────────────────────────────────────────
ficha_uninstall() {
    echo "${__SBOS__STEP_START__} uninstall"
    export KUBECONFIG=/etc/kubernetes/admin.conf
    echo "Resetting Kubernetes cluster..."
    kubeadm reset -f 2>/dev/null || true
    rm -rf /etc/kubernetes /var/lib/kubelet /etc/bos/.kube /root/.kube
    echo "${__SBOS__STEP_OK__} uninstall"
}

# ── health ─────────────────────────────────────────────────────
ficha_health() {
    echo "${__SBOS__STEP_START__} health"
    export KUBECONFIG=/etc/kubernetes/admin.conf
    if kubectl cluster-info --request-timeout=5s &>/dev/null; then
        local nodes
        nodes=$(kubectl get nodes --no-headers 2>/dev/null | grep -c ' Ready' || echo "0")
        echo "K8s cluster: HEALTHY ($nodes node(s) Ready)"
        echo "${__SBOS__STEP_OK__} health"
    else
        echo "K8s cluster: NOT HEALTHY"
        echo "${__SBOS__STEP_FAIL__} health"
        return 1
    fi
}

# ── diagnosis ──────────────────────────────────────────────────
ficha_diagnosis() {
    echo "=== SBOS Bootstrap K8s Diagnosis ==="
    echo "containerd: $(systemctl is-active containerd 2>/dev/null || echo unknown)"
    echo "kubelet: $(systemctl is-active kubelet 2>/dev/null || echo unknown)"
    export KUBECONFIG=/etc/kubernetes/admin.conf
    kubectl cluster-info 2>&1 || echo "  Cluster not reachable"
    kubectl get nodes 2>&1 || echo "  No nodes"
    kubectl get pods -A 2>&1 || echo "  No pods"
}

export -f _detect_environment
export -f _install_cni
export -f detect_snapshotter
export -f _ensure_cgroup_ownership
export -f _ensure_cgroup_controllers
