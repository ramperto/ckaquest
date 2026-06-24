#!/usr/bin/env bash
# Validate level-15: Native Sidecar Container
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Native Sidecar Container ==="
echo ""

echo "[ Check 1 ] Pod 'app-with-sidecar' exists"
if kubectl get pod app-with-sidecar -n "$NS" &>/dev/null; then
  ok "Pod 'app-with-sidecar' exists"
else
  fail "Pod 'app-with-sidecar' not found in namespace $NS"
fi

echo ""
echo "[ Check 2 ] Pod is Running"
PHASE=$(kubectl get pod app-with-sidecar -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
if [[ "$PHASE" == "Running" ]]; then
  ok "Pod is Running"
else
  fail "Pod phase: $PHASE (expected Running — init container may be blocking)"
fi

echo ""
echo "[ Check 3 ] Init container 'log-agent' has restartPolicy: Always"
RESTART_POLICY=$(kubectl get pod app-with-sidecar -n "$NS" \
  -o jsonpath='{.spec.initContainers[?(@.name=="log-agent")].restartPolicy}' 2>/dev/null || echo "")
if [[ "$RESTART_POLICY" == "Always" ]]; then
  ok "Init container 'log-agent' has restartPolicy: Always (native sidecar)"
else
  fail "Init container 'log-agent' restartPolicy: '${RESTART_POLICY:-<not set>}' (expected 'Always')"
fi

echo ""
echo "[ Check 4 ] Main container 'main-app' is Ready"
MAIN_READY=$(kubectl get pod app-with-sidecar -n "$NS" \
  -o jsonpath='{.status.containerStatuses[?(@.name=="main-app")].ready}' 2>/dev/null || echo "false")
if [[ "$MAIN_READY" == "true" ]]; then
  ok "Main container 'main-app' is Ready"
else
  fail "Main container 'main-app' is not Ready (the init container may be blocking startup)"
fi

echo ""
echo "[ Check 5 ] Both containers are running"
INIT_RUNNING=$(kubectl get pod app-with-sidecar -n "$NS" \
  -o jsonpath='{.status.initContainerStatuses[?(@.name=="log-agent")].state.running}' 2>/dev/null || echo "")
MAIN_RUNNING=$(kubectl get pod app-with-sidecar -n "$NS" \
  -o jsonpath='{.status.containerStatuses[?(@.name=="main-app")].state.running}' 2>/dev/null || echo "")
if [[ -n "$INIT_RUNNING" && -n "$MAIN_RUNNING" ]]; then
  ok "Both containers are running (sidecar + main)"
else
  if [[ -z "$INIT_RUNNING" ]]; then
    fail "Init sidecar 'log-agent' is not running"
  fi
  if [[ -z "$MAIN_RUNNING" ]]; then
    fail "Main container 'main-app' is not running"
  fi
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  Native sidecar running alongside the main container!"
  echo ""
  exit 0
else
  echo ""
  echo "  Add 'restartPolicy: Always' to the init container 'log-agent'"
  echo "  to make it a native sidecar that runs alongside the main container."
  echo ""
  exit 1
fi
