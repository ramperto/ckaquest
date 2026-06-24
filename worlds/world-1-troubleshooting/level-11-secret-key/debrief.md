# Debrief: Secret Key Reference — Wrong Key Name

## What happened?

The Secret stored the password under key `password` (lowercase), but the pod
spec referenced key `PASSWORD` (uppercase). Kubernetes secret key lookups are
case-sensitive. The mismatch caused `CreateContainerConfigError`.

## Viewing Secret keys (without decoding values)

```bash
# List just the keys
kubectl get secret db-creds -n ckaquest \
  -o jsonpath='{.data}' | python3 -m json.tool

# Decode a specific value
kubectl get secret db-creds -n ckaquest \
  -o jsonpath='{.data.password}' | base64 -d
```

## Secret data encoding

All Secret values in `.data` are base64 encoded. Use `.stringData` to set
values as plain text (Kubernetes encodes them automatically):

```yaml
# stringData — plain text input (easier to write)
stringData:
  password: "mysecret"

# data — base64 encoded (what you see in kubectl get secret -o yaml)
data:
  password: bXlzZWNyZXQ=  # echo -n "mysecret" | base64
```

## CKA exam tip

When debugging secret/configmap issues:
1. `kubectl describe pod` → Events show which resource/key is missing
2. `kubectl get secret <name> -o jsonpath='{.data}'` → see actual keys
3. Keys are case-sensitive — "Password" ≠ "password" ≠ "PASSWORD"

## Interview question

**Q: How do you rotate a secret that's being used by a running pod?**

A: Update the Secret's data. If mounted as a volume, the change propagates
automatically (within kubelet's sync period, ~1 minute). If loaded as env
vars via `env.valueFrom`, the pod must be restarted to pick up the new
value — env vars are injected at container start and don't auto-update.
