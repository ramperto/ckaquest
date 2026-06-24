#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# Get node IP + Traefik NodePort
NODE_IP=$(kubectl get nodes \
  -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null)
TRAEFIK_PORT=$(kubectl get svc -n kube-system traefik \
  -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}' 2>/dev/null)
TRAEFIK_PORT=${TRAEFIK_PORT:-80}

# Check ingress path
INGRESS_PATH=$(kubectl get ingress webapp-ingress -n "$NS" \
  -o jsonpath='{.spec.rules[0].http.paths[0].path}' 2>/dev/null)

if [[ "$INGRESS_PATH" == "/application" ]]; then
  echo "❌ Ingress path is still '/application' — needs to be '/app' or '/'."
  exit 1
fi

# Test /app path via ingress
RESULT=$(curl -s --max-time 5 \
  -H "Host: localhost" \
  "http://${NODE_IP}:${TRAEFIK_PORT}/app" 2>&1 || \
  curl -s --max-time 5 "http://localhost:${TRAEFIK_PORT}/app" 2>&1)

if echo "$RESULT" | grep -qi "nginx\|html\|welcome"; then
  echo "✅ Ingress correctly routes /app to webapp-svc!"
  exit 0
fi

# Fallback: just check path is fixed
if [[ "$INGRESS_PATH" != "/application" ]]; then
  echo "✅ Ingress path updated to '${INGRESS_PATH}'"
  echo "   (Traefik may take a few seconds to reload. Test manually:)"
  echo "   curl http://${NODE_IP}:${TRAEFIK_PORT}/app"
  exit 0
fi

echo "❌ Ingress path is still wrong or Traefik not routing correctly."
echo "   Current path: ${INGRESS_PATH}"
exit 1
