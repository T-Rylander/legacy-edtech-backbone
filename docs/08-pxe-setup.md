# PXE Network Boot Setup

## Overview

Configure PXE server on Z390 for zero-touch imaging of client devices.

## Storage Device

The provisioning script mounts `/srv/images` from a dedicated disk. Set the block
device via `IMAGES_DISK` in your `.env` (defaults to `/dev/sdb1`). The disk must
be formatted as ext4.

Example overrides:

```bash
export IMAGES_DISK=/dev/sdd1
sudo ./scripts/provision-dc.sh
```

If `/srv/images` is already mounted, the script detects it and skips remounting.

## HTTP Server for iPXE Chainloading

**Critical**: iPXE requires HTTP to fetch `boot.ipxe` after loading from TFTP. The
provisioning script installs nginx to serve `/srv/tftp` over port 80.

Without HTTP:
- TFTP delivers `undionly.kpxe` successfully
- iPXE loads but fails to fetch `boot.ipxe` (connection refused)
- Client retries PXE boot indefinitely (retry loop)

Validation:
```bash
# Test HTTP chainload (should return 200 OK)
curl -I http://192.168.1.11/boot.ipxe

# Check nginx status
sudo systemctl status nginx

# Monitor PXE flow with HTTP visibility
sudo tail -f /var/log/syslog | grep -E 'dnsmasq|nginx'
```

The script validates HTTP during provisioning—if it fails, iPXE chainloading won't work.

## Populate Ubuntu ISO (for NFS boot)

To boot Ubuntu Live over NFS, extract an Ubuntu ISO into `/srv/images/linux/ubuntu`
so `casper/vmlinuz` and `casper/initrd` are present. You can use the helper script:

```bash
sudo ./scripts/fix-pxe-loop.sh /path/to/ubuntu-24.04-desktop-amd64.iso
```

Or let it download automatically (no arg). After extraction, the script also ensures
an NFS export for `/srv/images/linux/ubuntu` and regenerates the iPXE menu.

## Install dnsmasq

```bash
sudo apt install -y dnsmasq

# Backup default config
sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig

# Create new config
sudo tee /etc/dnsmasq.conf << 'EOF'
# PXE proxy mode (USG handles DHCP)
interface=eth0
bind-interfaces
port=0

# TFTP settings
enable-tftp
tftp-root=/srv/tftp
tftp-secure

# PXE boot
dhcp-range=192.168.1.0,proxy
dhcp-boot=pxelinux.0

# Logging
log-queries
log-dhcp
EOF

# Create TFTP root
sudo mkdir -p /srv/tftp
sudo chown -R nobody:nogroup /srv/tftp

# Restart dnsmasq
sudo systemctl restart dnsmasq
```

## Download PXE Bootloaders

```bash
# Install syslinux
sudo apt install -y syslinux pxelinux

# Copy bootloader files
sudo cp /usr/lib/PXELINUX/pxelinux.0 /srv/tftp/
sudo cp /usr/lib/syslinux/modules/bios/*.c32 /srv/tftp/

# Create menu directory
sudo mkdir -p /srv/tftp/pxelinux.cfg
```

## Configure PXE Menu

```bash
sudo tee /srv/tftp/pxelinux.cfg/default << 'EOF'
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300

MENU TITLE Legacy EdTech PXE Boot

LABEL local
  MENU LABEL ^Boot from Local Disk
  LOCALBOOT 0

LABEL win11-install
  MENU LABEL Windows 11 EDU Install
  KERNEL memdisk
  INITRD images/win11.iso
  APPEND iso raw

LABEL ubuntu-install
  MENU LABEL Ubuntu 24.04 Install
  KERNEL ubuntu/vmlinuz
  APPEND initrd=ubuntu/initrd boot=casper netboot=nfs nfsroot=192.168.1.10:/srv/nfs/ubuntu
EOF
```

---

**Next**: [Image Management →](09-image-management.md)
