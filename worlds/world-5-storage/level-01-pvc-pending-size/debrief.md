# Debrief: PVC — Size Mismatch with Static PV

## PVC binding rules

A PVC binds to a PV only when ALL of these match:
1. `storageClassName` matches (or both empty)
2. `accessModes` — PVC modes must be a subset of PV modes
3. `resources.requests.storage` — PVC request must be **≤ PV capacity**
4. `labelSelector` (if set on PVC) must match PV labels
5. `volumeName` (if set on PVC) must name the specific PV

If any condition fails, the PVC stays Pending.

## PV capacity vs PVC request

```
PV capacity:  5Gi
PVC request: 10Gi → Pending (can't satisfy)

PV capacity:  5Gi
PVC request:  3Gi → Binds (3Gi ≤ 5Gi)
              But you "waste" 2Gi — PV is fully reserved
```

Kubernetes binds the smallest PV that satisfies the claim:
```
Available PVs: 2Gi, 5Gi, 10Gi
PVC request:   3Gi
→ Binds to 5Gi PV (smallest that fits)
```

## Diagnosing Pending PVCs

```bash
# Check all PVCs
kubectl get pvc -n ckaquest

# Why is it Pending?
kubectl describe pvc db-data -n ckaquest | grep -A5 "Events:"

# What PVs are available?
kubectl get pv
# Check CAPACITY, ACCESS MODES, STATUS, STORAGECLASS columns
```

Common `describe` messages:
- `no persistent volumes available for this claim and no storage class is set` → no matching PV + no dynamic provisioner
- `Insufficient capacity` → PVC too large for all available PVs
- `no node is available to host the volume` → topology constraint failure

## PVC spec is immutable (after creation)

Once a PVC is created, only `spec.resources.requests.storage` can be
increased (volume expansion) if the StorageClass allows it.
Everything else (accessModes, storageClassName) is frozen.

To change these: delete and recreate.

```bash
# Get existing PVC spec to reuse
kubectl get pvc db-data -n ckaquest -o yaml > /tmp/db-data.yaml
# Edit the size
kubectl delete pvc db-data -n ckaquest
kubectl apply -f /tmp/db-data.yaml
```

## Access modes reference

| Mode | Short | Meaning |
|------|-------|---------|
| ReadWriteOnce | RWO | One node can mount read-write |
| ReadOnlyMany | ROX | Many nodes can mount read-only |
| ReadWriteMany | RWX | Many nodes can mount read-write |
| ReadWriteOncePod | RWOP | One pod (not just node) can mount read-write |

`hostPath` and `local` volumes only support RWO.
NFS, CephFS, etc. support RWX.

## CKA exam tip

When you see a Pending PVC, always check in this order:
1. `kubectl get pv` — is there a matching PV?
2. `kubectl describe pvc` — what's the binding failure reason?
3. Compare PV and PVC: storageClassName, accessModes, capacity

## Interview question

**Q: A PVC has been Pending for 10 minutes. How do you diagnose it?**

A: Run `kubectl describe pvc <name>` and check the Events section for the
binding failure reason. Common causes: (1) no PV with matching storageClassName,
(2) no PV with sufficient capacity (PVC requests more than any available PV),
(3) accessModes mismatch (PVC wants RWX but only RWO PVs exist), (4) labelSelector
on the PVC that no PV satisfies, or (5) dynamic provisioner not running/configured
for the requested StorageClass.
