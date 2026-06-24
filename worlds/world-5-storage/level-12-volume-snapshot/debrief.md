# Level 12 Debrief: Volume Snapshots

## What Happened

The VolumeSnapshot `data-snapshot` referenced a VolumeSnapshotClass called
`csi-snap-class` that did not exist. Without the class, the snapshot controller
had no instructions for how to take the snapshot. Creating the missing
VolumeSnapshotClass resolved the issue.

## Volume Snapshots Deep Dive

### The Snapshot Trilogy

Volume snapshots follow the same pattern as PV/PVC/StorageClass:

| Storage Concept | Snapshot Equivalent | Purpose |
|----------------|--------------------|---------|
| StorageClass | VolumeSnapshotClass | Defines driver and deletion policy |
| PersistentVolumeClaim | VolumeSnapshot | User-facing request for a snapshot |
| PersistentVolume | VolumeSnapshotContent | The actual snapshot data reference |

### VolumeSnapshotClass

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotClass
metadata:
  name: csi-snap-class
driver: ebs.csi.aws.com          # Must match the CSI driver
deletionPolicy: Delete            # Delete or Retain
```

Key fields:
- **driver** -- must match the CSI driver provisioner for the volumes you want to snapshot
- **deletionPolicy** -- `Delete` removes the snapshot when VolumeSnapshot is deleted; `Retain` keeps it

### VolumeSnapshot

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: my-snapshot
  namespace: default
spec:
  volumeSnapshotClassName: csi-snap-class
  source:
    persistentVolumeClaimName: my-pvc    # PVC to snapshot
```

### VolumeSnapshotContent

Created automatically by the snapshot controller (dynamic provisioning) or
manually (pre-provisioned). This is the "PV" of snapshots -- it points to the
actual snapshot in the storage backend.

```yaml
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshotContent
metadata:
  name: snapcontent-xxx
spec:
  deletionPolicy: Delete
  driver: ebs.csi.aws.com
  source:
    snapshotHandle: snap-0123456789abcdef0   # Backend snapshot ID
  volumeSnapshotRef:
    name: my-snapshot
    namespace: default
```

### Restoring from a Snapshot

Create a PVC with `dataSource` pointing to the snapshot:

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: restored-pvc
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
  dataSource:
    name: my-snapshot
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
```

### Snapshot Workflow

```
PVC (source-data)
    |
    v
VolumeSnapshot (data-snapshot)  --->  VolumeSnapshotClass (csi-snap-class)
    |                                        |
    v                                        v
VolumeSnapshotContent (auto-created)    CSI Driver takes snapshot
    |
    v
PVC (restored-data, dataSource: data-snapshot)  <--- Restore
```

### Prerequisites

1. **CSI driver must support snapshots** -- not all drivers do
2. **Snapshot CRDs must be installed** -- these are not part of core Kubernetes
3. **Snapshot controller must be running** -- usually deployed as a sidecar or standalone
4. **VolumeSnapshotClass must exist** -- matching the CSI driver

### Common Commands

```bash
# List snapshot classes
kubectl get volumesnapshotclass

# List snapshots
kubectl get volumesnapshot -n <namespace>

# List snapshot contents
kubectl get volumesnapshotcontent

# Check snapshot status
kubectl describe volumesnapshot <name> -n <namespace>

# Check if snapshot CRDs are installed
kubectl get crd | grep snapshot
```

## CKA Exam Tips

- **Know the API group**: `snapshot.storage.k8s.io/v1`
- **VolumeSnapshotClass is cluster-scoped** (no namespace), while VolumeSnapshot is namespaced
- **The driver field** in VolumeSnapshotClass must match the CSI provisioner
- **dataSource** in a PVC is how you restore from a snapshot -- know the syntax
- **Snapshot CRDs are external** -- they are not installed by default in all clusters

## Common Interview Questions

**Q: How do you take a snapshot of a PVC in Kubernetes?**
A: Create a VolumeSnapshot resource that references the PVC in its
`spec.source.persistentVolumeClaimName`. The cluster must have the snapshot
CRDs installed, a snapshot controller running, and a VolumeSnapshotClass that
matches the CSI driver.

**Q: How do you restore a PVC from a snapshot?**
A: Create a new PVC with `spec.dataSource` pointing to the VolumeSnapshot.
Set `dataSource.kind: VolumeSnapshot`, `dataSource.apiGroup:
snapshot.storage.k8s.io`, and `dataSource.name` to the snapshot name.

**Q: What is the difference between VolumeSnapshot and VolumeSnapshotContent?**
A: VolumeSnapshot is the user-facing request (like PVC), namespaced and
managed by users. VolumeSnapshotContent is the cluster-level representation
of the actual snapshot data (like PV), typically managed by the snapshot
controller or administrator.
