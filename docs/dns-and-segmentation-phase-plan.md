# DNS And Segmentation Phase Plan

This plan starts from the current stable baseline and prepares the next change window.

## Stable Baseline

- OPNsense routes the flat LAN at `10.0.0.1/24`
- Proxmox management is `10.0.0.112/24`
- Netgear LAX20 is AP-only with DHCP disabled
- Wired and wireless clients already use OPNsense as their gateway

No VLAN changes should be made until DNS migration is complete and a policy matrix is agreed.

## Goals For The Next Phase

1. Migrate internal DNS authority away from the retired Pi-hole node at `10.0.0.170`
2. Preserve resolution for `*.homelab.internal`
3. Separate Kubernetes nodes from general client devices
4. Allow only approved client access into Kubernetes-exposed services
5. Keep a rollback path during each phase

## Locked-In Decisions

- Admin endpoints for management access: `MacBook` and `gaming PC` only
- Kubernetes clients should be approved explicitly, not opened broadly to all client devices
- Kubernetes nodes need access to Synology-backed services over `NFS`, `SMB`, and `S3`/Garage
- Target DNS stack is `AdGuard Home -> Unbound`
- `rpi03` is retired from DNS duty
- no separate DNS VM or dedicated DNS host will be introduced for this migration
- OPNsense Unbound is the current source of truth for internal DNS
- `external-dns` target is `RFC2136 -> OPNsense os-bind`
- Unbound remains the client-facing local resolver
- Remote-access VPN endpoint is `vpn.example.com`
- WireGuard road-warrior clients use `10.10.60.0/24`
- Approved client devices for Kubernetes-published services:
  - `MacBook Pro`
  - `gaming PC`
  - `Google Pixel 10 Pro XL`
  - `Samsung Tab S7`

## Known DNS Dependencies Still Pointing At `10.0.0.170`

These references were intentionally left unchanged until the DNS move is executed:

- [platform/networking/external-dns/values.yaml](../platform/networking/external-dns/values.yaml)
- [charts/external-dns/values.yaml](../charts/external-dns/values.yaml)
- [platform/monitoring/kube-prometheus-stack/values.yaml](../platform/monitoring/kube-prometheus-stack/values.yaml)
- [README.md](../README.md)

Treat those files as the phase-two checklist rather than active truth.

Important: the old repo state used Pi-hole as the `external-dns` backend via:

- `--provider=pihole`
- `--pihole-server=http://10.0.0.170`

Those settings are currently present in both:

- [platform/networking/external-dns/values.yaml](../platform/networking/external-dns/values.yaml)
- [charts/external-dns/values.yaml](../charts/external-dns/values.yaml)

## ExternalDNS Path

Verified target:

- `external-dns -> RFC2136 -> OPNsense os-bind`
- no separate DNS VM
- no `rpi03` DNS role
- Unbound stays in front for clients

Verification basis:

