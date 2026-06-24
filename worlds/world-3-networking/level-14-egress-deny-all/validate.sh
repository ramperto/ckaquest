#!/usr/bin/env bash
# Validate level-14: Egress Deny All — NetworkPolicy
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Egress Deny All ==="
echo ""

# -- 1. Deployment web has ready replicas --------------------------------------
echo "[ Check 1 ] Deployment web has ready replicas"
WEB_READY=$(kubectl get deployment web -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "${WEB_READY:-0}" -ge 1 ]]; then
  ok "Deployment web: ${WEB_READY} replica(s) ready"
else
  fail "Deployment web: ${WEB_READY:-0} replicas ready (need at least 1)"
fi

# -- 2. Deployment api has ready replicas --------------------------------------
echo ""
echo "[ Check 2 ] Deployment api has ready replicas"
API_READY=$(kubectl get deployment api -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "${API_READY:-0}" -ge 1 ]]; then
  ok "Deployment api: ${API_READY} replica(s) ready"
else
  fail "Deployment api: ${API_READY:-0} replicas ready (need at least 1)"
fi

# -- 3. NetworkPolicy web-egress exists ----------------------------------------
echo ""
echo "[ Check 3 ] NetworkPolicy web-egress exists"
if kubectl get networkpolicy web-egress -n "$NS" &>/dev/null; then
  ok "NetworkPolicy 'web-egress' exists"
else
  fail "NetworkPolicy 'web-egress' not found"
fi

# -- 4. NetworkPolicy has at least one egress rule -----------------------------
echo ""
echo "[ Check 4 ] NetworkPolicy has at least one egress rule"
EGRESS_COUNT=$(kubectl get networkpolicy web-egress -n "$NS" -o json 2>/dev/null | \
  python3 -c "
import sys, json
np = json.loads(sys.stdin.read())
egress = np.get('spec', {}).get('egress', [])
print(len(egress))
" 2>/dev/null || echo "0")
if [[ "$EGRESS_COUNT" -ge 1 ]]; then
  ok "NetworkPolicy has $EGRESS_COUNT egress rule(s)"
else
  fail "NetworkPolicy has 0 egress rules (egress: [] = deny all)"
fi

# -- 5. Web pod can reach api-svc ----------------------------------------------
echo ""
echo "[ Check 5 ] Web pod can reach api-svc on port 80"
WEB_POD=$(kubectl get pods -n "$NS" -l app=web \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -z "$WEB_POD" ]]; then
  fail "No web pod found"
else
  RESULT=$(kubectl exec "$WEB_POD" -n "$NS" --request-timeout=10s -- \
    wget -qO- --timeout=5 api-svc 2>&1 || echo "FAILED")
  if echo "$RESULT" | grep -qi "nginx\|html\|welcome\|DOCTYPE" && ! echo "$RESULT" | grep -qi "FAILED"; then
    ok "Web pod can reach api-svc (got HTTP response)"
  else
    fail "Web pod cannot reach api-svc — egress may still be blocked"
  fi
fi

# -- Summary -------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  NetworkPolicy fixed! Web pods can now"
  echo "  reach api-svc while egress is restricted."
  echo ""
  exit 0
else
  echo ""
  echo "  Some checks failed. Ensure the NetworkPolicy"
  echo "  allows egress to api pods (80) and DNS (53)."
  echo ""
  exit 1
fi
