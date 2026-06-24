#!/bin/bash
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

check() {
  local desc="$1"; shift
  if "$@" > /dev/null 2>&1; then
    echo "  ✅  $desc"
    ((PASS++))
  else
    echo "  ❌  $desc"
    ((FAIL++))
  fi
}

echo "=== Level 14: API Server Curl — Validation ==="
echo ""

# 1. Pod debug-pod is Running
check "Pod debug-pod is Running" \
  bash -c "
    STATUS=\$(kubectl get pod debug-pod -n $NS -o jsonpath='{.status.phase}')
    [ \"\$STATUS\" = 'Running' ]
  "

# 2. Pod does NOT have KUBERNETES_SERVICE_HOST set to 10.99.99.99
check "Pod does NOT have KUBERNETES_SERVICE_HOST overridden to 10.99.99.99" \
  bash -c "
    ENV_VAL=\$(kubectl get pod debug-pod -n $NS -o jsonpath='{.spec.containers[0].env[?(@.name==\"KUBERNETES_SERVICE_HOST\")].value}')
    [ \"\$ENV_VAL\" != '10.99.99.99' ]
  "

# 3. Pod can reach the API server
check "Pod can reach the API server (curl kubernetes.default.svc)" \
  bash -c "
    kubectl exec debug-pod -n $NS -- \
      curl -sk --max-time 5 \
        -H \"Authorization: Bearer \$(kubectl exec debug-pod -n $NS -- cat /var/run/secrets/kubernetes.io/serviceaccount/token)\" \
        https://kubernetes.default.svc/api 2>&1 | grep -q 'kind'
  "

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "🎉 Level 14 complete!" || exit 1
