#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: ConfigMap Volume ===" ; echo ""

echo "[ Check 1 ] ConfigMap app-config exists"
kubectl get configmap app-config -n "$NS" &>/dev/null && ok "ConfigMap app-config exists" || fail "ConfigMap app-config not found"

echo ""; echo "[ Check 2 ] ConfigMap has key app.properties"
KEY=$(kubectl get configmap app-config -n "$NS" \
  -o jsonpath='{.data.app\.properties}' 2>/dev/null || echo "")
[[ -n "$KEY" ]] && ok "ConfigMap has key app.properties" || fail "Key app.properties missing from ConfigMap"

echo ""; echo "[ Check 3 ] Pod config-app is Running"
PHASE=$(kubectl get pod config-app -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$PHASE" == "Running" ]] && ok "Pod Running" || fail "Pod phase: $PHASE (expected Running)"

echo ""; echo "[ Check 4 ] Pod can read /etc/app/app.properties"
if [[ "$PHASE" == "Running" ]]; then
  CONTENT=$(kubectl exec --request-timeout=5s config-app -n "$NS" -- cat /etc/app/app.properties 2>/dev/null || echo "")
  [[ -n "$CONTENT" ]] && ok "File /etc/app/app.properties readable" || fail "Cannot read /etc/app/app.properties"
else
  fail "Skipped — pod not Running"
fi

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ ConfigMap mounted and pod running!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Create ConfigMap app-config with key app.properties"; echo ""; exit 1; }
