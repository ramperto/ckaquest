#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check configmap exists
CM=$(kubectl get configmap app-config -n "$NS" -o name 2>/dev/null)
if [[ -z "$CM" ]]; then
  echo "❌ ConfigMap 'app-config' does not exist."
  echo "💡 Create it: kubectl create configmap app-config --from-literal=APP_ENV=production -n $NS"
  exit 1
fi

# Check pod is running
PHASE=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ ConfigMap 'app-config' exists and pod 'app' is Running!"
  exit 0
fi

REASON=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null)
echo "❌ Pod 'app' is not Running. Status: ${REASON:-${PHASE:-unknown}}"
echo ""
echo "💡 ConfigMap exists. Try: kubectl delete pod app -n $NS && kubectl apply -f broken.yaml"
exit 1
