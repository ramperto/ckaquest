# Level 14 Debrief: Projected Volumes

## What Happened

The pod `projected-app` had two typos in its projected volume definition:
`configmap` instead of `configMap` (camelCase) and `metadata.label` instead of
`metadata.labels` (plural). These prevented the pod from starting. Fixing both
allowed all three sources to project into `/etc/projected/`.

## Projected Volumes Deep Dive

### What Are Projected Volumes?

A projected volume combines multiple volume sources into a single mount point.
Instead of creating separate volumes for a Secret, ConfigMap, and Downward API,
you merge them into one directory.

### Supported Source Types

| Source Type | Description | Example Data |
|------------|-------------|-------------|
| `secret` | Kubernetes Secret data | API keys, passwords, TLS certs |
| `configMap` | ConfigMap data | Configuration files |
| `downwardAPI` | Pod metadata and resource info | Labels, annotations, CPU limits |
| `serviceAccountToken` | Auto-rotated SA token | JWT for API authentication |

### Projected Volume Syntax

```yaml
volumes:
  - name: all-in-one
    projected:
      sources:
        - secret:
            name: my-secret
            items:                    # Optional: select specific keys
              - key: api-key
                path: api-key
        - configMap:
            name: my-config
            items:
              - key: config.yaml
                path: config.yaml
        - downwardAPI:
            items:
              - path: "labels"
                fieldRef:
                  fieldPath: metadata.labels
              - path: "cpu-limit"
                resourceFieldRef:
                  containerName: app
                  resource: limits.cpu
        - serviceAccountToken:
            path: token
            expirationSeconds: 3600
            audience: vault
```

### Downward API Fields

| Field | Value |
|-------|-------|
| `metadata.name` | Pod name |
| `metadata.namespace` | Pod namespace |
| `metadata.labels` | All pod labels |
| `metadata.annotations` | All pod annotations |
| `metadata.uid` | Pod UID |
| `spec.nodeName` | Node the pod runs on |
| `spec.serviceAccountName` | Service account name |
| `status.podIP` | Pod IP address |

Resource fields (require `containerName`):

| Field | Value |
|-------|-------|
| `requests.cpu` | CPU request |
| `requests.memory` | Memory request |
| `limits.cpu` | CPU limit |
| `limits.memory` | Memory limit |

### Projected vs Individual Volumes

| Feature | Individual Volumes | Projected Volume |
|---------|-------------------|-----------------|
| Mount points | One per source | Single mount for all sources |
| Volume count | Multiple volumes needed | One volume |
| File organization | Separate directories | All files in one directory |
| Key conflicts | Not possible | Files from different sources can overlap (last wins) |
| Complexity | Simple per volume | Slightly more complex YAML |

### Common Use Cases

1. **Service mesh sidecar config**: Combine TLS certs (Secret) + proxy config
   (ConfigMap) + pod metadata (Downward API) into one mount

2. **Application bootstrap**: API key (Secret) + app config (ConfigMap) +
   auto-rotating token (serviceAccountToken) in `/etc/app/`

3. **Monitoring agent**: Pod labels and annotations (Downward API) + scrape
   config (ConfigMap) + auth token (Secret)

### serviceAccountToken Source

This is the modern way to get auto-rotating, audience-scoped tokens:

```yaml
- serviceAccountToken:
    path: token
    expirationSeconds: 3600    # Token rotated before expiry
    audience: vault             # Token audience claim
```

This replaces the legacy auto-mounted SA token which was long-lived and
not audience-scoped.

### CamelCase Gotchas

The Kubernetes API uses camelCase consistently:

| Wrong | Correct |
|-------|---------|
| `configmap` | `configMap` |
| `downwardapi` | `downwardAPI` |
| `serviceaccounttoken` | `serviceAccountToken` |
| `fieldref` | `fieldRef` |
| `resourcefieldref` | `resourceFieldRef` |
| `metadata.label` | `metadata.labels` |
| `metadata.annotation` | `metadata.annotations` |

## CKA Exam Tips

- **Projected volumes are common in production** -- expect questions about combining
  multiple sources into one mount
- **CamelCase matters** in Kubernetes YAML -- `configMap`, `downwardAPI`,
  `serviceAccountToken`, `fieldRef`
- **Know the Downward API fields** -- `metadata.labels` (plural!), `metadata.name`,
  `metadata.namespace`
- **serviceAccountToken projected source** is the recommended way to get SA tokens
  in modern Kubernetes (1.20+)
- **Use `kubectl explain`** to check field names: `kubectl explain pod.spec.volumes.projected.sources`

## Common Interview Questions

**Q: What is a projected volume and when would you use one?**
A: A projected volume combines multiple volume sources (Secret, ConfigMap,
Downward API, serviceAccountToken) into a single mount point. Use it when you
need data from multiple sources in one directory, reducing mount points and
simplifying container configuration.

**Q: How does a projected serviceAccountToken differ from the default SA token?**
A: Projected SA tokens are time-limited (configurable expiration), audience-scoped
(intended for a specific recipient), and auto-rotated by the kubelet. The legacy
default token was long-lived, not audience-scoped, and stored as a Secret.

**Q: Can files from different projected sources conflict?**
A: Yes. If two sources project a file with the same name (path), the last
source in the list wins. This can be intentional (overriding defaults) or a bug.
