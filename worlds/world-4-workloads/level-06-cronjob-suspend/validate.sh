#!/usr/bin/env bash
# Validate level-06: CronJob unsuspend
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: CronJob Unsuspend ==="
echo ""

echo "[ Check 1 ] CronJob 'report-generator' exists"
if kubectl get cronjob report-generator -n "$NS" &>/dev/null; then
  ok "CronJob 'report-generator' exists"
else
  fail "CronJob 'report-generator' not found"
fi

echo ""
echo "[ Check 2 ] CronJob is not suspended"
SUSPENDED=$(kubectl get cronjob report-generator -n "$NS" \
  -o jsonpath='{.spec.suspend}' 2>/dev/null || echo "true")
if [[ "$SUSPENDED" == "false" || "$SUSPENDED" == "" ]]; then
  ok "CronJob suspend: false"
else
  fail "CronJob suspend: $SUSPENDED (should be false)"
fi

echo ""
echo "[ Check 3 ] At least one Job from CronJob has succeeded"
# Jobs created from a CronJob have an owner reference
SUCCEEDED=$(kubectl get jobs -n "$NS" \
  -o jsonpath='{range .items[?(@.status.succeeded>=1)]}{.metadata.name}{"\n"}{end}' \
  2>/dev/null | wc -l | tr -d ' ')
if [[ "$SUCCEEDED" -ge 1 ]]; then
  ok "$SUCCEEDED Job(s) have succeeded"
else
  # Check if any job is still running
  ACTIVE=$(kubectl get jobs -n "$NS" \
    -o jsonpath='{range .items[*]}{.status.active}{"\n"}{end}' \
    2>/dev/null | grep -c "^[1-9]" || true)
  if [[ "$ACTIVE" -ge 1 ]]; then
    fail "A Job is still running — wait and re-validate"
  else
    fail "No succeeded Jobs found. Trigger one with: kubectl create job test --from=cronjob/report-generator -n ckaquest"
  fi
fi

echo ""
echo "[ Check 4 ] CronJob schedule is set"
SCHED=$(kubectl get cronjob report-generator -n "$NS" \
  -o jsonpath='{.spec.schedule}' 2>/dev/null || echo "")
if [[ -n "$SCHED" ]]; then
  ok "Schedule: $SCHED"
else
  fail "CronJob has no schedule"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ CronJob unsuspended and verified!"
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Unsuspend the CronJob and trigger a manual run."
  echo ""
  exit 1
fi
