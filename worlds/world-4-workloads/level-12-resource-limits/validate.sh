#!/usr/bin/env bash
# Validate level-12: Resource Limits
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

# Helper: convert resource string to milliunits for comparison
# Handles: 100m -> 100, 1 -> 1000, 250m -> 250
cpu_to_milli() {
  local val="$1"
  if [[ "$val" == *m ]]; then
    echo "${val%m}"
  else
    echo $((val * 1000))
  fi
}

# Helper: convert memory to bytes for comparison
# Handles: Ki, Mi, Gi, K, M, G
mem_to_bytes() {
  local val="$1"
  if [[ "$val" == *Gi ]]; then
    echo $(( ${val%Gi} * 1073741824 ))
  elif [[ "$val" == *Mi ]]; then
    echo $(( ${val%Mi} * 1048576 ))
  elif [[ "$val" == *Ki ]]; then
    echo $(( ${val%Ki} * 1024 ))
  elif [[ "$val" == *G ]]; then
    echo $(( ${val%G} * 1000000000 ))
  elif [[ "$val" == *M ]]; then
    echo $(( ${val%M} * 1000000 ))
  elif [[ "$val" == *K ]]; then
    echo $(( ${val%K} * 1000 ))
  else
    echo "$val"
  fi
}

echo ""
echo "=== Validating: Resource Limits ==="
echo ""

echo "[ Check 1 ] Pod 'resource-pod' exists"
if kubectl get pod resource-pod -n "$NS" &>/dev/null; then
  ok "Pod 'resource-pod' exists"
else
  fail "Pod 'resource-pod' not found in namespace $NS (admission error? check limits >= requests)"
fi

echo ""
echo "[ Check 2 ] Pod is Running"
PHASE=$(kubectl get pod resource-pod -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
if [[ "$PHASE" == "Running" ]]; then
  ok "Pod is Running"
else
  fail "Pod phase: $PHASE (expected Running)"
fi

echo ""
echo "[ Check 3 ] limits.memory >= requests.memory"
REQ_MEM=$(kubectl get pod resource-pod -n "$NS" \
  -o jsonpath='{.spec.containers[0].resources.requests.memory}' 2>/dev/null || echo "0")
LIM_MEM=$(kubectl get pod resource-pod -n "$NS" \
  -o jsonpath='{.spec.containers[0].resources.limits.memory}' 2>/dev/null || echo "0")
REQ_MEM_BYTES=$(mem_to_bytes "$REQ_MEM")
LIM_MEM_BYTES=$(mem_to_bytes "$LIM_MEM")
if [[ "$LIM_MEM_BYTES" -ge "$REQ_MEM_BYTES" ]] 2>/dev/null; then
  ok "limits.memory ($LIM_MEM) >= requests.memory ($REQ_MEM)"
else
  fail "limits.memory ($LIM_MEM) < requests.memory ($REQ_MEM) — limits must be >= requests"
fi

echo ""
echo "[ Check 4 ] limits.cpu >= requests.cpu"
REQ_CPU=$(kubectl get pod resource-pod -n "$NS" \
  -o jsonpath='{.spec.containers[0].resources.requests.cpu}' 2>/dev/null || echo "0")
LIM_CPU=$(kubectl get pod resource-pod -n "$NS" \
  -o jsonpath='{.spec.containers[0].resources.limits.cpu}' 2>/dev/null || echo "0")
REQ_CPU_MILLI=$(cpu_to_milli "$REQ_CPU")
LIM_CPU_MILLI=$(cpu_to_milli "$LIM_CPU")
if [[ "$LIM_CPU_MILLI" -ge "$REQ_CPU_MILLI" ]] 2>/dev/null; then
  ok "limits.cpu ($LIM_CPU) >= requests.cpu ($REQ_CPU)"
else
  fail "limits.cpu ($LIM_CPU) < requests.cpu ($REQ_CPU) — limits must be >= requests"
fi

echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  Resource requests and limits are correctly configured!"
  echo ""
  exit 0
else
  echo ""
  echo "  Fix the pod spec: ensure limits >= requests for both memory and CPU."
  echo "  Delete the pod first if it exists, then apply the corrected spec."
  echo ""
  exit 1
fi
