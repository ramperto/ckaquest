# Debrief: Node Affinity — Schedule in the Right Zone

## Node affinity vs nodeSelector

`nodeSelector` is the simple version (key=value must match exactly).
`nodeAffinity` is more expressive — supports operators, multiple values, and
preferred (soft) scheduling.

```yaml
# Simple nodeSelector
spec:
  nodeSelector:
    zone: us-west

# Equivalent nodeAffinity (required)
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        nodeSelectorTerms:
          - matchExpressions:
              - key: zone
                operator: In
                values:
                  - us-west
```

## Required vs Preferred

| Type | Behaviour |
|------|-----------|
| `requiredDuringSchedulingIgnoredDuringExecution` | Hard — pod stays Pending if no node matches |
| `preferredDuringSchedulingIgnoredDuringExecution` | Soft — prefers matching nodes but schedules anywhere if none match |

The `IgnoredDuringExecution` part means: once the pod is running, changes
to node labels do NOT evict the pod.

## Operators for matchExpressions

| Operator | Meaning |
|----------|---------|
| `In` | Label value is in the list |
| `NotIn` | Label value is NOT in the list |
| `Exists` | Label key exists (any value) |
| `DoesNotExist` | Label key does not exist |
| `Gt` | Label value (numeric) is greater than |
| `Lt` | Label value (numeric) is less than |

```yaml
matchExpressions:
  - key: zone
    operator: In
    values: [us-west, us-central]   # either zone is OK

  - key: gpu
    operator: Exists                # node has any gpu label
```

## Preferred affinity with weights

```yaml
spec:
  affinity:
    nodeAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
        - weight: 80          # 0-100; higher = more preferred
          preference:
            matchExpressions:
              - key: zone
                operator: In
                values: [us-west]
        - weight: 20
          preference:
            matchExpressions:
              - key: zone
                operator: In
                values: [us-central]
```

Scheduler scores nodes using weights. Pod schedules on best match, but
will schedule anywhere if no preferred node is available.

## Checking node labels

```bash
# All labels
kubectl get nodes --show-labels

# Specific label
kubectl get nodes -L zone,disktype

# Add a label
kubectl label node <node> zone=us-west

# Remove a label (append -)
kubectl label node <node> zone-
```

## CKA exam tip

Node affinity YAML is verbose. On the exam:
1. Start from `kubectl explain pod.spec.affinity.nodeAffinity`
2. Know the two types: `requiredDuring...` and `preferredDuring...`
3. Remember the six operators for matchExpressions
4. Always check `kubectl get nodes --show-labels` before writing affinity rules

## Interview question

**Q: When would you use nodeAffinity over nodeSelector?**

A: Use `nodeAffinity` when you need: (1) soft/preferred scheduling (the pod
can still run if no matching node exists), (2) complex matching (multiple
values with `In`/`NotIn`, existence checks with `Exists`/`DoesNotExist`,
numeric comparisons with `Gt`/`Lt`), or (3) multiple independent selector
terms (OR logic between `nodeSelectorTerms`, AND logic within each term).
Use `nodeSelector` when a simple key=value match is sufficient — it's
less verbose and easier to read.
