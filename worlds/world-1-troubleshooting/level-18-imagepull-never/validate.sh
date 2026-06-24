#!/bin/bash
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

# Check 1: Pod local-app exists
POD=$(kubectl get pod local-app -n "$NS" -o name 2>/dev/null)
if [[ -n "$POD" ]]; then
  echo "PASS: Pod 'local-app' exists."
  ((PASS++))
else
  echo "FAIL: Pod 'local-app' not found in namespace $NS."
  exit 1
fi

# Check 2: Pod is Running
PHASE=$(kubectl get pod local-app -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null)
if [[ "$PHASE" == "Running" ]]; then
  echo "PASS: Pod 'local-app' is Running."
  ((PASS++))
else
  echo "FAIL: Pod 'local-app' is not Running (status: ${PHASE:-Unknown})."
  echo "  Check: kubectl describe pod local-app -n $NS"
  ((FAIL++))
fi

# Check 3: imagePullPolicy is NOT Never
PULL_POLICY=$(kubectl get pod local-app -n "$NS" \
  -o jsonpath='{.spec.containers[0].imagePullPolicy}' 2>/dev/null)
if [[ "$PULL_POLICY" != "Never" ]]; then
  echo "PASS: imagePullPolicy is '$PULL_POLICY' (not Never)."
  ((PASS++))
else
  echo "FAIL: imagePullPolicy is still 'Never'."
  echo "  Change it to 'IfNotPresent' or 'Always'."
  ((FAIL++))
fi

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "Level 18 complete! All $PASS checks passed. Image pull policy fixed."
  exit 0
else
  echo "$PASS passed, $FAIL failed."
  exit 1
fi
