#!/usr/bin/env bash
# Validate level-09: NetworkPolicy combined (3-tier zero-trust)
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: NetworkPolicy Combined (3-tier) ==="
echo ""

# ── 1. All three NetworkPolicies exist ──────────────────────────────────────
echo "[ Check 1 ] NetworkPolicies exist"
for pol in frontend-policy backend-policy db-policy; do
  if kubectl get networkpolicy "$pol" -n "$NS" &>/dev/null; then
    ok "NetworkPolicy '$pol' exists"
  else
    fail "NetworkPolicy '$pol' missing"
  fi
done

# ── 2. frontend-policy selects tier=frontend ─────────────────────────────────
echo ""
echo "[ Check 2 ] frontend-policy targets tier=frontend"
SELECTOR=$(kubectl get networkpolicy frontend-policy -n "$NS" \
  -o jsonpath='{.spec.podSelector.matchLabels.tier}' 2>/dev/null || echo "")
if [[ "$SELECTOR" == "frontend" ]]; then
  ok "frontend-policy podSelector matches tier=frontend"
else
  fail "frontend-policy podSelector does not match tier=frontend (got: '$SELECTOR')"
fi

# ── 3. frontend-policy has both Ingress and Egress policyTypes ───────────────
echo ""
echo "[ Check 3 ] frontend-policy enforces both Ingress and Egress"
TYPES=$(kubectl get networkpolicy frontend-policy -n "$NS" \
  -o jsonpath='{.spec.policyTypes[*]}' 2>/dev/null || echo "")
if echo "$TYPES" | grep -q "Ingress" && echo "$TYPES" | grep -q "Egress"; then
  ok "frontend-policy has Ingress + Egress policyTypes"
else
  fail "frontend-policy missing Ingress or Egress policyType (got: '$TYPES')"
fi

# ── 4. frontend-policy allows egress to tier=backend on port 80 ──────────────
echo ""
echo "[ Check 4 ] frontend-policy allows egress to tier=backend:80"
FRONTEND_EGRESS=$(kubectl get networkpolicy frontend-policy -n "$NS" -o json 2>/dev/null || echo "{}")
if echo "$FRONTEND_EGRESS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
egress = d.get('spec', {}).get('egress', [])
for rule in egress:
    to = rule.get('to', [])
    ports = rule.get('ports', [])
    for peer in to:
        ml = peer.get('podSelector', {}).get('matchLabels', {})
        if ml.get('tier') == 'backend':
            for p in ports:
                if p.get('port') == 80:
                    print('ok')
                    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "frontend-policy egress allows tier=backend port 80"
else
  fail "frontend-policy egress does not allow tier=backend port 80"
fi

# ── 5. frontend-policy allows egress DNS (port 53) ───────────────────────────
echo ""
echo "[ Check 5 ] frontend-policy allows egress DNS (port 53)"
if echo "$FRONTEND_EGRESS" | python3 -c "
import sys, json
d = json.load(sys.stdin)
egress = d.get('spec', {}).get('egress', [])
for rule in egress:
    ports = rule.get('ports', [])
    for p in ports:
        if p.get('port') == 53:
            print('ok')
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "frontend-policy egress allows DNS port 53"
else
  fail "frontend-policy egress missing DNS port 53 (pods can't resolve hostnames)"
fi

# ── 6. backend-policy selects tier=backend ───────────────────────────────────
echo ""
echo "[ Check 6 ] backend-policy targets tier=backend"
BSELECTOR=$(kubectl get networkpolicy backend-policy -n "$NS" \
  -o jsonpath='{.spec.podSelector.matchLabels.tier}' 2>/dev/null || echo "")
if [[ "$BSELECTOR" == "backend" ]]; then
  ok "backend-policy podSelector matches tier=backend"
else
  fail "backend-policy podSelector does not match tier=backend (got: '$BSELECTOR')"
fi

