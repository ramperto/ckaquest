# Level 13 Debrief: subPath Volume Mount

## What Happened

The pod mounted an entire ConfigMap at `/etc/app/`, which placed both
`app.conf` and `logging.conf` in that directory. The app only needed
`app.conf`. By using `subPath: app.conf` on the volumeMount, we mounted
only the single file without replacing the directory contents.

## subPath Deep Dive

### The Problem with Directory Mounts

When you mount a ConfigMap or Secret as a volume at a directory path, Kubernetes
**replaces the entire directory** with the volume contents. Any files that were
already in that directory disappear.

```yaml
# This replaces ALL of /etc/app/ with ConfigMap contents
volumeMounts:
  - name: config-vol
    mountPath: /etc/app          # directory mount
```

### The subPath Solution

`subPath` lets you mount a **single file or subdirectory** from a volume at a
specific path without replacing the parent directory:

```yaml
# This mounts ONLY app.conf at /etc/app/app.conf
volumeMounts:
  - name: config-vol
    mountPath: /etc/app/app.conf   # full file path
    subPath: app.conf              # key from ConfigMap
```

### subPath vs items[]

There are two ways to select specific keys from a ConfigMap/Secret volume:

| Feature | subPath | items[] |
|---------|---------|---------|
| Syntax | On volumeMount | On volume definition |
| Mounts | Single file at a specific path | Selected files in a directory |
| Replaces directory | No | Yes (only selected items appear) |
| Auto-updates | No -- file is NOT updated when ConfigMap changes | Yes -- files update on ConfigMap change |
| Use case | Mount one file without touching the directory | Mount selected files, OK to replace directory |

#### Using items[] (alternative approach)

```yaml
volumes:
  - name: config-vol
    configMap:
      name: app-config
      items:
        - key: app.conf
          path: app.conf        # Only this file appears in the mount
```

This still replaces the directory, but only `app.conf` appears (not
`logging.conf`). However, if you need the directory to contain other files
too, `subPath` is the only option.

### subPath Limitations

| Limitation | Details |
|-----------|---------|
| No auto-update | When the ConfigMap/Secret changes, the subPath-mounted file is NOT updated. The pod must be restarted. |
| No symlink | subPath mounts are bind mounts, not symlinks. The kubelet mounts the file directly. |
| Security | `subPathExpr` with environment variables can be used for per-pod paths, but requires careful validation. |

### subPathExpr

For dynamic paths based on environment variables:

```yaml
containers:
  - name: app
    env:
      - name: POD_NAME
        valueFrom:
          fieldRef:
            fieldPath: metadata.name
    volumeMounts:
      - name: logs
        mountPath: /var/log/app
        subPathExpr: $(POD_NAME)     # Each pod gets its own subdirectory
volumes:
  - name: logs
    persistentVolumeClaim:
      claimName: shared-logs
```

### When to Use What

```
Need to mount one file without touching the directory?
  --> Use subPath

Need to select specific keys but OK to replace the directory?
  --> Use items[]

Need auto-updating config files?
  --> Use directory mount or items[] (NOT subPath)

Need per-pod subdirectories on shared storage?
  --> Use subPathExpr
```

### Common Commands

```bash
# Check what's mounted in a pod
kubectl exec <pod> -n <ns> -- ls -la /etc/app/

# Check volumeMount spec
kubectl get pod <pod> -n <ns> -o jsonpath='{.spec.containers[0].volumeMounts}'

# Check if subPath is used
kubectl get pod <pod> -n <ns> -o yaml | grep subPath
```

## CKA Exam Tips

- **subPath is the answer** when the question says "mount a single file without
  replacing the directory"
- **Remember the trade-off**: subPath files do NOT auto-update when the source changes
- **mountPath must be the full file path** when using subPath (e.g.,
  `/etc/app/app.conf`, not `/etc/app/`)
- **subPath value matches the key name** in the ConfigMap or Secret
- **Pods are immutable** -- you must delete and recreate a pod to change volumeMounts

## Common Interview Questions

**Q: What is the difference between subPath and items[] in a ConfigMap volume?**
A: `subPath` on a volumeMount mounts a single file at a specific path without
replacing the parent directory, but the file does not auto-update when the
ConfigMap changes. `items[]` on the volume definition selects which keys to
project into the mount directory, still replacing the directory, but files
auto-update when the ConfigMap changes.

**Q: Why would a ConfigMap-mounted file not update after you change the ConfigMap?**
A: If the file was mounted using `subPath`, it is a bind mount that does not
receive updates. Only directory-mounted ConfigMap volumes (without subPath)
get automatic updates via the kubelet's sync loop.

**Q: When would you use subPathExpr?**
A: When you need per-pod paths on a shared volume. For example, mounting
a shared PVC but giving each pod its own subdirectory based on the pod name
using `subPathExpr: $(POD_NAME)`.
