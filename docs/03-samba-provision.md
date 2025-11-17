# Samba AD Domain Controller Provisioning

## Overview

This guide walks through setting up a Samba Active Directory Domain Controller on Ubuntu 24.04 LTS. The domain will provide centralized authentication for Windows and Linux clients.

## Prerequisites

- Ubuntu 24.04 LTS installed ([OS Installation](02-os-install.md))
- Static IP configured (e.g., 192.168.1.10)
- Root or sudo access
- `.env` file populated from `.env.example`

## Automated Provisioning

Use the provided script for one-command setup:

```bash
# Clone the repo
git clone https://github.com/T-Rylander/legacy-edtech-backbone.git
cd legacy-edtech-backbone

# Copy environment template
cp .env.example .env

# Edit with your values
nano .env
# Set: REALM=LEGACYEDTECH.LOCAL
#      DOMAIN=LEGACYEDTECH
#      ADMIN_PASSWORD=[strong password]
#      DNS_FORWARDER=8.8.8.8

# Run provisioning script
sudo ./scripts/provision-dc.sh
```

The script will:
1. Install Samba, Kerberos, Winbind packages
2. Provision AD domain with `samba-tool domain provision`
3. Configure DNS forwarder
4. Start Samba services
5. Verify domain with `smbclient` and `wbinfo`

## Manual Provisioning (Step-by-Step)

If you prefer manual control, follow these steps:

### 1. Install Packages

```bash
# Update package lists
sudo apt update

# Install Samba AD DC packages
sudo apt install -y \
  samba \
  smbclient \
  winbind \
  libpam-winbind \
  libnss-winbind \
  krb5-user \
  krb5-config \
  libpam-krb5
```

During installation, configure Kerberos:
- **Default Kerberos realm**: `LEGACYEDTECH.LOCAL`
- **Kerberos servers**: `dc01.legacyedtech.local`
- **Admin server**: `dc01.legacyedtech.local`

### 2. Stop and Disable Default Services

```bash
# Stop services
sudo systemctl stop smbd nmbd winbind

# Disable services (AD DC uses samba-ad-dc instead)
sudo systemctl disable smbd nmbd winbind

# Mask to prevent accidental start
sudo systemctl mask smbd nmbd winbind
```

### 3. Backup Default Configuration

```bash
# Backup smb.conf
sudo mv /etc/samba/smb.conf /etc/samba/smb.conf.orig
```

### 4. Provision Domain

```bash
# Run samba-tool provision
sudo samba-tool domain provision \
  --realm=LEGACYEDTECH.LOCAL \
  --domain=LEGACYEDTECH \
  --adminpass='YourStrongPassword123!' \
  --server-role=dc \
  --dns-backend=SAMBA_INTERNAL \
  --use-rfc2307

# Output will show:
# - Administrator password (save this!)
# - DNS configuration
# - Kerberos realm
```

!!! warning "Password Complexity"
    Administrator password must meet complexity requirements:
    - Minimum 8 characters
    - Mix of uppercase, lowercase, numbers, symbols
    - Not contain username

### 5. Configure DNS Forwarder

```bash
# Edit smb.conf
sudo nano /etc/samba/smb.conf
```

Add to `[global]` section:

```ini
dns forwarder = 8.8.8.8
```

### 6. Copy Kerberos Configuration

```bash
# Link Samba's Kerberos config
sudo cp /var/lib/samba/private/krb5.conf /etc/krb5.conf
```

### 7. Start Samba AD DC

```bash
# Unmask samba-ad-dc
sudo systemctl unmask samba-ad-dc

# Enable and start
sudo systemctl enable samba-ad-dc
sudo systemctl start samba-ad-dc

# Check status
sudo systemctl status samba-ad-dc
```

### 8. Configure Firewall

