# Debrief: ImagePullBackOff

## What happened?

The pod spec referenced `nginx:1.99.99` which doesn't exist on Docker Hub.
Kubernetes tried to pull the image, received a 404/manifest not found error,
and entered ImagePullBackOff — retrying with exponential backoff.

## ErrImagePull vs ImagePullBackOff

- **ErrImagePull** — the immediate failure state (pull just failed)
- **ImagePullBackOff** — Kubernetes is waiting before retrying

Both mean the same root cause: image couldn't be pulled.

## Common causes

| Cause | Example |
|-------|---------|
| Wrong tag | `nginx:1.99.99` |
| Typo in image name | `ngnix:latest` |
| Private registry, no pull secret | `myregistry.io/app:v1` |
| Registry unreachable | network policy blocking egress |
| Rate limit (Docker Hub) | too many pulls from one IP |

## Commands you practiced

```bash
kubectl describe pod <name> -n <ns>   # Shows pull error in Events
kubectl get pod -o jsonpath='{.spec.containers[0].image}'  # Check image
kubectl delete pod <name> -n <ns>     # Delete to recreate
kubectl run <name> --image=<img>      # Recreate with fixed image
```

## CKA exam tip

On the exam, when you see ImagePullBackOff:
1. `kubectl describe pod` → check Events for exact error message
2. Is it a tag problem? Registry auth problem? Network problem?
3. Fix accordingly — usually delete + recreate with correct image

For private registry auth issues, you'd create an `imagePullSecret`.

## Interview question

**Q: How do you use an image from a private registry in Kubernetes?**

A: Create a Secret of type `kubernetes.io/dockerconfigjson` with registry
credentials, then reference it in the pod spec under `imagePullSecrets`.
