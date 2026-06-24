# Debrief: Egress Deny All — Empty Egress Array Blocks Everything

## The egress trap: `egress: []` vs omitting egress

This is one of the most confusing aspects of NetworkPolicy:

| Configuration                                | Effect                          |
|----------------------------------------------|---------------------------------|
| `policyTypes: [Egress]` + `egress: []`       | **Deny ALL egress**             |
| `policyTypes: [Egress]` + egress with rules  | Allow only what rules permit    |
| `policyTypes: [Egress]` + no egress field    | **Deny ALL egress**             |
| No Egress in policyTypes + no egress field   | No egress restriction           |

The key insight: once `Egress` appears in `policyTypes`, all outbound
traffic is denied **unless** explicitly allowed by egress rules. An empty
array `[]` and an omitted field both mean "no rules" = "deny all".

## Why DNS matters for egress policies

When you restrict egress, pods lose the ability to make DNS queries
unless you explicitly allow it. Without DNS:

- `wget api-svc` fails (can't resolve the name)
- `wget 10.43.100.5` might work (direct IP bypasses DNS)

This is why **every egress NetworkPolicy should include a DNS rule**:

```yaml
egress:
  # Allow DNS resolution
  - to: []
    ports:
      - port: 53
        protocol: UDP
      - port: 53
        protocol: TCP
```

## NetworkPolicy egress rule structure

```yaml
egress:
  - to:                    # destination selectors (AND-ed with ports)
      - podSelector: {}    # which pods
      - namespaceSelector: {}  # which namespaces
      - ipBlock: {}        # which IP ranges
    ports:                 # which ports
      - port: 80
        protocol: TCP
```

### Important: `to` array items are OR-ed

```yaml
to:
  - podSelector:            # match pods with app=api
      matchLabels:
        app: api
  - namespaceSelector:      # OR match any pod in kube-system
      matchLabels:
        kubernetes.io/metadata.name: kube-system
```

This allows traffic to api pods in the current namespace **OR** to any
pod in kube-system. They are independent selectors.

### Combining selectors (AND logic)

To require BOTH a namespace AND a pod selector, put them in the **same**
`to` list item:

```yaml
to:
  - podSelector:              # AND — must match both
      matchLabels:
        app: api
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: backend
```

## Building a proper egress policy

Here is the complete pattern for restricting egress while keeping DNS:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: web-egress
  namespace: ckaquest
spec:
  podSelector:
    matchLabels:
      app: web
  policyTypes:
    - Egress
  egress:
    # Rule 1: Allow traffic to specific pods
    - to:
        - podSelector:
            matchLabels:
              app: api
      ports:
        - port: 80
          protocol: TCP

    # Rule 2: Allow DNS (always include this!)
    - to: []
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
```

## More restrictive DNS rule

The above DNS rule allows DNS to **any** destination. For tighter security,
target only the kube-system namespace where CoreDNS runs:

```yaml
    # DNS only to kube-system
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
```

Note: the namespace label `kubernetes.io/metadata.name` is automatically
added by Kubernetes 1.21+.

## Debugging NetworkPolicy egress

```bash
# 1. Check what NetworkPolicies apply to a pod
kubectl get networkpolicies -n ckaquest

# 2. Describe to see rules
kubectl describe networkpolicy web-egress -n ckaquest

# 3. Test connectivity from the affected pod
WEB_POD=$(kubectl get pods -n ckaquest -l app=web -o name | head -1)
kubectl exec $WEB_POD -n ckaquest -- wget -qO- --timeout=3 api-svc
kubectl exec $WEB_POD -n ckaquest -- nslookup api-svc

# 4. Test with direct IP (bypasses DNS — isolates the problem)
API_IP=$(kubectl get pod -n ckaquest -l app=api -o jsonpath='{.items[0].status.podIP}')
kubectl exec $WEB_POD -n ckaquest -- wget -qO- --timeout=3 $API_IP

# 5. If direct IP works but name doesn't — DNS is blocked
```

## Default deny patterns

```yaml
# Deny all egress for all pods in namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-egress
spec:
  podSelector: {}          # all pods
  policyTypes:
    - Egress
  egress: []               # deny all

# Deny all ingress for all pods in namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all-ingress
spec:
  podSelector: {}
  policyTypes:
    - Ingress
  ingress: []

# Deny all ingress AND egress
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress: []
  egress: []
```

## CKA exam tip

When writing egress NetworkPolicies on the CKA exam, **ALWAYS add a DNS
egress rule**. This is the single most common mistake. Without DNS,
pods can't resolve any service names, and the entire application breaks.

The exam may not explicitly mention DNS — you need to know it's required.
A good habit: every time you add `policyTypes: [Egress]`, immediately
add a DNS rule before doing anything else.

## Interview question

**Q: What is the difference between `egress: []` and not specifying
egress at all in a NetworkPolicy?**

A: If `Egress` is in `policyTypes`, both `egress: []` and omitting
the egress field entirely have the same effect: deny all egress traffic.
If `Egress` is NOT in `policyTypes` and the egress field is omitted,
the policy does not affect egress at all. The critical distinction is
whether `Egress` appears in `policyTypes`. Once it does, you must
explicitly allow every type of outbound traffic you need, including DNS
on port 53.
