#!/bin/bash
# Level 19 Setup: Generate a TLS cert with WRONG CN and create the secret
NS="${NAMESPACE:-ckaquest}"

# Ensure namespace exists
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f -

# Generate self-signed cert with WRONG CN
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /tmp/wrong-tls.key \
  -out /tmp/wrong-tls.crt \
  -subj '/CN=wrong.example.com' \
  2>/dev/null

# Delete existing secret if present
kubectl delete secret app-tls -n "$NS" --ignore-not-found

# Create TLS secret with the wrong cert
kubectl create secret tls app-tls \
  --cert=/tmp/wrong-tls.crt \
  --key=/tmp/wrong-tls.key \
  -n "$NS"

# Clean up temp files
rm -f /tmp/wrong-tls.key /tmp/wrong-tls.crt

echo "Setup complete: TLS secret 'app-tls' created with CN=wrong.example.com"
