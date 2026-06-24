# Debrief: Cluster Upgrade — kubeadm Sequence

## Why sequence matters

The Kubernetes version skew policy dictates what versions can co-exist:
- kubelet can be at most **2 minor versions** behind kube-apiserver
- Nodes must be upgraded AFTER the control plane
- kubeadm must be upgraded BEFORE running `kubeadm upgrade apply`

If you upgrade kubelet before the control plane, the node may become
incompatible with the API server.

## Complete upgrade sequence

```bash
# ═══ CONTROL PLANE ═══

# 1. Unhold kubeadm (apt holds prevent accidental upgrades)
apt-mark unhold kubeadm

# 2. Install target kubeadm version
apt-get update
apt-get install -y kubeadm=1.29.0-1.1

# 3. Re-hold kubeadm
apt-mark hold kubeadm

# 4. Check what will be upgraded
kubeadm upgrade plan

# 5. Apply control plane upgrade
kubeadm upgrade apply v1.29.0 -y

# ═══ NODE COMPONENTS ═══

# 6. Drain the node
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data

# 7. Unhold node components
apt-mark unhold kubelet kubectl

# 8. Upgrade
apt-get install -y kubelet=1.29.0-1.1 kubectl=1.29.0-1.1

# 9. Re-hold
apt-mark hold kubelet kubectl

# 10. Reload and restart
systemctl daemon-reload
systemctl restart kubelet

# 11. Restore node to schedulable
kubectl uncordon <node>

# 12. Verify
kubectl get nodes
```

## Worker node upgrade (multi-node clusters)

For worker nodes, skip the `kubeadm upgrade apply` step:

```bash
# On each worker node:
apt-mark unhold kubeadm
apt-get install -y kubeadm=1.29.0-1.1
apt-mark hold kubeadm
kubeadm upgrade node  # ← different from control plane!

kubectl drain <worker> --ignore-daemonsets --delete-emptydir-data
apt-mark unhold kubelet kubectl
apt-get install -y kubelet=1.29.0-1.1 kubectl=1.29.0-1.1
apt-mark hold kubelet kubectl
systemctl daemon-reload && systemctl restart kubelet
kubectl uncordon <worker>
```

## CKA exam tip

The upgrade is a guaranteed CKA exam question. Memorize:
1. Control plane: `kubeadm upgrade apply v1.X.Y`
2. Worker: `kubeadm upgrade node` (no apply!)
3. Always drain before upgrading kubelet
4. Always uncordon after
5. Use `apt-mark hold/unhold` to manage package locks

## Interview question

**Q: What is the maximum version skew allowed between kubeadm and kubelet?**

A: Kubelet can be at most 3 minor versions behind kube-apiserver (as of
Kubernetes 1.28+, previously 2). kubeadm and kube-apiserver should be
the same version. kube-controller-manager and kube-scheduler can be 1
minor version behind kube-apiserver. kubectl can be 1 version behind or ahead.
