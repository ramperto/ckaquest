# Debrief: NetworkPolicy Combined — 3-Tier Zero-Trust

## The zero-trust model

Zero-trust networking means **deny everything by default, allow only what's needed**.
The moment a NetworkPolicy selects a pod, ALL unmatched traffic is dropped.

For a 3-tier app the allowed paths are exactly:
```
[frontend] → port 80 → [backend] → port 5432 → [db]
```
Everything else (frontend→db, db→anyone, external→backend, etc.) is blocked.

## One policy per tier

| Policy | Selects | Ingress | Egress |
|--------|---------|---------|--------|
| `frontend-policy` | `tier=frontend` | empty (blocked) | backend:80 + DNS:53 |
| `backend-policy` | `tier=backend` | from frontend:80 | db:5432 + DNS:53 |
| `db-policy` | `tier=database` | from backend:5432 | empty (blocked) |

## AND vs OR inside a single rule

`to:` (or `from:`) and `ports:` inside the **same list item** are ANDed:

```yaml
egress:
  - to:                          # ─┐ AND:
      - podSelector:             #  │  destination = tier=database
          matchLabels:           #  │
            tier: database       # ─┤
    ports:                       #  │  AND port = 5432
      - port: 5432               # ─┘
```

Separate list items are ORed:

```yaml
egress:
  - to:                          # Rule A: to database:5432
      - podSelector:
          matchLabels:
            tier: database
    ports:
      - port: 5432
  - ports:                       # Rule B (OR): DNS to anywhere
      - port: 53
        protocol: UDP
```

Rule B has no `to:`, so it allows DNS to **any** destination (CoreDNS).

## policyTypes is mandatory for full lock-down

If you omit `policyTypes`, Kubernetes infers based on what rules are present:
- Has `ingress:` rules → adds `Ingress` automatically
- Has `egress:` rules → adds `Egress` automatically
- Has neither → only `Ingress` is implied (Egress stays open!)

**Always declare policyTypes explicitly** when you want to block both directions:

```yaml
policyTypes:
  - Ingress
  - Egress
ingress: []    # explicit empty = block all ingress
egress: []     # explicit empty = block all egress
```

## The DNS rule (again)

Every tier that needs to contact other services via hostname must allow DNS egress:

```yaml
egress:
  - ports:
      - protocol: UDP
        port: 53
      - protocol: TCP   # fallback for large DNS responses
        port: 53
```

The `db` pod has `egress: []` because it never resolves any hostname —
it just listens. No DNS rule needed there.

## Verifying policy structure

```bash
# List all policies in namespace
kubectl get networkpolicy -n ckaquest

# Detailed view of rules
kubectl describe networkpolicy backend-policy -n ckaquest

# JSON — useful for scripted checks
kubectl get networkpolicy frontend-policy -n ckaquest -o json | jq '.spec'
```

## CKA exam tip

CKA questions often ask you to "restrict traffic so that only X can reach Y on port Z".
The recipe:

1. Write a policy on the **destination** pod with an `ingress` rule allowing from the source.
2. Write a policy on the **source** pod with an `egress` rule allowing to the destination.
3. Always add DNS to egress rules (unless the pod never uses service names).
4. Declare both `Ingress` and `Egress` in `policyTypes` when locking both directions.

## Why NetworkPolicy isn't enforced on this cluster

k3s uses **Flannel** as the default CNI, which does not implement NetworkPolicy.
The YAML structure is valid and matches what CKA graders check, but the kernel-level
enforcement requires a CNI like **Calico**, **Cilium**, or **Weave**.

CKA exam clusters run Calico — policies you write there **are** enforced.

## Interview question

**Q: How do you lock down a 3-tier application with NetworkPolicy?**

A: Apply one policy per tier, each selecting its own pods via `podSelector`.
Declare both `Ingress` and `Egress` in `policyTypes` to lock both directions.
Use `ingress.from.podSelector` to whitelist allowed sources, and
`egress.to.podSelector` + `egress.ports` to whitelist allowed destinations.
Always include a separate egress rule for DNS (port 53 UDP/TCP) on tiers
that need hostname resolution. Empty `ingress: []` or `egress: []` blocks
all traffic in that direction.
