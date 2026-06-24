# Debrief: OOMKilled

## What happened?

The pod's memory limit was set to 2Mi. nginx requires ~20-30Mi just to start,
and at least 64Mi for stable operation. The Linux kernel's OOM killer
terminated the container as soon as it tried to use more memory than allowed.

## How to diagnose OOMKilled

```bash
kubectl describe pod web -n ckaquest
```

Look for:
```
Last State:  Terminated
  Reason:    OOMKilled
  Exit Code: 137
```

Exit code 137 = 128 + 9 (SIGKILL). The kernel sent SIGKILL to the process.

## Resource model in Kubernetes

```
requests: what the scheduler uses to find a node with enough capacity
limits:   the hard ceiling — container is killed if it exceeds this
```

Best practice:
- Set requests = your app's typical usage
- Set limits = your app's maximum acceptable usage
- ratio limit/request is typically 1x–2x

## CKA exam tip

Common OOM patterns you'll see:
1. Limit too low (this level)
2. Memory leak — app grows until it hits limit
3. Heap dump / core dump triggered at startup

On the exam: `kubectl describe pod` first, look for OOMKilled reason,
then fix the limit.

## Interview question

**Q: What exit code does an OOMKilled container show?**

A: Exit code 137 (128 + signal 9 / SIGKILL). The kernel's OOM killer
sends SIGKILL to the container process when it exceeds its memory limit.
