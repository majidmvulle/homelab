# raspi_baseline

Post-install baseline for Raspberry Pi hosts.

Scope:

- install baseline packages
- enable SSH
- set hostname from inventory
- enable the USB Ethernet HAT overlay where required
- write a small host summary under `/opt/homelab/`

This role does not configure static IPs or cluster-specific services.
