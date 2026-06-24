# Debrief: NetworkPolicy — All Traffic Blocked

## What happened?

A NetworkPolicy selected all pods with `app: backend` and specified
`policyTypes: [Ingress]` with an empty `ingress: []`. An empty ingress list
with Ingress in policyTypes = deny ALL ingress. No traffic could reach backend.

## NetworkPolicy fundamentals

**Without any NetworkPolicy:** all traffic flows freely (default allow).

**Once a NetworkPolicy selects a pod:** only traffic explicitly allowed by
matching policies is permitted (whitelist model).

```
ingress: []   # means: Ingress type is controlled, but nothing is allowed
              # = DENY ALL ingress

ingress:      # absent policyType = not controlled = still default allow
              # this only matters if policyTypes includes Ingress
```

## NetworkPolicy structure

```yaml
spec:
  podSelector:          # which pods this policy applies to
    matchLabels:
      app: backend

  policyTypes:
    - Ingress           # control ingress
    - Egress            # control egress

  ingress:
    - from:             # allow from:
        - podSelector:          # pods with these labels
            matchLabels:
              app: frontend
        - namespaceSelector:    # OR pods in these namespaces
            matchLabels:
              name: monitoring
      ports:
        - port: 80              # only on port 80

  egress:
    - to:               # allow traffic to:
        - cidr: 0.0.0.0/0
      ports:
        - port: 443     # only HTTPS
```

## Common NetworkPolicy patterns

```yaml
# Allow all ingress (undo a deny-all)
ingress:
  - {}

# Allow from entire namespace
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: frontend-ns

# Allow from specific pods in specific namespace
ingress:
  - from:
      - namespaceSelector:
          matchLabels:
            name: prod
        podSelector:
          matchLabels:
            app: frontend
```

## CKA exam tip

NetworkPolicy is frequently tested. Key points:
1. NetworkPolicy requires a CNI that supports it (Calico, Cilium, Weave)
   k3s uses Flannel by default which does NOT support NetworkPolicy
   — but the exam clusters use CNIs that do support it
2. `ingress: []` with `policyTypes: [Ingress]` = deny all ingress
3. Multiple policies are additive (OR logic) — any matching policy allows traffic
4. Test with `kubectl exec <pod> -- wget/curl` to verify

## Interview question

**Q: Two NetworkPolicies both select the same pod. How does Kubernetes apply them?**

A: NetworkPolicies are additive/union. If either policy allows a connection,
the traffic is permitted. There is no way for one NetworkPolicy to override
or deny what another has allowed — you can only add allow rules, not deny rules.
(Calico has its own CRD for deny rules, but standard NetworkPolicy only supports allow.)
