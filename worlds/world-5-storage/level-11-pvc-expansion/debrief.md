# Level 11 Debrief: PVC Expansion

## What Happened

The PVC `app-data` needed more storage (500Mi to 2Gi), but the StorageClass
`no-expand-sc` had `allowVolumeExpansion: false`, blocking the resize request.
The fix required two steps: patching the StorageClass, then expanding the PVC.

## PVC Expansion Deep Dive

### The allowVolumeExpansion Field

Every StorageClass has an optional field `allowVolumeExpansion`. When set to
`true`, PVCs using that StorageClass can be resized by editing the PVC's
`spec.resources.requests.storage` field.

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: expandable-sc
provisioner: kubernetes.io/aws-ebs
allowVolumeExpansion: true    # <-- this is the key
```

### Expansion Process

| Step | What Happens |
|------|-------------|
| 1. User edits PVC | `spec.resources.requests.storage` is increased |
| 2. Controller notices | The PV controller detects the size mismatch |
| 3. Volume plugin expands | The CSI driver or volume plugin resizes the underlying volume |
| 4. Kubelet resizes FS | On next pod mount, kubelet performs filesystem resize |
| 5. PVC updates | `status.capacity.storage` reflects the new size |

### Online vs Offline Expansion

| Type | Description | Supported By |
|------|-------------|-------------|
| Online | Resize while pod is running, no downtime | Most CSI drivers (EBS, GCE-PD, Azure Disk) |
| Offline | Requires pod deletion, PV detach, then resize | Older provisioners, some storage backends |

When offline expansion is needed, you will see the PVC condition:
```
type: FileSystemResizePending
message: Waiting for user to (re-)start a pod to finish file system resize
```

### Key Rules

1. **You can only grow a PVC, never shrink it**
2. **The StorageClass must have `allowVolumeExpansion: true`**
3. **You can patch the StorageClass at any time** -- it takes effect immediately
4. **The PVC edit triggers the resize** -- change `spec.resources.requests.storage`
5. **For filesystem-based PVs**, the kubelet performs the FS resize when the pod mounts

### Common Commands

```bash
# Check if a StorageClass supports expansion
kubectl get storageclass <name> -o jsonpath='{.allowVolumeExpansion}'

# Enable expansion on a StorageClass
kubectl patch storageclass <name> -p '{"allowVolumeExpansion": true}'

# Expand a PVC
kubectl patch pvc <name> -n <ns> \
  -p '{"spec":{"resources":{"requests":{"storage":"2Gi"}}}}'

# Check PVC resize status
kubectl get pvc <name> -n <ns> -o jsonpath='{.status.conditions}'
```

### PVC Expansion Conditions

After requesting expansion, the PVC may show conditions:

| Condition | Meaning |
|-----------|---------|
| `Resizing` | Volume plugin is resizing the underlying volume |
| `FileSystemResizePending` | Volume resized, waiting for pod to restart for FS resize |
| (none) | Expansion complete |

## CKA Exam Tips

- **Know `kubectl patch`** for StorageClass changes -- it is faster than editing YAML
- **PVC expansion is a two-step process**: enable on SC, then edit PVC
- **You cannot shrink a PVC** -- if asked on the exam, the answer is "not supported"
- **Check `allowVolumeExpansion`** on the StorageClass when a PVC resize fails
- **Remember**: the StorageClass can be patched without affecting existing PVCs until they are resized

## Common Interview Questions

**Q: Can you expand a PVC without downtime?**
A: Yes, if the CSI driver supports online expansion. Most modern cloud CSI
drivers (AWS EBS, GCE PD, Azure Disk) support online expansion. The kubelet
performs the filesystem resize on the next mount or while the pod is running.

**Q: What happens if you try to shrink a PVC?**
A: Kubernetes does not support PVC shrinking. The API server will reject the
request with a validation error. If you need less storage, create a new smaller
PVC and migrate data.

**Q: Can you change allowVolumeExpansion on an existing StorageClass?**
A: Yes. You can patch it at any time with `kubectl patch storageclass <name>
-p '{"allowVolumeExpansion": true}'`. The change applies to future expansion
requests for PVCs using that StorageClass.
