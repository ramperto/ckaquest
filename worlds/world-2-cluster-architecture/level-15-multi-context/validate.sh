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

echo "=== Level 15: Multi-Context Kubeconfig — Validation ==="
echo ""

# 1. Current context is local-k3s
check "Current context is local-k3s" \
  bash -c "
    CTX=\$(kubectl config current-context)
    [ \"\$CTX\" = 'local-k3s' ]
  "

# 2. kubectl get nodes succeeds (cluster is reachable)
check "Cluster is reachable (kubectl get nodes succeeds)" \
  kubectl get nodes --request-timeout=5s

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "🎉 Level 15 complete!" || exit 1
