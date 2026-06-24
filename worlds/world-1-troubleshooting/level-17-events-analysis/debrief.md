# Level 17 Debrief: Events Analysis — Cascading Failures

## What Happened

Two bugs were stacked on top of each other:

1. **Missing ServiceAccount** — The Deployment referenced `serviceAccountName: app-runner`,
   but the ServiceAccount didn't exist. This prevented the pod from being created properly.
2. **Wrong Service targetPort** — The Service targeted port 8080, but nginx listens on
   port 80. Even after the pod started, the Service wouldn't route traffic correctly.

## Using kubectl Events for Diagnosis

Kubernetes events are the most important troubleshooting tool. They record what the
control plane tried to do and what went wrong.

### Key Commands

```bash
# Get events sorted by time (most recent last)
kubectl get events -n ckaquest --sort-by='.lastTimestamp'

# Get events for a specific resource
kubectl describe pod <pod-name> -n ckaquest
# (Events section at the bottom)

# Watch events in real-time
kubectl get events -n ckaquest --watch

# Filter by type (Warning events are problems)
kubectl get events -n ckaquest --field-selector type=Warning
```

### Event Types

- **Normal** — Expected operations: pulling images, scheduling, starting containers
- **Warning** — Problems: failed scheduling, failed image pull, back-off, missing resources

### Event Fields

| Field | Meaning |
|-------|---------|
| `Type` | Normal or Warning |
| `Reason` | Machine-readable cause (e.g., FailedScheduling, Pulled) |
| `Object` | The resource the event is about |
| `Message` | Human-readable description of what happened |
| `Count` | How many times this event occurred |

## Cascading Failures

In production, failures rarely happen in isolation. A missing ServiceAccount causes
a pod to fail, which means the Service has no endpoints, which means health checks
fail, which triggers alerts. The key is to trace back to the root cause by reading
events chronologically.

### Diagnosis Strategy

1. Start with `kubectl get events --sort-by='.lastTimestamp'`
2. Look for the earliest Warning event
3. Fix that issue first
4. Re-check events for the next issue
5. Repeat until all Warnings are resolved

## CKA Exam Tips

- **Always check events first** when troubleshooting — they tell you exactly what went wrong
- `kubectl describe <resource>` shows events at the bottom of the output
- Events expire after 1 hour by default (configurable)
- For missing ServiceAccounts, `kubectl create serviceaccount <name> -n <ns>` is fastest
- After fixing a Deployment issue, you may need to delete existing failed pods or
  restart the rollout: `kubectl rollout restart deployment <name> -n <ns>`
