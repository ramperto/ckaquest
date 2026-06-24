#!/bin/bash
# 1. Create the ConfigMap that will be "backed up"
kubectl create configmap app-secrets-backup \
  --from-literal=DB_HOST=postgres.prod.svc \
  --from-literal=DB_PORT=5432 \
  --from-literal=REDIS_URL=redis://cache.prod.svc:6379 \
  -n ckaquest --dry-run=client -o yaml | kubectl apply -f - 2>/dev/null

# 2. Create the etcd snapshot BEFORE deleting it
sudo mkdir -p /opt

echo "Creating etcd snapshot (this is the 'before deletion' state)..."
sudo k3s etcd-snapshot save --name pre-deletion-backup

SNAPSHOT=$(sudo ls -t /var/lib/rancher/k3s/server/db/snapshots/ | head -1)
sudo cp "/var/lib/rancher/k3s/server/db/snapshots/$SNAPSHOT" /opt/etcd-backup.db

echo "Snapshot saved to /opt/etcd-backup.db"

# 3. "Accidentally delete" the ConfigMap
sleep 2
kubectl delete configmap app-secrets-backup -n ckaquest --ignore-not-found=true

echo ""
echo "⚠️  app-secrets-backup has been deleted!"
echo "   Snapshot is at: /opt/etcd-backup.db"
echo "   Restore the cluster to recover it."
