# Debrief: etcd Restore — Recover Lost Data

## What happened?

A ConfigMap was deleted (simulating accidental deletion or data corruption).
An etcd snapshot taken before the deletion contained the ConfigMap. Restoring
from the snapshot rolled the entire cluster state back to that point.

## etcd restore on the CKA exam (kubeadm)

```bash
# 1. Stop control plane (static pods)
sudo systemctl stop kubelet

# 2. Move old etcd data
sudo mv /var/lib/etcd /var/lib/etcd.OLD

# 3. Restore snapshot to a new data directory
ETCDCTL_API=3 etcdctl snapshot restore /opt/etcd-backup.db \
  --data-dir=/var/lib/etcd \
  --name=$(hostname) \
  --initial-cluster=$(hostname)=https://127.0.0.1:2380 \
  --initial-advertise-peer-urls=https://127.0.0.1:2380

# 4. Fix ownership
sudo chown -R etcd:etcd /var/lib/etcd

# 5. Restart kubelet (triggers static pod restart including etcd)
sudo systemctl start kubelet
```

## etcd restore on k3s

```bash
sudo systemctl stop k3s
sudo k3s server --cluster-reset --cluster-reset-restore-path=/opt/etcd-backup.db
# (wait for completion, then Ctrl+C)
sudo systemctl start k3s
```

## Important: restore rolls back ALL state

Restoring etcd brings back state from the snapshot moment. Any resources
created after the snapshot was taken are GONE. Plan accordingly:
- Take snapshot → do risky operation → if fails, restore
- This is exactly the pre-upgrade workflow

## CKA exam tip

The etcd restore question on the CKA exam typically provides:
1. A snapshot file path
2. A target data directory
3. You must update the etcd static pod manifest to use the new data directory

Read the question carefully — it will specify the exact `--data-dir` to use.

## Interview question

**Q: What's the difference between an etcd snapshot and a full cluster backup?**

A: An etcd snapshot captures all Kubernetes API objects (pods, services,
secrets, etc.). What it does NOT capture: the contents of PersistentVolumes
(actual application data stored on disk). For a complete disaster recovery
plan, you need etcd backups AND persistent volume backups (e.g., Velero).
