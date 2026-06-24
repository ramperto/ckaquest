#!/bin/bash

# Static pod name format: <pod-name>-<node-name>
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
STATIC_POD_NAME="infra-monitor-${NODE}"

PHASE=$(kubectl get pod "$STATIC_POD_NAME" -n kube-system \
  -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod "$STATIC_POD_NAME" -n kube-system \
  -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Static pod '$STATIC_POD_NAME' is Running!"
  exit 0
fi

echo "❌ Static pod '$STATIC_POD_NAME' not Running."
echo "   Phase: ${PHASE:-Not Found}"
echo ""
echo "💡 Edit the manifest: sudo vim /etc/kubernetes/manifests/infra-monitor.yaml"
echo "   kubelet automatically restarts pods when the manifest changes."
echo "   Check kubelet logs: sudo journalctl -u k3s -n 50"
exit 1
