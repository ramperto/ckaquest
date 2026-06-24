#!/usr/bin/env bash
# Validate level-15: Service Routing — Selector Typo + Readiness Probe
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Service Routing ==="
echo ""

# -- 1. Deployment frontend has 2 ready replicas ------------------------------
echo "[ Check 1 ] Deployment frontend has 2 ready replicas"
READY=$(kubectl get deployment frontend -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED=$(kubectl get deployment frontend -n "$NS" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "2")
if [[ "${READY:-0}" == "2" && "$DESIRED" == "2" ]]; then
  ok "Deployment frontend: 2/2 replicas ready"
else
  fail "Deployment frontend: ${READY:-0}/$DESIRED replicas ready (need 2/2)"
fi

# -- 2. Service frontend-svc exists -------------------------------------------
echo ""
echo "[ Check 2 ] Service frontend-svc exists"
if kubectl get service frontend-svc -n "$NS" &>/dev/null; then
  ok "Service 'frontend-svc' exists"
else
  fail "Service 'frontend-svc' not found"
fi

# -- 3. Endpoints have at least 2 addresses -----------------------------------
echo ""
echo "[ Check 3 ] Endpoints for frontend-svc have at least 2 addresses"
EP_IPS=$(kubectl get endpoints frontend-svc -n "$NS" \
  -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
EP_COUNT=$(echo "$EP_IPS" | tr ' ' '\n' | grep -c '.' 2>/dev/null || echo "0")
if [[ "$EP_COUNT" -ge 2 ]]; then
  ok "Endpoints have $EP_COUNT addresses"
else
  fail "Endpoints have $EP_COUNT address(es) (expected at least 2)"
fi

# -- 4. Pods are Ready (readiness probe passes) --------------------------------
echo ""
echo "[ Check 4 ] All frontend pods are Ready"
NOT_READY=$(kubectl get pods -n "$NS" -l app=frontend \
  -o jsonpath='{.items[*].status.conditions[?(@.type=="Ready")].status}' \
  2>/dev/null | tr ' ' '\n' | grep -c "False" 2>/dev/null || echo "0")
TOTAL_PODS=$(kubectl get pods -n "$NS" -l app=frontend \
  -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | wc -w | tr -d ' ')
if [[ "$NOT_READY" == "0" && "$TOTAL_PODS" -ge 2 ]]; then
  ok "All $TOTAL_PODS frontend pods are Ready"
else
  fail "$NOT_READY of $TOTAL_PODS frontend pods are not Ready — check readiness probe"
fi

# -- 5. NodePort 30080 responds -----------------------------------------------
echo ""
echo "[ Check 5 ] NodePort 30080 responds with HTTP content"
HTTP_RESP=$(curl -s --max-time 5 localhost:30080 2>/dev/null || echo "")
if echo "$HTTP_RESP" | grep -qi "nginx\|html\|welcome\|DOCTYPE"; then
  ok "curl localhost:30080 returned HTTP content"
else
  fail "curl localhost:30080 failed or returned no content"
fi

# -- Summary -------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  Service routing fixed! Both the selector"
  echo "  and readiness probe are now correct."
  echo ""
  exit 0
else
  echo ""
  echo "  Some checks failed. Check both the Service"
  echo "  selector AND the readiness probe path."
  echo ""
  exit 1
fi
