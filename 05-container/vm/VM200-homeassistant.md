# VM 200 — homeassistant (HA OS)

## Spec

| Spec        | Wert                                    |
|-------------|-----------------------------------------|
| Name        | homeassistant                           |
| IP          | 192.168.2.208/24                        |
| RAM         | 10240 MB                                |
| CPU         | 2 Cores                                 |
| BIOS        | OVMF (UEFI)                             |
| Machine     | q35                                     |
| efidisk0    | local-lvm:vm-200-disk-0, 4 MB           |
| scsi0       | local-lvm:vm-200-disk-1, 32 GB SSD, discard, iothread |
| scsihw      | virtio-scsi-single                      |
| net0        | virtio, vmbr0, firewall=1               |
| MAC         | BC:24:11:94:21:9C                       |
| boot        | order=scsi0                             |
| onboot      | 1                                       |
| startup     | order=3                                 |
| agent       | 1 (qemu-guest-agent)                    |
| smbios uuid | 0631efc1-df9e-4900-9a0e-e3392616727a    |

## OS

- Home Assistant OS (HAOS) — Read-only-Image, eigenes Filesystem
- Updates via HA-Web-UI: Settings → System → Updates

## Services

- Home Assistant Core auf Port **8123**
- Matter-Server (172.30.32.1:5580 intern)
- Diverse Add-Ons (z.B. File editor für /config/configuration.yaml)

## URLs

- LAN: http://192.168.2.208:8123
- Public: https://ha.rxf-sys.de (über Cloudflare Tunnel)

## Cloudflare-Setup

In HA `configuration.yaml`:
```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.2.205    # CT 104 cloudflared
    - 172.16.0.0/12
    - 172.17.0.0/16
```

Cloudflare-Route `ha.rxf-sys.de`:
- HTTP Host Header: `ha.rxf-sys.de`
- Origin: http://192.168.2.208:8123

Ohne `trusted_proxies` gibt HA **400 Bad Request** auf Tunnel-Requests.

## Backup

- vzdump täglich 02:00 → pbs (Vollbild der VM mit allen HA-States)
- Restore-Test: VMID 999 mit `qm restore` analog zu CT-Tests

## Wartung

```bash
# Via qemu-guest-agent
qm guest exec 200 -- uptime
qm guest exec 200 -- df -h

# HA-CLI (im Container) via SSH-Add-on oder HA-Terminal
ha core info
ha core update
```
