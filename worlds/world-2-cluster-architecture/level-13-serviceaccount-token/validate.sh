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

echo "=== Level 13: ServiceAccount Token — Validation ==="
echo ""

# 1. Pod api-test is Running
check "Pod api-test is Running" \
  bash -c "
    STATUS=\$(kubectl get pod api-test -n $NS -o jsonpath='{.status.phase}')
    [ \"\$STATUS\" = 'Running' ]
  "

# 2. Pod does NOT have automountServiceAccountToken: false
check "Pod does NOT have automountServiceAccountToken: false" \
  bash -c "
    VAL=\$(kubectl get pod api-test -n $NS -o jsonpath='{.spec.automountServiceAccountToken}')
    [ \"\$VAL\" != 'false' ]
  "

# 3. Token file exists inside the pod
check "Token file is mounted at /var/run/secrets/kubernetes.io/serviceaccount/token" \
  kubectl exec api-test -n "$NS" -- cat /var/run/secrets/kubernetes.io/serviceaccount/token

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "🎉 Level 13 complete!" || exit 1
