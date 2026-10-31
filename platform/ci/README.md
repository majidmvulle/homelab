# GitHub Actions Runner Controller (ARC)

This directory contains the GitOps deployment for GitHub Actions Runner Controller (ARC) and autoscaling self-hosted runner scale sets.

## Architecture

- **Controller**: `platform/ci/gh-arc-controller`
  - Deploys `gha-runner-scale-set-controller` (OCI chart) into the `ci` namespace.
  - Manages runner scale sets, listeners, and ephemeral runner pod lifecycles.
- **Runner Scale Set**: `platform/ci/homelab-gh-runner`
  - Deploys `gha-runner-scale-set` (OCI chart) into the `ci` namespace.
  - Registers autoscaling ephemeral runners (`runs-on: homelab-gh-runner`) to the `your-org` organization.
  - Configured with `containerMode: dind` to allow building container images and running Docker commands.

---

## 1. Prerequisites & Secret Setup

ARC requires authentication to register runners with your GitHub organization (`https://github.com/your-org`).

### A. Create a GitHub Personal Access Token (PAT)
1. Go to **GitHub** > **Settings** > **Developer Settings** > **Personal access tokens** (Classic or Fine-grained).
2. For Classic PAT:
   - Required scope: `admin:org` (to register organization-wide runners).
3. For Fine-grained PAT:
   - Organization permissions: `Organization self-hosted runners` (Read and Write).

### B. Create Source Secret in `external-secrets-vault`
Create the source secret in the `external-secrets-vault` namespace so the External Secrets Operator can sync it to the `ci` namespace:

```bash
kubectl create secret generic homelab-gh-runner-secret \
  -n external-secrets-vault \
  --from-literal=github_token="ghp_your_personal_access_token_here"
```

---

## 2. Using the Runner in Workflows

In any GitHub Actions workflow inside `your-org` repositories, target the runner using:

```yaml
name: CI Workflow

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: homelab-gh-runner # Matches the runnerScaleSetName in values.yaml
    steps:
      - uses: actions/checkout@v4

      - name: Build Docker Image
        run: |
          docker build -t test-image:latest .
          docker images
```

> **Note**: Workflows can choose on a per-job basis whether to run on GitHub-hosted runners (`runs-on: ubuntu-latest`) or this self-hosted runner cluster (`runs-on: homelab-gh-runner`).
