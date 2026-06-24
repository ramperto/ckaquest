#!/bin/bash
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

echo "=== Level 13 Validation: subPath Mount ==="
echo ""

# Check 1: Pod config-app is Running
echo -n "1. Pod config-app is Running ... "
PHASE=$(kubectl get pod config-app -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PHASE" = "Running" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (phase: '${PHASE:-not found}')"
  ((FAIL++))
fi

# Check 2: File /etc/app/app.conf exists with correct content
echo -n "2. File /etc/app/app.conf exists with correct content ... "
CONTENT=$(kubectl exec config-app -n "$NS" -- cat /etc/app/app.conf 2>/dev/null) || CONTENT=""
if echo "$CONTENT" | grep -q "port=8080"; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (content: '${CONTENT:-file not found}')"
  ((FAIL++))
fi

# Check 3: File /etc/app/logging.conf does NOT exist
echo -n "3. File /etc/app/logging.conf does NOT exist ... "
if kubectl exec config-app -n "$NS" -- test -f /etc/app/logging.conf 2>/dev/null; then
  echo "FAIL (logging.conf exists — subPath not used)"
  ((FAIL++))
else
  echo "PASS (file correctly absent)"
  ((PASS++))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "MISSION COMPLETE! +200 XP"
  exit 0
else
  echo "Some checks failed. Keep troubleshooting!"
  exit 1
fi
