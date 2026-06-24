# Level 20 Debrief: Ephemeral Storage Requests

## What Happened

The pod `storage-hog` requested `500Gi` of ephemeral storage — half a terabyte. No
node in the cluster had that much available disk space for ephemeral use, so the
scheduler couldn't place the pod anywhere. It remained Pending with the event message
"Insufficient ephemeral-storage".

The fix was simple: change `500Gi` to `500Mi` (a classic unit typo) and recreate the pod.

## Ephemeral Storage in Kubernetes

Ephemeral storage is the temporary disk space used by pods on the node's filesystem.
It includes:

- Container writable layers (anything written inside the container)
- Log files
- `emptyDir` volumes (unless backed by memory)
- Container image layers (pulled images)

### How It Maps to Node Disk

Ephemeral storage comes from the node's root filesystem (typically `/var/lib/kubelet`
and `/var/lib/containers`). The kubelet tracks usage and reports allocatable
ephemeral storage.

```bash
# Check node's allocatable ephemeral storage
kubectl describe node <name> | grep -A5 "Allocatable"
```

### Requests vs Limits

| Field | Behavior |
|-------|----------|
| `requests.ephemeral-storage` | Used for scheduling — pod won't be placed if node can't satisfy |
| `limits.ephemeral-storage` | Enforced at runtime — pod is evicted if it exceeds the limit |

```yaml
resources:
  requests:
    ephemeral-storage: 500Mi    # scheduling guarantee
  limits:
    ephemeral-storage: 1Gi      # hard cap — evicted if exceeded
```

### Eviction Behavior

When a pod exceeds its ephemeral storage limit, the kubelet **evicts** it:

1. Kubelet monitors disk usage periodically
2. If a pod's total ephemeral usage exceeds its limit, the pod is evicted
3. The eviction is immediate — no grace period for ephemeral storage
4. The pod status will show `Evicted` with reason `EphemeralStorageLimitExceeded`

### Eviction Thresholds

The kubelet also has node-level eviction thresholds:

```
--eviction-hard=nodefs.available<10%
--eviction-soft=nodefs.available<15%
```

When the node's available disk drops below these thresholds, the kubelet starts
evicting pods (highest usage first) to reclaim disk space.

## Common Issues

| Symptom | Cause |
|---------|-------|
| Pod Pending, "Insufficient ephemeral-storage" | Request too high for any node |
| Pod Evicted, "EphemeralStorageLimitExceeded" | Pod exceeded its ephemeral storage limit |
| Node DiskPressure | Node-level disk is running low |
| Pod Evicted, "DiskPressure" | Kubelet evicted pod to reclaim node disk |

## Storage Units

Be careful with units — a common source of bugs:

| Unit | Value |
|------|-------|
| `Ki` | Kibibytes (1024 bytes) |
| `Mi` | Mebibytes (1024 Ki) |
| `Gi` | Gibibytes (1024 Mi) |
| `Ti` | Tebibytes (1024 Gi) |
| `K` | Kilobytes (1000 bytes) |
| `M` | Megabytes (1000 K) |
| `G` | Gigabytes (1000 M) |

## CKA Exam Tips

- Ephemeral storage is often overlooked but can appear on the exam
- Know the difference between `requests` (scheduling) and `limits` (eviction)
- Remember that `emptyDir` volumes count toward ephemeral storage usage
- Use `kubectl describe node` to see allocatable ephemeral storage
- Pods are immutable for resource requests — you must delete and recreate
- Double-check units: `Mi` vs `Gi` is a 1000x difference
