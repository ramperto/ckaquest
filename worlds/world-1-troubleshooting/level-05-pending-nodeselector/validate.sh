#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod cache -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod cache -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Pod 'cache' is Running!"
  exit 0
fi

if [[ "$PHASE" == "Pending" ]]; then
  echo "❌ Pod 'cache' is still Pending."
  echo ""
  echo "💡 Check node labels: kubectl get nodes --show-labels"
  echo "   Check pod events: kubectl describe pod cache -n $NS"
fi

exit 1
