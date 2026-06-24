#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  # Verify the env var key reference is correct (not PASSWORD)
  KEY=$(kubectl get pod app -n "$NS" \
    -o jsonpath='{.spec.containers[0].env[0].valueFrom.secretKeyRef.key}' 2>/dev/null)
  if [[ "$KEY" == "PASSWORD" ]]; then
    echo "❌ Pod is Running but key is still 'PASSWORD' — it may have started by chance."
    echo "   Fix the key reference to 'password' (lowercase)."
    exit 1
  fi
  echo "✅ Pod 'app' is Running with correct secret key reference!"
  exit 0
fi

REASON=$(kubectl get pod app -n "$NS" \
  -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
echo "❌ Pod 'app' not running. Status: ${REASON:-${PHASE:-unknown}}"
echo ""
echo "💡 Check: kubectl describe pod app -n $NS"
echo "   The secret key name in the pod spec must exactly match the key in the Secret."
exit 1
