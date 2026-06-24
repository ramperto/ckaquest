#!/bin/bash
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

echo "=== Level 11 Validation: PVC Expansion ==="
echo ""

# Check 1: StorageClass has allowVolumeExpansion: true
echo -n "1. StorageClass no-expand-sc has allowVolumeExpansion: true ... "
ALLOW=$(kubectl get storageclass no-expand-sc -o jsonpath='{.allowVolumeExpansion}' 2>/dev/null)
if [ "$ALLOW" = "true" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (got: '$ALLOW')"
  ((FAIL++))
fi

# Check 2: PVC app-data request is >= 1Gi
echo -n "2. PVC app-data storage request >= 1Gi ... "
STORAGE=$(kubectl get pvc app-data -n "$NS" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
# Convert to bytes for comparison
STORAGE_BYTES=0
if echo "$STORAGE" | grep -qE '^[0-9]+Gi$'; then
  NUM=$(echo "$STORAGE" | sed 's/Gi//')
  STORAGE_BYTES=$((NUM * 1073741824))
elif echo "$STORAGE" | grep -qE '^[0-9]+Mi$'; then
  NUM=$(echo "$STORAGE" | sed 's/Mi//')
  STORAGE_BYTES=$((NUM * 1048576))
elif echo "$STORAGE" | grep -qE '^[0-9]+$'; then
  STORAGE_BYTES=$STORAGE
fi

if [ "$STORAGE_BYTES" -ge 1073741824 ] 2>/dev/null; then
  echo "PASS (storage: $STORAGE)"
  ((PASS++))
else
  echo "FAIL (storage: $STORAGE)"
  ((FAIL++))
fi

# Check 3: Deployment data-app has 1 ready replica
echo -n "3. Deployment data-app has 1 ready replica ... "
READY=$(kubectl get deployment data-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$READY" = "1" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (ready replicas: '${READY:-0}')"
  ((FAIL++))
fi

# Check 4: PVC app-data is Bound
echo -n "4. PVC app-data is Bound ... "
PHASE=$(kubectl get pvc app-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PHASE" = "Bound" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (phase: '$PHASE')"
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
