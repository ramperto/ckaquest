# Debrief: Multi-Container Pod — Sidecar CrashLoopBackOff

## What happened?

The sidecar container tried to `tail` files including `/WRONG_PATH/error.log`,
a path that doesn't exist. `tail -f` on a non-existent file returns exit code 1,
causing CrashLoopBackOff for that specific container.

The web container was completely fine — one crashing container doesn't stop
other containers in the same pod, it just keeps the READY count short (1/2).

## Multi-container pod patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| **Sidecar** | Helper container enhancing main app | Log collector, service mesh proxy |
| **Ambassador** | Proxy between app and external service | Database proxy |
| **Adapter** | Transform/normalize app output | Metrics converter |

## Container-specific kubectl commands

```bash
# Logs for a specific container
kubectl logs <pod> -c <container> -n <ns>
kubectl logs <pod> -c <container> -n <ns> --previous  # last crash

# Exec into a specific container
kubectl exec <pod> -c <container> -n <ns> -- sh

# Describe shows all containers
kubectl describe pod <pod> -n <ns>
```

## Shared volumes between containers

Containers in the same pod can share volumes:

```yaml
spec:
  volumes:
    - name: shared-data
      emptyDir: {}
  containers:
    - name: main
      volumeMounts:
        - name: shared-data
          mountPath: /data
    - name: sidecar
      volumeMounts:
        - name: shared-data
          mountPath: /data   # Same volume, same data
```

This is how the log-collector pattern works — both containers mount the
same `emptyDir`, the web server writes logs there, sidecar reads them.

## Interpreting READY column

```
READY
1/2    = 1 container ready out of 2 total
2/2    = all containers ready
0/1    = single container not ready
```

## CKA exam tip

For multi-container pods, always specify `-c <container-name>` when running
`kubectl logs` or `kubectl exec`. Without it, kubectl picks the first container.

## Interview question

**Q: What is the sidecar pattern and why is it useful?**

A: The sidecar pattern places a helper container alongside the main application
container in the same pod. They share the same network namespace (can communicate
via localhost) and can share volumes. Common uses: log forwarding, service mesh
proxies (Envoy/Istio), secrets injection (Vault agent), metrics collection.
The sidecar lifecycle is coupled to the main container — if the pod is deleted,
both go away. This differs from DaemonSets which run node-level helpers independently.
