# Debrief: PriorityClass — Schedule the Critical Pod

## What is a PriorityClass?

A PriorityClass assigns a numeric priority to pods. Higher priority pods:
1. Are scheduled before lower priority pods when resources are tight
2. Can **preempt** (evict) lower priority pods to free up resources

```yaml
apiVersion: scheduling.k8s.io/v1
kind: PriorityClass
metadata:
  name: high-priority        # cluster-scoped — no namespace
value: 1000000               # higher = more important
globalDefault: false         # if true, applies to pods without priorityClassName
preemptionPolicy: PreemptLowerPriority   # default
description: "Critical production workloads"
```

## Using a PriorityClass in a pod

```yaml
spec:
  priorityClassName: high-priority   # references the PriorityClass by name
  containers:
    - name: app
      image: nginx:1.25
```

## Priority values

| PriorityClass | Value | Purpose |
|---------------|-------|---------|
| `system-cluster-critical` | 2,000,000,000 | Built-in: cluster add-ons (CoreDNS, etc.) |
| `system-node-critical` | 2,000,001,000 | Built-in: node-level critical pods |
| Custom high | 1,000,000 | Your critical apps |
| Default (unset) | 0 | Regular workloads |

**Rule**: values >= 1,000,000,000 are reserved for system use.

## Preemption

When a high-priority pod can't be scheduled (insufficient resources), the
scheduler looks for lower-priority pods to evict:

1. Finds nodes where evicting low-priority pods would free enough resources
2. Evicts those pods (they are gracefully terminated)
3. Schedules the high-priority pod on the now-available node

```yaml
# Disable preemption for this PriorityClass
preemptionPolicy: Never
```

Use `Never` for high-priority pods that should be scheduled preferentially
but should NOT kick out running workloads.

## globalDefault

```yaml
globalDefault: true   # pods with no priorityClassName get this value
```

Only ONE PriorityClass per cluster can have `globalDefault: true`.

## Diagnosing priority-related issues

```bash
# List all PriorityClasses
kubectl get priorityclass

# Check pod priority
kubectl get pod <name> -o jsonpath='{.spec.priority}'

# See if a pod was preempted
kubectl describe pod <name> | grep -A5 "Nominated Node"

# Events showing preemption
kubectl get events --sort-by='.lastTimestamp' | grep -i preempt
```

## CKA exam tip

PriorityClass is cluster-scoped — never use `-n` when creating or getting it.
Remember the API version: `scheduling.k8s.io/v1`.

Quick check if the resource type exists:
```bash
kubectl api-resources | grep priority
# priorityclasses   pc   scheduling.k8s.io/v1   false   PriorityClass
```

## Interview question

**Q: How does Kubernetes handle scheduling when resources are insufficient for a high-priority pod?**

A: The Kubernetes scheduler uses preemption. When a pod with a high priority
(`spec.priority` from its PriorityClass) cannot be scheduled, the scheduler
identifies nodes where evicting lower-priority pods would create enough room.
It then preempts (gracefully terminates) those pods and schedules the
high-priority pod on the freed node. Pods set `preemptionPolicy: Never` to
opt out of causing preemption while still having scheduling preference when
resources are available.
