#!/bin/bash

# Check CoreDNS ConfigMap has a stub zone for internal.corp
COREFILE=$(kubectl get configmap coredns -n kube-system \
  -o jsonpath='{.data.Corefile}' 2>/dev/null)

if echo "$COREFILE" | grep -q "internal.corp"; then
  if echo "$COREFILE" | grep -q "10.0.0.53"; then
    echo "✅ CoreDNS stub zone for 'internal.corp' → 10.0.0.53 found!"

    # Check CoreDNS pods are running/reloaded
    RUNNING=$(kubectl get pods -n kube-system -l k8s-app=kube-dns \
      --field-selector=status.phase=Running \
      --no-headers 2>/dev/null | wc -l)
    echo "   CoreDNS pods running: $RUNNING"
    exit 0
  else
    echo "❌ Stub zone for 'internal.corp' found but wrong upstream IP."
    echo "   Expected: 10.0.0.53"
    echo "   Current config:"
    echo "$COREFILE" | grep -A3 "internal.corp"
    exit 1
  fi
fi

echo "❌ No stub zone for 'internal.corp' found in CoreDNS config."
echo ""
echo "💡 Edit: kubectl edit configmap coredns -n kube-system"
echo "   Add a block BEFORE the main .:53 section:"
echo ""
echo '   internal.corp:53 {'
echo '       errors'
echo '       cache 30'
echo '       forward . 10.0.0.53'
echo '   }'
echo ""
echo "   Then restart: kubectl rollout restart deployment coredns -n kube-system"
exit 1
