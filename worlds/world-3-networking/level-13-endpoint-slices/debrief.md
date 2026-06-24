# Debrief: Endpoint Slices — Service Selector Typo

## How Services find their pods

A Kubernetes Service uses a **label selector** to find which pods should
receive traffic. The endpoint controller watches for pods matching the
selector and populates an Endpoints (or EndpointSlice) object with their IPs.

```
Service (selector: app=backend)
   |
   +-- scans all pods in namespace
   |
   +-- finds pods with label app=backend
   |
   +-- creates Endpoints with those pod IPs
   |
   +-- kube-proxy programs iptables/ipvs rules
```

If the selector doesn't match any pods, the Endpoints object is empty
and all traffic to the Service fails.

## Endpoints vs EndpointSlices

| Feature         | Endpoints                          | EndpointSlices                        |
|-----------------|------------------------------------|---------------------------------------|
| API version     | v1                                 | discovery.k8s.io/v1                   |
| Scale           | Single object, all IPs             | Split into slices (max 100 IPs each)  |
| Default in      | All versions                       | v1.21+ (auto-created)                 |
| Check command   | `kubectl get endpoints`            | `kubectl get endpointslices`          |

EndpointSlices are the modern replacement for Endpoints. They scale better
for Services with many pods. Both are auto-managed by the endpoint controller.

## Debugging empty endpoints

This is the **most common Service debugging scenario**:

```bash
# Step 1: Check endpoints
kubectl get endpoints backend-svc -n ckaquest
# If empty, no pods match the selector

# Step 2: Get the Service selector
kubectl get svc backend-svc -n ckaquest -o jsonpath='{.spec.selector}'
# Output: {"app":"backendd"}

# Step 3: List pods with that label
kubectl get pods -n ckaquest -l app=backendd
# No resources found — the label doesn't exist

# Step 4: Check actual pod labels
kubectl get pods -n ckaquest --show-labels
# Output: ... app=backend,tier=api ...

# Step 5: Fix the selector
kubectl edit svc backend-svc -n ckaquest
```

## Why selectors don't validate against existing labels

Kubernetes does **not** validate that a Service selector matches any
existing pods. This is by design:

- Pods may not exist yet (Service created before Deployment)
- Pods come and go (scaling, rolling updates)
- Labels might be applied later

This means a typo in a selector is **silently accepted** — there's no
error or warning. The only symptom is empty endpoints.

## Common selector pitfalls

| Mistake                                       | Symptom                        |
|-----------------------------------------------|--------------------------------|
| Typo in label value (`backendd` vs `backend`) | Empty endpoints                |
| Wrong label key (`apps` vs `app`)             | Empty endpoints                |
| Extra selector label that pods don't have     | Empty endpoints                |
| Selector matches only some pods               | Partial endpoints (fewer IPs)  |
| Namespace mismatch (pods in wrong namespace)  | Empty endpoints                |

## Using labels effectively

```bash
# List all pods with their labels
kubectl get pods -n ckaquest --show-labels

# Filter pods by a specific label
kubectl get pods -n ckaquest -l app=backend

# Show just one label column
kubectl get pods -n ckaquest -L app

# Check which pods a Service would select
kubectl get pods -n ckaquest -l "$(kubectl get svc backend-svc -n ckaquest \
  -o jsonpath='{.spec.selector}' | python3 -c '
import sys, json
d = json.loads(sys.stdin.read())
print(",".join(f"{k}={v}" for k, v in d.items()))
')"
```

## CKA exam tip

When a Service is not working, the **first thing** to check is always
endpoints:

```bash
kubectl get endpoints <service-name> -n <namespace>
```

If endpoints are empty:
1. Get the Service selector
2. List pods with matching labels
3. Fix the mismatch

This debugging pattern appears in nearly every CKA exam. Always verify
endpoints after creating or editing a Service. It takes 5 seconds and
catches the most common mistake.

## Interview question

**Q: You deployed a Service and a Deployment in the same namespace, but
`curl <service-ip>` returns "connection refused". How do you debug it?**

A: First, check `kubectl get endpoints <svc>` — if empty, the Service
selector doesn't match any pod labels. Compare `kubectl get svc <svc> -o yaml`
selector with `kubectl get pods --show-labels`. Fix the selector to match.
If endpoints exist, check that pods are Ready (unready pods are excluded
from endpoints), verify the targetPort matches the container port, and
check NetworkPolicies that might block ingress.