# ── 7. backend-policy ingress allows from tier=frontend on port 80 ───────────
echo ""
echo "[ Check 7 ] backend-policy allows ingress from tier=frontend:80"
BACKEND_POL=$(kubectl get networkpolicy backend-policy -n "$NS" -o json 2>/dev/null || echo "{}")
if echo "$BACKEND_POL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ingress = d.get('spec', {}).get('ingress', [])
for rule in ingress:
    frm = rule.get('from', [])
    ports = rule.get('ports', [])
    for peer in frm:
        ml = peer.get('podSelector', {}).get('matchLabels', {})
        if ml.get('tier') == 'frontend':
            for p in ports:
                if p.get('port') == 80:
                    print('ok')
                    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "backend-policy ingress allows tier=frontend port 80"
else
  fail "backend-policy ingress does not allow tier=frontend port 80"
fi

# ── 8. backend-policy egress allows to tier=database on port 5432 ────────────
echo ""
echo "[ Check 8 ] backend-policy allows egress to tier=database:5432"
if echo "$BACKEND_POL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
egress = d.get('spec', {}).get('egress', [])
for rule in egress:
    to = rule.get('to', [])
    ports = rule.get('ports', [])
    for peer in to:
        ml = peer.get('podSelector', {}).get('matchLabels', {})
        if ml.get('tier') == 'database':
            for p in ports:
                if p.get('port') == 5432:
                    print('ok')
                    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "backend-policy egress allows tier=database port 5432"
else
  fail "backend-policy egress does not allow tier=database port 5432"
fi

# ── 9. backend-policy egress allows DNS ──────────────────────────────────────
echo ""
echo "[ Check 9 ] backend-policy allows egress DNS (port 53)"
if echo "$BACKEND_POL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
egress = d.get('spec', {}).get('egress', [])
for rule in egress:
    for p in rule.get('ports', []):
        if p.get('port') == 53:
            print('ok')
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "backend-policy egress allows DNS port 53"
else
  fail "backend-policy egress missing DNS port 53"
fi

# ── 10. db-policy selects tier=database ──────────────────────────────────────
echo ""
echo "[ Check 10 ] db-policy targets tier=database"
DBSELECTOR=$(kubectl get networkpolicy db-policy -n "$NS" \
  -o jsonpath='{.spec.podSelector.matchLabels.tier}' 2>/dev/null || echo "")
if [[ "$DBSELECTOR" == "database" ]]; then
  ok "db-policy podSelector matches tier=database"
else
  fail "db-policy podSelector does not match tier=database (got: '$DBSELECTOR')"
fi

# ── 11. db-policy ingress allows from tier=backend on port 5432 ──────────────
echo ""
echo "[ Check 11 ] db-policy allows ingress from tier=backend:5432"
DB_POL=$(kubectl get networkpolicy db-policy -n "$NS" -o json 2>/dev/null || echo "{}")
if echo "$DB_POL" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ingress = d.get('spec', {}).get('ingress', [])
for rule in ingress:
    frm = rule.get('from', [])
    ports = rule.get('ports', [])
    for peer in frm:
        ml = peer.get('podSelector', {}).get('matchLabels', {})
        if ml.get('tier') == 'backend':
            for p in ports:
                if p.get('port') == 5432:
                    print('ok')
                    sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
  ok "db-policy ingress allows tier=backend port 5432"
else
  fail "db-policy ingress does not allow tier=backend port 5432"
fi

# ── 12. All pods still running ───────────────────────────────────────────────
echo ""
echo "[ Check 12 ] All 3 pods are Running"
for pod in frontend backend db; do
  PHASE=$(kubectl get pod "$pod" -n "$NS" \
    -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
  if [[ "$PHASE" == "Running" ]]; then
    ok "Pod '$pod' is Running"
  else
    fail "Pod '$pod' phase: $PHASE (expected Running)"
  fi
done

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Zero-trust policies locked! Only the"
  echo "    allowed paths are open. Well done."
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Some checks failed. Re-read the mission"
  echo "    and review your NetworkPolicy specs."
  echo ""
  exit 1
fi
