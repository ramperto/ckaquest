#!/bin/bash
NS="${NAMESPACE:-ckaquest}"
PASS=0
FAIL=0

# Check 1: Secret app-tls exists and is type kubernetes.io/tls
SECRET_TYPE=$(kubectl get secret app-tls -n "$NS" \
  -o jsonpath='{.type}' 2>/dev/null)
if [[ "$SECRET_TYPE" == "kubernetes.io/tls" ]]; then
  echo "PASS: Secret 'app-tls' exists and is type kubernetes.io/tls."
  ((PASS++))
else
  echo "FAIL: Secret 'app-tls' not found or wrong type (type: ${SECRET_TYPE:-Not Found})."
  ((FAIL++))
fi

# Check 2: Certificate CN or SAN contains app.example.com
CERT_DATA=$(kubectl get secret app-tls -n "$NS" \
  -o jsonpath='{.data.tls\.crt}' 2>/dev/null)
if [[ -n "$CERT_DATA" ]]; then
  CERT_SUBJECT=$(echo "$CERT_DATA" | base64 -d | openssl x509 -noout -subject 2>/dev/null)
  CERT_SAN=$(echo "$CERT_DATA" | base64 -d | openssl x509 -noout -ext subjectAltName 2>/dev/null)

  if echo "$CERT_SUBJECT $CERT_SAN" | grep -q "app.example.com"; then
    echo "PASS: Certificate contains 'app.example.com'."
    echo "  Subject: $CERT_SUBJECT"
    ((PASS++))
  else
    echo "FAIL: Certificate does not contain 'app.example.com'."
    echo "  Current subject: $CERT_SUBJECT"
    echo "  Regenerate with correct CN: openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt -subj '/CN=app.example.com'"
    ((FAIL++))
  fi
else
  echo "FAIL: Could not read certificate data from secret."
  ((FAIL++))
fi

# Check 3: Deployment tls-app is Running
READY=$(kubectl get deployment tls-app -n "$NS" \
  -o jsonpath='{.status.readyReplicas}' 2>/dev/null)
if [[ "$READY" -ge 1 ]] 2>/dev/null; then
  echo "PASS: Deployment 'tls-app' has $READY ready replica(s)."
  ((PASS++))
else
  echo "FAIL: Deployment 'tls-app' has no ready replicas (ready: ${READY:-0})."
  ((FAIL++))
fi

echo ""
if [[ $FAIL -eq 0 ]]; then
  echo "Level 19 complete! All $PASS checks passed. TLS certificate fixed."
  exit 0
else
  echo "$PASS passed, $FAIL failed."
  exit 1
fi
