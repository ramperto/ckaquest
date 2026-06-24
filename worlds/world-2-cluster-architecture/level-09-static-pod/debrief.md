# Debrief: Static Pod — Broken Manifest

## What are static pods?

Static pods are managed directly by the kubelet on each node, not by the
Kubernetes API server. They're defined as YAML files in a directory on the
host (typically `/etc/kubernetes/manifests/`).

The API server creates "mirror pods" — read-only representations of static
pods. You can `kubectl get` them, but you cannot `kubectl delete` them.
Deleting a mirror pod just recreates it.

## Static pod characteristics

| Aspect | Behavior |
|--------|---------|
| Managed by | kubelet (not control plane) |
| Namespace | Any, but typically kube-system |
| Name | `<pod-name>-<node-name>` |
| Delete via kubectl | No — delete the manifest file instead |
| Restart | kubelet restarts on crash/change |
| restartPolicy | Must be `Always` (or default) |

## Why static pods matter for CKA

Kubernetes control plane components (kube-apiserver, kube-scheduler,
kube-controller-manager, etcd) run as static pods on kubeadm clusters:

```bash
ls /etc/kubernetes/manifests/
# kube-apiserver.yaml
# kube-controller-manager.yaml
# kube-scheduler.yaml
# etcd.yaml
```

**Diagnosing a broken control plane = editing these manifests.**

## Static pod management

```bash
# Create: place manifest file
sudo cp my-pod.yaml /etc/kubernetes/manifests/

# Edit: modify the file — kubelet auto-detects changes
sudo vim /etc/kubernetes/manifests/my-pod.yaml

# Delete: remove the file
sudo rm /etc/kubernetes/manifests/my-pod.yaml

# kubelet logs for static pod issues
sudo journalctl -u kubelet -f
# (or for k3s: sudo journalctl -u k3s -f)
```

## CKA exam tip

Static pods appear in the exam in two contexts:
1. **Control plane troubleshooting** — a component is down because its
   manifest has a bug (wrong flag, wrong cert path, etc.)
2. **Create a static pod** — place a manifest in `/etc/kubernetes/manifests/`

Always check mirror pod status with `kubectl get pod -n kube-system` and
the actual manifest at `/etc/kubernetes/manifests/`.

## Interview question

**Q: How do you troubleshoot a kube-scheduler that's not scheduling pods?**

A: On a kubeadm cluster:
1. `kubectl get pod -n kube-system | grep scheduler` → is it Running?
2. `kubectl logs -n kube-system kube-scheduler-<node>` → any errors?
3. `sudo cat /etc/kubernetes/manifests/kube-scheduler.yaml` → any config issues?
4. `sudo journalctl -u kubelet` → kubelet errors starting the static pod?

The scheduler static pod manifest is the first place to look.
