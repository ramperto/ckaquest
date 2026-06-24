# Debrief: Pending Pod — Insufficient Resources

## What happened?

The pod requested `cpu: "100"` (100 CPU cores) and `memory: "200Gi"`.
Your node only has 4 CPUs and 4Gi RAM. The scheduler couldn't find any node
that could satisfy the request, so the pod stayed Pending indefinitely.

## CPU units in Kubernetes

```
1     = 1 CPU core (1000m)
500m  = 0.5 CPU core (500 millicores)
100m  = 0.1 CPU core  ← typical small app request
```

The mistake was `cpu: "100"` (100 cores) instead of `cpu: "100m"` (0.1 cores).
This is a common production mistake, especially when someone copies config
from a document and misses the "m" suffix.

## Scheduler decision process

```
Pod created → Scheduler finds candidate nodes
  → Filter: enough CPU? enough memory? taints? nodeSelector?
  → Score: which node is best?
  → Bind: assign pod to node

If no node passes the Filter step → pod stays Pending
```

## Commands for diagnosing pending pods

```bash
# See scheduler events
kubectl describe pod <name> -n <ns>

# See node capacity and allocations
kubectl describe nodes
kubectl top nodes  # (requires metrics-server)

# See total requested on a node
kubectl describe node <node-name> | grep -A8 "Allocated resources"
```

## CKA exam tip

When a pod is Pending, there are 4 common causes:
1. **Insufficient resources** (this level) — scheduler event says "Insufficient cpu/memory"
2. **NodeSelector mismatch** — next level!
3. **Taint/Toleration** — pod needs toleration for node taint
4. **PVC not bound** — pod waiting for storage

Always `kubectl describe pod` first and read the Events.

## Interview question

**Q: What's the difference between resource requests and limits?**

A: Requests are what the scheduler uses to decide node placement — it
reserves that much capacity on the node. Limits are the hard ceiling enforced
at runtime by cgroups. A container can use more than its request (if the node
has slack) but will be throttled/killed if it exceeds its limit.
