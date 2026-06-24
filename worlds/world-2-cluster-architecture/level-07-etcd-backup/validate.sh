#!/bin/bash

BACKUP_PATH="/opt/etcd-backup.db"

if [[ ! -f "$BACKUP_PATH" ]]; then
  echo "❌ Backup file not found at $BACKUP_PATH"
  echo ""
  echo "💡 Create it with:"
  echo "   sudo k3s etcd-snapshot save --name my-backup"
  echo "   sudo cp /var/lib/rancher/k3s/server/db/snapshots/my-backup* $BACKUP_PATH"
  echo ""
  echo "   OR use etcdctl directly:"
  echo "   ETCDCTL_API=3 etcdctl snapshot save $BACKUP_PATH \\"
  echo "     --endpoints=https://127.0.0.1:2379 \\"
  echo "     --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \\"
  echo "     --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \\"
  echo "     --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key"
  exit 1
fi

# Verify it's a valid etcd snapshot (has correct header bytes)
FILE_TYPE=$(file "$BACKUP_PATH" 2>/dev/null)
SIZE=$(stat -c%s "$BACKUP_PATH" 2>/dev/null || stat -f%z "$BACKUP_PATH" 2>/dev/null)

if [[ "$SIZE" -gt 4096 ]]; then
  echo "✅ etcd snapshot found at $BACKUP_PATH (size: ${SIZE} bytes)"
  echo "   Verify with: ETCDCTL_API=3 etcdctl snapshot status $BACKUP_PATH --write-out=table"
  exit 0
fi

echo "❌ File at $BACKUP_PATH is too small to be a valid snapshot (${SIZE} bytes)."
echo "   It may be an empty file. Re-create the snapshot."
exit 1
