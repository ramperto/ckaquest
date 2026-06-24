#!/usr/bin/env bash
set -euo pipefail
NS="ckaquest"
PASS=0; FAIL=0
ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""; echo "=== Validating: Volume Mount Path ===" ; echo ""

echo "[ Check 1 ] Deployment webapp exists and is healthy"
READY=$(kubectl get deployment webapp -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
[[ "${READY:-0}" -ge 1 ]] && ok "Deployment webapp: ${READY} ready" || fail "Deployment webapp not ready (${READY:-0} replicas)"

echo ""; echo "[ Check 2 ] Volume 'data-vol' is mounted at /app/data"
MOUNT=$(kubectl get deployment webapp -n "$NS" \
  -o jsonpath='{range .spec.template.spec.containers[0].volumeMounts[*]}{.name}:{.mountPath}{"\n"}{end}' \
  2>/dev/null | grep "^data-vol:" | cut -d: -f2 || echo "")
if [[ "$MOUNT" == "/app/data" ]]; then
  ok "data-vol mounted at /app/data"
else
  fail "data-vol mounted at '${MOUNT}' (expected /app/data)"
fi

echo ""; echo "[ Check 3 ] PVC webapp-pvc is Bound"
PVC=$(kubectl get pvc webapp-pvc -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
[[ "$PVC" == "Bound" ]] && ok "PVC webapp-pvc: Bound" || fail "PVC webapp-pvc: $PVC"

echo ""; echo "[ Check 4 ] File written to /app/data inside the pod"
POD=$(kubectl get pods -n "$NS" -l app=webapp \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$POD" ]]; then
  CONTENT=$(kubectl exec "$POD" -n "$NS" --request-timeout=5s -- cat /app/data/out.txt 2>/dev/null || echo "")
  if [[ -n "$CONTENT" ]]; then
    ok "File /app/data/out.txt readable (volume write confirmed)"
  else
    fail "File /app/data/out.txt is empty or unreadable"
  fi
else
  fail "No webapp pod found"
fi

echo ""; echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"
[[ $FAIL -eq 0 ]] && { echo ""; echo "  ✓ Volume correctly mounted — data persists!"; echo ""; exit 0; } || { echo ""; echo "  ✗ Fix the mountPath to /app/data in the Deployment."; echo ""; exit 1; }
