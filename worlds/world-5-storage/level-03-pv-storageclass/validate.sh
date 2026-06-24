#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: PVC StorageClass Mismatch ===" ; echo ""

echo "[ Check 1 ] PVC app-storage exists"
kubectl get pvc app-storage -n "$NS" &>/dev/null && ok "PVC exists" || fail "PVC not found"

echo ""; echo "[ Check 2 ] PVC is Bound"
S=$(kubectl get pvc app-storage -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$S" == "Bound" ]] && ok "PVC Bound" || fail "PVC status: $S"

echo ""; echo "[ Check 3 ] PV app-pv is Bound"
P=$(kubectl get pv app-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$P" == "Bound" ]] && ok "PV Bound" || fail "PV status: $P"

echo ""; echo "[ Check 4 ] PVC storageClassName is standard"
SC=$(kubectl get pvc app-storage -n "$NS" -o jsonpath='{.spec.storageClassName}' 2>/dev/null || echo "")
[[ "$SC" == "standard" ]] && ok "storageClassName: standard" || fail "storageClassName: $SC (expected standard)"

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ PVC bound with correct StorageClass!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Fix the PVC storageClassName to 'standard'."; echo ""; exit 1; }
