# AGENTS.md

Guidelines for AI agents working on this homelab infrastructure repository.

## Repository Structure

```
homelab-infra/
├── ansible/           # Ansible playbooks for node configuration
├── apps/              # Application deployments (values overrides)
│   ├── downloads/     # qbittorrent, jackett
│   ├── music/         # navidrome, lidarr, syncthing
│   └── videos/        # jellyfin, radarr, sonarr
├── bootstrap/         # Bootstrap manifests (metallb, longhorn, argocd)
├── charts/            # Custom Helm charts
└── platform/          # Platform services (cert-manager, traefik, monitoring)
```

## App Deployment Types

The `app.yaml` file determines how ArgoCD deploys each application. There are **three types**:

### 1. `type: remote` - External Helm Charts with Dependencies

Use when pulling a chart from an external Helm repository as a dependency.

**Directory structure:**
```
platform/<category>/<app-name>/
├── app.yaml       # type: remote
├── Chart.yaml     # Helm chart with dependencies
└── values.yaml    # Values overrides for the dependency
```

**app.yaml:**
```yaml
type: remote
```

**Chart.yaml:**
```yaml
apiVersion: v2
name: <app-name>
version: 0.1.0
dependencies:
  - name: <chart-name>
    version: <version>
    repository: https://charts.example.com/
```

**values.yaml** (note: values are nested under dependency name):
```yaml
<chart-name>:
  setting: value
```

**Examples:** cert-manager, external-dns, kube-prometheus-stack, traefik, temporal

---

### 2. `type: local` - Local Charts from `/charts/`

Use when you have a custom chart in the `charts/` directory.

**Directory structure:**
```
platform/<category>/<app-name>/     # OR apps/<category>/<app-name>/
├── app.yaml       # type: local, chart: <chart-name>
└── values.yaml    # Values overrides

charts/<chart-name>/
├── Chart.yaml
├── values.yaml
└── templates/
```

**app.yaml:**
```yaml
chart: <chart-name>
type: local
```

**values.yaml** (values are NOT nested):
```yaml
setting: value
```

**Examples:** jellyfin, radarr, sonarr, haproxy, valkey, ca-issuer

---

### 3. `type: oci` - OCI Registry Charts

Use when pulling a chart from an OCI container registry.

**Directory structure:**
```
platform/<category>/<app-name>/
├── app.yaml       # type: oci, repoURL, chart, version
└── values.yaml    # Values overrides
```

**app.yaml:**
```yaml
type: oci
# Note: Do NOT include oci:// prefix, just the registry path
repoURL: ghcr.io/your-org/charts
chart: <chart-name>
version: <version>
```

**values.yaml** (values are NOT nested):
```yaml
setting: value
```

**Examples:** any chart published to an OCI registry

---

### Quick Reference

| Type | When to Use | app.yaml Fields |
|------|-------------|-----------------|
| `remote` | External Helm repo with Chart.yaml dependencies | `type: remote` |
| `local` | Custom chart in `/charts/` directory | `type: local`, `chart: <name>` |
| `oci` | OCI container registry | `type: oci`, `repoURL`, `chart`, `version` |

## Service Exposure Pattern

All services use **Traefik Ingress** for TLS termination:

1. **Service type:** `ClusterIP` (not LoadBalancer)
2. **Ingress:** Enabled with host-based routing
3. **TLS:** Handled by Traefik using wildcard certificate
4. **DNS:** external-dns creates A records in Pi-Hole pointing to Traefik's IP (10.0.0.18)

### Chart values.yaml Pattern
```yaml
service:
  type: ClusterIP
  port: <internal-port>

ingress:
  enabled: false  # Enabled via app values
  ingressClassName: traefik
  host: <app>.homelab.internal
  annotations: {}
  tls:
    enabled: true
```

### App values.yaml Pattern
```yaml
service:
  type: ClusterIP
  port: <internal-port>
ingress:
  enabled: true
  host: <app>.homelab.internal
```

## Key Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Traefik** | Ingress controller, TLS termination | `platform/networking/traefik/` |
| **cert-manager** | Certificate management | `platform/cert-manager/` |
| **external-dns** | DNS record management (Pi-Hole) | `platform/networking/external-dns/` |
| **MetalLB** | LoadBalancer IPs | `bootstrap/metallb/` |

