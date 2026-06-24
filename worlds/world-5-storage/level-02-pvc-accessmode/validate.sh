#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: PVC Access Mode ===" ; echo ""

echo "[ Check 1 ] PVC pipeline-data exists"
kubectl get pvc pipeline-data -n "$NS" &>/dev/null && ok "PVC exists" || fail "PVC not found"

echo ""; echo "[ Check 2 ] PVC is Bound"
S=$(kubectl get pvc pipeline-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$S" == "Bound" ]] && ok "PVC Bound" || fail "PVC status: $S"

echo ""; echo "[ Check 3 ] PV pipeline-pv is Bound"
P=$(kubectl get pv pipeline-pv -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$P" == "Bound" ]] && ok "PV Bound" || fail "PV status: $P"

echo ""; echo "[ Check 4 ] PVC accessMode is ReadWriteOnce"
AM=$(kubectl get pvc pipeline-data -n "$NS" -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null || echo "")
[[ "$AM" == "ReadWriteOnce" ]] && ok "accessMode: ReadWriteOnce" || fail "accessMode: $AM"

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ PVC bound!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Fix the PVC accessMode to ReadWriteOnce."; echo ""; exit 1; }
