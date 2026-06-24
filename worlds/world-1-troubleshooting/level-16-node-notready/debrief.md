# Level 16 Debrief: Node Tainted NotReady

## What Happened

The node had a `node.kubernetes.io/not-ready=true:NoSchedule` taint applied to it.
This taint prevented any pod without a matching toleration from being scheduled on
the node. Since this was a single-node cluster, the `critical-service` deployment
had nowhere to place its pod, leaving it stuck in Pending state.

## Node Conditions and Taints

Kubernetes nodes have **conditions** that reflect their health:

- `Ready` — kubelet is healthy and ready to accept pods
- `MemoryPressure` — node is running low on memory
- `DiskPressure` — node is running low on disk space
- `PIDPressure` — too many processes on the node
- `NetworkUnavailable` — network is not configured correctly

When certain conditions are true, the **kubelet automatically adds taints** to the
node. For example:

| Condition | Taint Added |
|-----------|-------------|
| `Ready=False` | `node.kubernetes.io/not-ready:NoSchedule` |
| `Ready=Unknown` | `node.kubernetes.io/unreachable:NoSchedule` |
| `MemoryPressure` | `node.kubernetes.io/memory-pressure:NoSchedule` |
| `DiskPressure` | `node.kubernetes.io/disk-pressure:NoSchedule` |

## How to Diagnose NotReady Nodes

1. **Check node status**: `kubectl get nodes` — look for NotReady status
2. **Describe the node**: `kubectl describe node <name>` — check Conditions and Taints
3. **Check kubelet logs**: `journalctl -u kubelet -f` on the node itself
4. **Common causes**: kubelet stopped, container runtime down, network issues, disk full

## The Taint Removal Syntax

To remove a taint, use the same taint specification with a trailing `-`:

```bash
# Add a taint
kubectl taint nodes mynode key=value:NoSchedule

# Remove a taint (note the trailing dash)
kubectl taint nodes mynode key:NoSchedule-

# Remove all taints with a specific key (any effect)
kubectl taint nodes mynode key-
```

## Taint Effects

- `NoSchedule` — new pods won't be scheduled (existing pods stay)
- `PreferNoSchedule` — scheduler tries to avoid, but no guarantee
- `NoExecute` — existing pods are evicted, new pods not scheduled

## CKA Exam Tips

- **Memorize the taint removal syntax** — the trailing `-` is easy to forget
- `kubectl taint nodes <node> key:Effect-` removes a specific taint
- `kubectl describe node` is your first stop for node issues
- Know that kubelet automatically manages taints based on node conditions
- Taints and tolerations work together: a pod must tolerate a taint to be scheduled
