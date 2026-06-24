# Debrief: Pending Pod — NodeSelector Mismatch

## What happened?

The pod spec had a `nodeSelector` requiring `disktype: ssd`. No node in the
cluster had that label, so the scheduler filtered out all nodes and the pod
stayed Pending.

## nodeSelector vs nodeAffinity

`nodeSelector` is the simple form — must match exactly.

`nodeAffinity` is the advanced form — supports required vs preferred,
expressions like `In`, `NotIn`, `Exists`:

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: disktype
              operator: In
              values: [ssd, nvme]
```

## Managing node labels

```bash
# View labels
kubectl get nodes --show-labels
kubectl describe node <name>

# Add label
kubectl label node <name> disktype=ssd

# Remove label
kubectl label node <name> disktype-
```

## CKA exam tip

When a pod is Pending and resources are fine, always check:
1. `kubectl describe pod` Events → "didn't match node selector"
2. `kubectl get nodes --show-labels` → does any node have the required label?
3. Fix: either label a node or remove the constraint

## Interview question

**Q: What's the difference between nodeSelector and nodeAffinity?**

A: `nodeSelector` is a simple key=value match — all specified labels must
exist on the node. `nodeAffinity` is more expressive: it supports logical
operators (In, NotIn, Exists, Gt), and separates required constraints
(pod won't schedule without them) from preferred ones (soft preferences
that influence scoring but don't block scheduling).
