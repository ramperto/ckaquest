# Debrief: Taint & Toleration — Schedule on a Tainted Node

## Taints and tolerations

**Taints** are set on nodes to repel pods.
**Tolerations** are set on pods to allow scheduling on tainted nodes.

They work as a **key-value-effect** matching system:

```bash
# Add a taint to a node
kubectl taint node <node> gpu=present:NoSchedule

# Remove a taint (append -)
kubectl taint node <node> gpu=present:NoSchedule-
```

```yaml
# Pod toleration that matches the above taint
tolerations:
  - key: "gpu"
    value: "present"
    effect: "NoSchedule"
```

## Taint effects

| Effect | Behaviour |
|--------|-----------|
| `NoSchedule` | Don't schedule new pods here (existing pods unaffected) |
| `PreferNoSchedule` | Avoid scheduling if possible (soft preference) |
| `NoExecute` | Don't schedule AND evict existing pods that don't tolerate |

`NoExecute` is the strongest — it evicts running pods immediately (or after
`tolerationSeconds` grace period).

## Toleration operators

```yaml
# Exact match (operator: Equal — the default)
tolerations:
  - key: "gpu"
    operator: "Equal"
    value: "present"
    effect: "NoSchedule"

# Match ANY value for this key
tolerations:
  - key: "gpu"
    operator: "Exists"
    effect: "NoSchedule"

# Match ALL taints (DaemonSet pattern)
tolerations:
  - operator: "Exists"   # no key = matches everything
```

## Common taint patterns

```bash
# Dedicated node for a team
kubectl taint node <node> team=ml:NoSchedule

# Mark node as unschedulable during maintenance
kubectl taint node <node> maintenance=true:NoExecute

# CKA exam: control-plane taint (set by kubeadm)
kubectl taint node <node> node-role.kubernetes.io/control-plane:NoSchedule
```

## Taints vs nodeSelector vs affinity

| Mechanism | Set on | Direction | Hard/Soft |
|-----------|--------|-----------|-----------|
| Taint/Toleration | Node | Repels pods | Hard (NoSchedule/NoExecute) or soft |
| nodeSelector | Pod | Attracts to label | Hard |
| nodeAffinity | Pod | Attracts to label | Hard or soft |
| podAffinity | Pod | Attracts to pod location | Hard or soft |

Taints push pods away; affinity/nodeSelector pull pods toward nodes.

## CKA exam tip

Taints and tolerations appear frequently. Remember:
1. Taint is on the **node** (`kubectl taint node`)
2. Toleration is in the **pod spec** (`spec.tolerations`)
3. `NoExecute` evicts running pods — most disruptive
4. `operator: Exists` tolerates any value for a key
5. Removing a taint: append `-` to the taint string

## Interview question

**Q: What is the difference between a taint with NoSchedule vs NoExecute?**

A: `NoSchedule` prevents NEW pods from being scheduled on the node if they
lack a matching toleration; pods already running on the node are not affected.
`NoExecute` does both — it prevents new scheduling AND evicts pods that are
currently running and don't have a matching toleration (or whose
`tolerationSeconds` has expired). Use `NoExecute` when you want to drain
workloads from a node gracefully (e.g. hardware maintenance).
