# Debrief: kubeconfig — Wrong Current Context

## What happened?

A new context (`broken-context`) was added with invalid credentials, and
`current-context` was set to it. Since the user referenced a non-existent
certificate, every API call failed with an authentication error.

## Context switching — the most-used CKA skill

The CKA exam uses multiple clusters. Every question tells you which context
to use. **Always switch context before starting a question.**

```bash
# The most important command on the CKA exam:
kubectl config use-context <context-name>
```

One mistake in context = working on the wrong cluster = failed question.

## Context components

```
context:
  cluster: which API server to connect to
  user: which credentials to use
  namespace: default namespace (optional)
```

## Setting a default namespace in a context

```bash
kubectl config set-context --current --namespace=ckaquest
# Now: kubectl get pods  →  gets pods from ckaquest namespace
```

This is very useful for the CKA exam to avoid typing `-n <ns>` every time.

## CKA exam workflow

```bash
# Start of every question:
kubectl config use-context <given-context>

# Optional: set default namespace for that question
kubectl config set-context --current --namespace=<given-ns>

# Verify you're in the right place
kubectl config current-context
kubectl get nodes
```

## Interview question

**Q: How do you create a kubeconfig for a new ServiceAccount?**

A: Extract the ServiceAccount's token secret, the cluster CA certificate,
and the API server URL. Then build a kubeconfig with:
- `kubectl config set-cluster` (server + CA)
- `kubectl config set-credentials` (with the SA token)
- `kubectl config set-context` (linking cluster + user)
- `kubectl config use-context` to activate it

Or use `kubectl create token <sa-name>` (Kubernetes 1.24+) to generate
a short-lived token without creating a Secret.
