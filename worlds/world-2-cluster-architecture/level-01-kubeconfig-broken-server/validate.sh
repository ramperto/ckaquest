#!/bin/bash

# Try to connect to the cluster
if kubectl get nodes &>/dev/null 2>&1; then
  SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
  echo "✅ kubectl can reach the cluster! Server: $SERVER"
  exit 0
fi

CURRENT_SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}' 2>/dev/null)
echo "❌ kubectl cannot connect to the cluster."
echo "   Current server: ${CURRENT_SERVER:-unknown}"
echo ""
echo "💡 Check: kubectl config view"
echo "   The server URL is wrong. k3s listens on port 6443."
echo "   Fix: sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config"
exit 1
