#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check endpoints are populated
ENDPOINTS=$(kubectl get endpoints backend-svc -n "$NS" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null)

if [[ -n "$ENDPOINTS" && "$ENDPOINTS" != "null" ]]; then
  EP_COUNT=$(kubectl get endpoints backend-svc -n "$NS" -o jsonpath='{.subsets[0].addresses}' 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
  echo "✅ Service 'backend-svc' has $EP_COUNT endpoint(s)! Traffic will route correctly."
  exit 0
fi

echo "❌ Service 'backend-svc' has no endpoints."
echo "   The service selector doesn't match any running pods."
echo ""
echo "💡 Check: kubectl get endpoints backend-svc -n $NS"
echo "   Check: kubectl get pods -n $NS --show-labels"
exit 1