## TLS Configuration

- **CA Certificate:** Self-signed, 10-year validity, in `ca-secret` (cert-manager namespace)
- **Wildcard Certificate:** `*.homelab.internal`, 1-year validity, auto-renewed
- **Traefik IP:** `10.0.0.18`

## Common Tasks

### Adding a New Service with TLS
1. Create chart in `charts/<name>/` with service and ingress templates
2. Create app config in `apps/<category>/<name>/` or `platform/<category>/<name>/`
3. Set `ingress.enabled: true` and `host: <name>.homelab.internal`
4. ArgoCD will auto-deploy and external-dns will create DNS record

### Checking Certificate Status
```bash
kubectl get certificate -A
kubectl describe certificate <name> -n <namespace>
```

### Workstation Setup Notes

- Keep workstation documentation neutral by default. If a step differs on macOS, Linux, or Windows, add OS-specific alternates instead of rewriting the whole guide around one platform.
- When documenting CA trust, include the export command from `cert-manager/ca-secret` and the relevant trust-store command(s) for the target OS only when needed.
- For Windows users, prefer WSL or another Linux shell for repo workflows, but keep the instructions usable from macOS and Linux too.
- When working from a Windows machine, run repo commands in Debian WSL by default. Avoid PowerShell and Command Prompt unless the task explicitly requires Windows-native tooling.
- Verify helper script names and paths before referencing them in docs. If a script no longer exists, update the documentation to the actual command or recreate the script.

## Do NOT

- Use `LoadBalancer` type for services (use `ClusterIP` + Ingress)
- Specify TLS secretName in Ingress (Traefik's default cert handles it)
- Run git add/commit/push commands
- Run kubectl write commands without user approval
- Perform direct cluster mutations for app/platform resources (`kubectl apply/patch/edit/delete`, Argo sync/refresh annotations, etc.) outside GitOps. All non-secret changes must flow through repo commits and Argo reconciliation.
- Exception: creating/updating source secrets in `external-secrets-vault` (for ExternalSecrets inputs such as `velero-backup-s3-secrets` and `longhorn-backup-s3-secrets`) is allowed when required.

## Storage & Backup Guidelines

- Treat in-cluster object storage as operational convenience only; DR-grade backups must target an external S3-compatible endpoint such as Garage or MinIO on Synology. Prefer the native Garage S3 API path (for example `http://s3.homelab.internal:3900`) over a reverse-proxied `443` listener for Velero/Longhorn traffic.
- Follow `docs/synology-garage-bootstrap.md` to bootstrap the Synology-side Garage endpoint, buckets, and access key before enabling Longhorn/Velero backups.
- Keep CNPG on in-cluster MinIO only as an interim state; migrate CNPG backups to the same external S3 backend once stability is confirmed for Velero and Longhorn restores.
- Update both `bootstrap/longhorn/settings/longhorn-backup-settings.yaml` and `platform/storage/velero/values.yaml` together whenever the S3 endpoint, bucket, or TLS settings change so backup paths stay consistent.
- Keep `longhorn-ephemeral`/`longhorn-standard`/`longhorn-persistent` aligned to their intended durability tiers (Delete vs Retain) and ensure every critical PVC explicitly picks the right class in its Helm values; refer to `bootstrap/longhorn/storage-classes.yaml` and reproduce the `numberOfReplicas=2`/`staleReplicaTimeout=2880` settings for future classes.
- Store DR S3 credentials in separate ExternalSecret source entries: `velero-backup-s3-secrets` and `longhorn-backup-s3-secrets`.
- Keep the shared public backup CA in Git at `platform/external-secrets-vault/external-secrets-vault/templates/backup-s3-ca.yaml`. Do not duplicate CA PEM blobs inside per-consumer source secrets.
- Each backup source secret must include only `access_key_id` and `secret_access_key`. Velero and Longhorn consume TLS trust from the shared `backup-s3-ca` secret so cluster rebuilds and source-secret drift cannot silently break S3 trust.
- Any maintenance workflow that drains longhorn-backed pods must annotate StatefulSet pods with `maintenance-ticket` before deletion; the Kyverno policy in `platform/kyverno/policies/maintenance-drain-policy.yaml` enforces this annotation on `DELETE` operations.
