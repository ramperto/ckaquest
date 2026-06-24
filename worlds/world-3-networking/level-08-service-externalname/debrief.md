# Debrief: ExternalName Service

## What ExternalName does

An ExternalName Service is a special type that doesn't proxy traffic.
Instead, CoreDNS returns a **CNAME record** for it:

```
database.ckaquest.svc.cluster.local
    CNAME → legacy-db.corp.internal
         → (resolved by upstream DNS)
         → 192.168.1.100
```

The pod's connection goes directly to the external host — Kubernetes
doesn't proxy or intercept the traffic.

## Use cases

| Use case | Example |
|----------|---------|
| Migrate from external to in-cluster | Start with ExternalName, replace with ClusterIP later |
| Abstract 3rd-party SaaS | `type: ExternalName, externalName: mydb.rds.amazonaws.com` |
| Reference service across namespaces | Point to `other-svc.other-ns.svc.cluster.local` |
| Environment-specific routing | Dev → dev-db, Prod → prod-db, same Service name |

## ExternalName YAML

```yaml
apiVersion: v1
kind: Service
metadata:
  name: database
  namespace: myapp
spec:
  type: ExternalName
  externalName: my.external.db.com
  # ports are optional (for documentation only — not enforced)
  ports:
    - port: 5432
```

## Gotchas

1. **No ClusterIP** — ExternalName services have no ClusterIP. You can't
   use them with `targetPort` in other Services.
2. **CNAME only** — no load balancing, no health checks, no iptables rules.
3. **TLS hostname mismatch** — if your app uses TLS, the cert may not match
   the CNAME chain. May need SNI configuration.
4. **Cross-namespace alias** — `externalName: svc.other-ns.svc.cluster.local`
   is a valid way to reference services across namespaces without copying them.

## CKA exam tip

ExternalName is a straightforward concept but easy to forget:
- No selector required
- No ClusterIP assigned
- `externalName` field takes a DNS name (not an IP)
- To point to an IP, use Endpoints + ClusterIP service instead

## Interview question

**Q: How would you migrate an external database to in-cluster without changing app config?**

A: Create an ExternalName Service pointing to the external DB. Apps use the
Service name. When the in-cluster DB is ready, change the Service type from
ExternalName to ClusterIP with a selector targeting the in-cluster DB pods.
The app config never changes — only the Service definition does.
