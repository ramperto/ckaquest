# Debrief: Liveness Probe Failure

## What happened?

The liveness probe was checking `GET /healthz` on port 80. nginx's default
configuration doesn't expose a `/healthz` endpoint — it returns HTTP 404.

Kubernetes treats any non-2xx response as a probe failure. After 3 consecutive
failures (`failureThreshold: 3`), it restarts the container. Since the app
never changes, it keeps failing and restarting.

## Liveness vs Readiness vs Startup probes

| Probe | Purpose | On failure |
|-------|---------|------------|
| **liveness** | Is the container alive? | Restart container |
| **readiness** | Is the container ready for traffic? | Remove from Service endpoints |
| **startup** | Has the app finished starting? | Restart (for slow-starting apps) |

## Probe types

```yaml
# HTTP (most common)
livenessProbe:
  httpGet:
    path: /health
    port: 8080

# TCP (check if port is open)
livenessProbe:
  tcpSocket:
    port: 8080

# Exec (run command in container)
livenessProbe:
  exec:
    command: ["cat", "/tmp/healthy"]
```

## Probe tuning parameters

```yaml
initialDelaySeconds: 15    # wait before first check (give app time to start)
periodSeconds: 10          # check every 10s
failureThreshold: 3        # fail 3 times before restarting
successThreshold: 1        # 1 success = healthy
timeoutSeconds: 1          # probe must respond within 1s
```

## CKA exam tip

When a pod keeps restarting with exit code 0 or 137:
- Check liveness probe configuration: `kubectl describe pod | grep -A10 Liveness`
- Count restarts: `kubectl get pod` (RESTARTS column)
- Distinguish: crash (app bug) vs probe failure (wrong health check config)

## Interview question

**Q: When would you use a startup probe vs an initialDelaySeconds?**

A: `initialDelaySeconds` is a fixed wait before the first liveness check.
A startup probe is more flexible — it runs a separate probe at startup with
its own `failureThreshold * periodSeconds` window. Once the startup probe
succeeds, liveness/readiness probes take over. Use startup probes for apps
that take variable time to initialize (e.g., JVM apps, database migrations).
