# Debrief: DNS Broken — Custom DNS Policy

## What happened?

The pod had `dnsPolicy: None` with a custom nameserver `1.2.3.4` that doesn't
respond. All DNS queries timed out, making the pod unable to resolve any
hostname — cluster services or external domains.

## Kubernetes DNS policies

| Policy | Behavior |
|--------|---------|
| `ClusterFirst` | **Default.** Cluster DNS (CoreDNS) first, then node's DNS |
| `ClusterFirstWithHostNet` | Like ClusterFirst but for pods using hostNetwork |
| `Default` | Inherits DNS from the node (NOT cluster DNS) |
| `None` | No DNS config — must provide dnsConfig manually |

**Confusingly: `Default` ≠ the default. `ClusterFirst` is the actual default.**

## Debugging DNS inside a pod

```bash
# Test basic DNS resolution
kubectl exec <pod> -n <ns> -- nslookup kubernetes.default
kubectl exec <pod> -n <ns> -- nslookup <service-name>.<namespace>

# Check /etc/resolv.conf inside the pod
kubectl exec <pod> -n <ns> -- cat /etc/resolv.conf

# Use dig for more detail
kubectl exec <pod> -n <ns> -- dig kubernetes.default.svc.cluster.local
```

## CoreDNS service

CoreDNS runs as a Deployment in kube-system:

```bash
kubectl get pods -n kube-system -l k8s-app=kube-dns
kubectl get svc -n kube-system kube-dns  # Usually 10.96.0.10
```

The cluster IP of kube-dns is what appears in pod's `/etc/resolv.conf`
as the nameserver when using `ClusterFirst`.

## CKA exam tip

DNS troubleshooting flow:
1. `kubectl exec <pod> -- nslookup kubernetes.default` — test DNS
2. `kubectl exec <pod> -- cat /etc/resolv.conf` — check nameserver
3. `kubectl get pods -n kube-system` — is CoreDNS running?
4. `kubectl logs -n kube-system -l k8s-app=kube-dns` — CoreDNS logs

## Interview question

**Q: What is the FQDN of a Service in Kubernetes?**

A: `<service-name>.<namespace>.svc.<cluster-domain>`

Example: `backend-svc.ckaquest.svc.cluster.local`

Within the same namespace, just `backend-svc` works. Across namespaces,
use `backend-svc.other-namespace`. The search domains in `/etc/resolv.conf`
handle the expansion automatically.
