# AP Replacement Requirements

Use this checklist when replacing the Netgear LAX20.

## Required Features

- 802.1Q VLAN tagging on the uplink
- multiple SSIDs
- per-SSID VLAN assignment
- AP mode without routing or NAT
- WPA2/WPA3 support
- stable roaming support for phones and laptops
- local management or controller access that does not require a cloud dependency

## Strongly Preferred

- management VLAN support
- multiple radios with separate 2.4 GHz and 5 GHz tuning
- guest portal integration or captive portal compatibility
- PoE support
- configuration backup and restore
- OpenWrt support or vendor documentation with clear VLAN behavior

## Network Behavior Requirements

- one Ethernet uplink must carry multiple VLANs as a tagged trunk
- primary SSID must map to the client VLAN
- guest SSID must map to a dedicated guest VLAN
- AP management must sit on the management VLAN or a clearly documented fallback network
- the AP must pass tagged frames transparently without enabling its own DHCP/NAT path

## Validation Before Purchase

- verify that AP mode still supports VLAN tagging
- verify that guest SSIDs can map to a different VLAN than the primary SSID
- verify that SSID-to-VLAN mapping does not require router mode
- verify that management access still works when the AP receives a tagged uplink
- verify that documentation matches the exact hardware revision and firmware branch

## Fit For This Homelab

Minimum target:

- primary SSID on `VLAN 40`
- guest SSID on a dedicated guest VLAN
- management on `VLAN 10`
- single uplink back to the TP-Link switch
