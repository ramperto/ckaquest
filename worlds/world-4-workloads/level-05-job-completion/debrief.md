# Debrief: Job — Fix the Failing Backup

## What is a Kubernetes Job?

A Job runs a pod to **completion** (exit code 0) rather than keeping it
running indefinitely. When the pod succeeds, the Job is marked `Complete`.

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: db-backup
spec:
  completions: 1       # how many successful completions needed (default: 1)
  parallelism: 1       # pods running simultaneously (default: 1)
  backoffLimit: 4      # retry on failure up to this many times (default: 6)
  template:
    spec:
      restartPolicy: Never   # or OnFailure — Never creates a new pod per retry
      containers:
        - name: backup
          image: busybox:1.36
          command: ["sh", "-c", "echo backup OK"]
```

## restartPolicy choices

| Value | Behaviour |
|-------|-----------|
| `Never` | New pod created on each failure (records per-attempt history) |
| `OnFailure` | Same pod restarted on failure (fewer pods, loses per-attempt logs) |

Use `Never` when you need logs from each attempt. Use `OnFailure` to keep
the pod count low for fast-retry workloads.

## Job immutability

**A Job's pod template is immutable.** You cannot patch the command, image,
or env of an existing Job. The workflow is always:

```bash
kubectl delete job <name>
kubectl apply -f fixed-job.yaml
```

## Diagnosing failed Jobs

```bash
# Check overall status
kubectl get job db-backup -n ckaquest

# Why did it fail?
kubectl describe job db-backup -n ckaquest
kubectl get pods -n ckaquest -l job-name=db-backup
kubectl logs -n ckaquest -l job-name=db-backup

# Events
kubectl get events -n ckaquest --sort-by='.lastTimestamp' | grep backup
```

## backoffLimit and failure modes

`backoffLimit: 2` means: try up to 3 times total (1 initial + 2 retries).
After exhaustion, the Job gets condition `type: Failed, status: True`.
No further pods are created.

```bash
kubectl get job db-backup -n ckaquest \
  -o jsonpath='{.status.conditions[*].type}'
# Failed
```

## Parallel Jobs

```yaml
spec:
  completions: 5     # need 5 successes total
  parallelism: 2     # run 2 pods at a time
  backoffLimit: 3
```

Runs 2 pods in parallel, creates new pods until 5 succeed.
Useful for parallel batch processing (image resizing, data exports, etc.).

## CKA exam tip

Know the three Job patterns:
1. **Single job**: `completions: 1` (default)
2. **Fixed completion count**: `completions: N, parallelism: 1`
3. **Work queue**: `completions: N, parallelism: N`

Also know CronJob (next level) which creates Jobs on a schedule.

## Interview question

**Q: What happens when a Kubernetes Job's pod fails?**

A: The Job controller creates a new pod (if `restartPolicy: Never`) or
restarts the same pod (if `restartPolicy: OnFailure`). This repeats until
either a pod exits 0 (Job completes) or the failure count reaches
`backoffLimit` (Job is marked Failed with no more retries). Failed pods
are kept for log inspection until the Job or its TTL expires.
