# Debrief: NodePort — Expose to the Outside World

## Service types recap

| Type | Access | Use case |
|------|--------|---------|
| `ClusterIP` | Inside cluster only | Internal services |
| `NodePort` | `<node-ip>:<nodePort>` | Dev/test external access |
| `LoadBalancer` | Cloud load balancer IP | Production external access |
| `ExternalName` | DNS CNAME alias | Abstract external services |

## NodePort internals

kube-proxy opens the `nodePort` (30000-32767) on **every node** in the cluster,
even nodes that don't host the pods. Traffic routes like:

```
External client
  → node-ip:30080
    → ClusterIP:80 (iptables/IPVS)
      → pod-ip:80
```

This means you can hit any node's IP with the nodePort, and kube-proxy
handles routing to the actual pods.

## Create service quickly on CKA exam

```bash
# From a Deployment
kubectl expose deployment webapp \
  --type=NodePort --port=80 --name=webapp-svc -n ckaquest

# From a Pod
kubectl expose pod mypod \
  --type=NodePort --port=80 --name=mypod-svc -n ckaquest

# Then patch the nodePort if a specific one is required
kubectl patch svc webapp-svc -n ckaquest \
  --type=json \
  -p='[{"op":"replace","path":"/spec/ports/0/nodePort","value":30080}]'
```

## CKA exam tip

For NodePort questions on the exam:
1. Create the service imperatively with `kubectl expose`
2. Patch the nodePort if a specific value is required
3. Verify: `curl <node-ip>:<nodePort>` or `kubectl get svc`
4. The nodePort range is **30000-32767** — outside this range = rejected

## Interview question

**Q: When would you choose NodePort over LoadBalancer?**

A: NodePort works in any environment (including bare-metal and on-prem)
without requiring a cloud provider. LoadBalancer requires a cloud provider
integration (AWS ELB, GCP LB, etc.) or MetalLB on bare-metal.
Use NodePort for: development clusters, testing, or as the backend when
you manage your own external load balancer. Use LoadBalancer in cloud
environments where you need a managed, stable external IP.
