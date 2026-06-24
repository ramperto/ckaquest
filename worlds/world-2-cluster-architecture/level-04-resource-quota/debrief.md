# Debrief: ResourceQuota — Deployment Blocked

## What happened?

The namespace had a ResourceQuota limiting it to 2 pods total. The Deployment
requested 3 replicas. The first 2 pods were created fine, but the 3rd was
rejected with "exceeded quota". The ReplicaSet controller keeps trying and
failing — visible in events as `FailedCreate`.

## ResourceQuota capabilities

```yaml
spec:
  hard:
    # Compute resources
    requests.cpu: "4"
    requests.memory: "8Gi"
    limits.cpu: "8"
    limits.memory: "16Gi"

    # Object counts
    pods: "10"
    services: "5"
    secrets: "20"
    configmaps: "20"
    persistentvolumeclaims: "4"

    # Storage
    requests.storage: "100Gi"
    storageclass.storage.k8s.io/requests.storage: "50Gi"
```

## Inspecting quota

```bash
kubectl describe resourcequota -n ckaquest
# Shows:
#   Name     Resource          Used  Hard
#   tight    pods              2     2     ← Used = Hard = blocked!
#   tight    requests.cpu      100m  200m
```

## Important: quotas require resource requests/limits

If a namespace has a ResourceQuota for CPU/memory, ALL pods in that namespace
MUST specify `resources.requests` and `resources.limits`. Otherwise the pod
is rejected with "must specify requests/limits".

This is often where LimitRange helps (sets defaults automatically).

## CKA exam tip

When a deployment is stuck with fewer replicas than desired:
1. Check events: `kubectl get events -n <ns> --sort-by='.lastTimestamp'`
2. Look for "exceeded quota" errors
3. Describe quota: `kubectl describe resourcequota -n <ns>`
4. Edit quota: `kubectl edit resourcequota <name> -n <ns>`

## Interview question

**Q: What happens to existing pods if you lower a ResourceQuota below current usage?**

A: Existing pods are NOT evicted. Kubernetes doesn't retroactively enforce
quota reductions on running pods. The quota only prevents NEW pod creation.
Existing pods continue running until they're deleted or restarted. This means
you can temporarily be "over quota" if the quota was reduced while pods were
already running.
