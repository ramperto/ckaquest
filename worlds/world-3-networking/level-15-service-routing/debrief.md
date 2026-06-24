# Debrief: Service Routing — Selector Typo + Failing Readiness Probe

## The two most common Service routing failures

When a Service doesn't route traffic, it's almost always one of these:

| Problem                     | Symptom                        | Diagnosis                           |
|-----------------------------|--------------------------------|-------------------------------------|
| Selector mismatch           | Endpoints empty                | `kubectl get endpoints <svc>`       |
| Readiness probe failure     | Pods exist but 0/1 Ready       | `kubectl get pods`, `describe pod`  |

This level had **both** bugs simultaneously, which is realistic — in
production, multiple small misconfigurations often compound.

## How Service routing works end-to-end

```
Client request
    |
    v
NodePort (30080) on every node
    |
    v
kube-proxy (iptables/ipvs rules)
    |
    v
Service ClusterIP (virtual IP)
    |
    v
Endpoints (pod IPs from selector match + Ready pods only)
    |
    v
Pod container (targetPort)
```

Every link in this chain must work:
1. Service selector must match pod labels
2. Pods must be **Ready** (readiness probe must pass)
3. targetPort must match the container port
4. The container must be listening on that port

## Readiness probes and endpoints

Kubernetes only adds a pod to Service endpoints when its readiness probe
passes. This is the **gate** between "pod is running" and "pod receives
traffic":

```
Pod Running + Readiness Passing  →  Added to Endpoints    →  Receives traffic
Pod Running + Readiness Failing  →  Removed from Endpoints →  No traffic
```

A pod can be Running (container is alive) but not Ready (readiness probe
fails). This is by design — it prevents traffic from reaching pods that
aren't fully initialized.

### Common readiness probe mistakes

| Mistake                              | Result                                  |
|--------------------------------------|-----------------------------------------|
| Wrong path (`/healthz` vs `/`)       | 404 response = probe fails              |
| Wrong port (8080 vs 80)              | Connection refused = probe fails        |
| Too aggressive timing                | App not ready before first check        |
| Probe succeeds but app not ready     | Traffic hits uninitialized app          |

## Debugging the full routing chain

```bash
# Step 1: Check endpoints
kubectl get endpoints frontend-svc -n ckaquest
# Empty? → selector mismatch or no Ready pods

# Step 2: Check selector match
kubectl get svc frontend-svc -n ckaquest -o jsonpath='{.spec.selector}'
kubectl get pods -n ckaquest --show-labels | grep frontend

# Step 3: Check pod readiness
kubectl get pods -n ckaquest -l app=frontend
# 0/1 READY? → readiness probe failing

# Step 4: Check probe details
kubectl describe pod <pod-name> -n ckaquest | grep -A 10 Readiness
kubectl describe pod <pod-name> -n ckaquest | grep -A 5 "Warning"

# Step 5: Test the probe path manually
kubectl exec <pod-name> -n ckaquest -- curl -s localhost/healthz
# 404? → wrong path

# Step 6: After fixing, verify endpoints populated
kubectl get endpoints frontend-svc -n ckaquest

# Step 7: Test end-to-end
curl -s localhost:30080
```

## NodePort Services

A NodePort Service exposes the application on a static port on every
node in the cluster:

```yaml
spec:
  type: NodePort
  ports:
    - port: 80           # ClusterIP port (internal)
      targetPort: 80     # container port
      nodePort: 30080    # exposed on every node (30000-32767)
```

Traffic flow: `<node-ip>:30080` -> Service -> Pod

| Field        | Range         | Description                           |
|--------------|---------------|---------------------------------------|
| `nodePort`   | 30000-32767   | Port on every node's external IP      |
| `port`       | 1-65535       | Port on the Service's ClusterIP       |
| `targetPort` | 1-65535       | Port on the container                 |

## readinessProbe vs livenessProbe vs startupProbe

| Probe Type    | Purpose                              | Failure Action              |
|---------------|--------------------------------------|-----------------------------|
| `readiness`   | Is the pod ready to serve traffic?   | Remove from endpoints       |
| `liveness`    | Is the pod alive?                    | Restart the container       |
| `startup`     | Has the pod finished starting up?    | Restart (disables others)   |

**Key insight for this level:** readiness probe failure does NOT restart
the pod — it only removes it from Service endpoints. The pod keeps running
but receives no traffic.

```yaml
readinessProbe:
  httpGet:
    path: /           # must return 200-399
    port: 80
  initialDelaySeconds: 2
  periodSeconds: 5
  failureThreshold: 3
  successThreshold: 1
```

## CKA exam tip

Service routing issues are a **staple** of the CKA exam. When debugging:

1. **Always start with endpoints** — `kubectl get endpoints <svc>`
2. If empty, check selector vs labels
3. If pods exist but 0/1 Ready, check readiness probes
4. If endpoints exist but traffic fails, check targetPort
5. For NodePort, verify the nodePort range (30000-32767)

The two-bug pattern (selector + readiness) is common in exams because
fixing just one doesn't solve the problem. Always verify end-to-end
after each fix.

## Interview question

**Q: A NodePort Service exists, pods are Running, but `curl <node-ip>:30080`
returns nothing. Walk through your debugging steps.**

A: First, `kubectl get endpoints <svc>` — if empty, compare the Service
selector with pod labels using `kubectl get svc -o yaml` and `kubectl get
pods --show-labels`. If selectors match but endpoints are still empty,
check if pods are Ready with `kubectl get pods` — look for 0/1 in the
READY column. If not Ready, `kubectl describe pod <name>` to see readiness
probe failures. Common causes: wrong probe path (404), wrong port, or
the application hasn't started yet. Fix the probe, wait for pods to
become Ready, then verify endpoints populate and `curl` succeeds.
