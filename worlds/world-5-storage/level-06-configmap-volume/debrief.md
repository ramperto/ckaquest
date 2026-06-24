# Debrief: ConfigMap Volume — Missing Source

## ConfigMap as a volume

When a ConfigMap is mounted as a volume, each key becomes a **file**:

```yaml
spec:
  volumes:
    - name: config-vol
      configMap:
        name: app-config      # ConfigMap must exist in same namespace
  containers:
    - volumeMounts:
        - name: config-vol
          mountPath: /etc/app
```

ConfigMap `app-config` with keys `app.properties` and `nginx.conf` produces:
```
/etc/app/app.properties    ← content of app.properties key
/etc/app/nginx.conf        ← content of nginx.conf key
```

## Missing ConfigMap → ContainerCreating stuck

If the referenced ConfigMap doesn't exist, the kubelet logs:
```
MountVolume.SetUp failed for volume "config-vol": configmap "app-config" not found
```

The pod stays in `ContainerCreating` indefinitely. Once you create the
ConfigMap, the kubelet retries automatically — no pod restart needed.

## ConfigMap volume options

```yaml
volumes:
  - name: config-vol
    configMap:
      name: app-config
      defaultMode: 0644        # file permissions (default: 0644)
      items:                   # mount only specific keys
        - key: app.properties
          path: config.properties   # rename the file inside the container
          mode: 0600                # override permissions for this file
```

Without `items:`, ALL keys are mounted as files.
With `items:`, only listed keys are mounted (renamed if `path` differs).

## ConfigMap vs Secret volume

Both work identically as volumes. The difference:
- ConfigMap: plaintext, shows in `kubectl get cm -o yaml`
- Secret: base64-encoded in etcd, redacted in `kubectl describe`

Both are projected into files at the specified mountPath.

## Auto-update of mounted ConfigMaps

ConfigMap values mounted as volumes are **automatically refreshed** when
the ConfigMap changes (within `--sync-frequency`, default ~1 minute).
This enables hot-reload without pod restarts.

**Exception**: environment variables from ConfigMaps (envFrom/valueFrom)
are NOT updated — they're baked in at pod start and need a pod restart.

## CKA exam tip

Common exam pattern: create a ConfigMap and mount it as a volume.
```bash
# Fastest way:
kubectl create configmap myconfig --from-literal=key=value -n <ns>
kubectl create configmap myconfig --from-file=app.conf=/path/to/file -n <ns>
```

## Interview question

**Q: What is the difference between using a ConfigMap as an environment variable vs a volume mount?**

A: As an environment variable (`envFrom` or `env.valueFrom.configMapKeyRef`),
the value is injected at pod startup and does NOT update if the ConfigMap changes —
the pod must be restarted. As a volume mount, each key becomes a file and the
kubelet periodically syncs changes — the file content updates automatically within
the sync period (default ~1 minute) without a pod restart. Volume mounting is
preferred for large configs and for applications that support hot-reload.
