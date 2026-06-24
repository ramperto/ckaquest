#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: PV Released → Available ===" ; echo ""

echo "[ Check 1 ] PV data-pv exists"
kubectl get pv data-pv &>/dev/null && ok "PV data-pv exists" || fail "PV not found"

echo ""; echo "[ Check 2 ] PV is Bound (claimRef removed, new PVC bound)"
PV_STATUS=$(kubectl get pv data-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
if [[ "$PV_STATUS" == "Bound" ]]; then
  ok "PV data-pv is Bound"
elif [[ "$PV_STATUS" == "Available" ]]; then
  fail "PV is Available but PVC new-data has not bound yet (check PVC)"
elif [[ "$PV_STATUS" == "Released" ]]; then
  fail "PV is still Released — remove the claimRef"
else
  fail "PV status: $PV_STATUS"
fi

echo ""; echo "[ Check 3 ] PVC new-data is Bound"
PVC_STATUS=$(kubectl get pvc new-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$PVC_STATUS" == "Bound" ]] && ok "PVC new-data is Bound" || fail "PVC new-data status: $PVC_STATUS"

echo ""; echo "[ Check 4 ] PV has no stale claimRef from temp-claim"
CLAIM_NAME=$(kubectl get pv data-pv \
  -o jsonpath='{.spec.claimRef.name}' 2>/dev/null || echo "")
if [[ "$CLAIM_NAME" != "temp-claim" ]]; then
  ok "claimRef is not pointing to old temp-claim"
else
  fail "PV claimRef still points to 'temp-claim' — remove it"
fi

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ PV recycled and rebound!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Remove the claimRef: kubectl patch pv data-pv --type=json -p='[{\"op\":\"remove\",\"path\":\"/spec/claimRef\"}]'"; echo ""; exit 1; }
