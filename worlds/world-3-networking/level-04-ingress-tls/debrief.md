# Debrief: Ingress TLS — Missing Certificate Secret

## What happened?

The Ingress spec had a `tls` section referencing Secret `webapp-tls`, but
the Secret didn't exist. Without it, the Ingress controller falls back to
its default self-signed cert or fails to serve HTTPS entirely.

## TLS secret structure

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: webapp-tls
  namespace: ckaquest
type: kubernetes.io/tls          # Must be this type
data:
  tls.crt: <base64-encoded-cert>  # PEM certificate
  tls.key: <base64-encoded-key>   # PEM private key
```

`kubectl create secret tls` handles all the encoding automatically.

## Generate a self-signed certificate

```bash
# Self-signed (for testing/dev)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key \
  -out tls.crt \
  -subj "/CN=myapp.example.com"

# Create the secret
kubectl create secret tls myapp-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n mynamespace
```

## Ingress TLS configuration

```yaml
spec:
  tls:
    - hosts:
        - myapp.example.com    # Must match the certificate's CN/SAN
      secretName: myapp-tls   # Must exist in same namespace as Ingress
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

## Test TLS

```bash
# Using -k to skip cert validation (self-signed)
curl -k https://myapp.example.com

# With Host header (if using IP)
NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[0].address}')
curl -k -H "Host: webapp.local" https://$NODE_IP
```

## CKA exam tip

TLS secrets are tested frequently. Key facts:
1. Secret type must be `kubernetes.io/tls`
2. Keys must be exactly `tls.crt` and `tls.key`
3. Secret must be in the **same namespace** as the Ingress
4. `kubectl create secret tls` is the fastest way to create it
5. On the exam, the cert/key files are usually provided — just create the secret

## Interview question

**Q: Where does TLS termination happen with Kubernetes Ingress?**

A: At the Ingress controller (e.g., nginx, Traefik). The controller decrypts
HTTPS traffic and forwards plain HTTP to the backend Service/Pods. This is
called TLS termination or SSL offloading. The traffic inside the cluster
(Ingress → Service → Pod) is unencrypted. For end-to-end encryption, you'd
need to configure TLS passthrough or re-encryption in the Ingress controller.
