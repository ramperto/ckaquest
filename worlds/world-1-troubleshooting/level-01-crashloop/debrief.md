# Debrief: CrashLoopBackOff

## What happened?

The pod spec overrode the container's default entrypoint with a custom `command`.
The path `/bin/shh` doesn't exist inside the container — it's a typo of `/bin/sh`.

Kubernetes tries to start the container, the process immediately fails with
"no such file or directory", and the container exits with a non-zero code.
After a few restarts, Kubernetes applies exponential backoff — that's the
"BackOff" in CrashLoopBackOff.

## Mental model

```
Pod created → container starts → process exits (non-zero) → restart
                                                             ↑
                          backoff: 10s → 20s → 40s → 160s ──┘
                          (CrashLoopBackOff)
```

## CrashLoopBackOff causes (CKA exam favorites)

| Cause | How to spot |
|-------|-------------|
| Bad command/entrypoint | `kubectl logs` shows exec error |
| App crash on startup | `kubectl logs` shows app traceback |
| Missing env var / config | App logs show config error |
| Missing volume mount | App logs show file not found |
| OOMKilled | `kubectl describe` shows OOMKilled reason |

## Commands you practiced

```bash
kubectl describe pod <name> -n <ns>   # Events + container state
kubectl logs <name> -n <ns>           # stdout/stderr of container
kubectl logs <name> -n <ns> --previous  # logs from PREVIOUS restart
kubectl delete pod <name> -n <ns>     # delete to recreate
kubectl run <name> --image=<img> -n <ns>  # quick pod creation
```

## CKA exam tip

On the CKA, you'll often get a pod in CrashLoopBackOff. Always start with:
1. `kubectl describe pod` — check Events and container state
2. `kubectl logs --previous` — see logs from the crash
3. Identify root cause, then delete + recreate (can't patch most pod fields)

## Real-world example

A common production incident: deployment to a new cluster where the base
image changed from Debian (has `/bin/bash`) to Alpine (only has `/bin/sh`).
Scripts using `/bin/bash` break immediately. Same pattern, same debugging flow.

## Interview question

**Q: What's the difference between CrashLoopBackOff and Error?**

A: Both mean the container exited non-zero. CrashLoopBackOff means it has
crashed multiple times and Kubernetes is applying exponential backoff before
restarting again. "Error" is the immediate state right after a crash, before
the backoff delay kicks in.
