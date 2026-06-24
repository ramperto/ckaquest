#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: Secret Volume Key ===" ; echo ""

echo "[ Check 1 ] Pod tls-proxy is Running"
PHASE=$(kubectl get pod tls-proxy -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$PHASE" == "Running" ]] && ok "Pod Running" || fail "Pod phase: $PHASE"

echo ""; echo "[ Check 2 ] Volume items use key 'tls.crt'"
ITEM_KEY=$(kubectl get pod tls-proxy -n "$NS" \
  -o jsonpath='{.spec.volumes[?(@.name=="tls-vol")].secret.items[0].key}' \
  2>/dev/null || echo "")
[[ "$ITEM_KEY" == "tls.crt" ]] && ok "Volume items key: tls.crt" || fail "Volume items key: '$ITEM_KEY' (expected tls.crt)"

echo ""; echo "[ Check 3 ] File /etc/ssl/tls.crt is non-empty inside pod"
if [[ "$PHASE" == "Running" ]]; then
  CONTENT=$(kubectl exec --request-timeout=5s tls-proxy -n "$NS" -- cat /etc/ssl/tls.crt 2>/dev/null || echo "")
  [[ -n "$CONTENT" ]] && ok "/etc/ssl/tls.crt has content" || fail "/etc/ssl/tls.crt is empty (wrong key mapping)"
else
  fail "Skipped — pod not Running"
fi

echo ""; echo "[ Check 4 ] Secret tls-secret exists with tls.crt key"
KEY=$(kubectl get secret tls-secret -n "$NS" \
  -o jsonpath='{.data.tls\.crt}' 2>/dev/null || echo "")
[[ -n "$KEY" ]] && ok "Secret has tls.crt key" || fail "Secret missing tls.crt key"

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ TLS cert correctly projected into pod!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Fix the items key from 'cert' to 'tls.crt' and recreate the pod."; echo ""; exit 1; }
