# Debrief: Pod Disruption Budgets (PDBs)

## What is a PodDisruptionBudget?

A PDB limits the number of pods that can be **voluntarily disrupted** at the
same time. It protects applications during planned operations like node drains,
cluster upgrades, and autoscaler scale-downs.

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: pdb-app-pdb
  namespace: ckaquest
spec:
  maxUnavailable: 1         # allow at most 1 pod down at a time
  selector:
    matchLabels:
      app: pdb-app
```

## minAvailable vs maxUnavailable

| Field | Meaning | Example (3 replicas) |
|-------|---------|---------------------|
| `minAvailable: 2` | At least 2 pods must remain available | 1 disruption allowed |
| `minAvailable: 3` | All 3 must remain available | 0 disruptions (broken!) |
| `maxUnavailable: 1` | At most 1 pod can be unavailable | 1 disruption allowed |
| `maxUnavailable: 0` | No pods can be unavailable | 0 disruptions (broken!) |

**Rule**: you can set `minAvailable` OR `maxUnavailable`, never both.

Both fields accept either an integer or a percentage string (e.g., `"33%"`).

## What counts as a voluntary disruption?

| Voluntary (PDB blocks) | Involuntary (PDB cannot block) |
|------------------------|-------------------------------|
| `kubectl drain` | Node crash / hardware failure |
| `kubectl delete pod` (via Eviction API) | OOM kill by kubelet |
| Cluster autoscaler scale-down | Kernel panic |
| Node upgrade / reboot | Container runtime crash |
| Deployment rolling update (respects PDB) | Preemption by higher-priority pod |

**Important**: `kubectl delete pod` bypasses PDB unless it goes through the
Eviction API. The drain command uses the Eviction API and respects PDBs.

## PDB status fields

```bash
kubectl get pdb pdb-app-pdb -n ckaquest -o wide
```

| Status Field | Description |
|-------------|-------------|
| `currentHealthy` | Number of healthy pods matching the selector |
| `desiredHealthy` | Minimum number that must remain healthy |
| `disruptionsAllowed` | How many pods can be disrupted right now |
| `expectedPods` | Total pods matching the selector |

Formula: `disruptionsAllowed = currentHealthy - desiredHealthy`

## Common pitfall: PDB blocks drain forever

```bash
# This will hang if PDB allows 0 disruptions
kubectl drain node01 --ignore-daemonsets --delete-emptydir-data

# Use --timeout to avoid hanging forever
kubectl drain node01 --ignore-daemonsets --timeout=60s

# Use --disable-eviction to bypass PDB (dangerous!)
kubectl drain node01 --ignore-daemonsets --disable-eviction
```

## PDB with rolling updates

Deployments respect PDBs during rolling updates:

```yaml
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1    # deployment strategy
      maxSurge: 1
```

If the PDB allows fewer disruptions than the deployment's `maxUnavailable`,
the PDB takes precedence — the rollout slows down to respect the PDB.

## Diagnosing PDB issues

```bash
# Check PDB status
kubectl get pdb -n ckaquest

# Detailed PDB info
kubectl describe pdb pdb-app-pdb -n ckaquest

# Check if drain is blocked by PDB
kubectl get events --sort-by='.lastTimestamp' -n ckaquest | grep -i evict

# Check disruptions allowed (programmatic)
kubectl get pdb pdb-app-pdb -n ckaquest -o jsonpath='{.status.disruptionsAllowed}'
```

## CKA exam tip

PDBs are commonly tested in **cluster upgrade** scenarios:

1. You need to drain a node for upgrade
2. Drain hangs because a PDB blocks eviction
3. Fix the PDB (change minAvailable/maxUnavailable)
4. Re-run the drain

Remember the API version: `policy/v1` (not `policy/v1beta1` which is removed
since Kubernetes 1.25).

## Interview question

**Q: A cluster admin runs `kubectl drain node01` but it hangs. What could
cause this and how would you troubleshoot?**

A: The most likely cause is a PodDisruptionBudget blocking eviction. Check
PDBs with `kubectl get pdb -A` and look for any with `ALLOWED=0`. This
happens when `minAvailable` equals the current replica count or
`maxUnavailable` is 0. Fix by adjusting the PDB to allow at least 1
disruption (e.g., `maxUnavailable: 1`). Other causes include pods with no
controller (add `--force` flag) or pods using local storage (add
`--delete-emptydir-data`). DaemonSet pods should be skipped with
`--ignore-daemonsets`.
