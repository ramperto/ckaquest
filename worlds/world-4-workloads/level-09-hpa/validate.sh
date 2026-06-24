#!/usr/bin/env bash
# Validate level-09: HPA with resource requests
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: HPA Resource Requests ==="
echo ""

echo "[ Check 1 ] Deployment 'web-api' exists"
if kubectl get deployment web-api -n "$NS" &>/dev/null; then
  ok "Deployment 'web-api' exists"
else
  fail "Deployment 'web-api' not found"
fi

echo ""
echo "[ Check 2 ] Container has CPU request set"
CPU_REQ=$(kubectl get deployment web-api -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' \
  2>/dev/null || echo "")
if [[ -n "$CPU_REQ" && "$CPU_REQ" != "null" ]]; then
  ok "CPU request: $CPU_REQ"
else
  fail "No CPU request defined (resources.requests.cpu is empty)"
fi

echo ""
echo "[ Check 3 ] HPA 'web-api-hpa' exists"
if kubectl get hpa web-api-hpa -n "$NS" &>/dev/null; then
  ok "HPA 'web-api-hpa' exists"
else
  fail "HPA 'web-api-hpa' not found"
fi

echo ""
echo "[ Check 4 ] HPA minReplicas: 1"
MIN=$(kubectl get hpa web-api-hpa -n "$NS" \
  -o jsonpath='{.spec.minReplicas}' 2>/dev/null || echo "")
if [[ "$MIN" == "1" ]]; then
  ok "HPA minReplicas: 1"
else
  fail "HPA minReplicas: '$MIN' (expected 1)"
fi

echo ""
echo "[ Check 5 ] HPA maxReplicas: 5"
MAX=$(kubectl get hpa web-api-hpa -n "$NS" \
  -o jsonpath='{.spec.maxReplicas}' 2>/dev/null || echo "")
if [[ "$MAX" == "5" ]]; then
  ok "HPA maxReplicas: 5"
else
  fail "HPA maxReplicas: '$MAX' (expected 5)"
fi

echo ""
echo "[ Check 6 ] HPA targets CPU (averageUtilization or targetCPUUtilizationPercentage)"
if kubectl get hpa web-api-hpa -n "$NS" -o json 2>/dev/null | python3 -c "
import sys, json
d = json.load(sys.stdin)
spec = d.get('spec', {})
# autoscaling/v2
for m in spec.get('metrics', []):
    if m.get('type') == 'Resource' and m.get('resource', {}).get('name') == 'cpu':
        sys.exit(0)
# autoscaling/v1
if spec.get('targetCPUUtilizationPercentage'):
    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "HPA targets CPU utilization"
else
  fail "HPA does not target CPU"
fi

echo ""
echo "[ Check 7 ] Deployment replicas are ready"
READY=$(kubectl get deployment web-api -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
if [[ "${READY:-0}" -ge 1 ]]; then
  ok "Deployment has ${READY} ready replica(s)"
else
  fail "Deployment has no ready replicas"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ HPA properly configured with CPU requests!"
  echo "    (Metric may show <unknown> briefly while metrics-server"
  echo "    collects data — this is normal for a new pod.)"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Add CPU requests to the Deployment containers."
  echo "    kubectl set resources deployment/web-api -n ckaquest"
  echo "    --requests=cpu=100m --limits=cpu=200m"
  echo ""
  exit 1
fi
