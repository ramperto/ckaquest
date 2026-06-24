#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

for pod in app db; do
  PHASE=$(kubectl get pod $pod -n "$NS" \
    -o jsonpath='{.status.phase}' 2>/dev/null)
  if [[ "$PHASE" != "Running" ]]; then
    echo "❌ Pod '$pod' not Running (phase: ${PHASE:-Not Found})."
    exit 1
  fi
done

# Check app can reach db-svc on port 5432
RESULT=$(kubectl exec --request-timeout=5s app -n "$NS" -- \
  nc -z -w 3 db-svc 5432 2>&1)

if [[ $? -eq 0 ]]; then
  echo "✅ App pod can reach db-svc:5432! Egress policy allows DB traffic."
  exit 0
fi

# Check if DNS works (secondary test)
DNS_RESULT=$(kubectl exec --request-timeout=5s app -n "$NS" -- \
  nslookup db-svc 2>&1)

if echo "$DNS_RESULT" | grep -qi "NXDOMAIN\|timeout\|server can"; then
  echo "❌ App cannot resolve 'db-svc' — DNS (port 53) egress is also blocked."
  echo "   Your egress policy must also allow UDP/TCP port 53."
else
  echo "❌ App cannot reach db-svc:5432 (DNS works but TCP 5432 blocked)."
fi

echo ""
echo "💡 Check existing egress policies: kubectl get networkpolicies -n $NS"
echo "   Add an egress rule allowing port 5432 to pods with label app=db"
echo "   AND port 53 (UDP/TCP) for DNS."
exit 1
