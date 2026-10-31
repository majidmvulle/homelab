# proxmox_prep

Safe preparation role for the Proxmox host.

Scope:

- install basic networking packages
- validate required Proxmox variables
- write reference files under `/root/homelab/`
- render staged `/etc/network/interfaces` fragments under `/root/homelab/interfaces.d/`

This role does not change live bridge or interface configuration.
It renders a bootstrap-state fragment and a later cutover-state fragment.
