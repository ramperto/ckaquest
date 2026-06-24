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

echo "=== Level 11: RBAC Create — Validation ==="
echo ""

# 1. Role exists
check "Role app-deployer-role exists" \
  kubectl get role app-deployer-role -n "$NS"

# 2. Role has get,list,watch on pods
check "Role grants get,list,watch on pods" \
  bash -c "
    VERBS=\$(kubectl get role app-deployer-role -n $NS -o jsonpath='{.rules[?(@.resources[0]==\"pods\")].verbs}')
    echo \"\$VERBS\" | grep -q 'get' && echo \"\$VERBS\" | grep -q 'list' && echo \"\$VERBS\" | grep -q 'watch'
  "

# 3. Role has create,get,list on deployments
check "Role grants create,get,list on deployments" \
  bash -c "
    VERBS=\$(kubectl get role app-deployer-role -n $NS -o jsonpath='{.rules[?(@.resources[0]==\"deployments\")].verbs}')
    echo \"\$VERBS\" | grep -q 'create' && echo \"\$VERBS\" | grep -q 'get' && echo \"\$VERBS\" | grep -q 'list'
  "

# 4. RoleBinding exists
check "RoleBinding app-deployer-binding exists" \
  kubectl get rolebinding app-deployer-binding -n "$NS"

# 5. RoleBinding binds to SA app-deployer
check "RoleBinding binds to ServiceAccount app-deployer" \
  bash -c "
    kubectl get rolebinding app-deployer-binding -n $NS -o jsonpath='{.subjects}' | grep -q 'app-deployer'
  "

# 6. auth can-i check
check "kubectl auth can-i list pods returns yes for app-deployer" \
  bash -c "
    kubectl auth can-i list pods --as=system:serviceaccount:${NS}:app-deployer -n $NS 2>&1 | grep -qi 'yes'
  "

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && echo "🎉 Level 11 complete!" || exit 1
