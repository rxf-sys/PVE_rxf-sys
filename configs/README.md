# configs/

Anonymisierte Kopien der wichtigsten Configs des Hosts.

| Datei                       | Ort auf Host                                                      |
|-----------------------------|-------------------------------------------------------------------|
| pve/jobs.cfg                | /etc/pve/jobs.cfg                                                 |
| pve/storage.cfg             | /etc/pve/storage.cfg                                              |
| pve/notifications.cfg       | /etc/pve/notifications.cfg                                        |
| pve/interfaces              | /etc/network/interfaces                                           |
| pve/hosts                   | /etc/hosts                                                        |
| pve/fstab                   | /etc/fstab                                                        |
| pve/firewall/cluster.fw     | /etc/pve/firewall/cluster.fw                                      |
| pve/firewall/host.fw        | /etc/pve/nodes/rxf-sys/host.fw                                    |
| pve/firewall/100.fw .. 201.fw | /etc/pve/firewall/<vmid>.fw                                     |
| apt/80pve-no-nag            | /etc/apt/apt.conf.d/80pve-no-nag                                  |

## Secrets — nicht im Repo

Diese Pfade enthalten Geheimnisse und gehören NICHT ins Repo:

- `/etc/pve/priv/storage/pbs.pw` — PBS-Token-Secret für vzdump
- `/etc/pve/priv/notifications.cfg` — Strato SMTP-Passwort
- `/etc/pve/priv/authorized_keys` — SSH-Keys
- CT 101 `/opt/rxf-admin/infrastructure/.env` — Admin-Dashboard ENV
- CT 109 `/opt/orynthia/.env` — Orynthia ENV
