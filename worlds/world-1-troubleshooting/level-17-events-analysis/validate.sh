#!/bin/bash
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

# Check 1: ServiceAccount app-runner exists
SA=$(kubectl get serviceaccount app-runner -n "$NS" -o name 2>/dev/null)
if [[ -n "$SA" ]]; then
  echo "PASS: ServiceAccount 'app-runner' exists."
  ((PASS++))
else
  echo "FAIL: ServiceAccount 'app-runner' not found in namespace $NS."
  echo "  Create it: kubectl create serviceaccount app-runner -n $NS"
  ((FAIL++))
fi

# Check 2: Deployment event-app has 1 ready replica
READY=$(kubectl get deployment event-app -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ "$READY" == "1" ]]; then
  echo "PASS: Deployment 'event-app' has 1 ready replica."
  ((PASS++))
else
  echo "FAIL: Deployment 'event-app' does not have 1 ready replica (ready: ${READY:-0})."
  echo "  Check pod status: kubectl get pods -n $NS -l app=event-app"
  ((FAIL++))
fi

# Check 3: Service event-svc targetPort is 80
TARGET_PORT=$(kubectl get svc event-svc -n "$NS" \
  -o jsonpath='{.spec.ports[0].targetPort}' 2>/dev/null)
if [[ "$TARGET_PORT" == "80" ]]; then
  echo "PASS: Service 'event-svc' targetPort is 80."
  ((PASS++))
else
  echo "FAIL: Service 'event-svc' targetPort is '${TARGET_PORT:-Not Found}' (expected 80)."
  echo "  Edit: kubectl edit svc event-svc -n $NS"
  ((FAIL++))
fi

# Check 4: Endpoints for event-svc are not empty
ENDPOINTS=$(kubectl get endpoints event-svc -n "$NS" \
  -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
if [[ -n "$ENDPOINTS" ]]; then
  echo "PASS: Service 'event-svc' has endpoints ($ENDPOINTS)."
  ((PASS++))
else
  echo "FAIL: Service 'event-svc' has no endpoints."
  echo "  Check that pod labels match service selector and the pod is Running."
  ((FAIL++))
fi

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "Level 17 complete! All $PASS checks passed. Events analysis mastered."
  exit 0
else
  echo "$PASS passed, $FAIL failed. Keep investigating the events."
  exit 1
fi
