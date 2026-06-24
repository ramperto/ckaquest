#!/usr/bin/env bash
# Validate level-04: DaemonSet nodeSelector fix
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: DaemonSet Node Selector ==="
echo ""

echo "[ Check 1 ] DaemonSet 'node-monitor' exists"
if kubectl get daemonset node-monitor -n "$NS" &>/dev/null; then
  ok "DaemonSet 'node-monitor' exists"
else
  fail "DaemonSet 'node-monitor' not found"
fi

echo ""
echo "[ Check 2 ] desiredNumberScheduled >= 1"
DESIRED=$(kubectl get daemonset node-monitor -n "$NS" \
  -o jsonpath='{.status.desiredNumberScheduled}' 2>/dev/null || echo "0")
if [[ "$DESIRED" -ge 1 ]]; then
  ok "desiredNumberScheduled: $DESIRED"
else
  fail "desiredNumberScheduled: $DESIRED (nodeSelector still blocking scheduling)"
fi

echo ""
echo "[ Check 3 ] numberReady >= 1"
READY=$(kubectl get daemonset node-monitor -n "$NS" \
  -o jsonpath='{.status.numberReady}' 2>/dev/null || echo "0")
if [[ "$READY" -ge 1 ]]; then
  ok "numberReady: $READY"
else
  fail "numberReady: $READY (pods not Running yet)"
fi

echo ""
echo "[ Check 4 ] DaemonSet selector intact (app=node-monitor)"
SELECTOR=$(kubectl get daemonset node-monitor -n "$NS" \
  -o jsonpath='{.spec.selector.matchLabels.app}' 2>/dev/null || echo "")
if [[ "$SELECTOR" == "node-monitor" ]]; then
  ok "Selector: app=node-monitor"
else
  fail "Selector broken: '$SELECTOR' (expected 'node-monitor')"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ DaemonSet is running on all eligible nodes!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Pods still not scheduling. Remove the bad"
  echo "    nodeSelector or label the node to match."
  echo ""
  exit 1
fi
