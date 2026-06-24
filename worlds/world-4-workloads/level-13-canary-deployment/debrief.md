# Debrief: Canary Deployments with Kubernetes Services

## What is a canary deployment?

A canary deployment gradually rolls out a new version alongside the existing
version. A small percentage of traffic goes to the new version (the "canary")
while the majority continues to the stable version. If the canary behaves
well, you increase its share; if not, you roll back.

```
                  +---> v1 pod (replica 1)
                  |
Service ----+---> v1 pod (replica 2)    75% traffic
(app: myapp)|
                  +---> v1 pod (replica 3)
                  |
                  +---> v2 pod (replica 1)    25% traffic (canary)
```

## How it works with Kubernetes Services

Services route traffic to ALL pods matching their selector. By using a
**shared label** across versions, both version pods receive traffic:

```yaml
# Service selector — matches both versions
spec:
  selector:
    app: myapp          # both v1 and v2 pods have this label

# v1 pod labels
labels:
  app: myapp            # matches Service selector
  version: v1           # distinguishes from v2

# v2 pod labels
labels:
  app: myapp            # matches Service selector
  version: v2           # distinguishes from v1
```

## Traffic splitting by replica count

Kubernetes Services use round-robin across all endpoints. The traffic split
is proportional to the number of pods:

| v1 Replicas | v2 Replicas | v1 Traffic | v2 Traffic |
|-------------|-------------|------------|------------|
| 3 | 1 | ~75% | ~25% |
| 9 | 1 | ~90% | ~10% |
| 1 | 1 | ~50% | ~50% |
| 0 | 3 | 0% | 100% (full rollout) |

## Label management is critical

The key lesson: **Services route based on pod labels, not deployment labels**.

```yaml
# Deployment metadata labels — used for organizing deployments
metadata:
  labels:
    app: myapp        # this does NOT affect Service routing

# Pod template labels — these are what Services actually select on
spec:
  template:
    metadata:
      labels:
        app: myapp    # THIS is what the Service sees
```

Common mistake: adding the label to the deployment metadata but forgetting
the pod template. The Service only looks at pod labels.

## Canary vs blue-green deployment

| Aspect | Canary | Blue-Green |
|--------|--------|------------|
| **Traffic split** | Gradual (e.g., 10% then 25% then 50%) | All-or-nothing switch |
| **Implementation** | Shared labels, adjust replica count | Two Services or label swap |
| **Rollback** | Scale down canary to 0 | Switch selector back |
| **Resource usage** | Low overhead (few canary replicas) | 2x resources during transition |
| **Risk** | Lower (small % of users affected) | Higher (all users switch at once) |

## Advanced canary with Istio/Ingress

For precise traffic splitting (not tied to replica count), use:

```yaml
# Istio VirtualService — exact percentage control
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  http:
    - route:
        - destination:
            host: myapp
            subset: v1
          weight: 90
        - destination:
            host: myapp
            subset: v2
          weight: 10
```

## Diagnosing canary routing issues

```bash
# Check Service selector
kubectl get svc myapp-svc -n ckaquest -o jsonpath='{.spec.selector}'

# Check which pods match the selector
kubectl get pods -n ckaquest -l app=myapp --show-labels

# Check Service endpoints (should include both v1 and v2 pod IPs)
kubectl get endpoints myapp-svc -n ckaquest

# Check individual pod labels
kubectl get pods -n ckaquest -l version=v2 --show-labels

# Test traffic distribution (run multiple times)
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -s myapp-svc.ckaquest.svc.cluster.local
```

## CKA exam tip

Label management is critical for Service routing. On the exam:

1. Always check that pod template labels (not deployment labels) match the
   Service selector
2. Use `kubectl get endpoints` to verify which pods a Service is routing to
3. Remember that deployment selectors (`spec.selector.matchLabels`) are
   **immutable** — you must delete and recreate the deployment to change them
4. `kubectl get pods --show-labels` is your best friend for debugging

## Interview question

**Q: How would you implement a canary deployment in Kubernetes without
a service mesh?**

A: Use two Deployments with a shared label (e.g., `app: myapp`) that a
single Service selects on. The stable version runs with more replicas
(e.g., 9) and the canary with fewer (e.g., 1), creating an approximate
90/10 traffic split via round-robin. To increase canary traffic, scale up
the canary deployment and scale down the stable one. To rollback, scale
the canary to 0. The limitation is that traffic percentages are tied to
replica counts, so fine-grained control (e.g., 1%) requires a service mesh
like Istio or an ingress controller with weighted routing.
