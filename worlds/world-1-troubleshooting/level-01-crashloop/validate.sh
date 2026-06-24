#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Pod 'web' is Running and Ready!"
  exit 0
fi

echo "❌ Pod 'web' is not healthy."
echo "   Phase: ${PHASE:-Not Found}  Ready: ${READY:-unknown}"
echo ""
echo "💡 Try: kubectl describe pod web -n $NS"
echo "   Then: kubectl logs web -n $NS"
exit 1
