# Debrief: RBAC Denied — Missing RoleBinding

## What happened?

The `pod-reader` Role granted list/get/watch on pods. The `monitor-sa`
ServiceAccount existed. But without a RoleBinding connecting them, the
ServiceAccount had no permissions — Kubernetes RBAC is deny-by-default.

## RBAC triangle

```
ServiceAccount ──── RoleBinding ──── Role
(who)                (connects)        (what permissions)
```

All three must exist. Any missing piece = 403 Forbidden.

## Role vs ClusterRole

| | Scope |
|---|---|
| Role | Single namespace |
| ClusterRole | Cluster-wide (all namespaces, or cluster-level resources) |
| RoleBinding | Binds Role OR ClusterRole to namespace |
| ClusterRoleBinding | Binds ClusterRole cluster-wide |

## The essential RBAC diagnostic

```bash
# Test permissions as a specific ServiceAccount
kubectl auth can-i <verb> <resource> \
  --as=system:serviceaccount:<namespace>:<sa-name> \
  -n <namespace>

# Examples
kubectl auth can-i list pods --as=system:serviceaccount:default:my-sa -n default
kubectl auth can-i create deployments --as=system:serviceaccount:default:my-sa -n default
kubectl auth can-i '*' '*' --as=system:serviceaccount:default:my-sa  # all permissions?
```

## Imperative RBAC commands (CKA exam speed)

```bash
# Create Role
kubectl create role pod-reader \
  --verb=get,list,watch \
  --resource=pods \
  -n ckaquest

# Create RoleBinding
kubectl create rolebinding sa-binding \
  --role=pod-reader \
  --serviceaccount=ckaquest:monitor-sa \
  -n ckaquest

# Create ClusterRoleBinding
kubectl create clusterrolebinding sa-binding \
  --clusterrole=view \
  --serviceaccount=ckaquest:monitor-sa
```

## CKA exam tip

RBAC is heavily tested. Always remember the 3-step flow:
1. **ServiceAccount** — who is making requests?
2. **Role/ClusterRole** — what is allowed?
3. **RoleBinding/ClusterRoleBinding** — who gets what?

`kubectl auth can-i` is your best friend for testing.

## Interview question

**Q: What's the difference between a Role and a ClusterRole?**

A: A Role is namespace-scoped — it grants permissions within a single namespace.
A ClusterRole is cluster-scoped — it can grant permissions across all namespaces
or for cluster-level resources (nodes, PersistentVolumes, etc.). A ClusterRole
can be bound with either a ClusterRoleBinding (cluster-wide) or a RoleBinding
(limited to a specific namespace).
