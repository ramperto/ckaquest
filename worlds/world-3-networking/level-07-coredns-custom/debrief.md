# Debrief: CoreDNS — Custom Stub Zone

## CoreDNS architecture

CoreDNS is the default DNS server in Kubernetes (replaced kube-dns since 1.12).
It runs as a Deployment in `kube-system` and is configured entirely through
a ConfigMap named `coredns` via its `Corefile`.

```bash
kubectl get configmap coredns -n kube-system -o yaml
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

## Default Corefile

```
.:53 {
    errors
    health { lameduck 5s }
    ready
    kubernetes cluster.local in-addr.arpa ip6.arpa {
        pods insecure
        fallthrough in-addr.arpa ip6.arpa
    }
    forward . /etc/resolv.conf   # forwards non-cluster DNS to node's resolver
    cache 30
    loop
    reload                       # auto-reloads on ConfigMap change
    loadbalance
}
```

## Common Corefile customisations

```
# Stub zone — forward specific domain to internal DNS
internal.corp:53 {
    errors
    cache 30
    forward . 10.0.0.53
}

# Rewrite hostname
rewrite name myoldapp.cluster.local myapp.ckaquest.svc.cluster.local

# Custom upstream for all external DNS
forward . 8.8.8.8 8.8.4.4
```

## Reload behaviour

CoreDNS has a `reload` plugin that watches for ConfigMap changes.
However, it's safest to also restart after changes:

```bash
kubectl rollout restart deployment coredns -n kube-system
kubectl rollout status deployment coredns -n kube-system
```

## CKA exam tip

CoreDNS questions typically ask you to:
1. Edit the ConfigMap to add a stub zone or change forwarding
2. Restart CoreDNS to apply
3. Test with `nslookup` from a pod

Don't confuse CoreDNS ConfigMap with pod dnsConfig — these are different:
- CoreDNS ConfigMap: cluster-level DNS behaviour
- Pod `dnsConfig`: per-pod DNS settings (nameservers, search domains)

## Interview question

**Q: How does CoreDNS handle a DNS query for 'backend-svc.ckaquest.svc.cluster.local'?**

A: CoreDNS receives the query, matches it to the `kubernetes` plugin in its
Corefile (which handles `cluster.local`). The plugin looks up the Service
in the Kubernetes API, finds the ClusterIP, and returns it. For external
hostnames, it falls through to the `forward` plugin which sends the query
to the upstream DNS server (usually the node's resolver in `/etc/resolv.conf`).
