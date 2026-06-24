# Debrief: Service Unreachable — Label Selector Mismatch

## What happened?

The Service had `selector: app: api` but the pods had label `app: backend`.
Kubernetes Services use label selectors to dynamically discover pods.
When no pods match, the Endpoints object has no addresses — traffic has nowhere to go.

## How service routing works

```
Service (selector: app=backend)
    ↓
Endpoints controller watches pods
    ↓
Pods with label app=backend → added to Endpoints
    ↓
kube-proxy programs iptables/ipvs rules
    ↓
Traffic to Service ClusterIP → routed to one of the Endpoints
```

## The golden diagnostic command

```bash
kubectl get endpoints <service-name> -n <ns>
```

- Shows endpoints: means pods matched
- Shows `<none>`: selector mismatch

## Commands you practiced

```bash
kubectl get endpoints -n ckaquest              # Check endpoint registration
kubectl get pods --show-labels -n ckaquest     # See pod labels
kubectl get svc -o yaml -n ckaquest            # See service selector
kubectl patch service ...                       # Fix selector without delete
kubectl describe svc <name> -n ckaquest        # Summary view
```

## CKA exam tip

Service connectivity issues on the CKA exam almost always trace back to:
1. Label selector mismatch (this level)
2. Wrong targetPort
3. NetworkPolicy blocking

Always check endpoints first. If endpoints are empty → selector problem.
If endpoints exist but traffic still fails → port or NetworkPolicy problem.

## Interview question

**Q: How does a Kubernetes Service know which pods to send traffic to?**

A: Via label selectors. The Endpoints controller continuously watches pods
that match the Service's selector. Matching pods' IPs are added to the
Endpoints object. kube-proxy uses this to program the node's iptables/IPVS
rules, routing traffic from the Service's ClusterIP to one of the pod IPs.
