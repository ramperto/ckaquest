#!/usr/bin/env bash
# Validate level-02: Deployment rollback
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Deployment Rollback ==="
echo ""

# ── 1. Deployment exists ─────────────────────────────────────────────────────
echo "[ Check 1 ] Deployment 'api' exists"
if kubectl get deployment api -n "$NS" &>/dev/null; then
  ok "Deployment 'api' exists"
else
  fail "Deployment 'api' not found"
fi

# ── 2. Image is nginx:1.25 (rolled back) ─────────────────────────────────────
echo ""
echo "[ Check 2 ] Image rolled back to nginx:1.25"
IMAGE=$(kubectl get deployment api -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
if [[ "$IMAGE" == "nginx:1.25" ]]; then
  ok "Image is nginx:1.25 (rollback successful)"
else
  fail "Image is '$IMAGE' (expected nginx:1.25 — did you run rollout undo?)"
fi

# ── 3. All 3 replicas ready ──────────────────────────────────────────────────
echo ""
echo "[ Check 3 ] All 3 replicas are Ready"
READY=$(kubectl get deployment api -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$READY" == "3" ]]; then
  ok "readyReplicas: 3/3"
else
  fail "readyReplicas: ${READY:-0}/3 — rollout not complete"
fi

# ── 4. No pods with broken image ─────────────────────────────────────────────
echo ""
echo "[ Check 4 ] No pods using the broken image"
BAD=$(kubectl get pods -n "$NS" -l app=api \
  -o jsonpath='{range .items[*]}{.spec.containers[0].image}{"\n"}{end}' 2>/dev/null \
  | grep -c "BROKEN" || true)
if [[ "$BAD" == "0" ]]; then
  ok "No pods running nginx:BROKEN"
else
  fail "$BAD pod(s) still using nginx:BROKEN"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Rollback complete! Revision 1 restored."
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Rollback not complete. Run:"
  echo "    kubectl rollout undo deployment/api -n ckaquest"
  echo ""
  exit 1
fi
