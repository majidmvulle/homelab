# Valkey Failover Notes

This Valkey deployment runs as `1` primary plus `2` replicas with a Sentinel sidecar on each pod.

## Writer Path

Applications should not connect to `valkey.cache.svc.cluster.local` for writes.

Write traffic goes through `valkey-haproxy.cache.svc.cluster.local:6379`, which probes each Valkey pod and only forwards to the node currently reporting `role:master`.

## Failover Behavior

Sentinel is responsible for promoting a replica when the current primary fails.

HAProxy does not elect a master. It only follows the result of Sentinel failover by checking `INFO replication` and routing to the pod that now reports itself as master.

## Restart Behavior

Valkey startup no longer assumes `valkey-0` is always the primary.

On restart, each Valkey pod tries startup in this order:

1. Ask peer Sentinels for the current `mymaster`.
2. Fall back to the last persisted `/data/sentinel.conf` state on the local pod.
3. Only if neither source is available, use the original bootstrap topology with `valkey-0` as the seed primary.

Each Sentinel sidecar also reuses its persisted `/data/sentinel.conf` when present, so a restart does not reset Sentinel's view of the elected master back to `valkey-0`.

## Operational Note

The bootstrap fallback still exists to recover from a full cold start where no Sentinel state is available anywhere yet. That path is for cluster initialization and disaster recovery, not for normal failover.
