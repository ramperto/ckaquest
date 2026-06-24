#!/usr/bin/env bash
# Validate level-14: Topology Spread Constraints
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Topology Spread Constraints ==="
echo ""

echo "[ Check 1 ] Deployment 'spread-app' exists"
if kubectl get deploy spread-app -n "$NS" &>/dev/null; then
  ok "Deployment 'spread-app' exists"
else
  fail "Deployment 'spread-app' not found in namespace $NS"
fi

echo ""
echo "[ Check 2 ] Deployment has 3 ready replicas"
READY=$(kubectl get deploy spread-app -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "${READY:-0}" == "3" ]]; then
  ok "Deployment has 3 ready replicas"
else
  fail "Deployment ready replicas: ${READY:-0} (expected 3)"
fi

echo ""
echo "[ Check 3 ] Topology spread constraint uses a valid topology key"
TOPO_KEY=$(kubectl get deploy spread-app -n "$NS" \
  -o jsonpath='{.spec.template.spec.topologySpreadConstraints[0].topologyKey}' 2>/dev/null || echo "")
if [[ -z "$TOPO_KEY" ]]; then
  fail "No topology spread constraint found on the deployment"
else
  # Check if any node has this label key
  NODE_HAS_KEY=$(kubectl get nodes -o jsonpath="{.items[*].metadata.labels}" 2>/dev/null | grep -c "$TOPO_KEY" || echo "0")
  if [[ "$NODE_HAS_KEY" -ge 1 ]]; then
    ok "Topology key '$TOPO_KEY' exists on at least one node"
  else
    fail "Topology key '$TOPO_KEY' not found on any node — use a key that exists (e.g., kubernetes.io/hostname)"
  fi
fi

echo ""
echo "[ Check 4 ] All pods are Running (not Pending)"
PENDING=$(kubectl get pods -n "$NS" -l app=spread-app \
  --field-selector=status.phase=Pending --no-headers 2>/dev/null | wc -l || echo "0")
RUNNING=$(kubectl get pods -n "$NS" -l app=spread-app \
  --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l || echo "0")
if [[ "$PENDING" -eq 0 && "$RUNNING" -ge 3 ]]; then
  ok "All pods are Running ($RUNNING running, 0 pending)"
else
  fail "$RUNNING running, $PENDING pending — fix the topology constraint"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  Topology spread constraints are working correctly!"
  echo ""
  exit 0
else
  echo ""
  echo "  Fix the topologyKey to one that exists on your nodes"
  echo "  (e.g., kubernetes.io/hostname) and use ScheduleAnyway"
  echo "  on single-node clusters."
  echo ""
  exit 1
fi
