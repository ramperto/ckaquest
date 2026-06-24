#!/bin/bash
# Add a broken context and set it as current-context

KUBECONFIG_FILE="$HOME/.kube/config"
BACKUP_FILE="$HOME/.kube/config.ckaquest-backup"

# Save backup
if [[ ! -f "$BACKUP_FILE" ]]; then
  cp "$KUBECONFIG_FILE" "$BACKUP_FILE"
fi

# Add a fake broken context
kubectl config set-credentials broken-user \
  --client-certificate=/nonexistent/cert.crt \
  --client-key=/nonexistent/key.key 2>/dev/null || true

kubectl config set-context broken-context \
  --cluster="$(kubectl config view -o jsonpath='{.clusters[0].name}')" \
  --user=broken-user \
  --namespace=broken-ns 2>/dev/null || true

# Switch to the broken context
kubectl config use-context broken-context

echo "Current context switched to 'broken-context'."
echo "Working context is 'default'."
