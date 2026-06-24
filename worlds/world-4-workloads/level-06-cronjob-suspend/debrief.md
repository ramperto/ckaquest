# Debrief: CronJob — Unsuspend the Report Generator

## CronJob structure

A CronJob creates a Job on a schedule (Unix cron syntax):

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: report-generator
spec:
  schedule: "*/5 * * * *"   # every 5 minutes
  suspend: false             # if true, no Jobs are created
  jobTemplate:               # template for each Job
    spec:
      template:
        spec:
          restartPolicy: Never
          containers:
            - name: reporter
              image: busybox:1.36
              command: ["sh", "-c", "echo report"]
```

## Cron schedule syntax

```
┌───────── minute        (0-59)
│ ┌──────── hour          (0-23)
│ │ ┌─────── day of month  (1-31)
│ │ │ ┌────── month         (1-12)
│ │ │ │ ┌───── day of week   (0-6, 0=Sunday)
│ │ │ │ │
* * * * *

Examples:
  "0 2 * * *"      → every day at 02:00
  "*/15 * * * *"   → every 15 minutes
  "0 0 * * 0"      → every Sunday midnight
  "@daily"         → alias for "0 0 * * *"
  "@hourly"        → alias for "0 * * * *"
```

## Key CronJob fields

```yaml
spec:
  schedule: "*/5 * * * *"
  suspend: false
  successfulJobsHistoryLimit: 3    # keep last 3 succeeded Jobs (default: 3)
  failedJobsHistoryLimit: 1        # keep last 1 failed Job (default: 1)
  concurrencyPolicy: Forbid        # Allow | Forbid | Replace
  startingDeadlineSeconds: 60      # seconds after missed schedule to still run
```

**concurrencyPolicy**:
- `Allow` (default) — concurrent Jobs permitted
- `Forbid` — skip new Job if previous is still running
- `Replace` — delete running Job, start new one

## Triggering a manual run

Don't wait for the schedule — create a Job immediately:

```bash
kubectl create job <job-name> --from=cronjob/<cronjob-name> -n <namespace>
```

This creates a Job with the same template as the CronJob. Useful for:
- Testing the CronJob works
- Running an on-demand batch job

## Suspend use cases

```bash
# Suspend (pause) — e.g. during maintenance
kubectl patch cronjob report-generator -p '{"spec":{"suspend":true}}'

# Unsuspend (resume)
kubectl patch cronjob report-generator -p '{"spec":{"suspend":false}}'
```

Suspended CronJobs do NOT create Jobs for missed schedules when unsuspended
(unless `startingDeadlineSeconds` allows catchup).

## CKA exam tip

Know the CronJob YAML structure from memory. The `jobTemplate` nesting trips
people up — it mirrors a Job spec under `spec.jobTemplate.spec`.

Also remember `kubectl create job --from=cronjob/...` for manual triggering.

## Interview question

**Q: How do CronJobs handle missed schedules?**

A: If a CronJob misses its scheduled time (e.g. the controller was down),
it will catch up with missed runs IF the missed count is less than 100 AND
`startingDeadlineSeconds` permits it. If more than 100 schedules were missed,
the CronJob will not be scheduled and logs an error. `concurrencyPolicy` controls
what happens when a previous run hasn't finished before the next schedule fires.
