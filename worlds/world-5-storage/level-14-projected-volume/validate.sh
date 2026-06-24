#!/bin/bash
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

echo "=== Level 14 Validation: Projected Volume ==="
echo ""

# Check 1: Pod projected-app is Running
echo -n "1. Pod projected-app is Running ... "
PHASE=$(kubectl get pod projected-app -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PHASE" = "Running" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (phase: '${PHASE:-not found}')"
  ((FAIL++))
fi

# Check 2: File /etc/projected/api-key exists (from Secret)
echo -n "2. File /etc/projected/api-key exists (from Secret) ... "
if kubectl exec projected-app -n "$NS" -- test -f /etc/projected/api-key 2>/dev/null; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (file not found)"
  ((FAIL++))
fi

# Check 3: File /etc/projected/config.yaml exists (from ConfigMap)
echo -n "3. File /etc/projected/config.yaml exists (from ConfigMap) ... "
if kubectl exec projected-app -n "$NS" -- test -f /etc/projected/config.yaml 2>/dev/null; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (file not found)"
  ((FAIL++))
fi

# Check 4: File /etc/projected/labels exists (from Downward API)
echo -n "4. File /etc/projected/labels exists (from Downward API) ... "
if kubectl exec projected-app -n "$NS" -- test -f /etc/projected/labels 2>/dev/null; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (file not found)"
  ((FAIL++))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "MISSION COMPLETE! +250 XP"
  exit 0
else
  echo "Some checks failed. Keep troubleshooting!"
  exit 1
fi
