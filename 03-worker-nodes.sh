#!/bin/bash
# ============================================================
# Run this script on server02 and server03 (worker nodes)
#
# Replace the kubeadm join command below with the actual
# output from step 02-control-plane-server01.sh
# ============================================================
set -e

echo "==> Joining the Kubernetes cluster..."
echo ""
echo "Paste the 'kubeadm join' command from the control plane output:"
echo "Example:"
echo "  kubeadm join 192.168.122.10:6443 --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
echo ""
read -p "Enter join command: " JOIN_CMD
eval "$JOIN_CMD"

echo ""
echo "==> Worker node $(hostname) has joined the cluster!"
echo "    Verify on server01 with: kubectl get nodes"
