# Debrief: Resource Requests and Limits

## How resource management works in Kubernetes

Every container can specify **requests** and **limits** for CPU and memory:

```yaml
resources:
  requests:
    memory: 256Mi     # guaranteed minimum — used for scheduling
    cpu: 100m         # 100 millicores = 0.1 CPU
  limits:
    memory: 512Mi     # hard cap — container is OOM-killed if exceeded
    cpu: 250m         # soft cap — container is CPU-throttled if exceeded
```

## Requests vs Limits

| Aspect | Requests | Limits |
|--------|----------|--------|
| **Purpose** | Scheduling guarantee | Enforcement cap |
| **Scheduler uses** | Yes — finds a node with enough capacity | No |
| **What happens when exceeded** | N/A (it's a minimum) | Memory: OOM kill. CPU: throttled |
| **Required relationship** | requests <= limits | limits >= requests |

**Key rule**: `limits` must always be >= `requests`. The API server rejects
the pod immediately if this is violated.

## CPU units

| Value | Meaning |
|-------|---------|
| `1` | 1 full CPU core |
| `500m` | 0.5 CPU (500 millicores) |
| `100m` | 0.1 CPU (100 millicores) |
| `250m` | 0.25 CPU |

1 CPU = 1000m (millicores). On AWS, 1 CPU = 1 vCPU. On GCP, 1 CPU = 1 core.

## Memory units

| Value | Meaning |
|-------|---------|
| `128Mi` | 128 mebibytes (128 * 1024 * 1024 bytes) |
| `1Gi` | 1 gibibyte |
| `128M` | 128 megabytes (128 * 1000 * 1000 bytes) |

Use `Mi` / `Gi` (binary) not `M` / `G` (decimal) for clarity.

## QoS Classes

Kubernetes assigns a Quality of Service class based on resource configuration:

| QoS Class | Condition | Eviction Priority |
|-----------|-----------|-------------------|
| **Guaranteed** | requests == limits for ALL containers | Last to be evicted |
| **Burstable** | At least one request or limit set, but not Guaranteed | Middle |
| **BestEffort** | No requests or limits set at all | First to be evicted |

```yaml
# Guaranteed QoS — requests equal limits
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 256Mi    # same as request
    cpu: 100m        # same as request

# Burstable QoS — requests < limits
resources:
  requests:
    memory: 256Mi
    cpu: 100m
  limits:
    memory: 512Mi    # higher than request
    cpu: 250m        # higher than request

# BestEffort QoS — no resources set (not recommended for production)
# resources: {}
```

## What happens when limits are exceeded

### Memory limit exceeded
The container is **OOM-killed** (Out Of Memory) by the kernel. The pod status
shows `OOMKilled`. The container restarts according to `restartPolicy`.

```bash
# Check for OOM kills
kubectl describe pod <name> | grep -A3 "Last State"
```

### CPU limit exceeded
The container is **throttled** — it still runs but is given less CPU time.
No restart occurs. Check for throttling:

```bash
# In the container (if available)
cat /sys/fs/cgroup/cpu/cpu.stat
```

## LimitRange — namespace-level defaults

Admins can set default requests/limits per namespace:

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: ckaquest
spec:
  limits:
    - type: Container
      default:         # default limits (if none specified)
        memory: 512Mi
        cpu: 500m
      defaultRequest:  # default requests (if none specified)
        memory: 256Mi
        cpu: 100m
      max:             # maximum allowed limits
        memory: 1Gi
        cpu: "1"
      min:             # minimum allowed requests
        memory: 64Mi
        cpu: 50m
```

## ResourceQuota — namespace-level totals

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
  namespace: ckaquest
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 4Gi
    limits.cpu: "8"
    limits.memory: 8Gi
    pods: "20"
```

## Diagnosing resource issues

```bash
# Check pod resource configuration
kubectl get pod <name> -n ckaquest -o jsonpath='{.spec.containers[0].resources}'

# Check QoS class
kubectl get pod <name> -n ckaquest -o jsonpath='{.status.qosClass}'

# Check node resource usage
kubectl describe node <node-name> | grep -A5 "Allocated resources"

# Check namespace quotas
kubectl describe resourcequota -n ckaquest

# Check namespace limit ranges
kubectl describe limitrange -n ckaquest
```

## CKA exam tip

Always set `requests <= limits`. A common exam scenario involves fixing a pod
that fails admission due to invalid resource specs. Remember:

- If only `limits` is set, Kubernetes auto-sets `requests = limits` (Guaranteed QoS)
- If only `requests` is set, there is no upper limit (Burstable QoS)
- `kubectl describe node` shows allocatable vs allocated resources for scheduling

## Interview question

**Q: Explain the difference between Guaranteed, Burstable, and BestEffort QoS
classes. When is each appropriate?**

A: Kubernetes assigns QoS classes based on resource configuration. **Guaranteed**
(requests == limits for all containers) provides the most predictable performance
and is evicted last — ideal for critical production workloads. **Burstable**
(at least one request set, but requests != limits) allows pods to use more
resources when available — good for variable workloads. **BestEffort** (no
resources specified) makes no guarantees and is evicted first under memory
pressure — only suitable for non-critical batch jobs. Under node pressure,
kubelet evicts BestEffort first, then Burstable pods exceeding their requests,
and Guaranteed last.
