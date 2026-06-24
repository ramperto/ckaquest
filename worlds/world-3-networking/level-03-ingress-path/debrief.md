# Debrief: Ingress — Path Not Matching

## What happened?

The Ingress rule used path `/application` but traffic was sent to `/app`.
These paths don't overlap under `pathType: Prefix`, so the Ingress controller
couldn't match any rule and returned 404.

## pathType values

| pathType | Behaviour |
|----------|---------|
| `Exact` | Exact string match. `/app` ≠ `/app/` |
| `Prefix` | Prefix match split by `/`. `/app` matches `/app`, `/app/`, `/app/page` |
| `ImplementationSpecific` | Controller-defined (regex support in some) |

```
pathType: Prefix, path: /app
  Matches: /app, /app/, /app/page, /app/v2/endpoint
  No match: /application, /App (case-sensitive), /otherapp
```

## Ingress rule anatomy

```yaml
spec:
  ingressClassName: nginx         # which controller handles this
  rules:
    - host: myapp.example.com     # optional: virtual hosting by hostname
      http:
        paths:
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: api-svc
                port:
                  number: 8080
          - path: /               # catch-all (must be last)
            pathType: Prefix
            backend:
              service:
                name: frontend-svc
                port:
                  number: 80
```

## k3s Traefik vs exam nginx-ingress

k3s uses **Traefik** as its default ingress controller.
The CKA exam clusters typically use **nginx ingress controller**.

Both support standard Kubernetes Ingress spec. The IngressClass name differs:
- k3s/Traefik: `ingressClassName: traefik`
- Exam/nginx: `ingressClassName: nginx`

On the CKA exam, the question will tell you which IngressClass to use.

## CKA exam tip

Ingress questions usually ask you to:
1. Create an Ingress with a specific host and/or path
2. Use a specific IngressClass (check: `kubectl get ingressclass`)
3. Route to a specific Service and port

Quick template:
```bash
kubectl create ingress myapp \
  --rule="myapp.com/api*=api-svc:8080" \
  --class=nginx \
  -n myns
```

## Interview question

**Q: Can one Ingress resource route to multiple services?**

A: Yes. A single Ingress can have multiple rules and multiple paths, each
routing to a different Service. You can route by host (`host: api.example.com`
vs `host: app.example.com`) and/or by path (`/api` vs `/web`). This is the
core feature that makes Ingress more powerful than NodePort — one entry point
with complex routing logic.
