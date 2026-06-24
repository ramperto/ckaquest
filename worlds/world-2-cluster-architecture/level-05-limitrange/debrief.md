# Debrief: LimitRange — Pod Rejected at Admission

## What happened?

The LimitRange `cpu-limits` set a `max.cpu` of 200m per container. The pod
requested 500m and limited to 1 CPU. The API server's LimitRanger admission
plugin rejected the pod **before it was created** — not a scheduling failure,
but an admission failure.

## LimitRange vs ResourceQuota

| | LimitRange | ResourceQuota |
|---|---|---|
| **Scope** | Per pod/container/PVC | Whole namespace |
| **Enforces** | min/max per object | Total consumption |
| **Default** | Sets defaults if not specified | N/A |
| **Rejects** | Objects exceeding min/max | Objects that would exceed total |

## LimitRange structure

```yaml
spec:
  limits:
    - type: Container   # or Pod, PersistentVolumeClaim
      min:
        cpu: "10m"         # container MUST request at least this
        memory: "16Mi"
      max:
        cpu: "2"           # container CANNOT exceed this
        memory: "1Gi"
      default:             # applied if container omits limits
        cpu: "500m"
        memory: "256Mi"
      defaultRequest:      # applied if container omits requests
        cpu: "100m"
        memory: "128Mi"
```

## LimitRange superpower: auto-injecting defaults

If a namespace has a LimitRange with `default`/`defaultRequest` and a pod
is created without resource specs, the LimitRange automatically injects
the defaults. This is how you enforce "all pods must have resource limits"
without requiring developers to always specify them.

## CKA exam tip

If a pod is rejected at creation (not even Pending, just an error from
`kubectl apply`), check:
1. `kubectl describe limitrange -n <ns>` → any violated constraints?
2. ResourceQuota: `kubectl describe resourcequota -n <ns>` → exceeded?
3. PodSecurityAdmission: privileged containers blocked?

## Interview question

**Q: What's the benefit of combining LimitRange and ResourceQuota?**

A: LimitRange ensures every pod has resource requests/limits (required for
ResourceQuota to work) and prevents any single pod from consuming too much.
ResourceQuota limits the total consumption of the namespace. Together:
LimitRange = "one tenant can't starve others on the same node",
ResourceQuota = "one namespace can't starve other namespaces in the cluster".
