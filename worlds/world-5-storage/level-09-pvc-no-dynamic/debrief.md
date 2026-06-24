# Debrief: PVC — Disabled Dynamic Provisioning

## The three storageClassName states

| YAML | Meaning |
|------|---------|
| `storageClassName: "fast-ssd"` | Use StorageClass named `fast-ssd` |
| `storageClassName: ""` | Static only — bind to a PV with no class |
| *(field omitted)* | Use the cluster's **default** StorageClass |

This is a subtle but critical distinction. `""` and *(omitted)* behave very
differently — one disables dynamic provisioning, one enables it.

## Default StorageClass

```bash
kubectl get storageclass
# NAME              PROVISIONER                    DEFAULT
# local-path        rancher.io/local-path          (default)
```

The `(default)` annotation means PVCs without a `storageClassName` field
automatically use this class. On k3s it's `local-path`. On kubeadm/EKS/GKE
it will be different.

Mark a StorageClass as default:
```bash
kubectl patch storageclass local-path \
  -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

## Dynamic provisioning flow

```
1. PVC created (no storageClassName → uses default)
2. kube-controller-manager sees new PVC
3. Calls the provisioner (e.g., local-path-provisioner)
4. Provisioner creates a directory on the node, creates a PV
5. PV is automatically bound to the PVC
6. PVC status: Pending → Bound (seconds)
```

## Static vs dynamic — when to use each

**Static provisioning** (create PV manually):
- Custom storage hardware with specific configurations
- Cloud volumes not supported by a provisioner
- When you need precise control over which physical storage is used

**Dynamic provisioning** (let StorageClass create PV):
- Cloud environments (AWS EBS, GCP PD, Azure Disk)
- k3s with local-path (dev/test)
- Simpler operations — no manual PV management

## StorageClass parameters

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: fast
provisioner: kubernetes.io/aws-ebs
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer   # or Immediate
allowVolumeExpansion: true
```

`WaitForFirstConsumer` delays PV creation until a pod is scheduled —
ensures the PV is created in the same AZ as the pod.

## CKA exam tip

When creating a PVC for dynamic provisioning, omit `storageClassName`
entirely (or explicitly set it to the default class name). Setting it
to `""` is almost always a bug on modern clusters.

```bash
# Quick dynamic PVC
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
      storage: 5Gi
EOF
```

## Interview question

**Q: What is the difference between storageClassName: "" and omitting storageClassName?**

A: `storageClassName: ""` explicitly requests static binding — the PVC will
only bind to a manually created PV that also has no StorageClass (empty string).
Omitting `storageClassName` activates the cluster's default StorageClass,
triggering dynamic provisioning where a provisioner automatically creates a PV.
This is one of the most common PVC misconfiguration mistakes in Kubernetes.
