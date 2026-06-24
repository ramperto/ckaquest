# Debrief: Secret Volume — Wrong Key in items

## Secret volume items

By default, mounting a Secret as a volume projects ALL keys as files.
The `items:` field lets you select and optionally rename specific keys:

```yaml
volumes:
  - name: tls-vol
    secret:
      secretName: tls-secret
      items:
        - key: tls.crt     # ← source key in the Secret
          path: cert.pem   # ← filename inside the container (at mountPath)
          mode: 0600       # ← optional file permission
```

**If `key` doesn't exist in the Secret, the projected file is empty (0 bytes).**
The pod starts but the file has no content — silent misconfiguration.

## Key vs path

```yaml
items:
  - key: tls.crt      # which Secret key to read
    path: tls.crt     # filename at mountPath/<path>
```

With `mountPath: /etc/ssl` and `path: tls.crt`, the file appears at:
`/etc/ssl/tls.crt`

You can rename it:
```yaml
  - key: tls.crt
    path: server.crt   # appears at /etc/ssl/server.crt
```

## Viewing Secret keys

```bash
# Show keys (but not values for Opaque secrets in describe)
kubectl describe secret tls-secret -n ckaquest

# Show base64-decoded values
kubectl get secret tls-secret -n ckaquest -o jsonpath='{.data.tls\.crt}' | base64 -d

# List all keys
kubectl get secret tls-secret -n ckaquest -o json | python3 -c "
import sys, json; d = json.load(sys.stdin)
print(list(d['data'].keys()))"
```

## TLS Secret type

```yaml
type: kubernetes.io/tls   # special type for TLS certs
```

TLS Secrets must have keys `tls.crt` and `tls.key` (validated by Kubernetes).
Using `type: Opaque` with the same keys works but loses the validation.

Creating a TLS Secret:
```bash
kubectl create secret tls my-tls \
  --cert=path/to/cert.crt \
  --key=path/to/key.key \
  -n ckaquest
```

## CKA exam tip

When using `items:` in a Secret or ConfigMap volume, always double-check
the `key` matches an actual key in the Secret/ConfigMap. The pod will start
but with empty files — a very subtle bug.

```bash
# Quick check: list keys in a Secret
kubectl get secret <name> -o jsonpath='{.data}' | python3 -m json.tool
```

## Interview question

**Q: How do you mount only specific keys from a Secret as files?**

A: Use the `items:` field in the Secret volume spec. Each item maps a
`key` (from the Secret's data) to a `path` (filename at the mountPath).
Only specified keys are mounted. If `items:` is omitted, all keys become
files. Using a wrong key name in `items:` results in an empty file —
the pod starts normally but the file has no content.
