# Debrief: Multi-Port Service — Missing Port Names

## Why multi-port Services need named ports

When a Service exposes only one port, no name is required. But the moment
you add a second port, **every port MUST have a unique name**. This is a
Kubernetes API validation rule.

Why? Because other resources reference service ports by name:

```yaml
# Ingress backend references a port by name
backend:
  service:
    name: multi-svc
    port:
      name: http        # not ambiguous

# NetworkPolicy uses port name
ports:
  - port: https         # references the named port
    protocol: TCP
```

Without names, these references would be ambiguous when multiple ports exist.

## Service port fields explained

```yaml
ports:
  - name: http          # unique identifier for this port
    port: 80            # port exposed on the Service (ClusterIP)
    targetPort: 80      # port on the container to forward to
    protocol: TCP       # TCP (default), UDP, or SCTP
```

| Field        | Description                                           |
|--------------|-------------------------------------------------------|
| `name`       | Unique name within the Service (required if >1 port)  |
| `port`       | The port number on the Service's ClusterIP             |
| `targetPort` | The port on the pod/container that receives traffic    |
| `protocol`   | Protocol (TCP, UDP, SCTP). Default: TCP                |
| `nodePort`   | NodePort number (only for type: NodePort/LoadBalancer) |

## targetPort — numbers vs names

`targetPort` can be a **number** or a **string** (referencing a named
container port):

```yaml
# By number — must match containerPort exactly
targetPort: 80

# By name — references the container port's name field
targetPort: http
```

Using named targetPorts is more flexible. If the container port number
changes (e.g., 8080 to 9090), you only update the Pod spec — the Service
keeps referencing the name and still works.

```yaml
# Container spec
ports:
  - name: http
    containerPort: 8080   # can change freely

# Service spec
ports:
  - name: http
    port: 80
    targetPort: http      # always resolves to the current containerPort
```

## Port naming conventions

Kubernetes and Istio/service mesh tools use port names for protocol
detection. Common conventions:

| Name Pattern       | Protocol Detected |
|--------------------|-------------------|
| `http`, `http-*`   | HTTP              |
| `https`, `https-*` | HTTPS             |
| `grpc`, `grpc-*`   | gRPC              |
| `tcp`, `tcp-*`     | TCP (generic)     |
| `udp`, `udp-*`     | UDP               |

If you use Istio, port names like `http` or `grpc` enable automatic
protocol detection for traffic management and telemetry.

## Common multi-port mistakes

1. **Missing port names** — API rejects or silently breaks references
2. **Wrong targetPort** — traffic sent to a port where nothing listens
3. **Duplicate port names** — names must be unique within a Service
4. **Protocol mismatch** — e.g., UDP service pointing to a TCP container

## Debugging multi-port Services

```bash
# Check service ports
kubectl get svc multi-svc -n ckaquest -o yaml

# Check endpoints — should show IPs with port mappings
kubectl get endpoints multi-svc -n ckaquest -o yaml

# Check container ports
kubectl get pod multi-app -n ckaquest -o jsonpath='{.spec.containers[0].ports}' | python3 -m json.tool

# Test connectivity to each port
kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- \
  wget -qO- --timeout=3 multi-svc.ckaquest:80

kubectl run test --image=busybox:1.36 --rm -it --restart=Never -- \
  wget -qO- --timeout=3 --no-check-certificate https://multi-svc.ckaquest:443
```

## CKA exam tip

Multi-port Services **MUST have named ports**. The API server rejects
the manifest without them. On the CKA exam, if you see a Service with
multiple ports, immediately check:

1. Every port has a `name`
2. Each `targetPort` matches the actual container port
3. Names are unique within the Service

This is a quick, high-confidence fix that earns points fast.

## Interview question

**Q: What happens if a Service's targetPort doesn't match any container
port?**

A: The Service will still be created and endpoints will be populated
(endpoints are based on selector matching, not port validation). However,
traffic forwarded to that targetPort will be refused or dropped because
nothing is listening on it inside the container. This is a common
misconfiguration that results in "connection refused" errors. You can
diagnose it by comparing `kubectl get svc -o yaml` targetPorts against
`kubectl get pod -o yaml` containerPorts.
