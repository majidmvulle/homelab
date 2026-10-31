# Ansible Fleet Plan

Ansible inventory, host metadata, and group variables for post-install host management.

## Managed by Ansible

- `mini01.homelab.internal`
- `mini02.homelab.internal`
- `mini03.homelab.internal`
- `rpi01.homelab.internal`
- `rpi02.homelab.internal`
- `rpi03.homelab.internal`
- `rpi04.homelab.internal`
- `pve01.homelab.internal`
- `opnsense01.homelab.internal`

## Manual Management

- `switch01.homelab.internal` (TP-Link TL-SG108E)
- `ap01.homelab.internal` (Netgear LAX20 in AP mode)

Inventory only. Configure through the device UI.

## Group Layout

- `hp_nodes`: Debian HP nodes running K3s/PostgreSQL
- `raspi`: Raspberry Pi fleet
- `raspi_pi4`: Raspberry Pi 4B hosts
- `raspi_zero2w`: Raspberry Pi Zero 2W hosts
- `proxmox_hosts`: Lenovo Proxmox hypervisor
- `opnsense`: OPNsense firewall/router VM
- `manual_network_devices`: UI-driven switch and AP endpoints
- `managed_linux`: all Linux hosts reachable by SSH

## Repository Scope

- inventory expansion
- host metadata in `host_vars/`
- VLAN and OPNsense variables in `group_vars/`
- network and host documentation in `docs/`
- dedicated Proxmox-first playbook in `proxmox-playbook.yaml`
- DNS migration and segmentation planning in `docs/dns-and-segmentation-phase-plan.md`

## Preconditions For Proxmox And OPNsense Roles

- confirm Proxmox interface names and bridge layout
- confirm the dedicated WAN NIC path to the Lenovo before rebuilding OPNsense
- enable OPNsense SSH/API/plugin management
- keep switch and AP configuration in the device UI

## Planned Additions

1. Raspberry Pi baseline role for hardening and package setup
2. Proxmox host role after `vmbr0`/`vmbr1` and NIC naming confirmation
3. OPNsense configuration automation after SSH/API enablement
4. Kubernetes-adjacent manifest updates for `external-dns -> RFC2136 -> OPNsense os-bind`
