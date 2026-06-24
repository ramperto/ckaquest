# Debrief: HPA — Fix Autoscaling with Resource Requests

## How HPA calculates CPU utilization

The formula is simple:

```
CPU utilization % = (sum of actual CPU usage across pods) /
                    (sum of CPU requests across pods)   * 100
```

**No CPU request = no denominator = `<unknown>`.**

This is the most common HPA failure mode. Always set CPU requests on
containers that are targeted by an HPA.

## HPA YAML (autoscaling/v2)

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-api
  minReplicas: 1
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50   # scale when avg CPU > 50% of request
```

## Imperative HPA creation (exam shortcut)

```bash
# Create HPA with kubectl autoscale
kubectl autoscale deployment web-api \
  --cpu-percent=50 \
  --min=1 \
  --max=5 \
  -n ckaquest
```

## Setting resource requests imperatively

```bash
# Set requests AND limits in one command
kubectl set resources deployment web-api -n ckaquest \
  --requests=cpu=100m,memory=128Mi \
  --limits=cpu=200m,memory=256Mi

# Requests only (limits optional but recommended)
kubectl set resources deployment web-api -n ckaquest \
  --requests=cpu=100m
```

## Checking HPA status

```bash
# Overview
kubectl get hpa -n ckaquest

# Detailed — shows conditions and events
kubectl describe hpa web-api-hpa -n ckaquest
```

Common conditions:
- `AbleToScale: True` — HPA can communicate with the scale target
- `ScalingActive: True` — metrics are available, HPA is working
- `ScalingLimited: True` — at min or max replicas boundary

## Memory-based HPA

```yaml
metrics:
  - type: Resource
    resource:
      name: memory
      target:
        type: AverageValue
        averageValue: 200Mi    # absolute memory per pod (not %)
```

Note: Memory-based HPA requires `type: AverageValue` not `Utilization`,
because memory doesn't have a clean "utilization percentage" concept
(memory isn't returned to the system when freed in most runtimes).

## metrics-server requirement

HPA requires **metrics-server** to be running in the cluster.
k3s ships with metrics-server by default. On kubeadm clusters:

```bash
# Check if metrics-server is running
kubectl get deployment metrics-server -n kube-system

# If missing, install
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## CKA exam tip

Two HPA commands you must know:
1. `kubectl autoscale deployment <name> --cpu-percent=<N> --min=<m> --max=<M>`
2. `kubectl set resources deployment <name> --requests=cpu=<N>`

And the diagnostic: `kubectl describe hpa <name>` to read the scaling conditions.

## Interview question

**Q: Why does an HPA show `<unknown>` for CPU metrics?**

A: HPA calculates CPU utilization as actual CPU usage divided by CPU request.
If the target pods have no `resources.requests.cpu` defined, there is no
baseline to divide by — the percentage is undefined, shown as `<unknown>`.
The fix is always to add CPU requests to the container spec. Additionally,
`<unknown>` can appear briefly after pod startup while metrics-server
hasn't yet scraped the new pod, or if metrics-server itself is not running.
