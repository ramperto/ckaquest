# Debrief: Volume — Wrong Mount Path

## The silent data loss bug

A wrong `mountPath` is dangerous because the pod runs normally — no errors.
Writes simply go to the ephemeral container filesystem instead of the PVC,
so all data is lost when the pod restarts.

```yaml
volumeMounts:
  - name: data-vol
    mountPath: /app/storage   # volume mounted here
                              # but app writes to /app/data → NOT persisted
```

## Volume mount anatomy

```yaml
spec:
  volumes:
    - name: data-vol           # ← logical name
      persistentVolumeClaim:
        claimName: webapp-pvc  # ← which PVC to use

  containers:
    - name: webapp
      volumeMounts:
        - name: data-vol       # ← must match volume name above
          mountPath: /app/data # ← where it appears inside the container
          readOnly: false       # ← optional, default false
          subPath: subdir       # ← optional, mount a subdirectory
```

## Multiple volumes in one pod

```yaml
volumes:
  - name: config-vol
    configMap:
      name: app-config
  - name: data-vol
    persistentVolumeClaim:
      claimName: webapp-pvc
  - name: tmp-vol
    emptyDir: {}

containers:
  - volumeMounts:
      - name: config-vol
        mountPath: /etc/app
      - name: data-vol
        mountPath: /app/data
      - name: tmp-vol
        mountPath: /tmp
```

## subPath — mounting a single file or subdirectory

```yaml
volumeMounts:
  - name: data-vol
    mountPath: /app/data/uploads   # mount only this subdir
    subPath: uploads               # relative path within the volume
```

Useful when one PVC holds data for multiple apps in different subdirectories.

## Diagnosing wrong mount paths

```bash
# Check what's mounted where
kubectl describe pod <name> | grep -A20 "Mounts:"

# Check what actually exists inside the container
kubectl exec <pod> -- df -h
kubectl exec <pod> -- ls /app/data
kubectl exec <pod> -- ls /app/storage
```

## CKA exam tip

Volume name links `spec.volumes[].name` to `spec.containers[].volumeMounts[].name`.
The `mountPath` is where the volume appears INSIDE the container — it must match
what the application actually uses.

Fixing mountPath on a running Deployment triggers a rolling update automatically
(pod template changed → new RS created).

## Interview question

**Q: How do you mount a specific subdirectory of a PVC into a container?**

A: Use `subPath` in the volumeMount spec. For example:
`mountPath: /app/logs` with `subPath: app-logs` mounts only the `app-logs`
subdirectory of the PVC at `/app/logs` inside the container. This lets
multiple pods or containers share one large PVC, each accessing different
subdirectories without interfering with each other.
