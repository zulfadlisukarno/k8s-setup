#!/bin/bash
# ============================================================
# Run on server01 to verify the cluster is healthy
# ============================================================
export KUBECONFIG=/etc/kubernetes/admin.conf

echo "==> Nodes:"
kubectl get nodes -o wide

echo ""
echo "==> System pods:"
kubectl get pods -n kube-system

echo ""
echo "==> Flannel pods:"
kubectl get pods -n kube-flannel

echo ""
echo "==> Deploying a test nginx pod..."
kubectl run nginx-test --image=nginx --port=80
sleep 15
kubectl get pods -o wide

echo ""
echo "==> Cluster info:"
kubectl cluster-info
