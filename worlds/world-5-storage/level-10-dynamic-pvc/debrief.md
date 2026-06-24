# Debrief: Dynamic PVC — Provision Storage for a StatefulApp

## The complete storage picture

This level brought together everything from World 5:

```
StorageClass (local-path)
    ↓ triggers
local-path-provisioner
    ↓ creates
PersistentVolume (pvc-<uuid>, hostPath on node)
    ↑ bound to
PersistentVolumeClaim (app-db, 1Gi, RWO)
    ↑ mounted by
Pod via volumes[].persistentVolumeClaim.claimName
    ↑ exposed at
Container mountPath /data
```

## Full storage workflow on the CKA exam

When a question asks you to "create persistent storage for a pod":

```bash
# 1. Check what StorageClasses exist
kubectl get storageclass

# 2. Create the PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-pvc
  namespace: default
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 2Gi
EOF

# 3. Reference it in the pod/deployment
spec:
  volumes:
    - name: my-vol
      persistentVolumeClaim:
        claimName: my-pvc
  containers:
    - volumeMounts:
        - name: my-vol
          mountPath: /data
```

## Persistence verification

```bash
# Write data
kubectl exec <pod> -- sh -c "echo hello > /data/test.txt"

# Delete the pod (Deployment recreates it)
kubectl delete pod <pod>

# New pod — data should survive
kubectl exec <new-pod> -- cat /data/test.txt
# hello
```

This only works if the new pod is scheduled on the SAME node (for local-path
volumes). For multi-node clusters, use network storage (NFS, cloud disks) which
can be accessed from any node.

## PVC in a StatefulSet (advanced)

StatefulSets have `volumeClaimTemplates` — each pod gets its own PVC:

```yaml
apiVersion: apps/v1
kind: StatefulSet
spec:
  replicas: 3
  volumeClaimTemplates:
    - metadata:
        name: data
      spec:
        accessModes: [ReadWriteOnce]
        resources:
          requests:
            storage: 5Gi
```

This creates: `data-pod-0`, `data-pod-1`, `data-pod-2` PVCs automatically.
Each pod mounts its own dedicated PVC — perfect for database clusters.

## Storage summary table

| Scenario | Solution |
|----------|----------|
| Temporary scratch space | `emptyDir` |
| Node-local persistent data | `hostPath` or `local-path` StorageClass |
| Shared config/secrets | `configMap` or `secret` volume |
| Multi-container data sharing | `emptyDir` with same mountPath |
| Single-pod persistent DB | Dynamic PVC (RWO) |
| Shared NFS data | Static PVC (RWX) |
| StatefulSet per-pod storage | `volumeClaimTemplates` |

## CKA exam tip

Storage questions are usually one of:
1. Create a PVC + mount it in a pod (this level)
2. Fix a Pending PVC (levels 01-03)
3. Fix a Released PV (level 04)
4. Fix a wrong mountPath (level 05)
5. Create a StorageClass (know the YAML structure)

Practice creating PVCs imperatively — it's faster on the exam than writing YAML.

## Interview question

**Q: What happens to a PVC and its data when the associated pod is deleted?**

A: When a pod is deleted, the PVC and PV are NOT deleted — they are separate
objects with independent lifecycles. The data persists until the PVC itself is
deleted. If the pod's Deployment or StatefulSet recreates the pod, the new pod
can bind to the same PVC (if the volume supports it) and access the same data.
This is the fundamental difference between persistent volumes and ephemeral
storage like emptyDir.
