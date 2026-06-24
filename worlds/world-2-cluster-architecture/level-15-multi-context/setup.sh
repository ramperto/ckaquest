#!/bin/bash
# Setup for Level 15: Multi-Context Kubeconfig
# Backs up the real kubeconfig and creates a merged one with multiple contexts.
# The current-context is set to "production" which points to an unreachable server.

# Backup real kubeconfig
cp ~/.kube/config ~/.kube/config.ckaquest-backup 2>/dev/null || true

# Extract real cluster details
REAL_SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')
REAL_CA=$(kubectl config view --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')
REAL_CERT=$(kubectl config view --raw -o jsonpath='{.users[0].user.client-certificate-data}')
REAL_KEY=$(kubectl config view --raw -o jsonpath='{.users[0].user.client-key-data}')

cat > ~/.kube/config <<EOF
apiVersion: v1
kind: Config
clusters:
  - name: production
    cluster:
      server: https://10.255.255.1:6443
      certificate-authority-data: ${REAL_CA}
  - name: staging
    cluster:
      server: https://10.255.255.2:6443
      certificate-authority-data: ${REAL_CA}
  - name: local-k3s
    cluster:
      server: ${REAL_SERVER}
      certificate-authority-data: ${REAL_CA}
contexts:
  - name: production
    context:
      cluster: production
      user: admin
  - name: staging
    context:
      cluster: staging
      user: admin
  - name: local-k3s
    context:
      cluster: local-k3s
      user: local-admin
current-context: production
users:
  - name: admin
    user:
      client-certificate-data: ${REAL_CERT}
      client-key-data: ${REAL_KEY}
  - name: local-admin
    user:
      client-certificate-data: ${REAL_CERT}
      client-key-data: ${REAL_KEY}
EOF

echo "Kubeconfig modified. Current context set to 'production' (unreachable)."
echo "Original config backed up to ~/.kube/config.ckaquest-backup"
