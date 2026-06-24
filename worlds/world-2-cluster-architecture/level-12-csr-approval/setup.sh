#!/bin/bash
# Setup for Level 12: CSR Approval
# Generate a key and CSR for dev-user, then submit to Kubernetes

NS="${NAMESPACE:-ckaquest}"

# Generate a private key and CSR for dev-user
openssl genrsa -out /tmp/dev-user.key 2048 2>/dev/null
openssl req -new -key /tmp/dev-user.key -out /tmp/dev-user.csr -subj '/CN=dev-user/O=developers' 2>/dev/null

# Submit CSR to Kubernetes
CSR_CONTENT=$(cat /tmp/dev-user.csr | base64 | tr -d '\n')
cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: dev-user-csr
spec:
  request: ${CSR_CONTENT}
  signerName: kubernetes.io/kube-apiserver-client
  usages:
    - client auth
EOF

echo "CSR dev-user-csr submitted and waiting for approval."
