#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
RESTARTS=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  # Check it's been stable for a bit (not just accidentally Running between restarts)
  # Probe path should not be /healthz
  PROBE_PATH=$(kubectl get pod web -n "$NS" -o jsonpath='{.spec.containers[0].livenessProbe.httpGet.path}' 2>/dev/null)
  if [[ "$PROBE_PATH" == "/healthz" ]]; then
    echo "❌ Pod is Running but liveness probe still points to /healthz."
    echo "   It will restart again in ~30 seconds."
    exit 1
  fi
  echo "✅ Pod 'web' is Running with a valid liveness probe! Restarts: $RESTARTS"
  exit 0
fi

echo "❌ Pod 'web' not healthy. Phase: ${PHASE:-Not Found}  Restarts: ${RESTARTS:-0}"
echo ""
echo "💡 Check: kubectl describe pod web -n $NS | grep -A10 'Liveness'"
exit 1
