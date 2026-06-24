#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Check the TLS secret exists with correct type and keys
SECRET=$(kubectl get secret webapp-tls -n "$NS" \
  -o jsonpath='{.type}' 2>/dev/null)

if [[ -z "$SECRET" ]]; then
  echo "❌ Secret 'webapp-tls' does not exist in namespace '$NS'."
  echo ""
  echo "💡 Create it:"
  echo "   openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\"
  echo "     -keyout /tmp/webapp.key -out /tmp/webapp.crt \\"
  echo "     -subj '/CN=webapp.local'"
  echo "   kubectl create secret tls webapp-tls \\"
  echo "     --cert=/tmp/webapp.crt --key=/tmp/webapp.key -n $NS"
  exit 1
fi

if [[ "$SECRET" != "kubernetes.io/tls" ]]; then
  echo "❌ Secret 'webapp-tls' exists but has wrong type: $SECRET"
  echo "   Expected: kubernetes.io/tls"
  echo "   Recreate with: kubectl create secret tls webapp-tls ..."
  exit 1
fi

# Verify both tls.crt and tls.key are present
CRT=$(kubectl get secret webapp-tls -n "$NS" \
  -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
KEY=$(kubectl get secret webapp-tls -n "$NS" \
  -o jsonpath='{.data.tls\.key}' 2>/dev/null)

if [[ -n "$CRT" && -n "$KEY" ]]; then
  echo "✅ TLS Secret 'webapp-tls' created with correct type and keys!"
  echo "   The Ingress controller will now use this certificate for webapp.local"
  exit 0
fi

echo "❌ Secret exists but is missing tls.crt or tls.key"
exit 1
