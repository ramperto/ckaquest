# Debrief: Pod Topology Spread Constraints

## What are topology spread constraints?

Topology spread constraints control how pods are distributed across failure
domains (nodes, zones, regions, racks). They help ensure high availability
by preventing all replicas from landing on the same topology domain.

```yaml
spec:
  topologySpreadConstraints:
    - maxSkew: 1
      topologyKey: kubernetes.io/hostname
      whenUnsatisfiable: ScheduleAnyway
      labelSelector:
        matchLabels:
          app: spread-app
```

## Key fields explained

| Field | Description | Example |
|-------|-------------|---------|
| `maxSkew` | Maximum difference in pod count between any two topology domains | `1` = at most 1 pod difference |
| `topologyKey` | Node label key that defines the topology domain | `kubernetes.io/hostname`, `topology.kubernetes.io/zone` |
| `whenUnsatisfiable` | What to do if the constraint can't be satisfied | `DoNotSchedule` or `ScheduleAnyway` |
| `labelSelector` | Which pods to count when calculating spread | Usually matches the deployment's pod labels |
| `minDomains` | Minimum number of domains required (K8s 1.25+) | `3` = need at least 3 zones |
| `matchLabelKeys` | Use pod label values for spreading (K8s 1.27+) | `["pod-template-hash"]` |

## whenUnsatisfiable options

| Value | Behavior |
|-------|----------|
| `DoNotSchedule` | **Hard constraint** — pod stays Pending if constraint can't be met |
| `ScheduleAnyway` | **Soft constraint** — scheduler tries its best but will place the pod regardless |

**Single-node clusters**: always use `ScheduleAnyway` since all pods land on
the same node and perfect distribution is impossible.

## Common topology keys

| Key | Domain | Available |
|-----|--------|-----------|
| `kubernetes.io/hostname` | Per node | Always (every node has this) |
| `topology.kubernetes.io/zone` | Per availability zone | Cloud providers (AWS, GCP, Azure) |
| `topology.kubernetes.io/region` | Per region | Cloud providers |
| Custom (e.g., `rack`) | Custom topology | Only if you manually label nodes |

## How maxSkew works

Example: 3 nodes (A, B, C), 5 pods, maxSkew: 1

```
Valid distribution (skew = 1):
  Node A: 2 pods
  Node B: 2 pods
  Node C: 1 pod      max - min = 2 - 1 = 1 (within maxSkew)

Invalid distribution (skew = 2):
  Node A: 3 pods
  Node B: 1 pod
  Node C: 1 pod      max - min = 3 - 1 = 2 (exceeds maxSkew: 1)
```

## Topology spread vs pod affinity/anti-affinity

| Feature | Topology Spread | Pod Anti-Affinity |
|---------|----------------|-------------------|
| **Goal** | Even distribution across domains | Avoid co-location |
| **Granularity** | Controls skew (maxSkew) | Binary: same domain or not |
| **Flexibility** | Can control "how even" | All or nothing |
| **Multiple constraints** | Each evaluated independently | Combined with AND |
| **Performance** | Generally better | Can be slow with many pods |

```yaml
# Pod anti-affinity: hard "no two pods on same node"
affinity:
  podAntiAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      - topologyKey: kubernetes.io/hostname
        labelSelector:
          matchLabels:
            app: myapp

# Topology spread: "distribute evenly, allow some skew"
topologySpreadConstraints:
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: myapp
```

## Multiple constraints

You can combine multiple topology spread constraints:

```yaml
topologySpreadConstraints:
  # Spread across zones (hard constraint)
  - maxSkew: 1
    topologyKey: topology.kubernetes.io/zone
    whenUnsatisfiable: DoNotSchedule
    labelSelector:
      matchLabels:
        app: myapp
  # Also spread across nodes within zones (soft constraint)
  - maxSkew: 1
    topologyKey: kubernetes.io/hostname
    whenUnsatisfiable: ScheduleAnyway
    labelSelector:
      matchLabels:
        app: myapp
```

All constraints must be satisfied (AND logic). If any hard constraint fails,
the pod stays Pending.

## Diagnosing topology spread issues

```bash
# Check pod status and events
kubectl describe pod <pending-pod> -n ckaquest

# Check node labels (what topology keys exist)
kubectl get nodes --show-labels

# Check specific topology key on nodes
kubectl get nodes -L kubernetes.io/hostname -L topology.kubernetes.io/zone

# See pod distribution
kubectl get pods -n ckaquest -l app=spread-app -o wide

# Check if topology key exists on any node
kubectl get nodes -o jsonpath='{.items[*].metadata.labels}' | grep "topology.kubernetes.io/rack"
```

## CKA exam tip

Topology spread constraints are increasingly common on the CKA exam:

1. If pods are Pending, check events for topology-related errors
2. Verify the `topologyKey` exists on nodes (`kubectl get nodes --show-labels`)
3. On single-node clusters (common in exam environments), use `ScheduleAnyway`
4. Remember: `DoNotSchedule` is like a hard requirement, `ScheduleAnyway`
   is like a soft preference
5. The API is under `spec.topologySpreadConstraints` (plural, array)

## Interview question

**Q: How do topology spread constraints differ from pod anti-affinity, and
when would you use each?**

A: Pod anti-affinity provides a binary constraint — pods either can or
cannot share a topology domain. Topology spread constraints provide
proportional distribution — they control the maximum skew (difference)
between domains. Use anti-affinity when you need strict separation (e.g.,
"never put two replicas on the same node"). Use topology spread when you
want even distribution but can tolerate some imbalance (e.g., "spread
across 3 zones with at most 1 pod difference"). Topology spread also
performs better at scale since the scheduler evaluates it more efficiently
than anti-affinity with large pod counts.
