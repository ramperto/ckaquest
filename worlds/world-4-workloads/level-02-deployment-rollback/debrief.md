# Debrief: Deployment — Rollback a Bad Release

## The rollback command

```bash
kubectl rollout undo deployment/<name> -n <namespace>
```

By default, this goes back one revision. To target a specific revision:

```bash
kubectl rollout undo deployment/<name> --to-revision=<N> -n <namespace>
```

## How rollout history works

Every change to a Deployment's pod template creates a new **revision** stored in an
annotation on the ReplicaSet. The Deployment retains `revisionHistoryLimit` revisions
(default: 10).

```bash
# See all revisions
kubectl rollout history deployment/api -n ckaquest

# See what changed in a specific revision
kubectl rollout history deployment/api --revision=1 -n ckaquest
```

Output:
```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

The `CHANGE-CAUSE` column is populated from the annotation
`kubernetes.io/change-cause`. Add it with:

```bash
kubectl annotate deployment/api kubernetes.io/change-cause="fix: bad image" -n ckaquest
```

This is good practice in production — audit trail of who changed what.

## Rollback mechanics

`rollout undo` swaps the active ReplicaSet:
```
Before undo:  RS-v2 (nginx:BROKEN, 3 replicas)   RS-v1 (nginx:1.25, 0 replicas)
After undo:   RS-v2 (nginx:BROKEN, 0 replicas)   RS-v1 (nginx:1.25, 3 replicas)
```

It's the same rolling update process — just in reverse. No new ReplicaSet is created;
the existing RS-v1 scales back up.

## Monitoring rollouts

```bash
# Watch until complete (or timeout)
kubectl rollout status deployment/api -n ckaquest

# Check deployment conditions
kubectl describe deployment api -n ckaquest | grep -A5 "Conditions:"

# See pod transitions
kubectl get pods -n ckaquest -l app=api -w
```

## CKA exam tip

Rollback is a one-liner — know it cold:
```bash
kubectl rollout undo deployment/<name>
```

Also know these rollout subcommands:
```bash
kubectl rollout status   # wait for completion
kubectl rollout history  # list revisions
kubectl rollout pause    # pause mid-rollout
kubectl rollout resume   # resume paused rollout
kubectl rollout restart  # force rolling restart (new pods, same config)
```

## Interview question

**Q: How does `kubectl rollout undo` work internally?**

A: Each change to a Deployment's pod template creates a new ReplicaSet.
Old ReplicaSets are kept (up to `revisionHistoryLimit`, default 10) at
zero replicas. `rollout undo` scales the target historical ReplicaSet
back up while scaling down the current one — the same rolling update
mechanism, just reversed. No new objects are created.
