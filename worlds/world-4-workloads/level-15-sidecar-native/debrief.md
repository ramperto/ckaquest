# Debrief: Native Sidecar Containers (KEP-753)

## What are native sidecar containers?

Native sidecar containers (introduced in Kubernetes 1.28, GA in 1.29) are
init containers with `restartPolicy: Always`. Unlike regular init containers
that must complete before the main container starts, native sidecars:

1. **Start before** main containers (like regular init containers)
2. **Run alongside** main containers (unlike regular init containers)
3. **Stop after** main containers during pod termination

```yaml
spec:
  initContainers:
    - name: log-agent
      image: busybox:1.36
      restartPolicy: Always    # THIS makes it a native sidecar
      command: ["sh", "-c", "while true; do echo collecting...; sleep 5; done"]
  containers:
    - name: main-app
      image: nginx:1.25
```

## Regular init container vs native sidecar

| Aspect | Regular Init Container | Native Sidecar |
|--------|----------------------|----------------|
| `restartPolicy` | Not set (defaults to pod policy) | `Always` |
| **Must complete?** | Yes — blocks main containers | No — runs forever |
| **Runs alongside main?** | No | Yes |
| **Startup order** | Before main containers | Before main containers |
| **Shutdown order** | N/A (already exited) | After main containers |
| **Counted in READY** | No | Yes (shows in x/y ready count) |
| **Resource accounting** | Max of init vs sum of containers | Added to sum of containers |

## Lifecycle ordering

```
Pod startup:
  1. Init container 1 starts and completes
  2. Init container 2 (sidecar, restartPolicy: Always) starts
     --> does NOT need to complete, proceeds immediately
  3. Main containers start
     --> sidecar continues running alongside

Pod shutdown:
  1. Main containers receive SIGTERM and stop
  2. Sidecar containers receive SIGTERM and stop
     --> sidecars get a chance to flush logs, close connections, etc.
```

## Before native sidecars (the old pattern)

Before Kubernetes 1.28, sidecar containers were placed in the `containers`
array alongside the main container:

```yaml
# Old pattern — sidecar in containers array
spec:
  containers:
    - name: main-app
      image: nginx:1.25
    - name: log-agent          # "sidecar" but no ordering guarantees
      image: busybox:1.36
      command: ["sh", "-c", "while true; do echo collecting...; sleep 5; done"]
```

Problems with the old pattern:
- No startup ordering — sidecar might start after main container
- No shutdown ordering — sidecar might stop before main container
- Sidecar could prevent Job completion (Job waits for ALL containers to exit)
- No way to distinguish "helper" from "application" containers

## Common use cases for native sidecars

| Use Case | Sidecar | Purpose |
|----------|---------|---------|
| **Log collection** | Fluentd, Filebeat | Ship logs to centralized system |
| **Service mesh** | Envoy, Istio proxy | Manage network traffic |
| **Secret injection** | Vault agent | Inject/rotate secrets |
| **Monitoring** | Prometheus exporter | Expose metrics |
| **Debugging** | tcpdump, strace | Capture network/system activity |

## Native sidecars and Jobs

One of the biggest motivations for native sidecars: **Jobs**.

```yaml
# Old problem: Job never completes because sidecar runs forever
apiVersion: batch/v1
kind: Job
spec:
  template:
    spec:
      containers:
        - name: worker
          image: busybox
          command: ["sh", "-c", "echo done"]
        - name: sidecar       # runs forever — Job never completes!
          image: envoy

# Solution: native sidecar — Job completes when main container exits
apiVersion: batch/v1
kind: Job
spec:
  template:
    spec:
      initContainers:
        - name: sidecar
          image: envoy
          restartPolicy: Always   # native sidecar — stops after main
      containers:
        - name: worker
          image: busybox
          command: ["sh", "-c", "echo done"]
      restartPolicy: Never
```

## Resource accounting

Native sidecars change how resource requests/limits are calculated:

```
# Regular init containers:
effective = max(sum(containers), max(initContainers))

# With native sidecars:
effective = max(sum(containers) + sum(sidecars), max(regularInitContainers) + sum(sidecars))
```

This means sidecar resources are ADDED to the total, not taken as the max.

## Probe support

Native sidecars support all standard probes:

```yaml
initContainers:
  - name: log-agent
    image: busybox:1.36
    restartPolicy: Always
    startupProbe:
      exec:
        command: ["test", "-f", "/tmp/ready"]
      periodSeconds: 5
    livenessProbe:
      exec:
        command: ["pgrep", "-f", "log-agent"]
      periodSeconds: 10
```

The startup probe on a sidecar gates when main containers can start.

## Diagnosing native sidecar issues

```bash
# Check pod status — native sidecars show in init container count
kubectl get pod app-with-sidecar -n ckaquest
# STATUS: Init:0/1 means init container running but blocking (no restartPolicy: Always)
# STATUS: Running with READY 2/2 means sidecar + main both running

# Check init container restart policy
kubectl get pod app-with-sidecar -n ckaquest \
  -o jsonpath='{.spec.initContainers[0].restartPolicy}'

# Check init container status
kubectl get pod app-with-sidecar -n ckaquest \
  -o jsonpath='{.status.initContainerStatuses[0].state}'

# Check if main container is waiting for init
kubectl describe pod app-with-sidecar -n ckaquest | grep -A10 "Init Containers"
```

## CKA exam tip

Native sidecar containers are a newer feature (GA in Kubernetes 1.29) and
are increasingly likely to appear on updated CKA exams. Key points:

1. They are init containers with `restartPolicy: Always` — nothing else changes
2. They solve the "sidecar prevents Job completion" problem
3. They provide startup/shutdown ordering guarantees
4. Check the Kubernetes version in the exam environment — if >= 1.28, this
   feature is available
5. The field is `restartPolicy` at the **container level** (not the pod level)

## Interview question

**Q: What problem do native sidecar containers solve that regular
multi-container pods cannot?**

A: Native sidecar containers (init containers with `restartPolicy: Always`)
solve three key problems: (1) **Startup ordering** — sidecars start before
main containers, ensuring dependencies like service mesh proxies or secret
agents are ready. (2) **Shutdown ordering** — sidecars stop after main
containers, allowing log flushers to capture final output. (3) **Job
completion** — with regular multi-container pods, a sidecar running forever
prevents Jobs from completing. Native sidecars are automatically terminated
after the main container exits, allowing the Job to complete normally.
These guarantees were previously impossible without custom shutdown scripts
or preStop hooks.
