# SSL/TLS Zertifikate

## Uebersicht

| Dienst | Zertifikat | Typ | Erneuerung |
|--------|-----------|-----|------------|
| Proxmox Web-UI | Self-signed | Selbst-signiert | Automatisch |
| Vaultwarden | Let's Encrypt | DV | Automatisch (Nginx PM) |
| PBS | Self-signed | Selbst-signiert | Automatisch |

## Let's Encrypt via Nginx Proxy Manager

### Konfiguration

Nginx Proxy Manager (CT 104) verwaltet die Let's Encrypt Zertifikate:

1. NPM Web-UI oeffnen: http://proxy.home:81
2. SSL Certificates -> Add SSL Certificate
3. Let's Encrypt auswaehlen
4. Domain eintragen: `vault-rxfsys.duckdns.org`
5. E-Mail-Adresse eintragen
6. DNS Challenge oder HTTP Challenge

### Proxy Hosts

| Domain | Ziel | SSL | Beschreibung |
|--------|------|-----|--------------|
| vault-rxfsys.duckdns.org | http://192.168.2.124:8081 | Let's Encrypt | Vaultwarden |

### Zertifikat-Erneuerung

Let's Encrypt Zertifikate werden automatisch alle 90 Tage erneuert. Nginx PM erledigt dies automatisch.

```bash
# Zertifikate pruefen (im Nginx Container)
pct exec 104 -- ls -la /data/letsencrypt/
```

## Proxmox Web-UI Zertifikat

### Eigenes Let's Encrypt Zertifikat (optional)

```bash
# ACME-Account erstellen
pvenode acme account register default <EMAIL> --directory https://acme-v02.api.letsencrypt.org/directory

# Zertifikat anfordern
pvenode acme cert order

# Automatische Erneuerung ist dann aktiv
```

## Pruefbefehle

```bash
# Zertifikat einer URL pruefen
openssl s_client -connect vault-rxfsys.duckdns.org:443 -servername vault-rxfsys.duckdns.org 2>/dev/null | openssl x509 -noout -dates

# Proxmox Zertifikat pruefen
openssl x509 -in /etc/pve/local/pve-ssl.pem -noout -dates
```
