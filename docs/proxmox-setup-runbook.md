# Proxmox Setup Runbook

Bring up `pve01.homelab.internal` first. Do not rebuild OPNsense until the Proxmox host is stable with separate LAN and WAN bridges.

## Target Host

- hostname: `pve01.homelab.internal`
- bootstrap management IP: `10.0.0.112`
- final management IP: `10.10.10.10`
- LAN NIC: `enp1s0`
- WAN NIC: `eno2`
- LAN bridge: `vmbr0`
- WAN bridge: `vmbr1`

## Current Live Baseline

- OPNsense flat-LAN gateway: `10.0.0.1`
- Proxmox host management: `10.0.0.112`
- Netgear LAX20: AP-only on the LAN side
- Proxmox default gateway should point to OPNsense, not a legacy router
- OPNsense WAN `Block private networks` must remain disabled for this ISP

## Scope

- keep live network changes manual and console-driven
- generate planning artifacts with Ansible
- maintain flat-LAN management until the new OPNsense VM is proven
- do not use a WAN VLAN

## Bootstrap Host State

Expected `/etc/network/interfaces` shape before OPNsense rebuild:

```text
auto enp1s0
iface enp1s0 inet manual

auto eno2
iface eno2 inet manual

auto vmbr0
iface vmbr0 inet static
    address 10.0.0.112/24
    gateway 10.0.0.1
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 20 30 40 50

auto vmbr1
iface vmbr1 inet manual
    bridge-ports eno2
    bridge-stp off
    bridge-fd 0
```

## Final Host State

After OPNsense VLAN 10 is proven:

```text
auto enp1s0
iface enp1s0 inet manual

auto eno2
iface eno2 inet manual

auto vmbr0
iface vmbr0 inet manual
    bridge-ports enp1s0
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    bridge-vids 10 20 30 40 50

auto vmbr0.10
iface vmbr0.10 inet static
    address 10.10.10.10/24
    gateway 10.10.10.1

auto vmbr1
iface vmbr1 inet manual
    bridge-ports eno2
    bridge-stp off
    bridge-fd 0
```

## Planning Step

```bash
cd ansible
ansible-playbook proxmox-playbook.yaml
```

Review:

- `/root/homelab/proxmox-network-plan.txt`
- `/root/homelab/opnsense-vm-plan.txt`
- `/root/homelab/interfaces.d/40-homelab-proxmox-bootstrap.cfg`
- `/root/homelab/interfaces.d/50-homelab-proxmox.cfg`
- `/root/homelab/interfaces.d/60-homelab-opnsense.cfg`

## New OPNsense VM Model

- VMID: `100`
- `net0` -> `vmbr0`
- `net1` -> `vmbr1`
- `net0` carries bootstrap LAN first, then VLANs later
- `net1` is the raw PPPoE WAN parent

## Build Sequence

1. Keep Proxmox host on `10.0.0.112`
2. Create fresh OPNsense VM on `vmbr0` + `vmbr1`
3. Bring up OPNsense with:
   - flat LAN on `vtnet0`
   - PPPoE on `vtnet1`
4. Validate WAN while physically connected to the Lenovo WAN NIC path
5. Add VLAN interfaces on `vtnet0`
6. Verify `10.10.10.1`
7. Move Proxmox management to `10.10.10.10`

## Do Not

- do not route WAN through the TP-Link switch
- do not reintroduce VLAN `4090`
- do not move Proxmox management before OPNsense VLAN 10 is proven
- do not remove the bootstrap LAN until VLAN 10 and VLAN 40 are both working
