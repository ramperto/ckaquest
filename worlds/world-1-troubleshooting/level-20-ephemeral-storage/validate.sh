#!/bin/bash
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

# Check 1: Pod storage-hog exists
POD=$(kubectl get pod storage-hog -n "$NS" -o name 2>/dev/null)
if [[ -n "$POD" ]]; then
  echo "PASS: Pod 'storage-hog' exists."
  ((PASS++))
else
  echo "FAIL: Pod 'storage-hog' not found in namespace $NS."
  exit 1
fi

# Check 2: Pod is Running
PHASE=$(kubectl get pod storage-hog -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null)
if [[ "$PHASE" == "Running" ]]; then
  echo "PASS: Pod 'storage-hog' is Running."
  ((PASS++))
else
  echo "FAIL: Pod 'storage-hog' is not Running (status: ${PHASE:-Unknown})."
  echo "  Check: kubectl describe pod storage-hog -n $NS"
  ((FAIL++))
fi

# Check 3: Ephemeral storage request is <= 10Gi (reasonable)
STORAGE_REQ=$(kubectl get pod storage-hog -n "$NS" \
  -o jsonpath='{.spec.containers[0].resources.requests.ephemeral-storage}' 2>/dev/null)

# Convert to a comparable number (handle Mi, Gi, Ki, and plain bytes)
convert_to_bytes() {
  local val="$1"
  if [[ "$val" =~ ^([0-9]+)Ki$ ]]; then
    echo $(( ${BASH_REMATCH[1]} * 1024 ))
  elif [[ "$val" =~ ^([0-9]+)Mi$ ]]; then
    echo $(( ${BASH_REMATCH[1]} * 1024 * 1024 ))
  elif [[ "$val" =~ ^([0-9]+)Gi$ ]]; then
    echo $(( ${BASH_REMATCH[1]} * 1024 * 1024 * 1024 ))
  elif [[ "$val" =~ ^([0-9]+)$ ]]; then
    echo "$val"
  else
    echo "0"
  fi
}

STORAGE_BYTES=$(convert_to_bytes "$STORAGE_REQ")
MAX_BYTES=$(( 10 * 1024 * 1024 * 1024 ))  # 10Gi

if [[ "$STORAGE_BYTES" -le "$MAX_BYTES" ]] 2>/dev/null; then
  echo "PASS: Ephemeral storage request is reasonable ($STORAGE_REQ)."
  ((PASS++))
else
  echo "FAIL: Ephemeral storage request is too high ($STORAGE_REQ). Must be <= 10Gi."
  ((FAIL++))
fi

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "Level 20 complete! All $PASS checks passed. Resource request fixed."
  exit 0
else
  echo "$PASS passed, $FAIL failed."
  exit 1
fi
