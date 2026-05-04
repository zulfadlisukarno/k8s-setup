#!/bin/bash
# ============================================================
# Run this script ONLY on server01 (control plane)
# ============================================================
set -e

CONTROL_PLANE_IP="192.168.122.10"
POD_CIDR="10.244.0.0/16"   # Flannel default

echo "==> [1/3] Initialize Kubernetes control plane"
kubeadm init \
    --apiserver-advertise-address=${CONTROL_PLANE_IP} \
    --pod-network-cidr=${POD_CIDR} \
    --node-name server01 \
    --kubernetes-version 1.32.0

echo "==> [2/3] Configure kubectl for current user"
REAL_USER=${SUDO_USER:-$(whoami)}
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)

mkdir -p ${REAL_HOME}/.kube
cp /etc/kubernetes/admin.conf ${REAL_HOME}/.kube/config
chown ${REAL_USER}:${REAL_USER} ${REAL_HOME}/.kube/config

# Also setup for root
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

export KUBECONFIG=/etc/kubernetes/admin.conf

echo "==> [3/3] Install Flannel CNI"
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml

echo ""
echo "============================================================"
echo "Control plane is ready! Waiting for node to become Ready..."
echo "============================================================"
kubectl get nodes -w &
WATCH_PID=$!
sleep 30
kill $WATCH_PID 2>/dev/null || true

echo ""
echo "==> SAVE THE JOIN COMMAND BELOW — run it on server02 and server03:"
echo "--------------------------------------------------------------------"
kubeadm token create --print-join-command
echo "--------------------------------------------------------------------"
