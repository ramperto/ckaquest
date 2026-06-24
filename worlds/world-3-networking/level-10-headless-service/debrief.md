# Debrief: Headless Service — Direct Pod Discovery

## What is a headless Service?

A normal ClusterIP Service creates a **virtual IP** (a stable address that
kube-proxy load-balances to backend pods). DNS returns that one IP.

A headless Service (`clusterIP: None`) skips the virtual IP entirely.
CoreDNS returns **one A record per ready pod** — the real pod IPs.

```
Normal Service DNS:  db-svc → 10.96.100.5   (single ClusterIP)

Headless Service DNS: db-headless → 10.244.0.5   (pod db-cluster-0)
                                  → 10.244.0.6   (pod db-cluster-1)
                                  → 10.244.0.7   (pod db-cluster-2)
```

## Why StatefulSets need headless Services

StatefulSets give each pod a **stable hostname** and ordinal index
(db-cluster-0, db-cluster-1, …). The headless Service enables DNS
for individual pods:

```
<pod-name>.<service-name>.<namespace>.svc.cluster.local
```

Examples:
```
db-cluster-0.db-headless.ckaquest.svc.cluster.local → 10.244.0.5
db-cluster-1.db-headless.ckaquest.svc.cluster.local → 10.244.0.6
```

This is how distributed databases discover and replicate to specific peers:
- **etcd**: each member must reach named peers
- **Cassandra**: seed nodes addressed by hostname
- **PostgreSQL streaming**: primary address is a stable pod DNS name
- **ZooKeeper, Kafka**: leader election needs stable IDs

## Creating a headless Service

The only difference from a regular Service is `clusterIP: None`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: db-headless
  namespace: ckaquest
spec:
  clusterIP: None       # ← headless
  selector:
    app: db-cluster
  ports:
    - port: 5432
      targetPort: 5432
```

**You cannot patch clusterIP after creation.** It is an immutable field.
Always delete and recreate when changing it.

## StatefulSet + headless Service — the serviceName link

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: db-cluster
spec:
  serviceName: db-headless   # must match the headless Service name
  replicas: 3
  ...
```

`serviceName` is what tells the StatefulSet controller which Service to use
for pod DNS registration. Without it, individual pod FQDNs won't work.

## Headless Service without a selector

You can also create a headless Service with **no selector** for custom
endpoint management (e.g. pointing to external hosts):

```yaml
spec:
  clusterIP: None
  # no selector
```

Then manually create an Endpoints object to control what IPs are returned.
This is an advanced pattern used by ExternalName-like setups.

## Verifying headless DNS

```bash
# Should return multiple A records
kubectl exec client -n ckaquest -- nslookup db-headless.ckaquest.svc.cluster.local

# Individual pod FQDN
kubectl exec client -n ckaquest -- nslookup db-cluster-0.db-headless.ckaquest.svc.cluster.local

# Also works with dig if available
kubectl exec client -n ckaquest -- dig db-headless.ckaquest.svc.cluster.local
```

## CKA exam tip

CKA questions involving StatefulSets almost always require a headless Service.
Look for these signals in the question:
- "stable network identity"
- "peer-to-peer communication between pods"
- "each pod must be addressable individually"
- `serviceName:` field in the StatefulSet spec

Remember the two required pieces:
1. Service with `clusterIP: None`
2. StatefulSet with `serviceName:` matching that Service

## Interview question

**Q: What is a headless Service and when would you use one?**

A: A headless Service is created with `clusterIP: None`. Instead of a
virtual IP, CoreDNS returns individual pod IP addresses — one A record per
ready pod. It's used with StatefulSets so that each pod gets a stable,
individually addressable DNS name in the form
`<pod>.<service>.<namespace>.svc.cluster.local`. This enables distributed
stateful applications (databases, message queues, consensus systems) to
discover and communicate with specific peers by name rather than going
through a load balancer.
