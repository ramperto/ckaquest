# Level 15 Debrief: Managing Multiple Kubeconfig Contexts

## What Was Broken

The kubeconfig had three contexts (production, staging, local-k3s) but the
current-context was set to `production`, which pointed to an unreachable server
(10.255.255.1). All kubectl commands were timing out.

## The Fix

```bash
kubectl config use-context local-k3s
```

This single command switches the active context to one that points to the real,
reachable k3s cluster.

## Kubeconfig Structure

A kubeconfig file has three main sections:

### clusters
Defines cluster endpoints and CA certificates:
```yaml
clusters:
  - name: my-cluster
    cluster:
      server: https://1.2.3.4:6443
      certificate-authority-data: <base64-ca-cert>
```

### users
Defines authentication credentials:
```yaml
users:
  - name: my-user
    user:
      client-certificate-data: <base64-cert>
      client-key-data: <base64-key>
```

### contexts
Combines a cluster + user + optional namespace:
```yaml
contexts:
  - name: my-context
    context:
      cluster: my-cluster
      user: my-user
      namespace: default
```

### current-context
The active context that kubectl uses by default.

## Essential kubectl config Commands

```bash
# View full kubeconfig (redacted)
kubectl config view

# View raw kubeconfig (with secrets)
kubectl config view --raw

# List all contexts
kubectl config get-contexts

# Show current context
kubectl config current-context

# Switch context
kubectl config use-context <name>

# Set a default namespace for a context
kubectl config set-context --current --namespace=ckaquest

# Create a new context
kubectl config set-context new-ctx \
  --cluster=my-cluster \
  --user=my-user \
  --namespace=my-ns
```

## Multiple Kubeconfig Files

You can merge multiple kubeconfig files using the KUBECONFIG env var:
```bash
export KUBECONFIG=~/.kube/config:~/.kube/config-cluster2
kubectl config get-contexts   # shows contexts from both files
```

## CKA Exam Tip

The CKA exam presents multiple clusters. At the top of EVERY question, there is
a context-switching command like:

```
kubectl config use-context k8s-cluster1
```

**Always run this first.** If you forget, you will make changes to the wrong
cluster and lose points. Make it a habit to:

1. Read the context-switch command
2. Run it
3. Verify with `kubectl config current-context`
4. Then start the actual task
