# Level 15 Debrief: StorageClass Reclaim Policy

## What Happened

The Deployment `db-app` stored critical data on a PVC backed by StorageClass
`delete-sc` (reclaimPolicy: Delete). If the PVC were deleted, the PV and all
data would be permanently destroyed. We created a new StorageClass `retain-sc`
with reclaimPolicy: Retain, provisioned a new PVC `safe-data`, and migrated
the Deployment to use the safer storage.

## Reclaim Policies Deep Dive

### The Three Reclaim Policies

| Policy | What Happens When PVC is Deleted | Data Fate | Use Case |
|--------|--------------------------------|-----------|----------|
| **Delete** | PV is deleted, underlying storage is removed | Data is permanently lost | Dev/test, ephemeral workloads |
| **Retain** | PV is kept with status "Released", data preserved | Data is safe, must manually reclaim | Production, databases, critical data |
| **Recycle** | PV is scrubbed (`rm -rf /thevolume/*`) and made Available | Data is erased but PV is reusable | **Deprecated** -- do not use |

### Reclaim Policy Lifecycle

```
PVC Bound to PV
     |
     | (PVC deleted)
     v
  +------------------+
  | reclaimPolicy?   |
  +------------------+
      |         |         |
   Delete    Retain    Recycle
      |         |         |
      v         v         v
  PV deleted  PV status  PV scrubbed
  Storage     "Released"  PV status
  removed     Data safe   "Available"
```

### Where Reclaim Policy is Set

The reclaim policy can be set in two places:

1. **StorageClass** -- applies to all dynamically provisioned PVs:
   ```yaml
   apiVersion: storage.k8s.io/v1
   kind: StorageClass
   metadata:
     name: retain-sc
   provisioner: rancher.io/local-path
   reclaimPolicy: Retain
   ```

2. **PersistentVolume** -- can be changed on individual PVs:
   ```yaml
   apiVersion: v1
   kind: PersistentVolume
   metadata:
     name: my-pv
   spec:
     persistentVolumeReclaimPolicy: Retain
   ```

### Changing a PV's Reclaim Policy

You can change an existing PV's reclaim policy without affecting the StorageClass:

```bash
# Change a single PV to Retain
kubectl patch pv <pv-name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'
```

This is useful when you have an existing PV with Delete policy that now contains
critical data you want to protect.

### Reclaiming a Released PV

When a PVC is deleted and the PV has Retain policy, the PV enters "Released"
state. To reuse it:

```bash
# 1. Check the released PV
kubectl get pv <pv-name>
# STATUS: Released

# 2. Remove the claimRef to make it Available again
kubectl patch pv <pv-name> -p '{"spec":{"claimRef": null}}'
# STATUS: Available

# 3. Now a new PVC can bind to it
```

### Migration Strategy (Production)

In a real production scenario, migrating data between PVCs involves:

| Step | Action |
|------|--------|
| 1 | Create new StorageClass with Retain policy |
| 2 | Create new PVC with the new StorageClass |
| 3 | Create a temporary pod that mounts both old and new PVCs |
| 4 | Copy data: `cp -a /old-mount/* /new-mount/` |
| 5 | Update Deployment to use new PVC |
| 6 | Verify application works with new storage |
| 7 | Delete old PVC when confirmed |

### Default StorageClass Reclaim Policy

Most cloud StorageClasses default to `Delete`:

| Provider | Default SC | Default Reclaim |
|----------|-----------|-----------------|
| AWS EKS | gp2 | Delete |
| GKE | standard | Delete |
| AKS | default | Delete |
| k3s | local-path | Delete |

This is why it is critical to explicitly set Retain for production workloads.

### Common Commands

```bash
# Check StorageClass reclaim policy
kubectl get storageclass <name> -o jsonpath='{.reclaimPolicy}'

# Check PV reclaim policy
kubectl get pv <name> -o jsonpath='{.spec.persistentVolumeReclaimPolicy}'

# Change PV reclaim policy
kubectl patch pv <name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

# List all PVs and their reclaim policies
kubectl get pv -o custom-columns=NAME:.metadata.name,RECLAIM:.spec.persistentVolumeReclaimPolicy,STATUS:.status.phase

# Find PVCs using a specific StorageClass
kubectl get pvc -A -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name,SC:.spec.storageClassName
```

## CKA Exam Tips

- **Production data should always use Retain** -- this is a best practice question favorite
- **You cannot change a StorageClass reclaim policy retroactively** for existing PVs;
  change the PV directly with `kubectl patch pv`
- **Know the difference between StorageClass `reclaimPolicy` and PV
  `persistentVolumeReclaimPolicy`** -- same concept, different field names
- **Released PVs need `claimRef` removed** to become Available again
- **Recycle is deprecated** -- if you see it on the exam, know it exists but
  recommend Retain or Delete instead

## Common Interview Questions

**Q: What happens to data when a PVC with Delete reclaim policy is deleted?**
A: The PV is automatically deleted by the PV controller, and the underlying
storage (e.g., EBS volume, GCE disk) is removed by the provisioner. All data
is permanently lost and cannot be recovered.

**Q: How do you protect existing PVs that were created with Delete policy?**
A: Patch each PV individually: `kubectl patch pv <name> -p
'{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'`. This overrides the
StorageClass default for that specific PV.

**Q: What is the difference between Retain and Recycle?**
A: Retain keeps the PV and its data intact when the PVC is deleted -- an admin
must manually reclaim it. Recycle (deprecated) scrubs the volume with `rm -rf`
and makes it Available for a new PVC. Retain is the recommended approach for
data safety; Recycle has been deprecated since Kubernetes 1.15.

**Q: Can you change a StorageClass from Delete to Retain?**
A: You can edit the StorageClass, but the change only affects newly provisioned
PVs. Existing PVs retain their original reclaim policy. To protect existing
PVs, patch them directly.
