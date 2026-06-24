#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check 1: Node has NO node.kubernetes.io/not-ready taint
NODE=$(kubectl get nodes -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
TAINTS=$(kubectl get node "$NODE" -o jsonpath='{.spec.taints[*].key}' 2>/dev/null)

if echo "$TAINTS" | grep -q "node.kubernetes.io/not-ready"; then
  echo "FAIL: Node '$NODE' still has the node.kubernetes.io/not-ready taint."
  echo "  Current taints: $TAINTS"
  echo ""
  echo "Hint: Remove it with: kubectl taint nodes $NODE node.kubernetes.io/not-ready:NoSchedule-"
  exit 1
fi
echo "PASS: Node '$NODE' has no node.kubernetes.io/not-ready taint."

# Check 2: Pod from critical-service deployment is Running
POD_STATUS=$(kubectl get pods -n "$NS" -l app=critical-service \
  -o jsonpath='{.items[0].status.phase}' 2>/dev/null)

if [[ "$POD_STATUS" != "Running" ]]; then
  echo "FAIL: critical-service pod is not Running (status: ${POD_STATUS:-Not Found})."
  echo ""
  echo "Hint: Check pod events: kubectl describe pod -l app=critical-service -n $NS"
  exit 1
fi

READY=$(kubectl get deployment critical-service -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)

echo "PASS: critical-service pod is Running (ready replicas: ${READY:-0})."
echo ""
echo "Level 16 complete! The taint has been removed and the critical service is running."
exit 0
