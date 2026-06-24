#!/usr/bin/env bash
# Validate level-05: Job completion
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Job Completion ==="
echo ""

echo "[ Check 1 ] Job 'db-backup' exists"
if kubectl get job db-backup -n "$NS" &>/dev/null; then
  ok "Job 'db-backup' exists"
else
  fail "Job 'db-backup' not found"
fi

echo ""
echo "[ Check 2 ] Job has succeeded (status.succeeded >= 1)"
SUCCEEDED=$(kubectl get job db-backup -n "$NS" \
  -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "0")
SUCCEEDED=${SUCCEEDED:-0}
if [[ "$SUCCEEDED" -ge 1 ]]; then
  ok "Job succeeded: $SUCCEEDED completion(s)"
else
  # Check if still running
  ACTIVE=$(kubectl get job db-backup -n "$NS" \
    -o jsonpath='{.status.active}' 2>/dev/null || echo "0")
  FAILED=$(kubectl get job db-backup -n "$NS" \
    -o jsonpath='{.status.failed}' 2>/dev/null || echo "0")
  if [[ "${ACTIVE:-0}" -ge 1 ]]; then
    fail "Job still running (active: $ACTIVE) — wait and retry"
  else
    fail "Job has not succeeded (succeeded: $SUCCEEDED, failed: ${FAILED:-0})"
  fi
fi

echo ""
echo "[ Check 3 ] Job is not in Failed state"
FAILED=$(kubectl get job db-backup -n "$NS" \
  -o jsonpath='{.status.conditions[?(@.type=="Failed")].status}' 2>/dev/null || echo "")
if [[ "$FAILED" != "True" ]]; then
  ok "Job is not in Failed condition"
else
  fail "Job condition is Failed — backoffLimit exhausted"
fi

echo ""
echo "[ Check 4 ] Container command uses 'sh' (not 'shh')"
CMD=$(kubectl get job db-backup -n "$NS" \
  -o jsonpath='{.spec.template.spec.containers[0].command[0]}' 2>/dev/null || echo "")
if [[ "$CMD" == "sh" ]]; then
  ok "Command: sh (typo fixed)"
else
  fail "Command: '$CMD' (expected 'sh')"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Backup Job completed successfully!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Job not complete. Delete and recreate with"
  echo "    the fixed command: sh -c 'echo backup OK'"
  echo ""
  exit 1
fi
