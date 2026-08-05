# 08 — Sicherheit

Stand: Audit vom 05.08.2026 — siehe [../09-wartung/audit-2026-08-05.md](../09-wartung/audit-2026-08-05.md).

| Bereich            | Status / Tool                                        |
|--------------------|------------------------------------------------------|
| PVE-Firewall       | enabled, Cluster-Policy `policy_in: DROP`; **Guest-Regelsätze unvollständig**, siehe [firewall.md](firewall.md) |
| fail2ban           | aktiv, **nur Jail `sshd`** — deckt die PVE-Weboberfläche nicht ab, siehe [fail2ban.md](fail2ban.md) |
| SSH                | gehärtet: `PasswordAuthentication no`, `PermitRootLogin without-password`, `PubkeyAuthentication yes` |
| Tokens             | dediziert pro Service, dokumentiert in [tokens.md](tokens.md) |
| 2FA                | **nicht aktiv** für `root@pam` |
| Subscription-Nag   | gepatcht via dpkg-Hook                               |
| Updates            | 0 ausstehende Pakete auf dem Host, kein CT mit >20 offenen Paketen |
| Notifications      | Strato SMTP für Backup-Failures                      |
| External Access    | via Cloudflare Tunnel; **kein Cloudflare Access davor** |
| AppArmor           | aktiv, 130 Profile geladen, 31 im Enforce-Modus      |
| Secure Boot        | enabled (shim-signed)                                 |
| PVE-Zertifikat     | gültig bis 19.05.2028                                 |

## SSH — Korrektur gegenüber der alten Doku

Frühere Fassungen dieser Doku beschrieben `PermitRootLogin yes` und
`PasswordAuthentication yes` als bewusste Abweichung für ein LAN-only-Setup.
**Das ist nicht mehr der Zustand.** Effektiv gilt laut `sshd -T`:

```
kbdinteractiveauthentication no
listenaddress 0.0.0.0:22
maxauthtries 6
passwordauthentication no
permitemptypasswords no
permitrootlogin without-password
port 22
pubkeyauthentication yes
```

Root-Login ist damit nur per Schlüssel möglich, Passwort-Authentifizierung ist
komplett aus. Das entspricht der Best Practice; die dokumentierte Abweichung
existiert nicht mehr.

## Offene Punkte

### 1. Privater SSH-Schlüssel in `authorized_keys`

In `/etc/pve/priv/authorized_keys` (via Symlink auch `/root/.ssh/authorized_keys`)
steht eine Zeile der Form

```
ssh-rsa b3BlbnNzaC1rZXktdjE...
```

`b3BlbnNzaC1rZXktdjE` ist base64 für `openssh-key-v1` — das ist der Header einer
**privaten** OpenSSH-Schlüsseldatei, nicht eines Public Keys. Beim RMM-Setup
wurde offenbar der private statt der öffentliche Teil eingefügt; die Zeile
darunter (`ssh-ed25519 … rmm`) ist der eigentliche Public Key.

Sshd ignoriert die kaputte Zeile, ein unmittelbares Zugriffsrisiko besteht also
nicht. Der Schlüssel selbst ist aber als kompromittiert zu behandeln:

```bash
# 1. kaputte Zeile identifizieren und entfernen
grep -n 'b3BlbnNzaC1rZXktdjE' /etc/pve/priv/authorized_keys
# 2. neues Keypair für RMM erzeugen, Public Key eintragen
# 3. alten rmm-Key überall zurückziehen
```

### 2. Guest-Firewall-Regelsätze fehlen

`firewall=1` steht an allen Guest-NICs, aber nur 100, 102, 103, 106 und 201
haben einen wirksamen Regelsatz. 111 hat eine Datei **ohne `[OPTIONS]`-Block**
(also ohne `enable: 1`) und ist damit ungefiltert — inklusive Port 80 und der
RustDesk-Ports 21115–21119. Für 101, 105, 107, 108, 109, 110 und 200 fehlt die
Datei ganz. Details: [firewall.md](firewall.md).

### 3. PVE- und PBS-Oberfläche öffentlich erreichbar

`pve.rxf-sys.de` und `pbs.rxf-sys.de` liefern über den Tunnel **HTTP 200** —
davor sitzt also keine Cloudflare-Access-Policy, die Anmeldemasken sind aus dem
Internet erreichbar. Passend dazu steht im Journal:

```
Aug 05 14:17:12 rxf-sys pvedaemon[…]: authentication failure;
  rhost=::ffff:192.168.2.213 user=root@pam msg=Authentication failure
```

`192.168.2.213` ist CT 110 (cloudflared) — der Login-Versuch kam also von außen
durch den Tunnel. Erschwerend: `root@pam` hat **kein 2FA**, und fail2ban
überwacht nur `sshd`, nicht `pveproxy`/`pvedaemon`.

Drei Stellschrauben, in dieser Reihenfolge:

1. **Cloudflare Access** vor `pve`, `pbs` und `vault` legen — oder die
   Hostnames entfernen, wenn der externe Zugriff nicht wirklich gebraucht wird.
2. **TOTP für `root@pam`** aktivieren (PVE-UI → Datacenter → Permissions →
   Two Factor).
3. **fail2ban-Jail für Proxmox** ergänzen, das auf `pvedaemon`-Authfailures
   reagiert.

### 4. API-Token ohne Privilege Separation

`admin-dashboard@pve!api` läuft mit `privsep 0`. Der Token hat damit exakt die
Rechte des Users, statt eigener, engerer ACLs. Der User selbst hat `DashboardRO`
auf `/` mit `propagate 1`. Bei einem reinen Read-Only-Dashboard vertretbar, aber
`privsep 1` plus explizite Token-ACL wäre sauberer.

### 5. rpcbind lauscht auf 0.0.0.0:111

Auf dem Host läuft `rpcbind` auf allen Interfaces. Die Host-Firewall lässt Port
111 nicht durch, es ist also nicht exponiert — wenn kein NFS gebraucht wird,
lässt sich der Dienst aber ersatzlos abschalten.

## Annahmen

- Heim-LAN, vertrauenswürdige Geräte
- Konsolen-Zugriff am Host (für Lockout-Recovery)
- Single-Admin-Setup

Die dritte Annahme trägt nicht mehr uneingeschränkt: Mit PVE- und PBS-UI hinter
einem offenen Tunnel ist das Setup nicht mehr nur aus dem LAN erreichbar.
