# Post-Install — PVE 9.2.x

> Ursprünglich für 9.2.2 geschrieben; Host läuft inzwischen 9.2.6 mit
> Kernel 7.0.14-8-pve. Die Schritte gelten unverändert.

Reihenfolge nach Frischinstallation. Idempotent — kann auf bestehendem Setup mehrfach laufen.

## 1. Repos: Enterprise raus, No-Subscription rein

```bash
# Disable Enterprise (gibt 401 ohne Sub)
mv /etc/apt/sources.list.d/pve-enterprise.sources \
   /etc/apt/sources.list.d/pve-enterprise.sources.disabled

# Disable Ceph (kein Ceph in Single-Node)
mv /etc/apt/sources.list.d/ceph.sources \
   /etc/apt/sources.list.d/ceph.sources.disabled

# No-Subscription (sollte schon da sein durch Installer)
echo "deb http://download.proxmox.com/debian/pve trixie pve-no-subscription" \
  > /etc/apt/sources.list.d/pve-no-subscription.list

apt update && apt -y dist-upgrade
```

## 2. Tools nachinstallieren

```bash
apt install -y jq smartmontools fail2ban htop iotop curl ca-certificates
```

## 3. Subscription-Nag-Patch

Patch + dpkg-Hook, sodass Patch nach Updates automatisch wieder greift.

```bash
# Skript
cat > /usr/local/sbin/repatch-no-nag.sh <<'EOF'
#!/bin/bash
PWT=/usr/share/javascript/proxmox-widget-toolkit/proxmoxlib.js
if [ -f "$PWT" ] && grep -q "data.status.toLowerCase() !== 'active'" "$PWT"; then
  sed -i "s/data\.status\.toLowerCase() !== 'active'/false/g" "$PWT"
  systemctl reload-or-restart pveproxy.service 2>/dev/null || true
  logger -t pve-no-nag "Re-applied subscription-nag patch"
fi
EOF
chmod +x /usr/local/sbin/repatch-no-nag.sh

# dpkg-Hook
cat > /etc/apt/apt.conf.d/80pve-no-nag <<'EOF'
DPkg::Post-Invoke {"/usr/local/sbin/repatch-no-nag.sh || true";};
EOF

# Initial-Patch
/usr/local/sbin/repatch-no-nag.sh
```

## 4. /etc/hosts pflegen

```bash
cat >> /etc/hosts <<'EOF'

# rxf-sys guests
192.168.2.209 pbs.home pbs
EOF
```

## 5. Notifications (Strato SMTP)

Siehe [../07-monitoring/notifications.md](../07-monitoring/notifications.md).

```bash
pvesh create /cluster/notifications/endpoints/smtp \
  --name strato \
  --server smtp.strato.de \
  --port 465 \
  --mode tls \
  --username 'info@rxf-sys.de' \
  --password 'STRATO_PASSWORD' \
  --from-address 'info@rxf-sys.de' \
  --mailto 'info@rxf-sys.de' \
  --comment 'Strato SMTP TLS:465'

pvesh create /cluster/notifications/matchers \
  --name to-strato --target strato --mode all \
  --comment 'Alles an Strato-SMTP'

pvesh set /cluster/notifications/matchers/default-matcher --disable 1
```

## 6. PVE-Firewall

Siehe [../08-sicherheit/firewall.md](../08-sicherheit/firewall.md).

```bash
# cluster.fw
cat > /etc/pve/firewall/cluster.fw <<'EOF'
[OPTIONS]
enable: 1
policy_in: DROP
policy_out: ACCEPT

[IPSET lan]
192.168.2.0/24

[RULES]
EOF

# host.fw
mkdir -p /etc/pve/nodes/rxf-sys
cat > /etc/pve/nodes/rxf-sys/host.fw <<'EOF'
[OPTIONS]
enable: 1

[RULES]
IN ACCEPT -source +dc/lan -p tcp -dport 8006 -log nolog
IN ACCEPT -source +dc/lan -p tcp -dport 22 -log nolog
IN ACCEPT -source +dc/lan -p icmp -log nolog
EOF

pve-firewall restart
```

## 7. fail2ban

Siehe [../08-sicherheit/fail2ban.md](../08-sicherheit/fail2ban.md).

```bash
cat > /etc/fail2ban/jail.d/sshd-rxf-sys.local <<'EOF'
[DEFAULT]
ignoreip = 127.0.0.1/8 ::1 192.168.2.0/24
backend = systemd
findtime = 10m
maxretry = 5
bantime = 1h

[sshd]
enabled = true
mode    = aggressive
port    = 22
EOF

systemctl enable --now fail2ban
```

## 8. Backup-Job

```bash
# Existiert nach Recovery schon, sonst:
# pvesh create /cluster/backup ...
# Inhalt siehe ../configs/pve/jobs.cfg

cat /etc/pve/jobs.cfg     # verify
```

## 9. /mnt/storage Mount

```bash
# Nur falls Disk nach Recovery neu mounted werden muss
mkdir -p /mnt/storage
# UUID aus blkid /dev/sda1
echo 'UUID=37be5df3-1c31-4470-84d5-d651eaa25a22 /mnt/storage ext4 defaults,noatime,nofail,x-systemd.device-timeout=30 0 2' >> /etc/fstab
mount -a
```

## 10. Host-Config-Backup einrichten

Siehe [../06-backup/host-config-backup.md](../06-backup/host-config-backup.md).
