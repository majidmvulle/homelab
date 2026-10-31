# Workstation Setup

This repo works well from a normal workstation shell on macOS, Linux, or Debian under WSL on Windows.
The examples below assume:

- SSH user on the nodes: `majid`
- K3s VIP: `k3s.homelab.internal` -> `10.0.0.2`
- Cluster nodes: `mini01`, `mini02`, `mini03`

## 1. Install the basic client tools

Make sure these are available in your workstation shell:

- `ssh`
- `ssh-copy-id`
- `kubectl`
- `ansible`
- `curl`
- `base64`

## 2. Set up SSH for Ansible

If you already have a key you want to use, skip the generate step and point to it in `~/.ssh/config`.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_homelab -C "majid@wsl"
```

Copy the public key to each node:

```bash
ssh-copy-id -i ~/.ssh/id_ed25519_homelab.pub majid@10.0.0.120
ssh-copy-id -i ~/.ssh/id_ed25519_homelab.pub majid@10.0.0.130
ssh-copy-id -i ~/.ssh/id_ed25519_homelab.pub majid@10.0.0.140
```

If your workstation DNS does not resolve `mini01.homelab.internal` and friends, add temporary host entries:

```bash
sudo sh -c 'printf "10.0.0.120 mini01.homelab.internal mini01\n10.0.0.130 mini02.homelab.internal mini02\n10.0.0.140 mini03.homelab.internal mini03\n10.0.0.2 k3s.homelab.internal k3s\n" >> /etc/hosts'
```

Optional but recommended: create `~/.ssh/config` so SSH and Ansible always use the same key.

```sshconfig
Host mini01 mini01.homelab.internal
  HostName 10.0.0.120
  User majid
  IdentityFile ~/.ssh/id_ed25519_homelab
  IdentitiesOnly yes

Host mini02 mini02.homelab.internal
  HostName 10.0.0.130
  User majid
  IdentityFile ~/.ssh/id_ed25519_homelab
  IdentitiesOnly yes

Host mini03 mini03.homelab.internal
  HostName 10.0.0.140
  User majid
  IdentityFile ~/.ssh/id_ed25519_homelab
  IdentitiesOnly yes
```

Test the connection:

```bash
ssh mini01 hostname
ssh mini02 hostname
ssh mini03 hostname
```

Run Ansible from the repo:

```bash
cd ~/homelab/ansible
ANSIBLE_PRIVATE_KEY_FILE=~/.ssh/id_ed25519_homelab ansible-playbook playbook.yaml --ask-vault-pass
```

The repo already sets `remote_user = majid` in `ansible/ansible.cfg`, so no inventory changes are needed for the workstation.

## 3. Set up kubectl access

Copy the K3s kubeconfig from a control-plane node:

```bash
mkdir -p ~/.kube
scp majid@mini01.homelab.internal:/etc/rancher/k3s/k3s.yaml ~/.kube/config
```

Update the API server address to the VIP:

```bash
sed -i 's#https://127.0.0.1:6443#https://k3s.homelab.internal:6443#g' ~/.kube/config
chmod 600 ~/.kube/config
```

Verify access:

```bash
kubectl get nodes -o wide
kubectl get pods -A
```

If your kubeconfig already uses the VIP, you may not need the `sed` step.

## 4. Trust the homelab CA on your workstation

Export the CA certificate from cert-manager:

```bash
kubectl -n cert-manager get secret ca-secret -o jsonpath='{.data.tls\.crt}' | base64 -d > ~/homelab-ca.crt
```

Install it into your workstation's trust store:

```bash
sudo cp ~/homelab-ca.crt /usr/local/share/ca-certificates/homelab-ca.crt
sudo update-ca-certificates
```

After this, workstation tools such as `curl` and `openssl` should trust `*.homelab.internal` services.

If you use macOS, import the same `homelab-ca.crt` into the System Keychain:

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain ~/homelab-ca.crt
```

If you use Windows, import the same `homelab-ca.crt` into the Windows Trusted Root store. From an elevated PowerShell session:

```powershell
Import-Certificate -FilePath $HOME\homelab-ca.crt -CertStoreLocation Cert:\LocalMachine\Root
```

If you prefer `certutil`, the equivalent command is:

```powershell
certutil -addstore -f Root $HOME\homelab-ca.crt
```
