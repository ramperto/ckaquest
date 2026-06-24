#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Find a NodePort service for webapp with nodePort 30080
SVC=$(kubectl get svc -n "$NS" -o json 2>/dev/null | \
  python3 -c "
import sys, json
svcs = json.load(sys.stdin)['items']
for s in svcs:
    ports = s.get('spec', {}).get('ports', [])
    sel = s.get('spec', {}).get('selector', {})
    stype = s.get('spec', {}).get('type', '')
    for p in ports:
        if p.get('nodePort') == 30080 and sel.get('app') == 'webapp' and stype == 'NodePort':
            print(s['metadata']['name'])
" 2>/dev/null)

if [[ -z "$SVC" ]]; then
  echo "❌ No NodePort Service found for 'webapp' with nodePort 30080."
  echo ""
  echo "💡 Create one: kubectl expose deployment webapp --type=NodePort \\"
  echo "     --port=80 --target-port=80 --name=webapp-svc -n $NS"
  echo "   Then set nodePort: kubectl patch svc webapp-svc -n $NS \\"
  echo "     --type=json -p='[{\"op\":\"replace\",\"path\":\"/spec/ports/0/nodePort\",\"value\":30080}]'"
  exit 1
fi

# Test connectivity on the nodePort
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
RESULT=$(curl -s --max-time 5 "http://${NODE_IP}:30080" 2>&1)

if echo "$RESULT" | grep -qi "nginx\|html\|welcome"; then
  echo "✅ webapp is reachable via NodePort 30080! Service: $SVC"
  exit 0
fi

EP=$(kubectl get endpoints "$SVC" -n "$NS" \
  -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null)
if [[ -z "$EP" ]]; then
  echo "❌ Service '$SVC' has no endpoints — selector may not match pods."
else
  echo "❌ Service exists but curl to ${NODE_IP}:30080 failed."
  echo "   (May be a firewall rule — check if port 30080 is open on your VPS)"
fi
exit 1
