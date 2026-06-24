# Debrief: etcd Backup — Create a Snapshot

## What is etcd?

etcd is the distributed key-value store that holds all Kubernetes cluster state:
pods, services, configmaps, secrets, RBAC, everything. If etcd is lost,
the entire cluster configuration is gone. **Backup etcd = backup the cluster.**

## etcd backup on the CKA exam (kubeadm clusters)

```bash
# The exam provides cert paths — find them first:
kubectl -n kube-system describe pod etcd-<node> | grep -E "\-\-cert|\-\-key|\-\-trusted"

# Then create snapshot:
ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify:
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db --write-out=table
```

## Backup on k3s

```bash
# Method 1: k3s native
sudo k3s etcd-snapshot save --name my-backup
# Files at: /var/lib/rancher/k3s/server/db/snapshots/

# Method 2: etcdctl (with k3s cert paths)
ETCDCTL_API=3 etcdctl snapshot save /opt/etcd-backup.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/var/lib/rancher/k3s/server/tls/etcd/server-ca.crt \
  --cert=/var/lib/rancher/k3s/server/tls/etcd/server-client.crt \
  --key=/var/lib/rancher/k3s/server/tls/etcd/server-client.key
```

## etcd snapshot verification

```bash
ETCDCTL_API=3 etcdctl snapshot status /opt/etcd-backup.db --write-out=table
# Output:
# +----------+----------+------------+------------+
# |   HASH   | REVISION | TOTAL KEYS | TOTAL SIZE |
# +----------+----------+------------+------------+
# | 12ab34cd |     1234 |        456 |    4.2 MB  |
# +----------+----------+------------+------------+
```

## CKA exam tip

etcd backup/restore is almost always in the CKA exam. Memorize:
1. Find cert paths from etcd pod: `kubectl -n kube-system describe pod etcd-*`
2. `etcdctl snapshot save <path> --endpoints=... --cacert=... --cert=... --key=...`
3. Verify with `etcdctl snapshot status <path>`

`ETCDCTL_API=3` is required (etcdctl v3 API).

## Interview question

**Q: How frequently should etcd be backed up in production?**

A: Industry standard is every 30 minutes to 1 hour using a CronJob or
systemd timer. Many teams use Velero for cluster-level backups which
includes etcd. The backup frequency should match your RTO/RPO requirements.
For critical clusters, some teams do continuous backups using etcd's
built-in snapshotting integrated with object storage (e.g., S3).
