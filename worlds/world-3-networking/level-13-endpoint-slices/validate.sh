#!/usr/bin/env bash
# Validate level-13: Endpoint Slices — Service Selector Typo
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Endpoint Slices — Selector Typo ==="
echo ""

# -- 1. Deployment backend has 2 ready replicas --------------------------------
echo "[ Check 1 ] Deployment backend has 2 ready replicas"
READY=$(kubectl get deployment backend -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED=$(kubectl get deployment backend -n "$NS" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "2")
if [[ "$READY" == "2" && "$DESIRED" == "2" ]]; then
  ok "Deployment backend: 2/2 replicas ready"
else
  fail "Deployment backend: ${READY:-0}/$DESIRED replicas ready (need 2/2)"
fi

# -- 2. Service backend-svc exists --------------------------------------------
echo ""
echo "[ Check 2 ] Service backend-svc exists"
if kubectl get service backend-svc -n "$NS" &>/dev/null; then
  ok "Service 'backend-svc' exists"
else
  fail "Service 'backend-svc' not found"
fi

# -- 3. Endpoints are NOT empty (at least 2 IPs) ------------------------------
echo ""
echo "[ Check 3 ] Endpoints for backend-svc have at least 2 addresses"
EP_IPS=$(kubectl get endpoints backend-svc -n "$NS" \
  -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
EP_COUNT=$(echo "$EP_IPS" | tr ' ' '\n' | grep -c '.' 2>/dev/null || echo "0")
if [[ "$EP_COUNT" -ge 2 ]]; then
  ok "Endpoints have $EP_COUNT addresses"
else
  fail "Endpoints have $EP_COUNT address(es) (expected at least 2)"
fi

# -- 4. Service selector matches pod labels -----------------------------------
echo ""
echo "[ Check 4 ] Service selector matches pod labels"
SVC_SELECTOR=$(kubectl get service backend-svc -n "$NS" \
  -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")
POD_LABEL=$(kubectl get pods -n "$NS" -l app=backend \
  -o jsonpath='{.items[0].metadata.labels.app}' 2>/dev/null || echo "")
if [[ -n "$SVC_SELECTOR" && "$SVC_SELECTOR" == "$POD_LABEL" ]]; then
  ok "Service selector 'app=$SVC_SELECTOR' matches pod label 'app=$POD_LABEL'"
else
  fail "Service selector 'app=$SVC_SELECTOR' does not match pod label 'app=$POD_LABEL'"
fi

# -- Summary -------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  Selector fixed! Endpoints are populated"
  echo "  and traffic can reach the backend pods."
  echo ""
  exit 0
else
  echo ""
  echo "  Some checks failed. Compare the Service"
  echo "  selector with actual pod labels."
  echo ""
  exit 1
fi
