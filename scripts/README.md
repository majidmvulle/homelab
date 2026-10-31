# Homelab Scripts

## Postgres Main Port Forward

Keep a manual outside-cluster port-forward to the homelab Postgres writer alive:

```bash
./port-forward-postgres-main.sh
```

Defaults to `127.0.0.1:5444 -> database/svc/postgres-main-rw:5432`. The helper waits for ready service endpoints and restarts `kubectl port-forward` when the tunnel drops after a pod-side TCP reset.

Optional overrides:

```bash
LOCAL_PORT=5445 ./port-forward-postgres-main.sh
./port-forward-postgres-main.sh --namespace database --resource svc/postgres-main-rw
```

## Backup S3 Secret Payload

Export the cert-manager CA certificate only when you are intentionally reissuing Synology from the cluster CA:

```bash
kubectl -n cert-manager get secret ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.pem
```

Do not store the backup CA in `velero-backup-s3-secrets` or `longhorn-backup-s3-secrets`.
The shared backup trust bundle is committed in Git at:

`platform/external-secrets-vault/external-secrets-vault/templates/backup-s3-ca.yaml`

If Synology starts serving a different CA, update that file once and let both
Velero and Longhorn consume it through ExternalSecrets.

## Synology TLS Export

Export the Synology certificate, key, and CA chain from cert-manager:

```bash
./export-synology-tls-from-cert-manager.sh
```

Optional output directory:

```bash
./export-synology-tls-from-cert-manager.sh ./out/synology-tls
```
