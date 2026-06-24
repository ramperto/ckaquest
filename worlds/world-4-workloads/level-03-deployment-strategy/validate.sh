#!/usr/bin/env bash
# Validate level-03: RollingUpdate strategy
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Deployment Rolling Update Strategy ==="
echo ""

echo "[ Check 1 ] Deployment 'webapp' exists"
if kubectl get deployment webapp -n "$NS" &>/dev/null; then
  ok "Deployment 'webapp' exists"
else
  fail "Deployment 'webapp' not found"
fi

echo ""
echo "[ Check 2 ] Strategy type is RollingUpdate"
STRAT=$(kubectl get deployment webapp -n "$NS" \
  -o jsonpath='{.spec.strategy.type}' 2>/dev/null || echo "")
if [[ "$STRAT" == "RollingUpdate" ]]; then
  ok "Strategy: RollingUpdate"
else
  fail "Strategy: '$STRAT' (expected RollingUpdate)"
fi

echo ""
echo "[ Check 3 ] maxUnavailable is 1"
MAX_UN=$(kubectl get deployment webapp -n "$NS" \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxUnavailable}' 2>/dev/null || echo "")
if [[ "$MAX_UN" == "1" ]]; then
  ok "maxUnavailable: 1"
else
  fail "maxUnavailable: '$MAX_UN' (expected 1)"
fi

echo ""
echo "[ Check 4 ] maxSurge is 1"
MAX_SG=$(kubectl get deployment webapp -n "$NS" \
  -o jsonpath='{.spec.strategy.rollingUpdate.maxSurge}' 2>/dev/null || echo "")
if [[ "$MAX_SG" == "1" ]]; then
  ok "maxSurge: 1"
else
  fail "maxSurge: '$MAX_SG' (expected 1)"
fi

echo ""
echo "[ Check 5 ] All 3 replicas Ready"
READY=$(kubectl get deployment webapp -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$READY" == "3" ]]; then
  ok "readyReplicas: 3/3"
else
  fail "readyReplicas: ${READY:-0}/3"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Zero-downtime rolling updates enabled!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Fix the strategy. Use kubectl patch or"
  echo "    kubectl edit deployment webapp -n ckaquest"
  echo ""
  exit 1
fi
