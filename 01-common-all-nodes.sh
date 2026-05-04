#!/bin/bash
# ============================================================
# Run this script on ALL nodes: server01, server02, server03
# ============================================================
set -e

echo "==> [1/7] Update /etc/hosts"
cat >> /etc/hosts <<EOF

# Kubernetes nodes
192.168.122.10  server01
192.168.122.11  server02
192.168.122.12  server03
EOF

echo "==> [2/7] Disable swap"
swapoff -a
sed -i '/swap/s/^/#/' /etc/fstab

echo "==> [3/7] Load kernel modules"
cat > /etc/modules-load.d/k8s.conf <<EOF
overlay
br_netfilter
EOF
modprobe overlay
modprobe br_netfilter

echo "==> [4/7] Set sysctl params"
cat > /etc/sysctl.d/k8s.conf <<EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sysctl --system

echo "==> [5/7] Install containerd"
apt-get update -y
apt-get install -y apt-transport-https ca-certificates curl gpg containerd

mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
# Enable SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl restart containerd
systemctl enable containerd

echo "==> [6/7] Install kubeadm, kubelet, kubectl (v1.32)"
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /' \
    > /etc/apt/sources.list.d/kubernetes.list

apt-get update -y
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl
systemctl enable kubelet

echo "==> [7/7] Done — common setup complete on $(hostname)"
