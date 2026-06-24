#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod web-with-sidecar -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null)

if [[ "$PHASE" != "Running" ]]; then
  echo "❌ Pod not Running (phase: ${PHASE:-Not Found})."
  exit 1
fi

# Check both containers are ready
WEB_READY=$(kubectl get pod web-with-sidecar -n "$NS" \
  -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
SIDECAR_READY=$(kubectl get pod web-with-sidecar -n "$NS" \
  -o jsonpath='{.status.containerStatuses[1].ready}' 2>/dev/null)
SIDECAR_RESTARTS=$(kubectl get pod web-with-sidecar -n "$NS" \
  -o jsonpath='{.status.containerStatuses[1].restartCount}' 2>/dev/null)

if [[ "$WEB_READY" == "true" && "$SIDECAR_READY" == "true" ]]; then
  echo "✅ Both containers are Running and Ready!"
  echo "   web: Ready, log-collector: Ready (restarts: $SIDECAR_RESTARTS)"
  exit 0
fi

echo "❌ Not all containers are Ready."
echo "   web container ready: ${WEB_READY:-unknown}"
echo "   log-collector ready: ${SIDECAR_READY:-unknown}  restarts: ${SIDECAR_RESTARTS:-0}"
echo ""
echo "💡 Check sidecar logs: kubectl logs web-with-sidecar -c log-collector -n $NS"
exit 1
