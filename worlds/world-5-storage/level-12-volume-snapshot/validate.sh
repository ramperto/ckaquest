#!/bin/bash
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

echo "=== Level 12 Validation: Volume Snapshot ==="
echo ""

# Check 1: VolumeSnapshotClass csi-snap-class exists
echo -n "1. VolumeSnapshotClass csi-snap-class exists ... "
if kubectl get volumesnapshotclass csi-snap-class &>/dev/null; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (VolumeSnapshotClass not found)"
  ((FAIL++))
fi

# Check 2: VolumeSnapshot data-snapshot exists and references csi-snap-class
echo -n "2. VolumeSnapshot data-snapshot references csi-snap-class ... "
SNAP_CLASS=$(kubectl get volumesnapshot data-snapshot -n "$NS" -o jsonpath='{.spec.volumeSnapshotClassName}' 2>/dev/null)
if [ "$SNAP_CLASS" = "csi-snap-class" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (got: '${SNAP_CLASS:-not found}')"
  ((FAIL++))
fi

# Check 3: VolumeSnapshot references PVC source-data
echo -n "3. VolumeSnapshot references PVC source-data ... "
PVC_NAME=$(kubectl get volumesnapshot data-snapshot -n "$NS" -o jsonpath='{.spec.source.persistentVolumeClaimName}' 2>/dev/null)
if [ "$PVC_NAME" = "source-data" ]; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (got: '${PVC_NAME:-not found}')"
  ((FAIL++))
fi

# Check 4: PVC source-data exists
echo -n "4. PVC source-data exists ... "
if kubectl get pvc source-data -n "$NS" &>/dev/null; then
  echo "PASS"
  ((PASS++))
else
  echo "FAIL (PVC not found)"
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
