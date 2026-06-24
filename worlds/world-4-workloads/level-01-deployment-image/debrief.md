# Debrief: Deployment — Fix the Bad Image

## The fastest fix on the CKA exam

```bash
kubectl set image deployment/<name> <container>=<image>:<tag> -n <ns>
kubectl rollout status deployment/<name> -n <ns>
```

`kubectl set image` is the go-to for image updates — no YAML editing needed.

## How Deployments manage rollouts

When you change a Deployment's pod template (image, env vars, etc.), it
creates a new ReplicaSet and gradually shifts pods from old → new:

```
Old ReplicaSet: 3 pods (nginx:1.99.99) → 2 → 1 → 0
New ReplicaSet: 0 pods (nginx:1.25)    → 1 → 2 → 3
```

The default `RollingUpdate` strategy keeps the app partially available
during the transition. This is why we update the Deployment, not the pods.

## Useful rollout commands

```bash
# Watch live rollout progress
kubectl rollout status deployment/web -n ckaquest

# View rollout history (shows revision numbers)
kubectl rollout history deployment/web -n ckaquest

# Inspect a specific revision
kubectl rollout history deployment/web -n ckaquest --revision=2

# Pause / resume a rollout mid-flight
kubectl rollout pause  deployment/web -n ckaquest
kubectl rollout resume deployment/web -n ckaquest
```

## Diagnosing ImagePullBackOff

```bash
# Which pods are failing?
kubectl get pods -n ckaquest -l app=web

# Why?
kubectl describe pod <pod-name> -n ckaquest | tail -20
# Look for: "Failed to pull image ... not found"

# Quick one-liner
kubectl get events -n ckaquest --sort-by='.lastTimestamp' | grep -i "pull"
```

## CKA exam tip

`kubectl set image` is explicitly tested. Know the syntax cold:

```bash
kubectl set image deployment/<deployment> <container>=<image>:<tag>
kubectl set image daemonset/<ds>          <container>=<image>:<tag>
kubectl set image pod/<pod>               <container>=<image>:<tag>
```

The container name comes from `spec.containers[].name` in the manifest.

## Interview question

**Q: How do you update a running Deployment's image with zero downtime?**

A: Use `kubectl set image deployment/<name> <container>=<image>:<tag>`.
The Deployment controller creates a new ReplicaSet with the updated pod
template and performs a rolling update — scaling up the new RS while
scaling down the old RS, one pod at a time. The `maxUnavailable` and
`maxSurge` fields control how aggressively it rolls. Use
`kubectl rollout status` to monitor completion.
