#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check endpoints exist
EP=$(kubectl get endpoints backend-svc -n "$NS" \
  -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
if [[ -z "$EP" ]]; then
  echo "❌ Service 'backend-svc' has no endpoints."
  exit 1
fi

# Check client pod is running
CLIENT=$(kubectl get pod client -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null)
if [[ "$CLIENT" != "Running" ]]; then
  echo "❌ Client pod not Running yet. Phase: ${CLIENT:-Not Found}"
  exit 1
fi

# Test actual connectivity from client pod
RESULT=$(kubectl exec --request-timeout=5s client -n "$NS" -- \
  wget -q -O- --timeout=5 http://backend-svc 2>&1)

if echo "$RESULT" | grep -qi "nginx\|html\|welcome"; then
  echo "✅ client can reach backend-svc! targetPort is correct."
  exit 0
fi

TARGET=$(kubectl get svc backend-svc -n "$NS" \
  -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
echo "❌ Cannot reach backend-svc from client pod."
echo "   Current targetPort: ${TARGET}"
echo ""
echo "💡 Check: kubectl describe svc backend-svc -n $NS"
echo "   The targetPort must match nginx's listen port (80)."
exit 1
