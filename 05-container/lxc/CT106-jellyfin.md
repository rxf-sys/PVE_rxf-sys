# CT 106 — jellyfin

## Spec

| Spec       | Wert                            |
|------------|---------------------------------|
| Hostname   | jellyfin                        |
| IP         | 192.168.2.207/24                |
| RAM        | 2048 MB                         |
| CPU        | 2 Cores                         |
| rootfs     | local-lvm:vm-106-disk-0, 10 GB  |
| OS         | Debian 13                       |
| Features   | nesting=1, unprivileged         |
| Tags       | media                           |
| MAC        | BC:24:11:9E:48:E3               |

## Bind-Mounts

| Host                | Container | Inhalt          |
|---------------------|-----------|-----------------|
| /mnt/storage/media  | /media    | Movies, Series  |

## GPU-Passthrough

`dev0: /dev/dri/renderD128,gid=44`

→ Intel UHD 630 (i5-9500T) für QuickSync-Transcoding.

Hardware-Acceleration in Jellyfin:
- Web-UI → Dashboard → Playback → Hardware Acceleration: **Intel QuickSync**
- Optimal: HEVC, VP9, AV1 (8-bit + 10-bit)

## Services (nativ)

| Service  | Port | Notiz                              |
|----------|------|------------------------------------|
| jellyfin | 8096 | HTTP, kein TLS lokal               |
| (DLNA)   | 1900 UDP | UPnP-Discovery                 |
| (DLNA)   | 7359 UDP | UPnP-Multicast                 |

## Ports / Firewall (106.fw)

| Port    | Protocol | Source         |
|---------|----------|----------------|
| 8096    | TCP      | 192.168.2.0/24 |
| 1900    | UDP      | 192.168.2.0/24 |
| 7359    | UDP      | 192.168.2.0/24 |

## URLs

- LAN: http://192.168.2.207:8096 oder http://jelly.home:8096
- Public: https://media.rxf-sys.de

## Wartung

```bash
pct exec 106 -- systemctl status jellyfin
pct exec 106 -- journalctl -u jellyfin --since '1 hour ago'

# vainfo (GPU-Funktionalität)
pct exec 106 -- vainfo 2>&1 | head -20

# /dev/dri permissions im CT
pct exec 106 -- ls -la /dev/dri/
```

## Backup

- vzdump täglich 02:00 → pbs
- Media unter /mnt/storage/media NICHT in vzdump
- Jellyfin-Config + Metadata-DB im CT rootfs → in vzdump
