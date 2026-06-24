#!/usr/bin/env bash
# Validate level-01: Deployment with fixed image
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Deployment Image Fix ==="
echo ""

# ── 1. Deployment exists ─────────────────────────────────────────────────────
echo "[ Check 1 ] Deployment 'web' exists"
if kubectl get deployment web -n "$NS" &>/dev/null; then
  ok "Deployment 'web' exists"
else
  fail "Deployment 'web' not found"
fi

# ── 2. Image is nginx:1.25 ───────────────────────────────────────────────────
echo ""
echo "[ Check 2 ] Container image is nginx:1.25"
IMAGE=$(kubectl get deployment web -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "")
if [[ "$IMAGE" == "nginx:1.25" ]]; then
  ok "Image is nginx:1.25"
else
  fail "Image is '$IMAGE' (expected nginx:1.25)"
fi

# ── 3. Replicas = 3 ──────────────────────────────────────────────────────────
echo ""
echo "[ Check 3 ] Deployment has 3 replicas configured"
DESIRED=$(kubectl get deployment web -n "$NS" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
if [[ "$DESIRED" == "3" ]]; then
  ok "Deployment replicas: 3"
else
  fail "Deployment replicas: $DESIRED (expected 3)"
fi

# ── 4. All replicas ready ────────────────────────────────────────────────────
echo ""
echo "[ Check 4 ] All 3 replicas are Ready"
READY=$(kubectl get deployment web -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "$READY" == "3" ]]; then
  ok "readyReplicas: 3/3"
else
  fail "readyReplicas: ${READY:-0}/3 — rollout not complete yet"
fi

# ── 5. No ImagePullBackOff pods ──────────────────────────────────────────────
echo ""
echo "[ Check 5 ] No pods in ImagePullBackOff"
BAD=$(kubectl get pods -n "$NS" -l app=web \
  --no-headers 2>/dev/null | grep -c "ImagePullBackOff\|ErrImagePull" || true)
if [[ "$BAD" == "0" ]]; then
  ok "No ImagePullBackOff pods"
else
  fail "$BAD pod(s) still in ImagePullBackOff / ErrImagePull"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Deployment rolled out successfully!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Rollout not complete. Check image tag"
  echo "    and wait for all pods to be Ready."
  echo ""
  exit 1
fi
