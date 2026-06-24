# Debrief: NetworkPolicy — Cross-Namespace Traffic

## The AND vs OR trap

This is the most confusing part of NetworkPolicy syntax:

```yaml
# This is AND — allows from pods that are BOTH in monitoring NS AND have app=prometheus
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            purpose: monitoring
        podSelector:          # ← same list item = AND
          matchLabels:
            app: prometheus

# This is OR — allows from monitoring NS OR from any pod with app=prometheus
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            purpose: monitoring
      - podSelector:          # ← separate list item = OR
          matchLabels:
            app: prometheus
```

**Single `-` item = AND. Two separate `-` items = OR.**

## Namespace labels

Namespaces need labels for `namespaceSelector` to work:

```bash
# Add label
kubectl label namespace monitoring purpose=monitoring

# Built-in label (Kubernetes 1.21+)
# kubernetes.io/metadata.name: <namespace-name> is automatic
# So you can always use:
namespaceSelector:
  matchLabels:
    kubernetes.io/metadata.name: monitoring
```

## Full isolation pattern

```yaml
# Deny all ingress and egress (zero-trust baseline)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}         # matches ALL pods in namespace
  policyTypes:
    - Ingress
    - Egress
```

Then add specific allow policies on top.

## CKA exam tip

Cross-namespace NetworkPolicy questions always involve:
1. Labelling the source namespace
2. Using `namespaceSelector` (possibly combined with `podSelector`)
3. Being careful about AND vs OR

The built-in label `kubernetes.io/metadata.name: <ns>` is a safe bet
when you can't add custom labels.

## Interview question

**Q: How do you allow traffic from any pod in namespace 'staging' without labelling specific pods?**

A: Label the namespace, then use `namespaceSelector` only (no `podSelector`):
```yaml
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: staging
```
This allows all pods in `staging` without restricting by pod label.
