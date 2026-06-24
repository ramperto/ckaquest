# Level 19 Debrief: TLS Certificate with Wrong Common Name

## What Happened

The TLS secret `app-tls` contained a certificate with `CN=wrong.example.com` instead
of the required `CN=app.example.com`. While the Deployment and Service worked fine,
any Ingress or application using this certificate would present the wrong identity
to clients, causing TLS verification failures.

## TLS in Kubernetes

### How TLS Secrets Work

Kubernetes TLS secrets store two pieces of data:
- `tls.crt` — the certificate (PEM encoded)
- `tls.key` — the private key (PEM encoded)

They are typed as `kubernetes.io/tls` and validated by the API server to ensure
both fields are present and properly formatted.

### Creating TLS Secrets

```bash
# Create from existing cert and key files
kubectl create secret tls my-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n my-namespace
```

### How Ingress Uses TLS Secrets

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-ingress
spec:
  tls:
    - hosts:
        - app.example.com
      secretName: app-tls    # references the TLS secret
  rules:
    - host: app.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-svc
                port:
                  number: 80
```

## Essential OpenSSL Commands

### Generate a Self-Signed Certificate

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj '/CN=app.example.com'
```

### Generate with Subject Alternative Names (SANs)

```bash
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj '/CN=app.example.com' \
  -addext 'subjectAltName=DNS:app.example.com,DNS:*.example.com'
```

### Inspect a Certificate

```bash
# View subject (CN)
openssl x509 -in tls.crt -noout -subject

# View full details
openssl x509 -in tls.crt -noout -text

# View expiration
openssl x509 -in tls.crt -noout -dates

# View SANs
openssl x509 -in tls.crt -noout -ext subjectAltName

# Inspect from a Kubernetes secret
kubectl get secret app-tls -n ckaquest \
  -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -subject
```

### Generate a CSR (Certificate Signing Request)

```bash
openssl req -new -newkey rsa:2048 -nodes \
  -keyout tls.key -out tls.csr \
  -subj '/CN=app.example.com'
```

## CKA Exam Tips

- **Know `openssl req`** for generating certs and CSRs
- **Know `openssl x509`** for inspecting certificates
- **Know `kubectl create secret tls`** — faster than writing YAML
- Modern browsers and tools check SANs, not just CN. Use `-addext` for SANs
- The CKA may ask you to create certificates for the Kubernetes API server,
  etcd, or kubelet — the openssl commands are the same pattern
- To replace a secret, delete and recreate — there is no `kubectl update secret`
