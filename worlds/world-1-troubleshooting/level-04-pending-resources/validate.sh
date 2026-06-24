#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod compute -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod compute -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Pod 'compute' is Running! Scheduler found a node with enough capacity."
  exit 0
fi

if [[ "$PHASE" == "Pending" ]]; then
  REASON=$(kubectl describe pod compute -n "$NS" 2>/dev/null | grep -A5 "Events:" | grep "Insufficient")
  echo "❌ Pod 'compute' is still Pending."
  [[ -n "$REASON" ]] && echo "   Reason: $REASON"
  echo ""
  echo "💡 Check node capacity: kubectl describe nodes"
  echo "   The pod is requesting more resources than any node has."
fi

exit 1
