# Level 14 Debrief: Accessing the API Server From Inside a Pod

## What Was Broken

The pod `debug-pod` had environment variables `KUBERNETES_SERVICE_HOST` and
`KUBERNETES_SERVICE_PORT` manually set to wrong values. The overridden
`KUBERNETES_SERVICE_HOST` pointed to `10.99.99.99` which does not exist,
preventing any API server communication.

## The Fix

Remove the env var overrides from the pod spec. Kubernetes automatically
injects the correct values for service discovery.

## How Pods Discover the API Server

Kubernetes provides two mechanisms for pods to find the API server:

### 1. Environment Variables (auto-injected)

Every pod automatically gets:
```
KUBERNETES_SERVICE_HOST=<api-server-ip>
KUBERNETES_SERVICE_PORT=443
```
These point to the `kubernetes` ClusterIP service in the `default` namespace.

### 2. DNS (preferred)

The API server is always reachable at:
```
https://kubernetes.default.svc
```
This is more reliable than env vars because DNS is dynamic.

## Authenticating From Inside a Pod

To call the API server from a pod, you need three things from the mounted
service account token volume:

```bash
# The token for authentication
TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

# The CA cert to verify the API server's TLS certificate
CACERT=/var/run/secrets/kubernetes.io/serviceaccount/ca.crt

# The namespace (useful for scoped requests)
NAMESPACE=$(cat /var/run/secrets/kubernetes.io/serviceaccount/namespace)

# Example API call
curl -s \
  --cacert $CACERT \
  -H "Authorization: Bearer $TOKEN" \
  https://kubernetes.default.svc/api/v1/namespaces/$NAMESPACE/pods
```

## Service Environment Variables

For every Service in the same namespace, Kubernetes injects env vars:
```
<SERVICE_NAME>_SERVICE_HOST=<cluster-ip>
<SERVICE_NAME>_SERVICE_PORT=<port>
```

The `kubernetes` service in the `default` namespace is special -- its env vars
are injected into ALL pods in ALL namespaces.

**Warning:** Manually setting these env vars overrides the auto-injected values,
which can break connectivity (as in this level).

## CKA Exam Tip

Know the mounted token path and how to curl the API server from inside a pod.
The exam may test:
- Path: `/var/run/secrets/kubernetes.io/serviceaccount/token`
- CA cert: `/var/run/secrets/kubernetes.io/serviceaccount/ca.crt`
- API URL: `https://kubernetes.default.svc`
- Auth header: `Authorization: Bearer <token>`
