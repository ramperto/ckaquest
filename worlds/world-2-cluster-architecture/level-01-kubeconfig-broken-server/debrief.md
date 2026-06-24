# Debrief: kubeconfig — Wrong Server Address

## What happened?

The kubeconfig `clusters[].cluster.server` field was changed to port 9999.
kubectl uses this URL to reach the Kubernetes API server. Port 9999 has
nothing listening, so every kubectl command failed with "connection refused".

## kubeconfig anatomy

```yaml
apiVersion: v1
kind: Config
clusters:
  - name: my-cluster
    cluster:
      server: https://127.0.0.1:6443   ← API server address
      certificate-authority-data: ...   ← CA cert for TLS verification
contexts:
  - name: my-context
    context:
      cluster: my-cluster
      user: my-user
      namespace: default               ← default namespace for this context
users:
  - name: my-user
    user:
      client-certificate-data: ...
      client-key-data: ...
current-context: my-context            ← active context
```

## Essential kubectl config commands

```bash
kubectl config view                    # Show current kubeconfig
kubectl config get-contexts            # List all contexts
kubectl config current-context         # Show active context
kubectl config use-context <name>      # Switch context
kubectl config set-cluster <name> --server=<url>  # Fix server URL
kubectl config set-context <name> --namespace=<ns>  # Set default ns
```

## Multiple kubeconfigs

```bash
# KUBECONFIG env var can merge multiple files
export KUBECONFIG=~/.kube/config:~/.kube/dev-config

# Or use --kubeconfig flag
kubectl get pods --kubeconfig=/path/to/config
```

## CKA exam tip

The CKA exam often gives you multiple clusters (contexts). Master:
1. `kubectl config get-contexts` — see all clusters
2. `kubectl config use-context <name>` — switch to the right cluster
3. Check the context's namespace if pods aren't showing up

Always verify you're in the right context before starting a question!

## Interview question

**Q: How do you configure kubectl to work with multiple clusters simultaneously?**

A: Set the `KUBECONFIG` environment variable to a colon-separated list of
kubeconfig files. kubectl merges them and presents all contexts. You can
also use `kubectl config use-context` to switch between them, or pass
`--context=<name>` per command to target a specific cluster without switching.
