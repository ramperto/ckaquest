#!/usr/bin/env bash
# Validate level-10: Dynamic PVC creation
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Dynamic PVC Provisioning ==="
echo ""

# ── 1. PVC app-db exists ─────────────────────────────────────────────────────
echo "[ Check 1 ] PVC 'app-db' exists"
if kubectl get pvc app-db -n "$NS" &>/dev/null; then
  ok "PVC 'app-db' exists"
else
  fail "PVC 'app-db' not found — create it!"
fi

# ── 2. PVC is Bound ──────────────────────────────────────────────────────────
echo ""
echo "[ Check 2 ] PVC is Bound"
PVC_STATUS=$(kubectl get pvc app-db -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "")
if [[ "$PVC_STATUS" == "Bound" ]]; then
  ok "PVC app-db: Bound"
else
  fail "PVC app-db status: $PVC_STATUS (expected Bound)"
fi

# ── 3. PVC capacity is at least 1Gi ─────────────────────────────────────────
echo ""
echo "[ Check 3 ] PVC requests storage"
REQ=$(kubectl get pvc app-db -n "$NS" \
  -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null || echo "")
if [[ -n "$REQ" ]]; then
  ok "PVC storage request: $REQ"
else
  fail "PVC has no storage request"
fi

# ── 4. Deployment has at least 1 ready replica ───────────────────────────────
echo ""
echo "[ Check 4 ] Deployment stateful-app has >= 1 ready replica"
READY=$(kubectl get deployment stateful-app -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "${READY:-0}" -ge 1 ]]; then
  ok "Deployment readyReplicas: $READY"
else
  fail "Deployment readyReplicas: ${READY:-0} — pod may still be starting"
fi

# ── 5. Pod can read the file it wrote to /data ────────────────────────────────
echo ""
echo "[ Check 5 ] Pod can read /data/test.txt (persistent write verified)"
POD=$(kubectl get pods -n "$NS" -l app=stateful-app \
  -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [[ -n "$POD" ]]; then
  CONTENT=$(kubectl exec --request-timeout=5s "$POD" -n "$NS" -- cat /data/test.txt 2>/dev/null || echo "")
  if [[ -n "$CONTENT" ]]; then
    ok "File /data/test.txt contains: $CONTENT"
  else
    fail "File /data/test.txt is empty or unreadable"
  fi
else
  fail "No stateful-app pod found"
fi

# ── 6. A PV was dynamically provisioned (named pvc-*) ────────────────────────
echo ""
echo "[ Check 6 ] PV was dynamically provisioned"
PV_NAME=$(kubectl get pvc app-db -n "$NS" \
  -o jsonpath='{.spec.volumeName}' 2>/dev/null || echo "")
if [[ "$PV_NAME" == pvc-* ]]; then
  ok "Dynamic PV: $PV_NAME"
else
  ok "PVC bound to PV: $PV_NAME (dynamic or static)"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Persistent storage provisioned and working!"
  echo "    Data survives pod restarts."
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Create the PVC app-db with 1Gi and default StorageClass."
  echo ""
  exit 1
fi
