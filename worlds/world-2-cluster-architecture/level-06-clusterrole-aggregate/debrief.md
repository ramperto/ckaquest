# Debrief: ClusterRole Aggregation

## What happened?

`platform-viewer` used `aggregationRule` to automatically collect rules from
any ClusterRole with the label `rbac.ckaquest.io/aggregate-to-platform-viewer: "true"`.
The `logs-reader` ClusterRole was missing this label, so its pod/log rules
were never included in `platform-viewer`.

## ClusterRole aggregation

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: my-aggregate-role
aggregationRule:
  clusterRoleSelectors:
    - matchLabels:
        my-label: "true"
rules: []   # auto-populated — do NOT manually add rules here
```

Kubernetes watches for ClusterRoles matching the selector and automatically
merges their rules into the aggregating ClusterRole. This is **live** — add
the label to a new ClusterRole and its rules appear instantly.

## Real-world example — extending built-in roles

Kubernetes uses aggregation for its built-in roles. `view`, `edit`, and
`admin` all use aggregation. To add CRD permissions to `view`:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: myapp-viewer
  labels:
    rbac.authorization.k8s.io/aggregate-to-view: "true"
rules:
  - apiGroups: ["myapp.io"]
    resources: ["myresources"]
    verbs: ["get", "list", "watch"]
```

Now anyone with the built-in `view` ClusterRole can also see your CRDs.

## CKA exam tip

ClusterRole aggregation is a tricky but tested concept. Key points:
- `aggregationRule` + matching label = automatic rules merging
- Aggregating ClusterRole should have `rules: []` — it's auto-populated
- You can extend built-in roles (view/edit/admin) using their aggregation labels

## Interview question

**Q: What are the aggregation labels for Kubernetes built-in ClusterRoles?**

A:
- `rbac.authorization.k8s.io/aggregate-to-view: "true"` → adds to `view`
- `rbac.authorization.k8s.io/aggregate-to-edit: "true"` → adds to `edit`
- `rbac.authorization.k8s.io/aggregate-to-admin: "true"` → adds to `admin`

This is the recommended way to grant CRD permissions to users who have
been given standard built-in roles.
