# Garage On Synology DS223j (Container Manager)

This runbook stands up a single-node Garage S3 endpoint on `synology01` and prepares buckets/credentials for:

- Longhorn backups (`longhorn-backups`)
- Velero backups (`velero-backups`)

It matches the repo manifests that now read credentials from two source secrets:

- `velero-backup-s3-secrets`
- `longhorn-backup-s3-secrets`

Both source secrets use the same property names:

- `access_key_id`
- `secret_access_key`

## 0. Decide the CA source for Synology

From your workstation with `kubectl` access to the cluster:

```bash
kubectl -n cert-manager get secret ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.pem
```

This exports `cert-manager/ca-secret` to `homelab-ca.pem`. Use it only if you
are intentionally issuing Synology from the cluster CA.

For full Synology certificate issuance/import, follow:

- `docs/synology-tls-chain-of-trust.md`

The backup clients themselves do not read CA material from `velero-backup-s3-secrets`
or `longhorn-backup-s3-secrets`. They read a shared Git-managed secret:

- `platform/external-secrets-vault/external-secrets-vault/templates/backup-s3-ca.yaml`

## 1. Prepare Synology folders

SSH to Synology and create persistent directories:

```bash
sudo mkdir -p /volume1/garage/{config,meta,data}
sudo chown -R 1000:1000 /volume1/garage
```

## 2. Create Garage config

Create `/volume1/garage/config/garage.toml`:

```toml
metadata_dir = "/var/lib/garage/meta"
data_dir = "/var/lib/garage/data"
db_engine = "sqlite"
replication_mode = "none"

rpc_bind_addr = "0.0.0.0:3901"
rpc_public_addr = "synology01.homelab.internal:3901"
rpc_secret = "REPLACE_WITH_LONG_RANDOM_SECRET"

[s3_api]
s3_region = "garage"
api_bind_addr = "0.0.0.0:3900"

[admin]
api_bind_addr = "0.0.0.0:3903"
admin_token = "REPLACE_WITH_LONG_RANDOM_TOKEN"
metrics_token = "REPLACE_WITH_LONG_RANDOM_TOKEN"
```

Generate strong values:

```bash
openssl rand -hex 32
```

## 3. Start Garage in Container Manager

Use a Container Manager project with this compose file:

```yaml
services:
  garage:
    image: dxflrs/garage:v2.2.0
    container_name: garage
    restart: unless-stopped
    ports:
      - "3900:3900" # S3 API
      - "3901:3901" # RPC
      - "3903:3903" # Admin API
    volumes:
      - /volume1/garage/config/garage.toml:/etc/garage.toml:ro
      - /volume1/garage/meta:/var/lib/garage/meta
      - /volume1/garage/data:/var/lib/garage/data
```

## 4. Initialize single-node layout

```bash
alias garage='docker exec -ti garage /garage -c /etc/garage.toml'
garage status
```

Grab the node ID from `garage status`, then:

```bash
garage layout assign -z homelab -c 1T <NODE_ID>
garage layout show
garage layout apply --version 1
```

## 5. Create buckets and access keys

```bash
garage bucket create longhorn-backups
garage bucket create velero-backups
garage key create longhorn-key
garage key create velero-key
garage key info longhorn-key
garage key info velero-key
```

From `garage key info ...`, copy:

- Access key ID
- Secret access key

Grant bucket permissions with least privilege (one key per bucket):

```bash
garage bucket allow --read --write --owner longhorn-backups --key longhorn-key
garage bucket allow --read --write --owner velero-backups --key velero-key
```

If you prefer one shared key for both buckets, create one key and grant both buckets to that key.

## 6. Put credentials into external secret store

Create/update entry `longhorn-backup-s3-secrets` with the Longhorn key:

```json
{
  "access_key_id": "<ACCESS_KEY_ID>",
  "secret_access_key": "<SECRET_ACCESS_KEY>"
}
```

Create/update entry `velero-backup-s3-secrets` with the Velero key using the same JSON shape.

The CA certificate (or full chain) that signed Synology's TLS cert belongs in:

- `platform/external-secrets-vault/external-secrets-vault/templates/backup-s3-ca.yaml`

That keeps one shared trust anchor under GitOps instead of two manual copies in
source secrets.

## 7. Endpoint/DNS/TLS

The repo should point backup clients to Garage's native S3 API using the
Garage hostname directly:

- `http://s3.homelab.internal:3900`

Recommended TLS setup:

- Import the certificate/key pair signed by the homelab CA into Synology Certificate Center.
- Assign that certificate to the reverse proxy/frontend serving `s3.homelab.internal`.
- Keep `platform/external-secrets-vault/external-secrets-vault/templates/backup-s3-ca.yaml`
  aligned to the CA used to sign that certificate.

Do not send Velero or Longhorn through the Synology reverse-proxy listener on
port 443 while it can return HTML `504` responses for S3 API calls. Keep the
reverse proxy only for browser-facing access if you need it.

If you do not have TLS at first, temporarily switch to `http://...` in:

- `bootstrap/longhorn/settings/longhorn-backup-settings.yaml`
- `platform/storage/velero/values.yaml`

Then switch back to HTTPS once Synology reverse proxy/cert is in place.

Quick TLS verification from cluster:

```bash
kubectl run tls-check --rm -it --restart=Never --image=curlimages/curl -- \
  sh -c "curl -v https://s3.homelab.internal"
```

## 8. Verify from cluster

After Argo sync:

```bash
kubectl -n longhorn-system get secret longhorn-backup-credentials -o yaml
kubectl -n storage get secret velero-cloud-credentials -o yaml
kubectl -n storage get pods -l app.kubernetes.io/name=velero
```

Validate with one manual Velero backup and one Longhorn recurring backup run.
