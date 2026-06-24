# Debrief: Readiness Probe — Pod Not Ready

## What happened?

The readiness probe was checking `HTTP GET / on port 8080`. nginx only
listens on port 80 (by default). Every probe attempt got "connection refused",
so the pod never became Ready and was never added to Service endpoints.

## Liveness vs Readiness — the key difference

```
Liveness failure  → container RESTARTED
Readiness failure → pod REMOVED from Service endpoints (not restarted)
```

The pod stays Running with a failing readiness probe. It just gets no traffic.
This is intentional: if your app is temporarily overloaded or initializing,
you want it to stop receiving traffic, not get killed and restarted.

## 0/1 READY explained

```bash
kubectl get pods -n ckaquest
NAME   READY   STATUS    RESTARTS
web    0/1     Running   0
       ^^^
       containers ready / containers total
```

`0/1` = pod is Running but readiness probe is failing.
`1/1` = pod is Running and ready to receive traffic.

## CKA exam tip

If a pod is `Running` but `0/1 READY` and has no restarts:
→ Readiness probe is failing
→ `kubectl describe pod` → look at "Readiness" and "Events"
→ Usually wrong port, wrong path, or app not fully initialized

## Interview question

**Q: A deployment has 3 pods. All show 0/1 READY. What do you check?**

A: First check `kubectl describe pod <any pod>` to see the readiness probe
details and failure events. Common causes: wrong port, wrong path, app
startup taking longer than `initialDelaySeconds`, or a dependency (database,
config service) not being reachable. Also check `kubectl get endpoints` for
the service — if 0/1 READY, there should be zero endpoints.
