#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

PHASE=$(kubectl get pod debug-pod -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
if [[ "$PHASE" != "Running" ]]; then
  echo "❌ Pod 'debug-pod' is not Running (phase: ${PHASE:-Not Found})."
  exit 1
fi

# Test DNS resolution inside the pod
RESULT=$(kubectl exec --request-timeout=5s debug-pod -n "$NS" -- \
  nslookup kubernetes.default.svc.cluster.local 2>&1)

if echo "$RESULT" | grep -q "Address"; then
  echo "✅ DNS working! Pod can resolve 'kubernetes.default.svc.cluster.local'."
  exit 0
fi

DNS_POLICY=$(kubectl get pod debug-pod -n "$NS" \
  -o jsonpath='{.spec.dnsPolicy}' 2>/dev/null)

echo "❌ DNS resolution failed inside the pod."
echo "   Current dnsPolicy: ${DNS_POLICY:-unknown}"
echo ""
echo "💡 The pod should use dnsPolicy: ClusterFirst (the default)"
echo "   to use the cluster's CoreDNS server."
exit 1
