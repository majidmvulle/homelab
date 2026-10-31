# Synology TLS Chain Of Trust (cert-manager CA)

Use the cluster CA (`ca-issuer`) as the trust root and issue Synology certificates from cert-manager.

This creates one chain of trust for:

- `synology01.homelab.internal`
- `files.homelab.internal`
- `photos.homelab.internal`
- `s3.homelab.internal`

## 1. Apply certificate resource

The repo now includes:

- `platform/cert-manager/ca-issuer/synology-services-certificate.yaml`

It issues `synology-services-tls` in `cert-manager` namespace.

After Argo sync, verify:

```bash
kubectl -n cert-manager get certificate synology-services
kubectl -n cert-manager get secret synology-services-tls
```

## 2. Export cert, key, and chain from cluster

```bash
./scripts/export-synology-tls-from-cert-manager.sh
```

Output directory (default): `./out/synology-tls`

Files:

- `synology-services-fullchain.crt`
- `synology-services.key`
- `homelab-ca.crt`

## 3. Import into Synology

In Synology Certificate Center:

- Import certificate using:
  - Certificate: `synology-services-fullchain.crt`
  - Private key: `synology-services.key`
- Assign this certificate to DSM/reverse proxy endpoints for:
  - `synology01.homelab.internal`
  - `files.homelab.internal`
  - `photos.homelab.internal`
  - `s3.homelab.internal`

## 4. Keep backup clients aligned

Use one shared CA in backup client trust:

- `platform/external-secrets-vault/external-secrets-vault/templates/backup-s3-ca.yaml`
  should contain the public CA cert that signs Synology's served TLS chain.
- `longhorn-backup-s3-secrets` should contain only the Longhorn S3 access key pair.
- `velero-backup-s3-secrets` should contain only the Velero S3 access key pair.
- Longhorn and Velero ExternalSecrets consume credentials from those source
  secrets and consume TLS trust from the shared `backup-s3-ca` secret.
