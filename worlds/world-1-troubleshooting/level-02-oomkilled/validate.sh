#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
REASON=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}' 2>/dev/null)
MEM_LIMIT=$(kubectl get pod web -n "$NS" -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null)

if [[ "$REASON" == "OOMKilled" ]]; then
  echo "❌ Container was OOMKilled — memory limit is still too low."
  echo "   Current limit: ${MEM_LIMIT:-not set}"
  echo ""
  echo "💡 nginx needs at least 64Mi to start. Delete and recreate with higher limits."
  exit 1
fi

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Pod 'web' is Running and Ready! Memory issue resolved."
  exit 0
fi

echo "❌ Pod 'web' not healthy. Phase: ${PHASE:-Not Found}  Ready: ${READY:-unknown}"
echo ""
echo "💡 Check: kubectl describe pod web -n $NS"
exit 1
