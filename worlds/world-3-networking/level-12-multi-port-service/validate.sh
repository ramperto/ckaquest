#!/usr/bin/env bash
# Validate level-12: Multi-Port Service
set -euo pipefail
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Multi-Port Service ==="
echo ""

# -- 1. Service multi-svc exists ----------------------------------------------
echo "[ Check 1 ] Service multi-svc exists"
if kubectl get service multi-svc -n "$NS" &>/dev/null; then
  ok "Service 'multi-svc' exists"
else
  fail "Service 'multi-svc' not found"
fi

# -- 2. Service has 2 ports ---------------------------------------------------
echo ""
echo "[ Check 2 ] Service has 2 ports"
PORT_COUNT=$(kubectl get service multi-svc -n "$NS" \
  -o jsonpath='{.spec.ports}' 2>/dev/null | python3 -c "import sys,json; print(len(json.loads(sys.stdin.read())))" 2>/dev/null || echo "0")
if [[ "$PORT_COUNT" == "2" ]]; then
  ok "Service has 2 ports defined"
else
  fail "Service has $PORT_COUNT port(s) (expected 2)"
fi

# -- 3. Both ports have names -------------------------------------------------
echo ""
echo "[ Check 3 ] Both ports have names (not empty)"
NAME_0=$(kubectl get service multi-svc -n "$NS" \
  -o jsonpath='{.spec.ports[0].name}' 2>/dev/null || echo "")
NAME_1=$(kubectl get service multi-svc -n "$NS" \
  -o jsonpath='{.spec.ports[1].name}' 2>/dev/null || echo "")
if [[ -n "$NAME_0" && -n "$NAME_1" ]]; then
  ok "Port names: '$NAME_0', '$NAME_1'"
else
  fail "One or both ports missing names: '$NAME_0', '$NAME_1'"
fi

# -- 4. Port 80 targetPort is 80 ----------------------------------------------
echo ""
echo "[ Check 4 ] Port 80 targetPort is 80"
# Find the port entry with port=80 and check targetPort
TP_80=$(kubectl get service multi-svc -n "$NS" -o json 2>/dev/null | \
  python3 -c "
import sys, json
svc = json.loads(sys.stdin.read())
for p in svc['spec']['ports']:
    if p['port'] == 80:
        print(p.get('targetPort', ''))
        break
" 2>/dev/null || echo "")
if [[ "$TP_80" == "80" ]]; then
  ok "Port 80 targetPort is 80"
else
  fail "Port 80 targetPort is '$TP_80' (expected 80)"
fi

# -- 5. Port 443 targetPort is 443 --------------------------------------------
echo ""
echo "[ Check 5 ] Port 443 targetPort is 443"
TP_443=$(kubectl get service multi-svc -n "$NS" -o json 2>/dev/null | \
  python3 -c "
import sys, json
svc = json.loads(sys.stdin.read())
for p in svc['spec']['ports']:
    if p['port'] == 443:
        print(p.get('targetPort', ''))
        break
" 2>/dev/null || echo "")
if [[ "$TP_443" == "443" ]]; then
  ok "Port 443 targetPort is 443"
else
  fail "Port 443 targetPort is '$TP_443' (expected 443)"
fi

# -- 6. Endpoints exist for the service ---------------------------------------
echo ""
echo "[ Check 6 ] Endpoints exist for multi-svc"
EP_ADDRS=$(kubectl get endpoints multi-svc -n "$NS" \
  -o jsonpath='{.subsets[*].addresses[*].ip}' 2>/dev/null || echo "")
if [[ -n "$EP_ADDRS" ]]; then
  ok "Endpoints have addresses: $EP_ADDRS"
else
  fail "No endpoint addresses found — check selector and pod status"
fi

# -- Summary -------------------------------------------------------------------
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  Multi-port Service fixed! Both ports are"
  echo "  named and routing to the correct targets."
  echo ""
  exit 0
else
  echo ""
  echo "  Some checks failed. Ensure both ports have"
  echo "  names and the HTTPS targetPort is 443."
  echo ""
  exit 1
fi
