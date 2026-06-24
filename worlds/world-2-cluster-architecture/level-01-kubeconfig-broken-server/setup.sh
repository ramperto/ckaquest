#!/bin/bash
# Break the kubeconfig by pointing the server to a wrong port
# First, save the original so the student (and validate.sh) can restore it

KUBECONFIG_FILE="$HOME/.kube/config"
BACKUP_FILE="$HOME/.kube/config.ckaquest-backup"

# Save a clean backup if it doesn't already exist
if [[ ! -f "$BACKUP_FILE" ]]; then
  cp "$KUBECONFIG_FILE" "$BACKUP_FILE"
fi

# Get current server URL to know the right address
CORRECT_SERVER=$(kubectl config view -o jsonpath='{.clusters[0].cluster.server}')

# Inject a broken server address (wrong port)
CLUSTER_NAME=$(kubectl config view -o jsonpath='{.clusters[0].name}')
kubectl config set-cluster "$CLUSTER_NAME" --server="https://127.0.0.1:9999"

echo "kubeconfig broken — server set to wrong port."
echo "Correct server: $CORRECT_SERVER  (saved to $BACKUP_FILE)"
