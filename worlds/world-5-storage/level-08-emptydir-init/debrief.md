# Debrief: emptyDir — Init Container Volume Handoff

## emptyDir lifecycle

An `emptyDir` volume:
- Created empty when the pod is scheduled to a node
- Shared between ALL containers in the pod (init + main)
- Deleted when the pod is removed from the node
- Survives container restarts (not pod deletion)

```yaml
volumes:
  - name: shared-vol
    emptyDir: {}          # in-memory variant: emptyDir: {medium: Memory}
```

## The init container handoff pattern

```
Init container:                    Main container:
  mountPath: /work          ←→       mountPath: /work
  writes /work/config.json           reads /work/config.json ✓

VS broken:
  mountPath: /work                   mountPath: /data
  writes /work/config.json           reads /data/config.json → empty! ✗
```

The emptyDir is the SAME volume object in kernel, but the path it
appears at inside each container is set by `mountPath`. Both must
use the same path to see the same files.

## Init container sequence

```
1. Init containers run sequentially (init-1 → init-2 → ... → main)
2. Each init must exit 0 before the next starts
3. Main containers start only after ALL inits complete
4. If an init crashes, pod retries according to restartPolicy
```

## emptyDir use cases

| Use case | Description |
|----------|-------------|
| Init handoff | Init pre-populates data for main container |
| Scratch space | Temporary workspace for a single container |
| Inter-container sharing | Two sidecars share logs/state |
| In-memory tmpfs | `medium: Memory` for high-speed ephemeral storage |

## emptyDir vs other volume types

| Type | Persists pod restart? | Persists pod deletion? | Shared across nodes? |
|------|----------------------|----------------------|---------------------|
| emptyDir | Yes | No | No |
| hostPath | Yes | Yes (on same node) | No |
| PVC (RWO) | Yes | Yes | No (same node) |
| PVC (RWX) | Yes | Yes | Yes |
| ConfigMap | N/A | N/A | Yes |

## CKA exam tip

Init container + emptyDir is a common CKA pattern. Always verify that:
1. The volume name in `volumes:` matches the name in both `volumeMounts:`
2. The `mountPath` is consistent between init and main containers
3. The init container completes successfully (check `kubectl logs -c init-config`)

## Interview question

**Q: How do init containers and main containers share data?**

A: Through shared volumes, typically `emptyDir`. The init container and main
container both declare a `volumeMount` for the same volume name. The `mountPath`
must be the same (or at least the init container must write files that the
main container reads from its own mountPath). Init containers complete
sequentially before any main container starts, making this pattern safe for
data pre-population, database migration scripts, or configuration generation.
