# Debrief: ConfigMap Missing

## What happened?

The pod referenced `app-config` via `envFrom.configMapRef`, but no ConfigMap
with that name existed. Kubernetes couldn't inject the environment variables,
so it couldn't create the container: `CreateContainerConfigError`.

## envFrom vs env

```yaml
# envFrom — load ALL keys from a ConfigMap as env vars
envFrom:
  - configMapRef:
      name: app-config

# env — load specific keys
env:
  - name: MY_VAR
    valueFrom:
      configMapKeyRef:
        name: app-config
        key: APP_ENV
```

`envFrom` is convenient but fragile — missing ConfigMap = pod won't start.
`env` with `optional: true` can be more resilient.

## ConfigMap creation methods

```bash
# From literals
kubectl create configmap myconfig \
  --from-literal=key1=value1 \
  --from-literal=key2=value2 \
  -n myns

# From a file
kubectl create configmap myconfig \
  --from-file=config.properties \
  -n myns

# From a directory
kubectl create configmap myconfig \
  --from-file=./config-dir/ \
  -n myns

# From YAML
kubectl apply -f configmap.yaml
```

## CKA exam tip

`CreateContainerConfigError` means a referenced ConfigMap or Secret doesn't exist.
Always:
1. `kubectl describe pod` → check Events for the missing resource name
2. `kubectl get configmaps` or `kubectl get secrets` → confirm it's missing
3. Create the missing resource

## Interview question

**Q: What happens if a pod references an optional: true ConfigMap that doesn't exist?**

A: With `optional: true` on the configMapRef or secretRef, the container
starts normally even if the referenced resource doesn't exist — the env vars
simply won't be set. Without `optional: true` (the default), the pod enters
`CreateContainerConfigError` and won't start until the resource is created.
