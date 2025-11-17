# OS Installation

## Ubuntu 24.04 LTS Server Setup

This guide covers installing Ubuntu Server on the Z390 domain controller with RAID1 for resilience.

## Prerequisites

- USB flash drive (4GB+) for Ubuntu installer
- Z390 hardware from [Hardware Specs](01-hardware-specs.md)
- Two SSDs of equal size for RAID1
- Network cable connected to UniFi switch

## Download Ubuntu Server

```bash
# From another machine, download Ubuntu 24.04 LTS
wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso

# Verify checksum
sha256sum ubuntu-24.04-live-server-amd64.iso

# Create bootable USB (Linux)
sudo dd if=ubuntu-24.04-live-server-amd64.iso of=/dev/sdX bs=4M status=progress
sync

# Or use Rufus on Windows (DD mode)
```

## Installation Steps

### 1. Boot from USB

1. Insert USB into Z390
2. Enter BIOS (F2 or DEL during boot)
3. Set boot order: USB first
4. Save and reboot

### 2. Basic Configuration

- **Language**: English
- **Keyboard**: US or your layout
- **Network**: Auto DHCP (configure static later)
- **Proxy**: None (unless required)
- **Mirror**: Default Ubuntu archive

### 3. Storage Configuration (RAID1)

!!! warning "Data Loss Warning"
    RAID setup will erase all data on both SSDs. Back up any existing data first.

**Option A: Guided RAID1** (Recommended for beginners)

1. Select "Custom storage layout"
2. Create new partition table on both SSDs (GPT)
3. For each SSD:
   - 1GB EFI partition (for redundancy)
   - Remaining space as RAID member
4. Create RAID1 device from both members
5. Format RAID device as ext4, mount as `/`

**Option B: Manual mdadm** (For advanced users, post-install)

See [scripts/raid-setup.sh](https://github.com/T-Rylander/legacy-edtech-backbone/blob/main/scripts/raid-setup.sh) for automated setup.

### 4. User Configuration

```plaintext
Your name: Legacy Admin
Server name: dc01
Username: legacyadmin
Password: [STRONG PASSWORD]
```

!!! tip "Security First"
    Use a 16+ character password or passphrase. Store in password manager.

### 5. SSH Setup

- **Install OpenSSH server**: ✅ Yes
- **Import SSH identity**: No (configure keys post-install)

### 6. Featured Server Snaps

**Skip all snaps** - we'll install packages manually for control.

### 7. Complete Installation

Wait for installation to complete (~10 minutes), then:

1. Remove USB drive
2. Reboot
3. Log in with credentials

## Post-Install Configuration

### Update System

```bash
# Update package lists
sudo apt update

# Upgrade all packages
sudo apt upgrade -y

# Reboot if kernel updated
sudo reboot
```

### Configure Static IP

```bash
# Edit netplan config
sudo nano /etc/netplan/00-installer-config.yaml
```

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    eno1:  # Your interface name (check with 'ip a')
      addresses:
        - 192.168.1.10/24
      routes:
        - to: default
          via: 192.168.1.1  # USG IP
      nameservers:
        addresses: [8.8.8.8, 1.1.1.1]  # Temporary, will use self later
```

```bash
# Apply netplan
sudo netplan apply

# Verify connectivity
ping -c 4 8.8.8.8
```

### Install Essential Packages

```bash
# Development and admin tools
sudo apt install -y \
  build-essential \
  git \
  curl \
  wget \
  vim \
  htop \
  tmux \
  net-tools \
  dnsutils \
  iptables \
  ufw

# Storage tools
sudo apt install -y \
  mdadm \
  smartmontools \
  lvm2

# Verify RAID status (if using mdadm)
cat /proc/mdstat
sudo mdadm --detail /dev/md0
```

### Configure Firewall (Basic)

```bash
# Allow SSH
sudo ufw allow 22/tcp

# Enable UFW
sudo ufw enable

# Verify status
sudo ufw status verbose
```

!!! info "Domain Controller Ports"
    Additional ports (53, 88, 389, 445, etc.) will be opened during Samba provisioning.

### Enable Automatic Updates

```bash
# Install unattended-upgrades
sudo apt install -y unattended-upgrades

# Configure
sudo dpkg-reconfigure -plow unattended-upgrades

# Verify config
cat /etc/apt/apt.conf.d/50unattended-upgrades
```

### Check System Health

```bash
# CPU info
lscpu

# Memory
free -h

# Storage
df -h
lsblk

# RAID status
cat /proc/mdstat

# Disk health
sudo smartctl -a /dev/sda
sudo smartctl -a /dev/sdb
```

## Verification Checklist

Before proceeding to Samba provisioning:

- [ ] System fully updated (`apt list --upgradable` shows none)
- [ ] Static IP configured and pingable
- [ ] RAID1 array healthy (`/proc/mdstat` shows active sync)
- [ ] SSH access working from remote machine
- [ ] Firewall enabled with SSH allowed
- [ ] Hostname set correctly (`hostnamectl`)
- [ ] No critical errors in `dmesg` or `journalctl -xe`

---

**Next Step**: [Samba AD DC Provisioning →](03-samba-provision.md)
