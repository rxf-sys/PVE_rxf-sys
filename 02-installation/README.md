# 02 — Installation

## Proxmox VE 9.2.6

Installiert via offiziellem PVE-ISO (Debian 13 Trixie). EFI + Secure Boot aktiv.

| Spec               | Wert                            |
|--------------------|---------------------------------|
| PVE-Version        | 9.2.6 (proxmox-ve 9.2.0)        |
| Debian             | 13 (Trixie)                     |
| Kernel             | 7.0.14-8-pve                    |
| Boot               | EFI, GRUB, kein proxmox-boot-tool (klassisch) |
| Subscription       | No-Subscription Repository      |

### Installations-Optionen

- Filesystem: ext4 (kein ZFS)
- Hostname: `rxf-sys.home`
- IP: 192.168.2.200/24
- Gateway: 192.168.2.1
- DNS: 192.168.2.1
- Mail: info@rxf-sys.de

### Post-Install

Siehe [post-install.md](post-install.md) — Subscription-Nag, Repos, Updates, Notifications, Firewall.

## Komponenten dieser Installation

- [post-install.md](post-install.md) — alle Schritte nach Frischinstallation
- [pbs-vm-setup.md](pbs-vm-setup.md) — wie VM 201 (PBS) mit sdb-Passthrough erstellt wurde
