#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

READY=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
PROBE_PORT=$(kubectl get pod web -n "$NS" -o jsonpath='{.spec.containers[0].readinessProbe.httpGet.port}' 2>/dev/null)

if [[ "$READY" == "true" ]]; then
  echo "✅ Pod 'web' is Ready (1/1)! Readiness probe passing."
  exit 0
fi

echo "❌ Pod 'web' is not Ready. Current readiness probe port: ${PROBE_PORT:-unknown}"
echo ""
echo "💡 Check: kubectl describe pod web -n $NS | grep -A5 'Readiness'"
echo "   nginx listens on port 80, not 8080."
exit 1
