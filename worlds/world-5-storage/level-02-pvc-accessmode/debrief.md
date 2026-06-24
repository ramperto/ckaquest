# Debrief: PVC — Access Mode Mismatch

## Access mode matching rule

A PVC's `accessModes` must be a **subset** of the PV's `accessModes`.

```
PV:  [ReadWriteOnce, ReadOnlyMany]
PVC: [ReadWriteOnce]   → OK (subset)
PVC: [ReadOnlyMany]    → OK (subset)
PVC: [ReadWriteMany]   → FAIL (not in PV's list)
```

## Access modes table

| Mode | Abbr | Meaning |
|------|------|---------|
| `ReadWriteOnce` | RWO | Single node, read-write |
| `ReadOnlyMany`  | ROX | Multiple nodes, read-only |
| `ReadWriteMany` | RWX | Multiple nodes, read-write |
| `ReadWriteOncePod` | RWOP | Single pod, read-write (k8s 1.22+) |

## Which volume types support which modes?

| Volume type | RWO | ROX | RWX |
|-------------|-----|-----|-----|
| hostPath | ✓ | – | – |
| local | ✓ | – | – |
| NFS | ✓ | ✓ | ✓ |
| CephFS | ✓ | ✓ | ✓ |
| AWS EBS | ✓ | – | – |
| Azure Disk | ✓ | – | – |
| Azure File | ✓ | ✓ | ✓ |

## CKA exam tip

Access mode mismatches always keep the PVC Pending.
`kubectl describe pvc <name>` will say something like:
```
no persistent volumes available for this claim
```
Or you can directly compare:
```bash
kubectl get pv <name> -o jsonpath='{.spec.accessModes}'
kubectl get pvc <name> -o jsonpath='{.spec.accessModes}'
```
