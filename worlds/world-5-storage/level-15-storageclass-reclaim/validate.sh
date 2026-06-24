#!/bin/bash
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

echo "=== Level 15 Validation: StorageClass Reclaim Policy ==="
echo ""

# Check 1: StorageClass retain-sc exists with reclaimPolicy: Retain
echo -n "1. StorageClass retain-sc has reclaimPolicy: Retain ... "
RECLAIM=$(kubectl get storageclass retain-sc -o jsonpath='{.reclaimPolicy}' 2>/dev/null)
if [ "$RECLAIM" = "Retain" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (got: '${RECLAIM:-not found}')"
  ((FAIL++))
fi

# Check 2: PVC safe-data exists and is Bound
echo -n "2. PVC safe-data is Bound ... "
PHASE=$(kubectl get pvc safe-data -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
if [ "$PHASE" = "Bound" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (phase: '${PHASE:-not found}')"
  ((FAIL++))
fi

# Check 3: PVC safe-data uses storageClassName: retain-sc
echo -n "3. PVC safe-data uses storageClassName retain-sc ... "
SC_NAME=$(kubectl get pvc safe-data -n "$NS" -o jsonpath='{.spec.storageClassName}' 2>/dev/null)
if [ "$SC_NAME" = "retain-sc" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (storageClassName: '${SC_NAME:-not found}')"
  ((FAIL++))
fi

# Check 4: Deployment db-app has 1 ready replica
echo -n "4. Deployment db-app has 1 ready replica ... "
READY=$(kubectl get deployment db-app -n "$NS" -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [ "$READY" = "1" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (ready replicas: '${READY:-0}')"
  ((FAIL++))
fi

# Check 5: Deployment db-app references PVC safe-data
echo -n "5. Deployment db-app references PVC safe-data ... "
CLAIM=$(kubectl get deployment db-app -n "$NS" -o jsonpath='{.spec.template.spec.volumes[0].persistentVolumeClaim.claimName}' 2>/dev/null)
if [ "$CLAIM" = "safe-data" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (claimName: '${CLAIM:-not found}')"
  ((FAIL++))
fi

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [ "$FAIL" -eq 0 ]; then
  echo "MISSION COMPLETE! +300 XP"
  exit 0
else
  echo "Some checks failed. Keep troubleshooting!"
  exit 1
fi
