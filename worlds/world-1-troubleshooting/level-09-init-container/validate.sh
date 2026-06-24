#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
READY=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)

if [[ "$PHASE" == "Running" && "$READY" == "true" ]]; then
  echo "✅ Pod 'app' is Running! Init container completed successfully."
  exit 0
fi

INIT_STATE=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.initContainerStatuses[0].state.running}' 2>/dev/null)
if [[ -n "$INIT_STATE" ]]; then
  echo "❌ Init container is still running — waiting for db-service on port 5432."
  echo ""
  echo "💡 Create the db-service: kubectl apply -f solution.yaml -n $NS"
  echo "   Check init logs: kubectl logs app -c wait-for-db -n $NS"
fi

echo "❌ Pod 'app' phase: ${PHASE:-Not Found}"
exit 1
