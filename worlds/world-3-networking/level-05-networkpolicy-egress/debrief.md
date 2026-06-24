# Debrief: NetworkPolicy Egress — App Can't Reach Database

## The DNS trap

The most common egress NetworkPolicy mistake: **forgetting to allow DNS**.

When your app tries `nc -z db-svc 5432`, it first resolves `db-svc` via DNS
(port 53 UDP to CoreDNS). If egress port 53 is blocked, the name never
resolves and the connection fails — even if port 5432 is perfectly allowed.

**Always include DNS in egress policies:**

```yaml
egress:
  - ports:
      - protocol: UDP
        port: 53
      - protocol: TCP
        port: 53
```

## Egress policy structure

```yaml
spec:
  podSelector:
    matchLabels:
      app: myapp         # applies to these pods
  policyTypes:
    - Egress
  egress:
    - to:                # destination (optional — omit for any destination)
        - podSelector:
            matchLabels:
              tier: database
        - ipBlock:
            cidr: 10.0.0.0/8
            except:
              - 10.0.0.0/24
      ports:             # destination ports
        - protocol: TCP
          port: 5432
```

## Multiple rules = OR logic

```yaml
egress:
  - ports:               # Rule 1: DNS to anywhere
      - port: 53
        protocol: UDP
  - to:                  # Rule 2: DB pods on 5432
      - podSelector:
          matchLabels:
            app: db
    ports:
      - port: 5432
```

These are two separate rules (OR). If either matches, traffic is allowed.

## Common egress allow patterns

```yaml
# Allow all outbound (undo egress restriction)
egress:
  - {}

# Allow only HTTPS to external
egress:
  - ports:
      - port: 443
  - ports:               # DNS
      - port: 53
        protocol: UDP

# Allow to specific CIDR (external DB)
egress:
  - to:
      - ipBlock:
          cidr: 192.168.1.100/32
    ports:
      - port: 5432
```

## CKA exam tip

Egress NetworkPolicy is harder than ingress — always test both:
```bash
# Test egress (from inside the restricted pod)
kubectl exec <pod> -- nc -z -w3 <destination> <port>
kubectl exec <pod> -- nslookup <service>
```

## Interview question

**Q: Why do egress NetworkPolicies often break DNS?**

A: DNS queries go to CoreDNS pods (port 53 UDP/TCP). When an egress
policy is applied without a DNS allow rule, pods can't resolve any
hostname — including Kubernetes service names. The fix is always to
explicitly allow egress on port 53 to `kube-system` namespace, or to
any destination (since DNS can come from any IP in the kube-dns Service).
