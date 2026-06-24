# Debrief: Node Drain — Prepare for Maintenance

## What happened?

`kubectl drain` safely evicts pods from a node before maintenance. It also
marks the node unschedulable (cordons it). But it blocks on two situations:
1. **DaemonSet pods** — they're managed by DaemonSet, they'll be recreated
2. **Pods without a controller** — no ReplicaSet to reschedule them elsewhere

## drain vs cordon

| Command | Effect |
|---------|--------|
| `kubectl cordon <node>` | Mark unschedulable — new pods won't schedule here |
| `kubectl drain <node>` | Cordon + evict all pods (respects PodDisruptionBudget) |
| `kubectl uncordon <node>` | Re-enable scheduling |

## drain flags

```bash
--ignore-daemonsets     # Skip DaemonSet pods (they can't be evicted anyway)
--delete-emptydir-data  # Delete pods using emptyDir (data is ephemeral)
--force                 # Evict orphaned pods (not managed by a controller)
--grace-period=30       # Override pod's terminationGracePeriodSeconds
--timeout=5m            # Give up after this time
--dry-run=client        # Preview what would be evicted
```

## PodDisruptionBudget interaction

If a PDB requires `minAvailable: 2` and a deployment has only 2 replicas,
drain will block (can't evict without violating the PDB). You'd need to
either scale up first or use `--disable-eviction` (not recommended in prod).

## CKA exam tip

Node drain is a core skill for the Cluster Architecture domain:
1. Get node name: `kubectl get nodes`
2. Drain: `kubectl drain <node> --ignore-daemonsets --delete-emptydir-data`
3. Do the task (upgrade, etc.)
4. Uncordon: `kubectl uncordon <node>`

**On the exam, always uncordon after draining** — if you forget, pods from
other questions may end up Pending.

## Interview question

**Q: What's the difference between kubectl cordon and kubectl drain?**

A: `cordon` only marks the node as unschedulable (new pods won't be scheduled
there) but leaves existing pods running. `drain` cordons the node AND evicts
all eligible pods — it's safe-to-stop for maintenance. Eviction respects
PodDisruptionBudgets, while cordon alone does not affect running pods.
