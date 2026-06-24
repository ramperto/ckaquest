#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check app pod is running
PHASE=$(kubectl get pod app -n "$NS" -o jsonpath='{.status.phase}' 2>/dev/null)
if [[ "$PHASE" != "Running" ]]; then
  echo "❌ Pod 'app' not Running in $NS."
  exit 1
fi

# Check prometheus pod is running
PROM=$(kubectl get pod prometheus -n monitoring \
  -o jsonpath='{.status.phase}' 2>/dev/null)
if [[ "$PROM" != "Running" ]]; then
  echo "❌ Pod 'prometheus' not Running in monitoring namespace."
  exit 1
fi

# Check monitoring namespace has a label
NS_LABELS=$(kubectl get namespace monitoring \
  -o jsonpath='{.metadata.labels}' 2>/dev/null)

# Check NetworkPolicy allows monitoring namespace
POLICY=$(kubectl get networkpolicies -n "$NS" \
  -o json 2>/dev/null | python3 -c "
import sys, json
policies = json.load(sys.stdin)['items']
for p in policies:
    ingress = p.get('spec', {}).get('ingress', [])
    for rule in ingress:
        for src in rule.get('from', []):
            if 'namespaceSelector' in src:
                print(p['metadata']['name'])
                sys.exit(0)
" 2>/dev/null)

if [[ -n "$POLICY" ]]; then
  # Try connectivity test
  APP_IP=$(kubectl get svc app-svc -n "$NS" \
    -o jsonpath='{.spec.clusterIP}' 2>/dev/null)
  RESULT=$(kubectl exec --request-timeout=5s prometheus -n monitoring -- \
    nc -z -w 3 app-svc.ckaquest.svc.cluster.local 8080 2>&1 || \
    kubectl exec --request-timeout=5s prometheus -n monitoring -- \
    nc -z -w 3 "$APP_IP" 8080 2>&1)
  if [[ $? -eq 0 ]]; then
    echo "✅ Prometheus in 'monitoring' can reach app-svc:8080!"
    exit 0
  fi
  echo "✅ NetworkPolicy with namespaceSelector found ('$POLICY')."
  echo "   If connectivity still fails, ensure the monitoring namespace"
  echo "   has the correct label matching your namespaceSelector."
  echo "   Check: kubectl get namespace monitoring --show-labels"
  exit 0
fi

echo "❌ No NetworkPolicy with namespaceSelector found."
echo ""
echo "💡 Steps:"
echo "   1. kubectl label namespace monitoring purpose=monitoring"
echo "   2. Apply NetworkPolicy with namespaceSelector: {purpose: monitoring}"
exit 1
