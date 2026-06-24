# Debrief: ClusterIP — Wrong targetPort

## What happened?

The Service's `targetPort` was set to 8080, but nginx listens on port 80.
kube-proxy programs iptables/IPVS rules to forward traffic to `<pod-IP>:targetPort`.
When nothing listens on that port, the connection is refused.

Endpoints were populated (selector matched), so the symptom was:
- `kubectl get endpoints` → shows pod IPs ✓
- `curl backend-svc` → connection refused ✗

This is the classic "endpoints exist but still broken" pattern.

## Service port fields

```yaml
spec:
  ports:
    - port: 80          # Port clients use to reach the Service (Service's own port)
      targetPort: 80    # Port on the Pod that receives traffic
      nodePort: 30080   # (NodePort/LoadBalancer only) external port on every node
      protocol: TCP
      name: http        # Optional name (required for multi-port services)
```

`targetPort` can be a number OR a named port:
```yaml
# Pod:
containerPort: 8080
name: http-port

# Service:
targetPort: http-port   # References the named port — survives port changes
```

## Debugging connectivity layer by layer

```
1. Are pods Running?
   kubectl get pods -n <ns>

2. Does service have endpoints?
   kubectl get endpoints <svc> -n <ns>
   → no endpoints: selector mismatch
   → has endpoints: port or NetworkPolicy issue

3. Can we reach the pod directly?
   kubectl exec <client> -- wget http://<pod-ip>:80
   → works: service targetPort is wrong
   → fails: app not listening / NetworkPolicy

4. Can we reach via service?
   kubectl exec <client> -- wget http://<svc-name>
   → works: everything fine
   → fails: DNS or port issue
```

## CKA exam tip

The `port` vs `targetPort` confusion is a frequent exam trap. Always:
1. Check what port the container actually exposes (`containerPort` in pod spec)
2. Make sure `targetPort` matches that

Named ports add resilience — change the container port number without
updating every Service that references it.

## Interview question

**Q: What is the difference between port, targetPort, and nodePort in a Service?**

A: `port` is the Service's own port — what clients inside the cluster use.
`targetPort` is where traffic is forwarded to on the selected Pods.
`nodePort` (only for NodePort/LoadBalancer types) is the port opened on
every cluster node for external access. Traffic path:
`external:nodePort → Service:port → Pod:targetPort`
