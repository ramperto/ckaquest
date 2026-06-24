# Debrief: PVC — Wrong StorageClass Name

## StorageClass in PV/PVC binding

`storageClassName` acts as a **label** that groups PVs and PVCs together.
A PVC with `storageClassName: X` can only bind to a PV with `storageClassName: X`.

```
PV:  storageClassName: standard
PVC: storageClassName: fast-ssd   → no match → Pending forever
PVC: storageClassName: standard   → matches → Bound
```

## Three special cases

```yaml
# 1. Both empty string — static provisioning, bypasses default StorageClass
storageClassName: ""

# 2. Field omitted — uses the cluster's default StorageClass (dynamic provisioning)
# (no storageClassName field at all)

# 3. Explicit name — must match a PV or a dynamic provisioner
storageClassName: local-path
```

## Listing StorageClasses

```bash
kubectl get storageclass
# NAME              PROVISIONER             DEFAULT
# local-path        rancher.io/local-path   (default)
# standard          kubernetes.io/no-provisioner
```

`(default)` means PVCs with no `storageClassName` field will use this class.

## Static vs dynamic provisioning

**Static**: Admin pre-creates PVs. PVC binds to a matching PV.
```yaml
# Admin creates:
kind: PersistentVolume
spec:
  storageClassName: manual
  capacity: {storage: 10Gi}

# User creates:
kind: PersistentVolumeClaim
spec:
  storageClassName: manual
  resources: {requests: {storage: 5Gi}}
```

**Dynamic**: StorageClass has a provisioner that creates PVs on demand.
```yaml
kind: PersistentVolumeClaim
spec:
  storageClassName: local-path   # provisioner creates PV automatically
  resources: {requests: {storage: 5Gi}}
```

## CKA exam tip

When a PVC is Pending and you see no matching PV:
1. `kubectl get storageclass` — does the requested class exist?
2. `kubectl get pv` — any PV with matching storageClassName?
3. If neither: wrong class name or missing provisioner.
