#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

SVC_TYPE=$(kubectl get svc database -n "$NS" \
  -o jsonpath='{.spec.type}' 2>/dev/null)
EXTERNAL=$(kubectl get svc database -n "$NS" \
  -o jsonpath='{.spec.externalName}' 2>/dev/null)

if [[ "$SVC_TYPE" != "ExternalName" ]]; then
  echo "❌ Service 'database' not found or wrong type: ${SVC_TYPE:-Not Found}"
  echo ""
  echo "💡 Create: kubectl apply -f solution.yaml -n $NS"
  exit 1
fi

if [[ "$EXTERNAL" == "legacy-db.corp.internal" ]]; then
  echo "✅ ExternalName Service 'database' correctly resolves to '$EXTERNAL'"
  echo ""
  echo "   Test DNS (from app pod):"
  echo "   kubectl exec --request-timeout=5s app -n $NS -- nslookup database"
  exit 0
fi

echo "❌ Service type is ExternalName but externalName is wrong: '$EXTERNAL'"
echo "   Expected: legacy-db.corp.internal"
exit 1
