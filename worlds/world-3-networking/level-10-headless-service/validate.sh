#!/usr/bin/env bash
# Validate level-10: Headless Service
set -euo pipefail
NS="ckaquest"
PASS=0
FAIL=0

ok()   { echo "  [PASS] $1"; PASS=$((PASS + 1)); }
fail() { echo "  [FAIL] $1"; FAIL=$((FAIL + 1)); }

echo ""
echo "=== Validating: Headless Service ==="
echo ""

# ── 1. Service db-headless exists ────────────────────────────────────────────
echo "[ Check 1 ] Service db-headless exists"
if kubectl get service db-headless -n "$NS" &>/dev/null; then
  ok "Service 'db-headless' exists"
else
  fail "Service 'db-headless' not found"
fi

# ── 2. clusterIP is None ─────────────────────────────────────────────────────
echo ""
echo "[ Check 2 ] Service has clusterIP: None (headless)"
CLUSTER_IP=$(kubectl get service db-headless -n "$NS" \
  -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "missing")
if [[ "$CLUSTER_IP" == "None" ]]; then
  ok "db-headless clusterIP is None (headless)"
else
  fail "db-headless clusterIP is '$CLUSTER_IP' — should be 'None'"
fi

# ── 3. Selector matches app=db-cluster ───────────────────────────────────────
echo ""
echo "[ Check 3 ] Service selector matches app=db-cluster"
SELECTOR=$(kubectl get service db-headless -n "$NS" \
  -o jsonpath='{.spec.selector.app}' 2>/dev/null || echo "")
if [[ "$SELECTOR" == "db-cluster" ]]; then
  ok "db-headless selector: app=db-cluster"
else
  fail "db-headless selector app='$SELECTOR' (expected 'db-cluster')"
fi

# ── 4. Port 5432 exposed ─────────────────────────────────────────────────────
echo ""
echo "[ Check 4 ] Service exposes port 5432"
PORT=$(kubectl get service db-headless -n "$NS" \
  -o jsonpath='{.spec.ports[0].port}' 2>/dev/null || echo "0")
if [[ "$PORT" == "5432" ]]; then
  ok "db-headless exposes port 5432"
else
  fail "db-headless port is '$PORT' (expected 5432)"
fi

# ── 5. StatefulSet db-cluster exists ─────────────────────────────────────────
echo ""
echo "[ Check 5 ] StatefulSet db-cluster exists"
if kubectl get statefulset db-cluster -n "$NS" &>/dev/null; then
  ok "StatefulSet 'db-cluster' exists"
else
  fail "StatefulSet 'db-cluster' not found"
fi

# ── 6. StatefulSet has 3 ready replicas ──────────────────────────────────────
echo ""
echo "[ Check 6 ] StatefulSet has 3 ready replicas"
READY=$(kubectl get statefulset db-cluster -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
DESIRED=$(kubectl get statefulset db-cluster -n "$NS" \
  -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "3")
if [[ "$READY" == "3" && "$DESIRED" == "3" ]]; then
  ok "StatefulSet db-cluster: 3/3 replicas ready"
else
  fail "StatefulSet db-cluster: $READY/$DESIRED replicas ready (need 3/3)"
fi

# ── 7. StatefulSet serviceName matches db-headless ───────────────────────────
echo ""
echo "[ Check 7 ] StatefulSet serviceName is 'db-headless'"
SVC_NAME=$(kubectl get statefulset db-cluster -n "$NS" \
  -o jsonpath='{.spec.serviceName}' 2>/dev/null || echo "")
if [[ "$SVC_NAME" == "db-headless" ]]; then
  ok "StatefulSet serviceName: db-headless"
else
  fail "StatefulSet serviceName: '$SVC_NAME' (expected 'db-headless')"
fi

# ── 8. client pod is Running ─────────────────────────────────────────────────
echo ""
echo "[ Check 8 ] client pod is Running"
CLIENT_PHASE=$(kubectl get pod client -n "$NS" \
  -o jsonpath='{.status.phase}' 2>/dev/null || echo "Missing")
if [[ "$CLIENT_PHASE" == "Running" ]]; then
  ok "Pod 'client' is Running"
else
  fail "Pod 'client' phase: $CLIENT_PHASE (expected Running)"
fi

# ── 9. DNS returns multiple A records (headless behaviour) ───────────────────
echo ""
echo "[ Check 9 ] DNS returns individual pod IPs (not a single ClusterIP)"
# nslookup from the client pod; count lines with "Address:" (excluding the
# server line which is "Server: ..." / "Address: <dns-server>#53")
DNS_OUT=$(kubectl exec --request-timeout=5s client -n "$NS" -- \
  nslookup db-headless.ckaquest.svc.cluster.local 2>/dev/null || echo "")

# Count address lines that are NOT the DNS server itself (#53 port)
ADDR_COUNT=$(echo "$DNS_OUT" | grep "^Address:" | grep -v "#53" | wc -l | tr -d ' ')

if [[ "$ADDR_COUNT" -ge 2 ]]; then
  ok "DNS returned $ADDR_COUNT A records — headless mode confirmed"
elif [[ "$ADDR_COUNT" -eq 1 ]]; then
  # Could be a single pod started so far, but warn
  # Also check if it's a real ClusterIP (would only ever return 1)
  if echo "$DNS_OUT" | grep -q "^Address:" && [[ "$CLUSTER_IP" == "None" ]]; then
    ok "DNS returned 1 A record (pods may still be starting — headless confirmed by clusterIP=None)"
  else
    fail "DNS returned only 1 address and clusterIP is not None — Service is not headless"
  fi
else
  fail "DNS lookup failed or returned no addresses. Is client pod Running?"
fi

# ── Summary ──────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Results: $PASS passed, $FAIL failed"
echo "============================================"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "  ✓ Headless Service working! Each StatefulSet"
  echo "    pod has its own DNS A record."
  echo ""
  exit 0
else
  echo ""
  echo "  ✗ Some checks failed. Ensure db-headless"
  echo "    has clusterIP: None and 3 replicas are Ready."
  echo ""
  exit 1
fi
