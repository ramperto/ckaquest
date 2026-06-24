# Debrief: Init Container Stuck

## What happened?

The pod had an init container that checked if `db-service:5432` was reachable.
No such service existed, so the init container looped forever and the main
app container never started.

## Init container fundamentals

```
Pod lifecycle with init containers:

[Init container 1] → must exit 0
       ↓
[Init container 2] → must exit 0
       ↓
[Main containers] → start in parallel
```

Init containers are sequential and must succeed. If any init container fails
or loops, the main containers never start.

## Common init container use cases

| Use case | Example |
|----------|---------|
| Wait for dependency | Wait for database/cache to be ready |
| Database migration | Run schema migrations before app starts |
| Download config | Fetch secrets or config from vault |
| Set up shared volume | Prepare files for the main container |

## Reading init container logs

```bash
# Init container logs (use -c to select container)
kubectl logs <pod> -c <init-container-name> -n <ns>

# Pod status shows init progress
kubectl get pod <name> -n <ns>
# Init:0/1 = 0 of 1 init containers done
# Init:1/2 = 1 of 2 init containers done
# PodInitializing = all init containers done, main starting
```

## CKA exam tip

`Init:0/1` or `PodInitializing` in pod status means:
- Init containers haven't all completed yet
- Check init container logs: `kubectl logs <pod> -c <init-container>`
- Look for what it's waiting on (service, file, network endpoint)

## Interview question

**Q: Can init containers share volumes with the main container?**

A: Yes. Volumes defined in the pod spec are accessible to both init containers
and main containers. This is commonly used to pass files between them —
for example, an init container downloads a config file into a shared volume
that the main container reads on startup.
