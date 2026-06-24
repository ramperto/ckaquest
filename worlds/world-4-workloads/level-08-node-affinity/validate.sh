#!/usr/bin/env bash
# Validate level-08: Node Affinity
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Node Affinity ==="
echo ""

echo "[ Check 1 ] Pod 'zone-aware-app' exists"
if kubectl get pod zone-aware-app -n "$NS" &>/dev/null; then
  ok "Pod 'zone-aware-app' exists"
else
  fail "Pod 'zone-aware-app' not found"
fi

echo ""
echo "[ Check 2 ] Pod is Running (affinity satisfied)"
PHASE=$(kubectl get pod zone-aware-app -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
if [[ "$PHASE" == "Running" ]]; then
  ok "Pod is Running"
else
  fail "Pod phase: $PHASE (expected Running — affinity still blocks scheduling)"
fi

echo ""
echo "[ Check 3 ] Pod has nodeAffinity using 'zone' key"
if kubectl get pod zone-aware-app -n "$NS" -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
na = d.get('spec', {}).get('affinity', {}).get('nodeAffinity', {})
terms = na.get('requiredDuringSchedulingIgnoredDuringExecution', {}).get('nodeSelectorTerms', [])
prefs = na.get('preferredDuringSchedulingIgnoredDuringExecution', [])
exprs = []
for t in terms:
    exprs.extend(t.get('matchExpressions', []))
for p in prefs:
    exprs.extend(p.get('preference', {}).get('matchExpressions', []))
sys.exit(0 if any(e.get('key') == 'zone' for e in exprs) else 1)
" 2>/dev/null; then
  ok "nodeAffinity uses 'zone' key"
else
  fail "nodeAffinity does not use 'zone' key"
fi

echo ""
echo "[ Check 4 ] Pod was NOT scheduled to wrong zone (no us-east in affinity)"
WRONG_ZONE=$(kubectl get pod zone-aware-app -n "$NS" -o json 2>/dev/null | \
  python3 -c "
import sys, json
d = json.load(sys.stdin)
spec = json.dumps(d.get('spec', {}))
if 'us-east' in spec:
    print('yes')
else:
    print('no')
" 2>/dev/null || echo "no")
if [[ "$WRONG_ZONE" == "no" ]]; then
  ok "Affinity no longer references non-existent zone us-east"
else
  fail "Affinity still references us-east (pod may be running despite this — check node labels)"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Pod scheduled in the correct zone!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Fix the nodeAffinity values to match the"
  echo "    actual node label (zone=us-west)."
  echo ""
  exit 1
fi