- official `external-dns` RFC2136 provider documentation
- OPNsense plugin support referenced in:
  - [external-dns issue comment](https://github.com/kubernetes-sigs/external-dns/issues/3721#issuecomment-2474290761)
  - [opnsense/plugins#4177](https://github.com/opnsense/plugins/pull/4177)

Working implication for this repo:

1. keep static infrastructure DNS in Unbound
2. move dynamic app DNS to OPNsense Bind via RFC2136
3. keep client recursive DNS on Unbound/AdGuard

## DNS Migration Strategy

### Phase 2A: Recover Or Reconstruct DNS Data

Conservative path:

1. Use the already exported Pi-hole data as the reconstruction source
2. Export all local DNS overrides from Pi-hole
3. Capture any DHCP reservations or hand-written aliases that only exist there
4. Build the target record set in the repo before changing live DNS

I am not assuming a specific Pi-hole database layout. Use a full Pi-hole UI backup/export if the node is recoverable. If it is not recoverable, reconstruct from:

- Ansible inventory
- known VIPs (`10.0.0.2`, `10.0.0.3`, `10.0.0.4`)
- ingress hostnames already present in Helm values
- any workstation `/etc/hosts` stopgaps

Preferred action is:

1. use the captured Pi-hole export already stored in the repo workflow
2. compare that export against the ingress hosts already declared in Git
3. keep `rpi03` out of the target DNS design

Seed inventory file for that comparison:

- [docs/dns-record-inventory.yaml](../docs/dns-record-inventory.yaml)
- [docs/unbound-host-overrides.yaml](../docs/unbound-host-overrides.yaml)

Locked decisions from the validated export:

- retire `jackett.homelab.internal`
- retire `wg.homelab.internal`
- retire the Kubernetes `wg-easy` application from the repo
- keep `synology01.homelab.internal` as the base A record
- stage `files.homelab.internal`, `photos.homelab.internal`, and `s3.homelab.internal` as aliases on the Synology host override in Unbound

### Phase 2B: Stage OPNsense DNS

Target DNS stack:

- Unbound = local authority for `homelab.internal`, DNSBL policy enforcement, and DoT forwarder
- AdGuard Home = client-facing DNS frontend
- DHCP clients should use AdGuard Home as the front door, with local authority in Unbound underneath

Unbound Resolution Pipeline on OPNsense:

1. **Local Authority (`host_entries.conf`):** All `*.homelab.internal` overrides and PTR records resolve locally first.
2. **DNSBL Filtering (`unbound-dnsbl/`):** Python DNSBL module evaluates blocklists (AdGuard, EasyList, HaGeZi) and sinkholes matching domains/CNAMEs locally before any forwarding.
3. **In-Memory Cache:** Cached records are returned immediately with 0ms latency.
4. **Encrypted Upstream Forwarding (DNS over TLS):** External queries forward over TLS (`TCP/853`) via `dot.conf`, eliminating ISP UDP/53 packet drops and throttling.
   - Forward Zone: `.` (global root catch-all)
   - Upstream servers:
     - Quad9: `9.9.9.9@853` (Verify CN: `dns.quad9.net`)
     - Cloudflare: `1.1.1.1@853` (Verify CN: `cloudflare-dns.com`)
   - Note: In OPNsense Web GUI (*Services > Unbound DNS > DNS over TLS*), set **Domain** to `.` (or empty) for catch-all forwarding, and use **Verify CN** for the server hostname.
5. **Dual-Stack Transport (`do-ip6: yes`):** Enabled and functional with WAN native IPv6 prefix delegation.

Conservative recommendation inside that chosen stack:

1. Stand up Unbound local overrides first
2. Validate `*.homelab.internal` resolution from a test client
3. Insert AdGuard Home in front only after local authority works cleanly
4. Move test clients to AdGuard Home first

This keeps the current authority inside OPNsense and still lands on your desired `AdGuard Home -> Unbound` stack.

### Phase 2C: DHCP DNS Cutover

1. Point OPNsense DHCP scopes to the new intended DNS target
2. Renew leases on test clients first
3. Verify:
   - `k3s.homelab.internal`
   - `argocd.homelab.internal`
   - `grafana.homelab.internal`
   - Synology names
4. Only after client validation, update Kubernetes-adjacent manifests that still reference `10.0.0.170`

## Proposed Subnet Model

This is the conservative starting point from the current design work:

| Segment | Subnet | Role |
|---------|--------|------|
| 10 | `10.10.10.0/24` | management plane only |
| 20 | `10.10.20.0/24` | servers and infrastructure services |
| 30 | `10.10.30.0/24` | Kubernetes nodes and cluster-facing services |
| 40 | `10.10.40.0/24` | trusted user/client devices |
| 50 | `10.10.50.0/24` | IoT / lower-trust devices |
| wireguard | `10.10.60.0/24` | remote-access VPN clients on OPNsense |

## Proposed Placement

Initial conservative placement:

- VLAN 10:
  - OPNsense management
  - Proxmox management
  - TP-Link switch management
  - Netgear AP management
  - admin-originated access from the MacBook and gaming PC only
- VLAN 20:
  - Synology
  - utility Pis not acting as cluster nodes
  - standalone infrastructure services
- VLAN 30:
  - `mini01`, `mini02`, `mini03`
  - any dedicated Kubernetes worker/control-plane hosts
- VLAN 40:
  - MacBook
  - gaming PC
  - phones and normal Wi-Fi clients
- VLAN 50:
  - IoT devices
- WireGuard:
  - road-warrior clients connecting to `vpn.example.com`
  - remote access stays split-tunnel
  - while the network is still flat, tunnel access targets `10.0.0.0/24` plus OPNsense DNS on `10.0.0.1`
  - after VLAN cutover, replace the flat-LAN allow with explicit VLAN policy

## Proposed Policy Matrix

Default posture:

- deny east-west by default
- allow DNS/NTP to OPNsense from all internal VLANs and WireGuard clients
- allow outbound internet from all approved VLANs
- explicitly allow only the flows below

### Required Allows

1. `WireGuard -> OPNsense`
- allow DNS to `This Firewall`
- allow UDP/TCP `53`
- client tunnel subnet: `10.10.60.0/24`

2. `WireGuard -> flat LAN`
- while the network remains on `10.0.0.0/24`, allow only the current homelab LAN plus OPNsense DNS
- current destination scope:
  - `10.0.0.0/24`
- replace this temporary flat-LAN rule set with explicit per-VLAN rules after segmentation

3. `VLAN 10 -> all`
- admin access only
- SSH, HTTPS, Proxmox UI, OPNsense UI, switch/AP management
- source devices: MacBook and gaming PC only

4. `VLAN 40 -> VLAN 30`
- allow only client access to published Kubernetes services
- start with:
  - TCP `80`
  - TCP `443`
- if you need direct Kubernetes API access from admin laptops, that should come from VLAN 10, not from all clients
- final allowlist should be per approved device, not whole-VLAN by default
- approved devices for this path:
  - `MacBook Pro`
  - `gaming PC`
  - `Google Pixel 10 Pro XL`
  - `Samsung Tab S7`

5. `WireGuard -> VLAN 30`
- after segmentation, allow only the same published Kubernetes service access granted to approved client devices
- do not grant broad node-subnet access to all VPN clients by default
- preferred implementation is a dedicated alias for approved remote client addresses if per-device VPN policy becomes necessary

6. `VLAN 30 -> VLAN 20`
- allow only the exact dependencies Kubernetes needs
- required examples already known:
  - NFS to Synology
  - SMB to Synology
  - S3/Garage endpoints on Synology

7. `VLAN 30 -> VLAN 40`
- block by default

8. `VLAN 40 -> VLAN 30 node addresses`
- block by default except approved published service ports

9. `VLAN 50 -> anything internal`
- block by default except DNS/NTP and any explicitly approved service

## Planned WireGuard Split-Tunnel Shape

Current flat-LAN phase:

1. OPNsense WireGuard tunnel address: `10.10.60.1/24`
2. Client addresses: `10.10.60.x/32`
3. Client DNS: `10.0.0.1`
4. Use the LAN-side OPNsense resolver address while the network is still flat because the working internal DNS view for Kubernetes-published services is currently available there.
5. Client `AllowedIPs`:
   - `10.0.0.0/24`
   - `10.10.60.0/24`

Post-segmentation target:

1. Keep client tunnel addresses in `10.10.60.0/24`
2. Keep DNS pointed at the OPNsense address that serves the authoritative internal view for clients at that stage
3. Replace `10.0.0.0/24` in client `AllowedIPs` with the exact internal VLANs that should remain reachable over VPN
4. Keep remote access aligned to the same least-privilege policy used for local clients instead of treating VPN as a blanket trusted path

## Conservative Rollout Order

1. Export Pi-hole records from `rpi03`
2. Build the authoritative record inventory in Git
3. Stage Unbound local overrides on OPNsense
4. Put AdGuard Home in front of Unbound for test clients
5. Validate client DNS on the still-flat network
6. Stand up WireGuard road-warrior access on OPNsense using `vpn.example.com` and `10.10.60.0/24` while the network is still flat
7. Validate split-tunnel access to `10.0.0.0/24` and DNS resolution through OPNsense over VPN
8. move `external-dns` to OPNsense os-bind over RFC2136
9. Migrate only management to VLAN 10 first
10. Migrate Kubernetes nodes to VLAN 30
11. Migrate clients to VLAN 40
12. Add inter-VLAN firewall policy
13. Replace the temporary WireGuard flat-LAN allow with explicit per-VLAN VPN policy
14. Move Netgear AP uplink to VLAN 40 only after wired client testing is complete

## Stop / Rollback Points

- If local DNS records are incomplete, stop before DHCP DNS cutover
- If WireGuard DNS resolution or flat-LAN access is unreliable, stop before relying on VPN for remote administration
- If Proxmox loses management during VLAN 10 migration, revert host management to the flat LAN immediately
- If Kubernetes control-plane access breaks after VLAN 30 migration, revert node ports to the flat LAN and stop before client migration
- If Wi-Fi clients lose access after the AP uplink move, return the AP uplink to the flat network and stop

## Planned Client Reservations For VLAN 40

Use DHCP static mappings in OPNsense keyed on MAC addresses. Build firewall aliases from the reserved IPs rather than from raw MAC matching.

| Device | Intended use | Fixed IP | MAC | Notes |
|--------|--------------|----------|-----|-------|
| `MacBook Pro` | approved Kubernetes client, admin workstation | `10.10.40.10` | `02:00:00:00:00:01` | Wi-Fi MAC from active `en0`; reserve wired separately only if the wired path will actually be used |
| `gaming PC` | approved Kubernetes client, admin workstation | `10.10.40.20` | `02:00:00:00:00:02` | Ethernet only; do not reserve the Wi-Fi card unless it will be used |
| `Google Pixel 10 Pro XL` | approved Kubernetes client | `10.10.40.30` | `02:00:00:00:00:03` | disable private/randomized MAC for the home SSID |
| `Samsung Tab S7` | approved Kubernetes client | `10.10.40.31` | `02:00:00:00:00:04` | disable private/randomized MAC for the home SSID |

### Reservation Scope Rules

- Do not create DHCP reservations for unused interfaces.
- A single Wi-Fi interface keeps the same MAC across `2.4 GHz` and `5 GHz`.
- If the `MacBook Pro` later needs wired access inside VLAN 40, add a second reservation for the actual wired adapter MAC at that time.
- If the `gaming PC` later uses Wi-Fi, add a second reservation for that Wi-Fi MAC at that time.

## Planned OPNsense Alias Model

Create these aliases before inter-VLAN policy is enabled and before tightening WireGuard access after segmentation:

1. `approved_k8s_client_devices`
- type: host
- members:
  - `10.10.40.10`
  - `10.10.40.20`
  - `10.10.40.30`
  - `10.10.40.31`

2. `approved_k8s_published_ports`
- type: port
- members:
  - `80`
  - `443`

3. `k8s_vlan30_subnet`
- type: network
- members:
  - `10.10.30.0/24`

4. `synology_storage_endpoints`
- type: host
- members:
  - populate with the Synology IP
  - populate with any Garage or S3 VIPs if they are separate

5. `wireguard_remote_clients`
- type: network
- members:
  - `10.10.60.0/24`

## Planned VLAN 40 To VLAN 30 Rule Shape

Initial client rule:

1. source: `approved_k8s_client_devices`
2. destination: `k8s_vlan30_subnet`
3. ports: `approved_k8s_published_ports`
4. action: allow

Default follow-up rule:

1. source: `VLAN 40 net`
2. destination: `k8s_vlan30_subnet`
3. action: block

This keeps Kubernetes node access closed to the rest of the client subnet while still allowing approved end-user access to published HTTP/HTTPS services.



