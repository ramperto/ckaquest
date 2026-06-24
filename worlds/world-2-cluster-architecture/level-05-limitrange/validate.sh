#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod highcpu -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod highcpu -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Pod 'highcpu' is Running! LimitRange constraint resolved."
  exit 0
fi

echo "❌ Pod 'highcpu' not Running. Phase: ${PHASE:-Not Found}"
echo ""
echo "💡 Check LimitRange: kubectl describe limitrange -n $NS"
echo "   Check pod status: kubectl describe pod highcpu -n $NS"
echo "   The pod's CPU request/limit must be within LimitRange min/max."
exit 1
