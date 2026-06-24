#!/usr/bin/env bash
# Validate level-07: Taint & Toleration
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Taint & Toleration ==="
echo ""

echo "[ Check 1 ] Pod 'gpu-worker' exists"
if kubectl get pod gpu-worker -n "$NS" &>/dev/null; then
  ok "Pod 'gpu-worker' exists"
else
  fail "Pod 'gpu-worker' not found"
fi

echo ""
echo "[ Check 2 ] Pod has toleration for gpu=present:NoSchedule"
if kubectl get pod gpu-worker -n "$NS" -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
tolerations = d.get('spec', {}).get('tolerations', [])
for t in tolerations:
    if t.get('key') == 'gpu' and t.get('effect') == 'NoSchedule':
        if t.get('value') == 'present' or t.get('operator') == 'Exists':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "Toleration: gpu=present:NoSchedule present"
else
  fail "Missing toleration for gpu=present:NoSchedule"
fi

echo ""
echo "[ Check 3 ] Pod is Running"
PHASE=$(kubectl get pod gpu-worker -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
if [[ "$PHASE" == "Running" ]]; then
  ok "Pod is Running"
else
  fail "Pod phase: $PHASE (expected Running)"
fi

echo ""
echo "[ Check 4 ] Pod is not in Pending state (was scheduled)"
if [[ "$PHASE" != "Pending" ]]; then
  ok "Pod was scheduled (not stuck Pending)"
else
  fail "Pod is still Pending — toleration may be incorrect"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

# ── Cleanup: remove the taint regardless of result ───────────────────────────
NODE=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name 2>/dev/null | head -1 || echo "")
if [[ -n "$NODE" ]]; then
  kubectl taint node "$NODE" gpu=present:NoSchedule- 2>/dev/null || true
  echo ""
  echo "  [cleanup] Taint gpu=present:NoSchedule removed from node $NODE"
fi

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Pod scheduled successfully on tainted node!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Add the correct toleration and recreate the pod."
  echo ""
  exit 1
fi
