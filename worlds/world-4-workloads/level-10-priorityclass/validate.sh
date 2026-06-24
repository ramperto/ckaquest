#!/usr/bin/env bash
# Validate level-10: PriorityClass
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: PriorityClass ==="
echo ""

echo "[ Check 1 ] PriorityClass 'high-priority' exists"
if kubectl get priorityclass high-priority &>/dev/null; then
  ok "PriorityClass 'high-priority' exists"
else
  fail "PriorityClass 'high-priority' not found (it's cluster-scoped — no -n needed)"
fi

echo ""
echo "[ Check 2 ] PriorityClass value is 1000000"
PCVAL=$(kubectl get priorityclass high-priority \
  -o jsonpath='{.value}' 2>/dev/null || echo "0")
if [[ "$PCVAL" == "1000000" ]]; then
  ok "PriorityClass value: 1000000"
else
  fail "PriorityClass value: $PCVAL (expected 1000000)"
fi

echo ""
echo "[ Check 3 ] Pod 'critical-app' exists in namespace"
if kubectl get pod critical-app -n "$NS" &>/dev/null; then
  ok "Pod 'critical-app' exists"
else
  fail "Pod 'critical-app' not found in namespace $NS"
fi

echo ""
echo "[ Check 4 ] Pod references priorityClassName: high-priority"
PC=$(kubectl get pod critical-app -n "$NS" \
  -o jsonpath='{.spec.priorityClassName}' 2>/dev/null || echo "")
if [[ "$PC" == "high-priority" ]]; then
  ok "Pod priorityClassName: high-priority"
else
  fail "Pod priorityClassName: '$PC' (expected high-priority)"
fi

echo ""
echo "[ Check 5 ] Pod is Running"
PHASE=$(kubectl get pod critical-app -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
if [[ "$PHASE" == "Running" ]]; then
  ok "Pod is Running"
else
  fail "Pod phase: $PHASE (create the PriorityClass, then delete/recreate the pod)"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Critical app running at high priority!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Create the PriorityClass first, then recreate the pod."
  echo "    kubectl apply -f - <<EOF"
  echo "    apiVersion: scheduling.k8s.io/v1"
  echo "    kind: PriorityClass"
  echo "    metadata:"
  echo "      name: high-priority"
  echo "    value: 1000000"
  echo "    globalDefault: false"
  echo "    EOF"
  echo ""
  exit 1
fi
