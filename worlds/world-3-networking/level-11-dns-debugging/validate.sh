#!/usr/bin/env bash
# Validate level-11: DNS Debugging
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: DNS Debugging ==="
echo ""

# -- 1. Deployment web-app has 1 ready replica --------------------------------
echo "[ Check 1 ] Deployment web-app has 1 ready replica"
READY=$(kubectl get deployment web-app -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$READY" == "1" ]]; then
  ok "Deployment web-app: 1/1 replicas ready"
else
  fail "Deployment web-app: ${READY:-0}/1 replicas ready"
fi

# -- 2. Service web-svc exists ------------------------------------------------
echo ""
echo "[ Check 2 ] Service web-svc exists"
if kubectl get service web-svc -n "$NS" &>/dev/null; then
  ok "Service 'web-svc' exists"
else
  fail "Service 'web-svc' not found"
fi

# -- 3. Pod dns-client is Running ----------------------------------------------
echo ""
echo "[ Check 3 ] Pod dns-client is Running"
PHASE=$(kubectl get pod dns-client -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
if [[ "$PHASE" == "Running" ]]; then
  ok "Pod 'dns-client' is Running"
else
  fail "Pod 'dns-client' phase: $PHASE (expected Running)"
fi

# -- 4. DNS resolution works from dns-client -----------------------------------
echo ""
echo "[ Check 4 ] dns-client can resolve web-svc via DNS"
DNS_OUT=$(kubectl exec dns-client -n "$NS" --request-timeout=10s -- \
  nslookup web-svc."$NS".svc.cluster.local 2>&1 || echo "FAILED")

if echo "$DNS_OUT" | grep -q "Address:" && ! echo "$DNS_OUT" | grep -qi "timed out\|SERVFAIL\|can't resolve\|FAILED"; then
  ok "nslookup web-svc.$NS.svc.cluster.local succeeded"
else
  fail "nslookup web-svc.$NS.svc.cluster.local failed — DNS is not working"
fi

# -- Summary -------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  DNS resolution fixed! The dns-client pod"
  echo "  can now resolve cluster services by name."
  echo ""
  exit 0
else
  echo ""
  echo "  Some checks failed. Verify the dns-client"
  echo "  pod's dnsPolicy and dnsConfig settings."
  echo ""
  exit 1
fi
