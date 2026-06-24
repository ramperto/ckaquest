#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
IMAGE=$(kubectl get pod web -n "$NS" -o jsonpath='{.spec.containers[0].image}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Pod 'web' is Running! Image used: $IMAGE"
  exit 0
fi

REASON=$(kubectl get pod web -n "$NS" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)

echo "❌ Pod 'web' is not Running."
echo "   State reason: ${REASON:-unknown}  Image: ${IMAGE:-unknown}"
echo ""
if [[ "$REASON" == "ImagePullBackOff" || "$REASON" == "ErrImagePull" ]]; then
  echo "💡 The image tag doesn't exist. Check available tags and fix the image."
fi
exit 1