```bash
# Allow AD DC ports
sudo ufw allow 53/tcp    # DNS
sudo ufw allow 53/udp
sudo ufw allow 88/tcp    # Kerberos
sudo ufw allow 88/udp
sudo ufw allow 135/tcp   # RPC
sudo ufw allow 137/udp   # NetBIOS
sudo ufw allow 138/udp
sudo ufw allow 139/tcp
sudo ufw allow 389/tcp   # LDAP
sudo ufw allow 389/udp
sudo ufw allow 445/tcp   # SMB
sudo ufw allow 464/tcp   # Kerberos password change
sudo ufw allow 464/udp
sudo ufw allow 636/tcp   # LDAPS
sudo ufw allow 3268/tcp  # Global catalog
sudo ufw allow 3269/tcp  # Global catalog SSL

# Reload UFW
sudo ufw reload

# Verify
sudo ufw status numbered
```

## Verification

### Test DNS Resolution

```bash
# Forward lookup
host -t A dc01.legacyedtech.local 127.0.0.1

# Reverse lookup
host -t PTR 192.168.1.10 127.0.0.1

# SRV records
host -t SRV _ldap._tcp.legacyedtech.local 127.0.0.1
host -t SRV _kerberos._tcp.legacyedtech.local 127.0.0.1
```

Expected output:
```
dc01.legacyedtech.local has address 192.168.1.10
_ldap._tcp.legacyedtech.local has SRV record 0 100 389 dc01.legacyedtech.local.
```

### Test Kerberos Authentication

```bash
# Get administrator ticket
kinit administrator@LEGACYEDTECH.LOCAL
# Enter password when prompted

# List tickets
klist

# Expected output:
# Ticket cache: FILE:/tmp/krb5cc_1000
# Default principal: administrator@LEGACYEDTECH.LOCAL
#
# Valid starting     Expires            Service principal
# 11/17/25 10:00:00  11/17/25 20:00:00  krbtgt/LEGACYEDTECH.LOCAL@LEGACYEDTECH.LOCAL
```

### Test SMB Client

```bash
# List domain shares
smbclient -L localhost -U administrator
# Enter password

# Expected output shows sysvol and netlogon shares
```

### Test Winbind

```bash
# Query domain users
wbinfo -u

# Query domain groups
wbinfo -g

# Expected output includes Administrator, Domain Users, etc.
```

## Post-Provisioning Tasks

### Configure Name Resolution

Update `/etc/resolv.conf` to use self:

```bash
sudo nano /etc/resolv.conf
```

```
search legacyedtech.local
nameserver 192.168.1.10
nameserver 8.8.8.8
```

Make immutable (prevent DHCP override):

```bash
sudo chattr +i /etc/resolv.conf
```

### Create Organizational Units

```bash
# Create OUs for structure
sudo samba-tool ou create "OU=Users,DC=legacyedtech,DC=local"
sudo samba-tool ou create "OU=Computers,DC=legacyedtech,DC=local"
sudo samba-tool ou create "OU=Groups,DC=legacyedtech,DC=local"
```

### Create Test User

```bash
# Create user in Users OU
sudo samba-tool user create testuser 'TestPass123!' \
  --given-name=Test \
  --surname=User \
  --mail-address=testuser@legacyedtech.local

# Add to Domain Users
sudo samba-tool group addmembers "Domain Users" testuser

# Verify
wbinfo -u | grep testuser
```

## Troubleshooting

### Service Won't Start

```bash
# Check logs
sudo journalctl -u samba-ad-dc -n 50 --no-pager

# Common issues:
# - Port conflict (check with netstat -tlnp)
# - Permission errors (check /var/lib/samba ownership)
# - DNS misconfiguration (verify /etc/resolv.conf)
```

### DNS Issues

```bash
# Restart DNS
sudo systemctl restart samba-ad-dc

# Test DNS from external host
dig @192.168.1.10 dc01.legacyedtech.local
```

### Kerberos Failures

```bash
# Delete old tickets
kdestroy

# Re-sync system time (critical for Kerberos)
sudo systemctl restart systemd-timesyncd
timedatectl status

# Retry kinit
kinit administrator@LEGACYEDTECH.LOCAL
```

## Next Steps

- [Join Windows clients to domain](03-samba-provision.md#joining-windows-clients)
- [Configure backup procedures](04-backup-dr.md)
- [Harden security](05-security-monitoring.md)

---

**Next Step**: [Backup & Disaster Recovery →](04-backup-dr.md)
