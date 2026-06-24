# Level 12 Debrief: Certificate Signing Request Approval

## What Was Broken

A CertificateSigningRequest `dev-user-csr` was submitted to the cluster but
left in Pending state. Without approval, no certificate is issued and the user
cannot authenticate.

## The Fix

```bash
kubectl certificate approve dev-user-csr
```

That single command approves the CSR and triggers the cluster CA to issue a
signed certificate.

## Kubernetes CSR Workflow

1. **Generate a private key** -- `openssl genrsa -out user.key 2048`
2. **Create a CSR** -- `openssl req -new -key user.key -out user.csr -subj '/CN=username/O=group'`
3. **Submit to Kubernetes** -- Create a CertificateSigningRequest object with the base64-encoded CSR
4. **Admin approves** -- `kubectl certificate approve <csr-name>`
5. **Extract the cert** -- `kubectl get csr <name> -o jsonpath='{.status.certificate}' | base64 -d`
6. **Configure kubeconfig** -- Use the cert + key to authenticate

## signerName Options

| Signer | Purpose |
|---|---|
| `kubernetes.io/kube-apiserver-client` | Client auth certificates (user access) |
| `kubernetes.io/kube-apiserver-client-kubelet` | Kubelet client certificates |
| `kubernetes.io/kubelet-serving` | Kubelet serving certificates |

## TLS Bootstrapping

Kubelets use the CSR mechanism to bootstrap their own certificates:
- Kubelet generates a key and CSR on startup
- Submits to the API server
- Controller manager auto-approves (with proper RBAC)
- Kubelet gets its certificate and begins serving

## Important Details

- The `usages` field must match the signerName requirements
- For `kube-apiserver-client`, you must include `client auth`
- The CN (Common Name) becomes the username
- The O (Organization) becomes the group
- CSRs can be denied: `kubectl certificate deny <name>`

## CKA Exam Tip

`kubectl certificate approve` is a frequently tested command. The exam may ask
you to approve a CSR or create one from scratch. Remember:
- Base64-encode the CSR content (no line breaks)
- Use the correct signerName
- Check the status after approval to confirm the certificate was issued
