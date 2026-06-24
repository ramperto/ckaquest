# Debrief: DNS Debugging — Wrong Nameserver in dnsConfig

## How DNS works in Kubernetes

Every Kubernetes cluster runs **CoreDNS** (or kube-dns) as a cluster-internal
DNS server. When a pod makes a DNS query like `web-svc.ckaquest.svc.cluster.local`,
the request goes to CoreDNS, which knows about all Services and Pods.

CoreDNS runs as a Deployment in `kube-system` and is exposed via a Service
(usually called `kube-dns`):

```bash
kubectl get svc -n kube-system kube-dns
# NAME       TYPE        CLUSTER-IP   PORT(S)
# kube-dns   ClusterIP   10.43.0.10   53/UDP,53/TCP
```

## DNS record format

Kubernetes creates DNS records in this format:

| Resource    | DNS Format                                           | Example                                    |
|-------------|------------------------------------------------------|--------------------------------------------|
| Service     | `<svc>.<ns>.svc.cluster.local`                       | `web-svc.ckaquest.svc.cluster.local`       |
| Pod (by IP) | `<ip-dashed>.<ns>.pod.cluster.local`                 | `10-244-0-5.ckaquest.pod.cluster.local`    |
| StatefulSet | `<pod>.<svc>.<ns>.svc.cluster.local`                 | `db-0.db-svc.ckaquest.svc.cluster.local`   |

With search domains configured, you can use short names:

```bash
# All of these resolve to the same Service IP:
nslookup web-svc                                # uses search domain
nslookup web-svc.ckaquest                       # uses search domain
nslookup web-svc.ckaquest.svc                   # uses search domain
nslookup web-svc.ckaquest.svc.cluster.local     # fully qualified
```

## dnsPolicy options

The `dnsPolicy` field on a pod spec controls how `/etc/resolv.conf` is populated:

| Policy                     | Behavior                                                                                  |
|----------------------------|-------------------------------------------------------------------------------------------|
| `ClusterFirst` (default)   | Use CoreDNS for cluster domains, fall back to node DNS for external names                 |
| `Default`                  | Inherit DNS settings from the node (`/etc/resolv.conf` of the host)                       |
| `ClusterFirstWithHostNet`  | Like ClusterFirst, but for pods using `hostNetwork: true`                                 |
| `None`                     | Kubernetes injects nothing. You MUST provide all DNS settings via `dnsConfig`              |

### When to use `dnsPolicy: None`

Use `None` only when you need full control over DNS — for example:
- Custom DNS server (not CoreDNS)
- Split-horizon DNS setups
- Pods that must NOT use cluster DNS for security reasons

**Danger:** If the nameserver IP in `dnsConfig` is wrong, the pod has
zero DNS resolution. It can't resolve service names, external domains,
or anything else.

## dnsConfig fields

When using `dnsPolicy: None` (or to supplement other policies), you can set:

```yaml
dnsConfig:
  nameservers:       # List of DNS server IPs (max 3)
    - "10.43.0.10"
  searches:          # Search domains (max 6, total 256 chars)
    - ckaquest.svc.cluster.local
    - svc.cluster.local
    - cluster.local
  options:           # resolver options
    - name: ndots
      value: "5"
    - name: single-request-reopen
```

## Finding the CoreDNS ClusterIP

```bash
# Method 1: get the kube-dns Service
kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}'

# Method 2: check resolv.conf in a working pod
kubectl exec <any-running-pod> -- cat /etc/resolv.conf

# Method 3: on k3s specifically
# CoreDNS ClusterIP is usually 10.43.0.10
```

## Debugging DNS step by step

```bash
# 1. Check if CoreDNS is running
kubectl get pods -n kube-system -l k8s-app=kube-dns

# 2. Check the pod's DNS settings
kubectl exec dns-client -n ckaquest -- cat /etc/resolv.conf

# 3. Test resolution
kubectl exec dns-client -n ckaquest -- nslookup kubernetes.default
kubectl exec dns-client -n ckaquest -- nslookup web-svc.ckaquest.svc.cluster.local

# 4. Use a known-good pod for comparison
kubectl run dnstest --image=busybox:1.36 --rm -it --restart=Never -- nslookup web-svc.ckaquest.svc.cluster.local
```

## The fix explained

The broken pod had:
```yaml
dnsPolicy: None
dnsConfig:
  nameservers:
    - "10.0.0.1"    # wrong IP — no DNS server here
```

**Option A** — Fix the nameserver:
```yaml
dnsPolicy: None
dnsConfig:
  nameservers:
    - "10.43.0.10"   # actual CoreDNS ClusterIP
  searches:
    - ckaquest.svc.cluster.local
    - svc.cluster.local
    - cluster.local
```

**Option B** — Use ClusterFirst (simpler):
```yaml
dnsPolicy: ClusterFirst
# No dnsConfig needed — Kubernetes handles it
```

Option B is almost always the right choice unless you have a specific
reason to override DNS configuration.

## CKA exam tip

DNS debugging is **heavily tested** on the CKA exam. Know how to:

1. Check if CoreDNS pods are running
2. Find the CoreDNS ClusterIP (`kubectl get svc -n kube-system kube-dns`)
3. Test DNS from inside a pod (`nslookup`, `dig`, `wget`)
4. Read `/etc/resolv.conf` inside a pod
5. Understand dnsPolicy options and when to use each

A common trap: the exam may give you a pod with `dnsPolicy: None` and
an incorrect `dnsConfig`. The quickest fix is to switch to `ClusterFirst`.

## Interview question

**Q: A pod cannot resolve any service names. DNS lookups time out. How do
you debug this?**

A: First, verify CoreDNS is running: `kubectl get pods -n kube-system -l
k8s-app=kube-dns`. Then check the pod's `/etc/resolv.conf` to see which
nameserver it's using. If the pod has `dnsPolicy: None`, verify the
`dnsConfig.nameservers` IP matches the actual CoreDNS ClusterIP (found via
`kubectl get svc -n kube-system kube-dns`). If the nameserver is wrong,
either fix the IP or change dnsPolicy to ClusterFirst. Also check
NetworkPolicies — if egress to port 53 is blocked, DNS will fail even
with the correct nameserver.
