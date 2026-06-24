# Debrief: Deployment — Rolling Update Strategy

## Recreate vs RollingUpdate

| Strategy | Behaviour | Use case |
|----------|-----------|----------|
| `Recreate` | Kill ALL old pods, then start new ones | Dev/test; apps that can't run two versions at once |
| `RollingUpdate` | Replace pods gradually (default) | Production — maintains availability |

## RollingUpdate parameters

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxUnavailable: 1    # max pods that can be down at once (abs or %)
    maxSurge: 1          # max extra pods above desired (abs or %)
```

With `replicas: 3`, `maxUnavailable: 1`, `maxSurge: 1`:
- Up to 4 pods running simultaneously (3 + 1 surge)
- Down to 2 pods running simultaneously (3 - 1 unavailable)
- Always at least 2 healthy pods during rollout

## Common production settings

```yaml
# Conservative — very safe, slow rollout
maxUnavailable: 0
maxSurge: 1          # one pod at a time added, then one removed

# Aggressive — fast rollout, accepts more downtime risk
maxUnavailable: 25%
maxSurge: 25%

# The Kubernetes default (when not specified)
maxUnavailable: 25%
maxSurge: 25%
```

## Patching strategy

```bash
# One-liner patch
kubectl patch deployment webapp -n ckaquest -p \
  '{"spec":{"strategy":{"type":"RollingUpdate","rollingUpdate":{"maxUnavailable":1,"maxSurge":1}}}}'

# Verify
kubectl get deployment webapp -n ckaquest \
  -o jsonpath='{.spec.strategy}' | python3 -m json.tool
```

## When to use Recreate

- Your app **cannot run two versions simultaneously** (e.g., database migrations
  that change schema in breaking ways)
- You have a **single-instance** stateful app that can't scale
- You need guaranteed clean slate on every deploy

In those cases, accept the downtime window and plan for it.

## CKA exam tip

The exam may ask you to change strategy or set specific `maxUnavailable`/`maxSurge`.
`kubectl patch` with inline JSON is fastest. The `--type=merge` flag is the default.

```bash
kubectl patch deployment <name> -p '{"spec":{"strategy":{"type":"RollingUpdate",...}}}'
```

## Interview question

**Q: What is the difference between Recreate and RollingUpdate deployment strategies?**

A: `Recreate` terminates all existing pods before creating new ones, causing a brief
downtime window but guaranteeing a clean cutover with no version overlap.
`RollingUpdate` replaces pods incrementally — `maxUnavailable` controls how many pods
can be down simultaneously, and `maxSurge` controls how many extra pods can run above
the desired count. RollingUpdate maintains partial availability throughout the rollout,
making it the default choice for stateless production services.
