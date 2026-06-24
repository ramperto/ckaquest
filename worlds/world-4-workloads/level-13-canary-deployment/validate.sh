#!/usr/bin/env bash
# Validate level-13: Canary Deployment
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Canary Deployment ==="
echo ""

echo "[ Check 1 ] Deployment 'app-v1' has ready replicas"
V1_READY=$(kubectl get deploy app-v1 -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "${V1_READY:-0}" -ge 1 ]] 2>/dev/null; then
  ok "Deployment 'app-v1' has $V1_READY ready replicas"
else
  fail "Deployment 'app-v1' has no ready replicas"
fi

echo ""
echo "[ Check 2 ] Deployment 'app-v2' has ready replicas"
V2_READY=$(kubectl get deploy app-v2 -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "${V2_READY:-0}" -ge 1 ]] 2>/dev/null; then
  ok "Deployment 'app-v2' has $V2_READY ready replicas"
else
  fail "Deployment 'app-v2' has no ready replicas"
fi

echo ""
echo "[ Check 3 ] Service 'myapp-svc' exists"
if kubectl get svc myapp-svc -n "$NS" &>/dev/null; then
  ok "Service 'myapp-svc' exists"
else
  fail "Service 'myapp-svc' not found in namespace $NS"
fi

echo ""
echo "[ Check 4 ] Service endpoints contain at least 4 IPs (3 v1 + 1 v2)"
ENDPOINTS=$(kubectl get endpoints myapp-svc -n "$NS" \
  -o jsonpath='{.subsets[0].addresses}' 2>/dev/null || echo "")
# Count the number of IPs in the endpoints
EP_COUNT=$(kubectl get endpoints myapp-svc -n "$NS" \
  -o jsonpath='{.subsets[0].addresses[*].ip}' 2>/dev/null | wc -w || echo "0")
if [[ "$EP_COUNT" -ge 4 ]] 2>/dev/null; then
  ok "Service has $EP_COUNT endpoints (>= 4)"
else
  fail "Service has ${EP_COUNT:-0} endpoints (expected >= 4 — v2 pods likely missing 'app: myapp' label)"
fi

echo ""
echo "[ Check 5 ] v2 pods have label 'app=myapp'"
V2_PODS_WITH_LABEL=$(kubectl get pods -n "$NS" -l "app=myapp,version=v2" \
  --no-headers 2>/dev/null | wc -l || echo "0")
if [[ "$V2_PODS_WITH_LABEL" -ge 1 ]] 2>/dev/null; then
  ok "v2 pods have label 'app=myapp' ($V2_PODS_WITH_LABEL pods)"
else
  fail "No v2 pods with label 'app=myapp' — add it to the v2 deployment pod template"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  Canary deployment active — v2 is now receiving traffic!"
  echo ""
  exit 0
else
  echo ""
  echo "  Add the 'app: myapp' label to the v2 deployment's pod template"
  echo "  so the Service routes traffic to both versions."
  echo ""
  exit 1
fi
