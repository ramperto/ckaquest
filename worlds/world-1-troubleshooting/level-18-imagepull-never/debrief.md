# Level 18 Debrief: ImagePullPolicy: Never

## What Happened

The pod `local-app` was configured with `imagePullPolicy: Never` and referenced an
image (`mycompany/internal-app:v2.1`) that doesn't exist on the node's local container
runtime. Kubernetes honored the "Never" policy and refused to pull the image, resulting
in the `ErrImageNeverPull` error.

## ImagePullPolicy Options

| Policy | Behavior |
|--------|----------|
| `Always` | Always pull the image from the registry, even if it exists locally |
| `IfNotPresent` | Pull only if the image is not already on the node |
| `Never` | Never pull — only use local images |

## Default Behavior

Kubernetes sets the default `imagePullPolicy` based on the image tag:

- **`:latest` tag or no tag** — defaults to `Always`
- **Specific tag (e.g., `:v1.25`)** — defaults to `IfNotPresent`
- **Digest reference (e.g., `@sha256:...`)** — defaults to `IfNotPresent`

This means:
```yaml
image: nginx          # defaults to Always (implicit :latest)
image: nginx:latest   # defaults to Always
image: nginx:1.25     # defaults to IfNotPresent
```

## When to Use Each Policy

- **Always** — Production environments where you want the latest version of a tag.
  Use with immutable tags or digests for reproducibility.
- **IfNotPresent** — Most common. Avoids unnecessary pulls while still fetching
  images that aren't cached.
- **Never** — Local development only (minikube, kind). Useful when building images
  directly inside the container runtime. Not suitable for multi-node clusters.

## Common Errors

| Error | Cause |
|-------|-------|
| `ErrImagePull` | Image exists in registry but pull failed (auth, network) |
| `ImagePullBackOff` | Repeated ErrImagePull with exponential backoff |
| `ErrImageNeverPull` | imagePullPolicy is Never and image is not local |
| `InvalidImageName` | Malformed image reference |

## CKA Exam Tips

- Know the default imagePullPolicy rules based on image tags
- Remember that pods are immutable for `image` and `imagePullPolicy` — you must
  delete and recreate the pod to change them
- In air-gapped environments, `Never` or `IfNotPresent` with pre-loaded images
  is the standard pattern
- `kubectl describe pod` will show the exact error in the Events section
- Use `crictl images` on the node to check what images are available locally
