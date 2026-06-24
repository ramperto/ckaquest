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

echo "=== Level 12: CSR Approval — Validation ==="
echo ""

# 1. CSR exists
check "CSR dev-user-csr exists" \
  kubectl get csr dev-user-csr

# 2. CSR is Approved
check "CSR dev-user-csr is Approved" \
  bash -c "
    kubectl get csr dev-user-csr -o jsonpath='{.status.conditions[*].type}' | grep -q 'Approved'
  "

# 3. CSR has certificate issued (status.certificate is non-empty)
check "CSR has issued certificate (status.certificate is non-empty)" \
  bash -c "
    CERT=\$(kubectl get csr dev-user-csr -o jsonpath='{.status.certificate}')
    [ -n \"\$CERT\" ]
  "

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "🎉 Level 12 complete!" || exit 1
