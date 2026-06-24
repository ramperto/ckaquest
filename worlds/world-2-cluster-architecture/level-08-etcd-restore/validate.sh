#!/bin/bash
NS="${NAMESPACE:-ckaquest}"

# First verify the cluster is responsive
if ! kubectl get nodes &>/dev/null 2>&1; then
  echo "❌ Cluster is not responding. Is k3s running?"
  echo "   sudo systemctl status k3s"
  echo "   sudo systemctl start k3s"
  exit 1
fi

# Check the ConfigMap was restored
CM=$(kubectl get configmap app-secrets-backup -n "$NS" \
  --ignore-not-found -o name 2>/dev/null)

if [[ -n "$CM" ]]; then
  DB_HOST=$(kubectl get configmap app-secrets-backup -n "$NS" \
    -o jsonpath='{.data.DB_HOST}' 2>/dev/null)
  echo "✅ ConfigMap 'app-secrets-backup' restored successfully!"
  echo "   DB_HOST: $DB_HOST"
  exit 0
fi

echo "❌ ConfigMap 'app-secrets-backup' not found in namespace '$NS'."
echo ""
echo "💡 The restore may not have been performed yet, or the cluster"
echo "   may still be starting. Try:"
echo "   kubectl get nodes  (cluster should be Ready)"
echo "   kubectl get configmap -n $NS"
exit 1
