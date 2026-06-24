# Level 11 Debrief: RBAC From Scratch

## What Was Broken

The ServiceAccount `app-deployer` existed and a pod was running with it, but no
Role or RoleBinding had been created. Without RBAC rules, the SA had zero
permissions in the cluster.

## The Fix

Created two resources:

1. **Role** `app-deployer-role` -- defines what actions are allowed on which resources
2. **RoleBinding** `app-deployer-binding` -- connects the Role to the ServiceAccount

## RBAC Model Deep Dive

Kubernetes RBAC uses four resource types:

| Resource | Scope | Purpose |
|---|---|---|
| **Role** | Namespace | Grants permissions within a single namespace |
| **ClusterRole** | Cluster-wide | Grants permissions across all namespaces (or on cluster-scoped resources) |
| **RoleBinding** | Namespace | Binds a Role (or ClusterRole) to subjects within a namespace |
| **ClusterRoleBinding** | Cluster-wide | Binds a ClusterRole to subjects across the entire cluster |

A Role has **rules**, each rule specifies:
- `apiGroups` -- the API group (e.g., `""` for core, `"apps"` for Deployments)
- `resources` -- the resource type (e.g., `pods`, `deployments`)
- `verbs` -- allowed actions (e.g., `get`, `list`, `watch`, `create`, `update`, `delete`)

## Imperative Commands (CKA Time-Savers)

Create a Role:
```bash
kubectl create role app-deployer-role \
  --verb=get,list,watch --resource=pods \
  --verb=create,get,list --resource=deployments \
  -n ckaquest
```

Create a RoleBinding:
```bash
kubectl create rolebinding app-deployer-binding \
  --role=app-deployer-role \
  --serviceaccount=ckaquest:app-deployer \
  -n ckaquest
```

Test permissions:
```bash
kubectl auth can-i list pods \
  --as=system:serviceaccount:ckaquest:app-deployer \
  -n ckaquest
```

## Key Concepts

- **Subjects** in a RoleBinding can be: ServiceAccount, User, or Group
- ServiceAccount format in subjects: `system:serviceaccount:<namespace>:<name>`
- `kubectl auth can-i --list` shows all permissions for a subject
- Roles are additive -- there is no "deny" rule in Kubernetes RBAC

## CKA Exam Tip

Imperative RBAC commands are much faster than writing YAML by hand. Memorize:
- `kubectl create role` with `--verb` and `--resource` flags
- `kubectl create rolebinding` with `--role` and `--serviceaccount` flags
- `kubectl auth can-i` for quick permission verification
