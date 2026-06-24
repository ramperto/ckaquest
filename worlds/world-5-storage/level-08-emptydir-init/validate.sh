#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: emptyDir Init Container Handoff ===" ; echo ""

echo "[ Check 1 ] Pod 'worker' exists"
kubectl get pod worker -n "$NS" &>/dev/null && ok "Pod worker exists" || fail "Pod worker not found"

echo ""; echo "[ Check 2 ] Pod is Running (not CrashLoopBackOff)"
PHASE=$(kubectl get pod worker -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$PHASE" == "Running" || "$PHASE" == "Succeeded" ]] && ok "Pod phase: $PHASE" || fail "Pod phase: $PHASE (should be Running or Succeeded)"

echo ""; echo "[ Check 3 ] Main container mounts shared-vol at /work"
MAIN_MOUNT=$(kubectl get pod worker -n "$NS" \
  -o jsonpath='{range .spec.containers[0].volumeMounts[*]}{.name}:{.mountPath}{"\n"}{end}' \
  2>/dev/null | grep "^shared-vol:" | cut -d: -f2 || echo "")
[[ "$MAIN_MOUNT" == "/work" ]] && ok "Main container mountPath: /work" || fail "Main container mountPath: '${MAIN_MOUNT}' (expected /work)"

echo ""; echo "[ Check 4 ] Init container also mounts shared-vol at /work"
INIT_MOUNT=$(kubectl get pod worker -n "$NS" \
  -o jsonpath='{range .spec.initContainers[0].volumeMounts[*]}{.name}:{.mountPath}{"\n"}{end}' \
  2>/dev/null | grep "^shared-vol:" | cut -d: -f2 || echo "")
[[ "$INIT_MOUNT" == "/work" ]] && ok "Init container mountPath: /work" || fail "Init container mountPath: '${INIT_MOUNT}'"

echo ""; echo "[ Check 5 ] File /work/config.json readable in main container"
if [[ "$PHASE" == "Running" ]]; then
  CONTENT=$(kubectl exec --request-timeout=5s worker -n "$NS" -- cat /work/config.json 2>/dev/null || echo "")
  [[ -n "$CONTENT" ]] && ok "/work/config.json readable: $CONTENT" || fail "/work/config.json empty or not found"
else
  fail "Skipped — pod not Running"
fi

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ Init container handoff working!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Fix main container mountPath from /data to /work."; echo ""; exit 1; }
