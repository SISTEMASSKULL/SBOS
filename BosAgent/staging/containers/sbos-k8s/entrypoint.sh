#!/bin/bash
# entrypoint.sh — prepare container for K8s
set -e

echo "[sbos-k8s] Starting init..."

# Ensure cgroups are mounted
mount -t cgroup2 cgroup2 /sys/fs/cgroup 2>/dev/null || true

# Load required kernel modules (if running on host kernel)
modprobe overlay 2>/dev/null || true
modprobe br_netfilter 2>/dev/null || true

# Ensure containerd starts
systemctl enable containerd
systemctl start containerd

# Enable kubelet
systemctl enable kubelet

echo "[sbos-k8s] Ready for kubeadm init"
echo "[sbos-k8s] Run: kubeadm init --pod-network-cidr=10.244.0.0/16"

# Hand off to systemd
exec /sbin/init
