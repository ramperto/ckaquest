# Debrief: DaemonSet — Scheduling on Every Node

## What is a DaemonSet?

A DaemonSet ensures **one pod runs on every eligible node** (or a subset via
nodeSelector/affinity). As nodes are added to the cluster, DaemonSet pods are
automatically scheduled on them. Common uses:

- Log collectors (Fluentd, Filebeat)
- Node monitoring agents (Prometheus node exporter)
- Network plugins (Calico, Cilium agents)
- Storage daemons (Ceph, GlusterFS)

## The nodeSelector trap

```yaml
spec:
  template:
    spec:
      nodeSelector:
        disktype: ssd    # ONLY schedules on nodes with this label
```

If no node has the label → `desiredNumberScheduled: 0` → no pods created.
This is silent — the DaemonSet appears healthy but runs nowhere.

## Diagnosing scheduling issues

```bash
# Check desired vs ready
kubectl get daemonset node-monitor -n ckaquest
# DESIRED   CURRENT   READY   UP-TO-DATE   AVAILABLE
# 0         0         0       0            0

# Check node labels
kubectl get nodes --show-labels
kubectl describe node <node-name> | grep Labels -A20

# DaemonSet events
kubectl describe daemonset node-monitor -n ckaquest | grep -A10 Events
```

## Fixes

**Option A: Remove the nodeSelector** (runs on all nodes)
```bash
kubectl patch daemonset node-monitor -n ckaquest \
  --type=json \
  -p='[{"op":"remove","path":"/spec/template/spec/nodeSelector"}]'
```

**Option B: Label the node** (keep nodeSelector, fix the node)
```bash
kubectl label node <node-name> disktype=ssd
```

## DaemonSet vs Deployment

| Feature | DaemonSet | Deployment |
|---------|-----------|------------|
| Pod count | 1 per eligible node | Fixed replicas |
| Scheduling | One per node (guaranteed) | kube-scheduler assigns |
| Scaling | Automatic with nodes | Manual or HPA |
| Use case | Per-node daemons | Stateless apps |

## DaemonSet tolerations

DaemonSets often need tolerations to run on control-plane nodes
(which have a `NoSchedule` taint):

```yaml
tolerations:
  - key: node-role.kubernetes.io/control-plane
    operator: Exists
    effect: NoSchedule
  - key: node-role.kubernetes.io/master
    operator: Exists
    effect: NoSchedule
```

Using `operator: Exists` (no key/value) tolerates ALL taints — useful for
system-level DaemonSets that must run everywhere.

## CKA exam tip

DaemonSet questions often combine nodeSelector with tolerations. Check both:
1. Does any node match the nodeSelector labels?
2. Are the tolerations covering node taints?

## Interview question

**Q: How does a DaemonSet differ from a Deployment with replicas equal to the node count?**

A: A DaemonSet is node-aware — it guarantees exactly one pod per eligible node and
automatically adds/removes pods as nodes join/leave the cluster. A Deployment just
maintains a replica count; the scheduler may place multiple pods on the same node
and won't track new node additions. DaemonSets also interact differently with node
taints, have their own update strategy (`OnDelete` or `RollingUpdate`), and use
the `hostPID`/`hostNetwork` options naturally for node-level tasks.
