#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check both pods are running
for pod in frontend backend; do
  PHASE=$(kubectl get pod $pod -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$PHASE" != "Running" ]]; then
    echo "❌ Pod '$pod' is not Running (phase: ${PHASE:-Not Found})."
    exit 1
  fi
done

# Get backend service IP
BACKEND_IP=$(kubectl get svc backend-svc -n "$NS" \
  -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

if [[ -z "$BACKEND_IP" ]]; then
  echo "❌ Service 'backend-svc' not found."
  exit 1
fi

# Test connectivity from frontend to backend
RESULT=$(kubectl exec --request-timeout=5s frontend -n "$NS" -- \
  wget -q -O- --timeout=5 "http://${BACKEND_IP}:80" 2>&1)

if echo "$RESULT" | grep -qi "nginx\|html\|welcome"; then
  echo "✅ Frontend can reach backend! NetworkPolicy is correctly configured."
  exit 0
fi

echo "❌ Frontend cannot reach backend (${BACKEND_IP}:80)."
echo "   NetworkPolicy is still blocking traffic."
echo ""
echo "💡 You need a NetworkPolicy that allows ingress to backend from frontend pods."
echo "   Check existing policies: kubectl get networkpolicies -n $NS"
exit 1
