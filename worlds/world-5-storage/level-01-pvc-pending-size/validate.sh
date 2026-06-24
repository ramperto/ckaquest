#!/usr/bin/env bash
# Validate level-01: PVC size mismatch fix
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: PVC Size Mismatch ==="
echo ""

echo "[ Check 1 ] PV 'db-pv' exists"
if kubectl get pv db-pv &>/dev/null; then
  ok "PV 'db-pv' exists"
else
  fail "PV 'db-pv' not found"
fi

echo ""
echo "[ Check 2 ] PVC 'db-data' exists"
if kubectl get pvc db-data -n "$NS" &>/dev/null; then
  ok "PVC 'db-data' exists"
else
  fail "PVC 'db-data' not found in namespace $NS"
fi

echo ""
echo "[ Check 3 ] PVC is Bound"
PVC_STATUS=$(kubectl get pvc db-data -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [[ "$PVC_STATUS" == "Bound" ]]; then
  ok "PVC db-data status: Bound"
else
  fail "PVC db-data status: $PVC_STATUS (expected Bound)"
fi

echo ""
echo "[ Check 4 ] PV is Bound"
PV_STATUS=$(kubectl get pv db-pv \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
if [[ "$PV_STATUS" == "Bound" ]]; then
  ok "PV db-pv status: Bound"
else
  fail "PV db-pv status: $PV_STATUS (expected Bound)"
fi

echo ""
echo "[ Check 5 ] PVC requests <= 5Gi"
PVC_REQ=$(kubectl get pvc db-data -n "$NS" \
  -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || echo "")
# Accept 1Gi through 5Gi
case "$PVC_REQ" in
  1Gi|2Gi|3Gi|4Gi|5Gi)
    ok "PVC requests: $PVC_REQ (fits in 5Gi PV)"
    ;;
  *)
    fail "PVC requests: $PVC_REQ (too large for 5Gi PV, or unexpected format)"
    ;;
esac

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

# Cleanup: delete PVC first (releases pv-protection finalizer), then PV

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ PVC bound to PV successfully!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Reduce the PVC size to 5Gi or less."
  echo "    # then recreate with storage: 5Gi"
  echo ""
  exit 1
fi
