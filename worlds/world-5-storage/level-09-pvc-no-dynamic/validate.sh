#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: PVC Dynamic Provisioning ===" ; echo ""

echo "[ Check 1 ] PVC cache-data exists"
kubectl get pvc cache-data -n "$NS" &>/dev/null && ok "PVC cache-data exists" || fail "PVC cache-data not found"

echo ""; echo "[ Check 2 ] PVC is Bound (dynamically provisioned)"
STATUS=$(kubectl get pvc cache-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$STATUS" == "Bound" ]] && ok "PVC Bound" || fail "PVC status: $STATUS (still Pending — fix storageClassName)"

echo ""; echo "[ Check 3 ] PVC does NOT have empty storageClassName (that disables dynamic provisioning)"
SC=$(kubectl get pvc cache-data -n "$NS" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "MISSING")
if [[ "$SC" == "" ]]; then
  fail "storageClassName is still empty string — dynamic provisioning disabled"
else
  ok "storageClassName: '$SC' (not empty)"
fi

echo ""; echo "[ Check 4 ] No manual PV named cache-pv was created (must be dynamic)"
if kubectl get pv cache-pv &>/dev/null; then
  fail "Found manual PV 'cache-pv' — this level requires dynamic provisioning"
else
  ok "No manual cache-pv PV (dynamic provisioning used)"
fi

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ PVC dynamically provisioned!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Delete PVC and recreate WITHOUT storageClassName field."; echo ""; exit 1; }
