# Notifications

Alle PVE+PBS-Notifications gehen über **Strato SMTP** an `info@rxf-sys.de` (via Cloudflare Email Routing weitergeleitet an Gmail).

## PVE-Host

Endpoint:
```bash
pvesh get /cluster/notifications/endpoints/smtp --output-format yaml
```
```yaml
- name: strato
  server: smtp.strato.de
  port: 465
  mode: tls
  username: info@rxf-sys.de
  from-address: info@rxf-sys.de
  mailto: [info@rxf-sys.de]
  comment: Strato SMTP TLS:465
```

Matcher:
```yaml
- name: to-strato
  mode: all
  target: [strato]
  comment: Alles an Strato-SMTP
- name: default-matcher
  disable: 1                       # bewusst disabled
  target: [mail-to-root]
```

vzdump-Job nutzt `notification-mode notification-system` → läuft über Matcher.

## PBS-VM

Analog konfiguriert via:
```bash
qm guest exec 201 -- proxmox-backup-manager notification endpoint smtp list
qm guest exec 201 -- proxmox-backup-manager notification matcher list
```

## Test-Mail

```bash
# PVE
pvesh create /cluster/notifications/targets/strato/test

# PBS — über Web-UI (kein CLI-Test verfügbar)
# https://192.168.2.209:8007 → Configuration → Notifications → strato → Test
```

## Passwort-Rotation

Bei Strato-Webmail Passwort ändern, dann in PVE neu setzen:

```bash
STRATO_PW='NEUES_PW'
pvesh set /cluster/notifications/endpoints/smtp/strato --password "$STRATO_PW"
STRATO_PW='REDACTED'; unset STRATO_PW

# PBS analog
qm guest exec 201 -- proxmox-backup-manager notification endpoint smtp update strato --password 'NEUES_PW'
```

## Cloudflare Email Routing

DNS-Setup bei Strato:
- MX-Record: `route.cloudflareemail.com` (Prio 10) etc.
- Routing-Regel in Cloudflare-Dashboard: `info@rxf-sys.de` → `<deine-gmail>@gmail.com`
