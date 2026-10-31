> **Public mirror.** This is a sanitized export of the private GitOps repo that runs my homelab.
> Personal apps are left out and real hostnames are replaced with `example.com`.
> I write about it at [https://homelab-blog.pages.dev](https://homelab-blog.pages.dev).
> Want to reuse it? Fork it and change `repoURL` in `bootstrap/argocd/`.

# homelab

Homelab infrastructure for Kubernetes, stateful services, host management, and edge-network planning.

For Valkey failover and restart behavior, see [platform/cache/valkey/README.md](platform/cache/valkey/README.md).

## Network Strategy

- OPNsense runs on `pve01.homelab.internal`
- Proxmox uses a dedicated WAN NIC plus a separate LAN trunk NIC
- the current stable network baseline is a flat `10.0.0.0/24` LAN with OPNsense at `10.0.0.1`
- wired segmentation uses VLANs for management, servers, Kubernetes, clients, and IoT
- the Netgear LAX20 stays in AP mode on a flat Wi-Fi client network
- guest VLAN Wi-Fi and captive portal require a future VLAN-capable AP replacement
Network planning details:

- [docs/network-migration-plan.md](docs/network-migration-plan.md)
- [docs/proxmox-setup-runbook.md](docs/proxmox-setup-runbook.md)
- [docs/dns-and-segmentation-phase-plan.md](docs/dns-and-segmentation-phase-plan.md)
- [docs/ap-replacement-requirements.md](docs/ap-replacement-requirements.md)

## 🖥️ Node Options

This homelab supports two node configurations:

| Option | Nodes | Use Case |
|--------|-------|----------|
| **HP ProDesk 600 G4** (Recommended) | 3× mini-PCs | Higher performance, PostgreSQL HA |
| **Raspberry Pi** (Alternative) | 2-3× Pis | Lower power, simpler setup |

---

## 🖥️ Option A: HP ProDesk 600 G4 Nodes (Recommended)

Three HP ProDesk 600 G4 Mini nodes configured via Ansible:

| Node | Hostname | IP | Roles |
|------|----------|-----|-------|
| mini01 | `mini01.homelab.internal` | `10.0.0.120` | K3s master, PostgreSQL primary |
| mini02 | `mini02.homelab.internal` | `10.0.0.130` | K3s master, PostgreSQL standby |
| mini03 | `mini03.homelab.internal` | `10.0.0.140` | K3s master, PostgreSQL standby |

**Virtual IPs (via Keepalived):**
- K3s API: `10.0.0.2` (`k3s.homelab.internal`)
- PostgreSQL Writer: `10.0.0.3` (`postgres-writer.homelab.internal`)
- PostgreSQL Reader: `10.0.0.4` (`postgres-reader.homelab.internal`)

### Prerequisites

1. **Install Debian 12 (Bookworm)** on all three nodes with static IPs as shown above
2. **Enable SSH** and copy your SSH key: `ssh-copy-id majid@<node-ip>`
3. **Install Ansible** on your workstation. If you are on Windows, Debian WSL is a good option.

### Setup with Ansible

```bash
cd ansible

# Install ansible dependencies (if needed)
# pip install ansible

# Run the playbook (will prompt for vault password)
ansible-playbook playbook.yaml --ask-vault-pass
```

Proxmox-only planning:

```bash
cd ansible
ansible-playbook proxmox-playbook.yaml
```

The Ansible playbook configures:
- **Common settings** and maintenance utilities
- **Raspberry Pi baseline** for shared post-install Linux setup
- **Proxmox host preparation** for network planning artifacts
- **OPNsense variable scaffolding** for the reduced wired VLAN design
- **NFS server** for shared storage
- **Keepalived** for VIP failover (K3s and PostgreSQL)
- **PostgreSQL 16** with repmgr for HA replication

### Ansible Vault

Sensitive values (passwords) are stored in `ansible/group_vars/vault.yaml`. Create your own:

```bash
cd ansible
ansible-vault create group_vars/vault.yaml
```

Required vault variables:
```yaml
keepalived_auth_pass: "<strong-password>"
repmgr_password: "<strong-password>"
```

---

## 🥧 Option B: Raspberry Pi Nodes (Legacy Alternative)

This section documents an older Raspberry Pi-first path. It is not the active long-term network and DNS design.

- current DNS: OPNsense Unbound on `10.0.0.1`
- dynamic DNS target: OPNsense os-bind via RFC2136
- planned DNS: AdGuard Home plus Unbound on OPNsense
- current Wi-Fi: flat network on the Netgear LAX20
- long-term guest Wi-Fi segmentation: future AP replacement

<details>
<summary>Click to expand Raspberry Pi setup instructions</summary>

### Prerequisites

1.  **Raspberry Pi OS:**
    *   Flash Raspberry Pi OS Lite (64-bit) onto SSDs for your K3s server nodes (`rpi01.homelab.internal`, `rpi02.homelab.internal`). SD cards are not appropriate for server nodes.
    *   Flash Raspberry Pi OS Lite (64-bit) onto an SD card for your DNS/Pi-hole node (`rpi03.homelab.internal`).
2.  **Enable Container Features (K3s Nodes Only):**
    *   On `rpi01.homelab.internal` and `rpi02.homelab.internal`, edit `/boot/firmware/cmdline.txt`:
    *   Add the following to the *end* of the line (do *not* create a new line):
        ```
        cgroup_enable=cpuset cgroup_memory=1 cgroup_enable=memory
        ```
3.  **SSH Access:**
    *   Ensure SSH is enabled on all Pis (can often be done by placing an empty file named `ssh` in the boot partition after flashing).
    *   Copy your SSH key to each Pi for passwordless login: `ssh-copy-id user@<pi-ip-address>`.

### K3s Server Node Setup (rpi01.homelab.internal, rpi02.homelab.internal)

Perform the following on K3s server nodes: `rpi01.homelab.internal` and `rpi02.homelab.internal`.

1.  **Update and Upgrade:**
    
    ```bash
    sudo apt update
    sudo apt upgrade -y
    ```
2.  **Set Static IPs**
    *   `rpi01.homelab.internal`: `10.0.0.150`
    *   `rpi02.homelab.internal`: `10.0.0.160`
    *   Get default route IP (usually your router):
        
        ```bash
        ip r | grep default
        ```
    *   Use Network Manager TUI to set the static IPs:
        
        ```bash
        sudo nmtui
        ```
        *   Select `Edit a connection`.
        *   Select `Wired connection 1` (or your active Ethernet).
        *   Change `IPv4 CONFIGURATION` to `Manual`. Select `Show`.
        *   Select `Addresses <Add...>` and enter the node's static IP (e.g., `10.0.0.150/24` for rpi01, `10.0.0.160/24` for rpi02).
        *   Set `Gateway` to your router IP (e.g., `10.0.0.1`).
        *   Set `DNS Servers` to your Pi-hole's IP address (e.g., `10.0.0.3`).
        *   Select `<OK>`, `<Back>`, `<Quit>`.
    *   Restart Network Manager:
        ```bash
        sudo systemctl restart NetworkManager
        ```
    *   Confirm the static IP:
        ```bash
        ip a | grep eth0 # Or your relevant interface
        ```
3.  **(Optional but Recommended) Set Hostnames:**
    *   On `rpi01.homelab.internal`: `sudo hostnamectl set-hostname rpi01.homelab.internal`
    *   On `rpi02.homelab.internal`: `sudo hostnamectl set-hostname rpi02.homelab.internal`
    *   Edit `/etc/hosts` on both nodes accordingly.

4.  **Install `keepalived` (both server nodes)**:
    
    ```bash
    sudo apt install -y keepalived
    ```
5.  **Configure `keepalived` (on both K3s server nodes):**
    *   **Node 1 (rpi01.homelab.internal - Master):**
        Create `/etc/keepalived/keepalived.conf`:
        
        ```conf
        # /etc/keepalived/keepalived.conf on rpi01.homelab.internal (MASTER)
        vrrp_instance VI_1 {
            state MASTER
            interface eth0         # Verify your network interface (e.g., using `ip a`)
            virtual_router_id 51 # Must be the same on all nodes
            priority 101         # Higher priority for MASTER
            advert_int 1
            authentication {
                auth_type PASS
                auth_pass your_strong_password # Use a strong, shared password!
            }
            virtual_ipaddress {
                10.0.0.2/24      # Your Virtual IP (VIP)
            }
        }
        ```
    *   **Node 2 (rpi02.homelab.internal - Backup):**
        Create `/etc/keepalived/keepalived.conf`:
        ```conf
        # /etc/keepalived/keepalived.conf on rpi02.homelab.internal (BACKUP)
        vrrp_instance VI_1 {
            state BACKUP
            interface eth0         # Verify your network interface
            virtual_router_id 51 # Must be the same on all nodes
            priority 100         # Lower priority for BACKUP
            advert_int 1
            authentication {
                auth_type PASS
                auth_pass your_strong_password # Must be the SAME as on Node 1
            }
            virtual_ipaddress {
                10.0.0.2/24      # Your Virtual IP (VIP)
            }
        }
        ```
    *   **Enable and Start (on both nodes):**
        
        ```bash
        sudo systemctl enable keepalived
        sudo systemctl start keepalived
        sudo systemctl status keepalived # Check for errors
        ```
    *   **Verify:**
        *   On the *active* node (initially rpi01): `ip a`. You should see the VIP (`10.0.0.2`) assigned.
        *   On the *backup* node (rpi02): `ip a`. You should *not* see the VIP.

</details>

---

## 🥧 DNS/Pi-hole Node Setup (Current Transitional Service)

This node uses a Raspberry Pi Zero 2 W with a **Waveshare ETH/USB HUB HAT** for network connectivity.

1.  **Enable USB Host Mode for Ethernet HAT:**
    *   Edit the boot configuration file:
        
        ```bash
        sudo nano /boot/firmware/config.txt
        ```
    *   Add the following line under the `[all]` section:
        
        ```
        dtoverlay=dwc2,dr_mode=host
        ```
    *   Save and reboot: `sudo reboot`

2.  **Update and Set Static IP:**
    *   SSH to the Pi and run: `sudo apt update && sudo apt upgrade -y`
    *   Set static IP `10.0.0.170` using `sudo nmtui`

3.  **Set Hostname:**
    ```bash
    sudo hostnamectl set-hostname rpi03.homelab.internal
    ```

4.  **Install Pi-hole:** Follow the official Pi-hole installation instructions.

Pi-hole is the current DNS service. The planned DNS stack moves to AdGuard Home plus Unbound on OPNsense. See [docs/network-migration-plan.md](docs/network-migration-plan.md).

## 🔧 K3s Installation

1.  **Add DNS Entry for VIP:**
    *   On your DNS server (`rpi03.homelab.internal` via Pi-hole interface), add an `A` record mapping your chosen cluster hostname to the `keepalived` VIP:
        
        ```
        k3s.homelab.internal -> 10.0.0.2
        ```
    *   Use `k3s.homelab.internal` as the cluster endpoint address going forward.

2.  **Install K3s (rpi01.homelab.internal - 10.0.0.150 - First Server Node):**
    
    ```bash
    curl -sfL https://get.k3s.io | K3S_DATASTORE_ENDPOINT="<datastore>" K3S_TOKEN="<token>" sh -s - server \
		    --write-kubeconfig-mode=644 \
		    --disable=servicelb \
		disable=servicelb \
		disable=traefik \
		cluster-cidr=10.42.0.0/16 \
		service-cidr=10.43.0.0/16 \
		    --tls-san="k3s.homelab.internal" \
		kubelet-arg=allowed-unsafe-sysctls="net.ipv4.ip_forward,net.ipv4.conf.all.rp_filter,net.ipv4.conf.default.rp_filter,net.ipv4.conf.all.src_valid_mark,net.ipv6.conf.all.disable_ipv6" \
		    --server "https://k3s.homelab.internal:6443"    
    ```

3.  **Get K3s Token (rpi01.homelab.internal):**
    
    ```bash
    # Run on rpi01
    sudo cat /var/lib/rancher/k3s/server/token
    ```
    Copy this token.

4.  **Install K3s (rpi02.homelab.internal - Second Server Node):**
    
    ```bash
    curl -sfL https://get.k3s.io | K3S_DATASTORE_ENDPOINT="<datastore>" K3S_TOKEN="<token>" sh -s - server \
		    --write-kubeconfig-mode=644 \
		    --disable=servicelb \
		disable=servicelb \
		disable=traefik \
		cluster-cidr=10.42.0.0/16 \
		service-cidr=10.43.0.0/16 \
		    --tls-san="k3s.homelab.internal" \
		kubelet-arg=allowed-unsafe-sysctls="net.ipv4.ip_forward,net.ipv4.conf.all.rp_filter,net.ipv4.conf.default.rp_filter,net.ipv4.conf.all.src_valid_mark,net.ipv6.conf.all.disable_ipv6" \
		    --server "https://k3s.homelab.internal:6443"  
    ```
    *Note: Using `--server https://k3s.homelab.internal:6443` makes the join process use the VIP.*

5.  **Accessing the Cluster from Outside:**
    *   Copy `/etc/rancher/k3s/k3s.yaml` from `rpi01` to your local machine as `~/.kube/config`.
        
        ```bash
        mkdir -p ~/.kube
        scp user@rpi01.homelab.internal:/etc/rancher/k3s/k3s.yaml ~/.kube/config
        ```
    *   Edit `~/.kube/config` on your local machine. Change the `server:` address from `https://127.0.0.1:6443` or `https://<node-ip>:6443` to use the VIP hostname:
        
        ```yaml
        server: https://k3s.homelab.internal:6443
        ```
    *   Make the config file secure:
        
        ```bash
        chmod 600 ~/.kube/config
        ```

6.  **Verify K3s Installation:**
    *   From your local machine:
        
        ```bash
        kubectl get nodes -o wide
        ```
    *   You should see both `rpi01.homelab.internal` and `rpi02.homelab.internal` in a `Ready` state with roles including `control-plane,master`.

## ☸️ Post-K3s Setup (Cluster Services)

Run these steps from your local machine where `kubectl` is configured.

1.  **Install MetalLB:**
    
    ```bash
    # Add metallb repository to helm
    helm repo add metallb https://metallb.github.io/metallb
    helm repo update

    # Install metallb
    helm upgrade --install metallb metallb/metallb \
      --create-namespace \
      --namespace metallb-system \
      --version 0.14.9 --wait # Check for latest compatible version
    ```
    *   Apply IP Pool and L2 Advertisement configuration:
        
        ```bash
        kubectl apply -f manifests/metallb/manifest.yaml
        ```

2.  **Install Longhorn:**
    
    ```bash
    # Add longhorn repository to helm
    helm repo add longhorn https://charts.longhorn.io
    helm repo update

    # Install longhorn
    helm install longhorn longhorn/longhorn \
      --namespace longhorn-system \
      --create-namespace \
      --version 1.10.1 \
      -f manifests/longhorn/values.yaml
    ```
    *   Create Longhorn storage classes (if needed beyond default):
        
        ```bash
        kubectl apply -f manifests/longhorn/manifest.yaml
        ```
    * If upgrading
    
     ```bash
        helm upgrade longhorn longhorn/longhorn \
        --namespace longhorn-system \
        -f manifests/longhorn/values.yaml
    ```

3.  **Install Traefik Ingress Controller & Configure TLS:**
    *   All services use Traefik for HTTPS access with automatic HTTP→HTTPS redirect.
    *   Traefik is deployed via ArgoCD at `platform/networking/traefik/`.
    *   Configuration:
        *   **LoadBalancer IP:** `10.0.0.18`
        *   **Wildcard Certificate:** `*.homelab.internal` (1-year validity)
        *   **CA Certificate:** Persisted CA from `external-secrets-vault/homelab-ca-secret`
    *   **Trust the CA on your workstation:**
        ```bash
        kubectl get secret ca-secret -n cert-manager -o jsonpath='{.data.tls\.crt}' | base64 -d > homelab-ca.crt
        sudo cp homelab-ca.crt /usr/local/share/ca-certificates/homelab-ca.crt
        sudo update-ca-certificates
        ```
    *   After trusting the CA, all `*.homelab.internal` services will be trusted by your workstation tools.
    *   If you use macOS, import the same `homelab-ca.crt` into the System Keychain:
        ```bash
        sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain homelab-ca.crt
        ```
    *   If you use Windows, import the same `homelab-ca.crt` into the Trusted Root store from an elevated PowerShell session:
        ```powershell
        Import-Certificate -FilePath $HOME\homelab-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
        ```
        Or, equivalently:
        ```powershell
        certutil -addstore -f Root $HOME\homelab-ca.crt
        ```

4.  **Install Argo CD:**
    *   Install using the official manifest:
        
        ```bash
        kubectl create namespace argocd
        kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
        ```
    *   ArgoCD is exposed via Traefik Ingress with TLS at `https://argocd.homelab.internal`.

5.  **Bootstrap Argo CD Apps (Two-Step Process):**

    This repository uses a two-step process to bootstrap Argo CD and deploy applications. This is necessary to manage the circular dependency where applications need the `external-secrets-operator` to be running, which itself is deployed as part of the platform.

    **Step 1: Deploy the Platform**

    This step deploys the `platform` ApplicationSet, which includes core services like the `external-secrets-operator`, `cert-manager`, and `traefik`.

    ```bash
    kubectl apply -f bootstrap/argocd/01-platform/platform-app.yaml
    ```

    Wait for the `platform` application to be `Synced` and `Healthy` in the Argo CD UI before proceeding to the next step.

    **Step 2: Deploy the Applications**

    This step deploys the `argocd-apps` application, which in turn manages the `apps` ApplicationSet and all the user-facing applications.

    ```bash
    kubectl apply -f bootstrap/argocd/02-apps/argocd-apps.yaml
    ```

6.  **Configure ArgoCD for Traefik Ingress:**
    *   After Traefik is deployed, apply the ArgoCD patch to enable Ingress and change service to ClusterIP:
        
        ```bash
        kubectl apply -f bootstrap/argocd/argocd-patch.yaml
        ```
    *   Access ArgoCD at `https://argocd.homelab.internal`.

## 🔑 Secrets Management

Secrets are managed using **external-secrets-operator** with a Kubernetes-based vault.

The homelab CA private key is also managed through this vault. Before bootstrapping
`ca-issuer`, create `external-secrets-vault/homelab-ca-secret` with `tls.crt`,
`tls.key`, and `ca.crt`. The `ca-issuer` chart mirrors that source secret into
`cert-manager/ca-secret`; it does not generate a replacement CA if the source is
missing. The chart now fails its Argo CD `PreSync` check if that source secret is
absent or incomplete, so CA migrations stop before pruning or re-pointing issuer
resources onto a missing prerequisite.

```bash
kubectl create secret generic homelab-ca-secret \
  -n external-secrets-vault \
  --from-file=tls.crt=homelab-ca.crt \
  --from-file=tls.key=homelab-ca.key \
  --from-file=ca.crt=homelab-ca.crt
```

### Architecture

```
┌───────────────────────────────┐      ┌──────────────────────┐
│  external-secrets-vault       │◄────│  ClusterSecretStore  │
│  namespace (hub)              │      │  cluster-k8s-store   │
│  ┌─────────────────────────┐ │      └──────────┬───────────┘
│  │ minio-secrets           │ │                 │
│  │ temporal-password       │ │                 ▼
│  │ grafana-admin-secrets   │ │      ┌──────────────────────┐
│  │ ...                     │ │      │  ExternalSecret      │
│  └─────────────────────────┘ │      │  (per app/platform)  │
└───────────────────────────────┘      └──────────────────────┘
```

### Adding a New Secret

1.  **Create the secret in the vault namespace:**
    
    ```bash
    kubectl create secret generic my-app-secrets \
      -n external-secrets-vault \
      --from-literal=username=myuser \
      --from-literal=password=mypassword
    ```

2.  **Create an ExternalSecret in your app:**
    
    ```yaml
    # apps/myapp/external-secrets.yaml
    apiVersion: external-secrets.io/v1
    kind: ExternalSecret
    metadata:
      name: my-app-secrets
    spec:
      secretStoreRef:
        name: cluster-k8s-store
        kind: ClusterSecretStore
      target:
        name: my-app-secrets
        creationPolicy: Owner
      dataFrom:
      - extract:
          key: my-app-secrets  # Name of secret in vault namespace
    ```

3.  **For individual properties:**
    
    ```yaml
    spec:
      data:
        - secretKey: db-password    # Key in target secret
          remoteRef:
            key: my-app-secrets     # Secret in vault namespace
            property: password      # Key in source secret
    ```

### Key Components

| Component | Location | Purpose |
|-----------|----------|---------|
| **external-secrets-operator** | `platform/external-secrets/` | Syncs secrets from vault to namespaces |
| **external-secrets-vault** | `platform/external-secrets-vault/` | Creates vault namespace and ClusterSecretStore |

## 🔗 Useful links

-   [K3s Documentation](https://docs.k3s.io/)
-   [Kubernetes Documentation](https://kubernetes.io/docs/)
-   [MetalLB Documentation](https://metallb.universe.tf/)
-   [Longhorn Documentation](https://longhorn.io/docs/)
-   [Argo CD Documentation](https://argo-cd.readthedocs.io/)
-   [External Secrets Documentation](https://external-secrets.io/)

## 👨🏿‍💻 Developers

-   Majid Mvulle [@majidmvulle](https://github.com/majidmvulle)
