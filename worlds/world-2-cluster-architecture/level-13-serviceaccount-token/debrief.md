# Level 13 Debrief: ServiceAccount Token Access

## What Was Broken

The pod `api-test` had `automountServiceAccountToken: false` in its spec. This
prevented the kubelet from mounting the projected service account token volume,
so the pod had no credentials to authenticate with the API server.

## The Fix

Remove `automountServiceAccountToken: false` or set it to `true`. Since pod
specs are immutable, the pod must be deleted and recreated.

## Projected Service Account Tokens (Kubernetes 1.24+)

Starting with Kubernetes 1.24, the legacy approach of storing a permanent
secret-based token for each ServiceAccount was deprecated. Instead, Kubernetes
uses **projected tokens** via the TokenRequest API:

- **Automatically rotated** -- tokens have a configurable expiration (default 1 hour)
- **Audience-bound** -- tokens are scoped to a specific audience
- **Pod-bound** -- tokens are invalidated when the pod is deleted

### Default mount path

```
/var/run/secrets/kubernetes.io/serviceaccount/
  token      -- the JWT token
  ca.crt     -- the cluster CA certificate
  namespace  -- the pod's namespace
```

## automountServiceAccountToken

This field can be set at two levels:

1. **ServiceAccount level** -- affects all pods using that SA
2. **Pod level** -- overrides the SA-level setting

Precedence: Pod spec > ServiceAccount spec > default (true)

```yaml
# On the ServiceAccount
apiVersion: v1
kind: ServiceAccount
metadata:
  name: my-sa
automountServiceAccountToken: false   # All pods using this SA won't get tokens

# On the Pod (overrides SA setting)
spec:
  serviceAccountName: my-sa
  automountServiceAccountToken: true   # This pod WILL get a token
```

## Legacy vs Projected Tokens

| Feature | Legacy (pre-1.24) | Projected (1.24+) |
|---|---|---|
| Storage | Secret object | In-memory projected volume |
| Expiration | Never | Configurable (default 1h) |
| Audience | None | API server (configurable) |
| Auto-created | Yes (deprecated) | On demand via TokenRequest |

## CKA Exam Tip

Know the default token mount path: `/var/run/secrets/kubernetes.io/serviceaccount/token`.
This comes up in questions about pod authentication, API server access, and
security hardening. Remember that `automountServiceAccountToken` can be set at
both the SA and pod level.
