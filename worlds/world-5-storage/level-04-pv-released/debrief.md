# Debrief: PV — Recycle a Released Volume

## PV lifecycle

```
Available → Bound → Released → (Deleted or Available again)
```

| State | Meaning |
|-------|---------|
| `Available` | Ready to be claimed |
| `Bound` | Bound to a PVC |
| `Released` | PVC deleted; data retained (Retain policy) |
| `Failed` | Volume failed reclamation |

## Reclaim policies

| Policy | On PVC deletion |
|--------|-----------------|
| `Retain` | PV becomes Released; data preserved; manual cleanup required |
| `Delete` | PV and underlying storage deleted automatically |
| `Recycle` | (deprecated) Basic scrub then returns to Available |

**Retain** is safest for production — you won't lose data accidentally.
**Delete** is convenient for cloud disks — auto-cleanup but irreversible.

## Recycling a Retained PV

When a PVC is deleted and the PV policy is Retain:
1. PV enters `Released` state
2. `spec.claimRef` still points to the deleted PVC
3. No new PVC can claim it until the claimRef is removed

**Fix:**
```bash
kubectl patch pv <name> --type=json \
  -p='[{"op":"remove","path":"/spec/claimRef"}]'
```

This JSON Patch removes the `claimRef` field, resetting PV to `Available`.

## Why not just edit it?

`kubectl edit pv <name>` works too — find and delete the `claimRef:` section.
The patch command is faster and scriptable (useful in automation).

## Changing reclaim policy

```bash
kubectl patch pv <name> -p '{"spec":{"persistentVolumeReclaimPolicy":"Delete"}}'
```

Or at creation:
```yaml
spec:
  persistentVolumeReclaimPolicy: Retain   # or Delete
```

## CKA exam tip

Know the three reclaim policies and what happens when a PVC is deleted under each.
The `kubectl patch pv --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'`
command for recycling Released PVs is CKA-exam material.

## Interview question

**Q: A PV is in Released state. How do you make it available for a new PVC?**

A: Remove the `spec.claimRef` field with a JSON Patch:
`kubectl patch pv <name> --type=json -p='[{"op":"remove","path":"/spec/claimRef"}]'`
This resets the PV to Available, allowing a new PVC to bind to it.
Note: this only applies to PVs with `persistentVolumeReclaimPolicy: Retain`.
With `Delete` policy, the PV and its storage are automatically removed when the PVC is deleted.
