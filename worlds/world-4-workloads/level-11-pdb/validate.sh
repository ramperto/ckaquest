#!/usr/bin/env bash
# Validate level-11: Pod Disruption Budget
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Pod Disruption Budget ==="
echo ""

echo "[ Check 1 ] Deployment 'pdb-app' exists"
if kubectl get deploy pdb-app -n "$NS" &>/dev/null; then
  ok "Deployment 'pdb-app' exists"
else
  fail "Deployment 'pdb-app' not found in namespace $NS"
fi

echo ""
echo "[ Check 2 ] Deployment has 3 ready replicas"
READY=$(kubectl get deploy pdb-app -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$READY" == "3" ]]; then
  ok "Deployment has 3 ready replicas"
else
  fail "Deployment ready replicas: ${READY:-0} (expected 3)"
fi

echo ""
echo "[ Check 3 ] PDB 'pdb-app-pdb' exists"
if kubectl get pdb pdb-app-pdb -n "$NS" &>/dev/null; then
  ok "PDB 'pdb-app-pdb' exists"
else
  fail "PDB 'pdb-app-pdb' not found in namespace $NS"
fi

echo ""
echo "[ Check 4 ] PDB allows at least 1 disruption"
ALLOWED=$(kubectl get pdb pdb-app-pdb -n "$NS" \
  -o jsonpath='{.status.disruptionsAllowed}' 2>/dev/null || echo "0")
if [[ "$ALLOWED" -ge 1 ]] 2>/dev/null; then
  ok "PDB disruptionsAllowed: $ALLOWED (>= 1)"
else
  fail "PDB disruptionsAllowed: ${ALLOWED:-0} (must be >= 1 — change minAvailable or use maxUnavailable)"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  PDB configured correctly — disruptions are now allowed!"
  echo ""
  exit 0
else
  echo ""
  echo "  Fix the PDB: minAvailable must be < replica count,"
  echo "  or use maxUnavailable: 1 instead."
  echo ""
  exit 1
fi
