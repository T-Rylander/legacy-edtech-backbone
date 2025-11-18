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
# PXE Network Boot (iPXE + nginx + NFS)

## Overview

This guide aligns with the provisioning script to deliver a lean, production-ready PXE stack:
- dnsmasq (PXE proxy) hands off to iPXE
- iPXE fetches `boot.ipxe` via HTTP (nginx serves `/srv/tftp`)
- Ubuntu Live boots over NFS from `/srv/images/linux/ubuntu`

Works with UniFi USG DHCP; dnsmasq runs in proxy mode (no IP conflicts).

## Prerequisites

- Ubuntu 24.04 LTS on the Z390 DC
- Static IP set; `.env` configured with `REALM`, `DOMAIN`, `ADMIN_PASSWORD`, `DNS_FORWARDER`, `DC_IP`, `IMAGES_DISK`
- Run `sudo ./scripts/provision-dc.sh` and answer `y` to enable PXE, or follow steps below

## Install Required Packages

```bash
sudo apt update
sudo apt install -y dnsmasq tftpd-hpa nfs-kernel-server nginx wget curl
```

## Directories and iPXE Bootloaders

```bash
sudo mkdir -p /srv/tftp /srv/images/linux/ubuntu
sudo chown -R tftp:tftp /srv/tftp
sudo chmod 755 /srv/images

# iPXE binaries
sudo wget -q -O /srv/tftp/undionly.kpxe http://boot.ipxe.org/undionly.kpxe
sudo wget -q -O /srv/tftp/ipxe.efi http://boot.ipxe.org/ipxe.efi
sudo chown tftp:tftp /srv/tftp/undionly.kpxe /srv/tftp/ipxe.efi
```

## iPXE Menu

Replace `DC_IP_HERE` with your controller’s IP (or export `DC_IP` in `.env` and use the provisioning script).

```bash
sudo tee /srv/tftp/boot.ipxe > /dev/null <<'EOF'
#!ipxe

dhcp
menu Legacy EdTech PXE Boot
item --key u ubuntu Ubuntu 24.04 Live
item --key s shell iPXE Shell
item --key l local Boot Local Disk
choose --default local --timeout 30000 target || goto local

:ubuntu
set nfs-server DC_IP_HERE
set nfs-root /srv/images/linux/ubuntu
kernel nfs://${nfs-server}${nfs-root}/casper/vmlinuz boot=casper netboot=nfs nfsroot=${nfs-server}:${nfs-root} ip=dhcp || goto shell
initrd nfs://${nfs-server}${nfs-root}/casper/initrd
boot || goto shell

:shell
shell

:local
sanboot --no-describe --drive 0x80 || exit
EOF
sudo chmod 644 /srv/tftp/boot.ipxe
```

## dnsmasq (PXE Proxy)

```bash
IFACE=$(ip -o link show up | awk -F': ' '{print $2}' | grep -v lo | head -1)
sudo tee /etc/dnsmasq.d/pxe.conf > /dev/null <<EOF
interface=${IFACE}
bind-interfaces
dhcp-range=192.168.1.0,proxy
dhcp-boot=tag:!ipxe,undionly.kpxe
dhcp-boot=tag:ipxe,http://DC_IP_HERE/boot.ipxe
enable-tftp
tftp-root=/srv/tftp
log-dhcp
EOF
sudo systemctl enable --now dnsmasq
```

## nginx (HTTP for iPXE)

```bash
sudo tee /etc/nginx/sites-available/pxe > /dev/null <<'EOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /srv/tftp;
    server_name _;
    location / { autoindex on; }
    location ~ \.ipxe$ { add_header Content-Type application/ipxe; }
}
EOF
sudo ln -sf /etc/nginx/sites-available/pxe /etc/nginx/sites-enabled/pxe
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl enable --now nginx
```

## NFS Export

```bash
if ! grep -q "^/srv/images/linux/ubuntu " /etc/exports; then
  echo "/srv/images/linux/ubuntu 192.168.1.0/24(ro,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
fi
sudo exportfs -ra
sudo showmount -e localhost | grep /srv/images/linux/ubuntu
```

## Firewall Rules (UFW)

```bash
sudo ufw allow from 192.168.1.0/24 to any port 69 proto udp comment 'TFTP'
sudo ufw allow from 192.168.1.0/24 to any port 80 proto tcp comment 'iPXE HTTP'
sudo ufw allow from 192.168.1.0/24 to any port 2049 proto tcp comment 'NFS'
sudo ufw allow from 192.168.1.0/24 to any port 111 proto tcp comment 'RPC'
sudo ufw allow from 192.168.1.0/24 to any port 111 proto udp comment 'RPC'
sudo ufw reload
```

## Validation

```bash
# HTTP chainload (should be 200 OK)


# TFTP quick test
tftp DC_IP_HERE -c get undionly.kpxe /tmp/test && rm /tmp/test

# NFS export visibility
showmount -e localhost | grep /srv/images/linux/ubuntu

# Service status
systemctl status dnsmasq nginx nfs-kernel-server --no-pager

# Live PXE logs
sudo tail -f /var/log/syslog | grep -E 'dnsmasq|tftp|nginx'
```

## Storage Device

The provisioning script mounts `/srv/images` from a disk set via `IMAGES_DISK` in `.env` (defaults to `/dev/sdb1`). Disk must be ext4.

```bash
export IMAGES_DISK=/dev/sdd1
sudo ./scripts/provision-dc.sh
```

If `/srv/images` is already mounted, the script detects it and skips remounting.

## HTTP Server for iPXE Chainloading

Critical: iPXE requires HTTP to fetch `boot.ipxe` after TFTP loads `undionly.kpxe`. The provisioning script installs nginx to serve `/srv/tftp` over port 80.

Without HTTP:
- TFTP delivers `undionly.kpxe`
- iPXE loads but fails to fetch `boot.ipxe` (connection refused)
- Client retries PXE boot indefinitely (retry loop)

## Populate Ubuntu ISO (for NFS boot)

Use the helper to extract an Ubuntu ISO into `/srv/images/linux/ubuntu` so `casper/vmlinuz` and `casper/initrd` exist.

```bash
sudo ./scripts/fix-pxe-loop.sh /path/to/ubuntu-24.04-desktop-amd64.iso
# or run without args to auto-download the ISO
sudo ./scripts/fix-pxe-loop.sh
```

The script also ensures the NFS export and regenerates `boot.ipxe` with `DC_IP`.

## UniFi DHCP Options (USG)

Set DHCP options on the LAN network:
- Option 66 (TFTP Server): `DC_IP`
- Option 67 (Boot Filename): `undionly.kpxe`

Apply and wait for provisioning, then PXE boot a client (F12) to verify the iPXE menu appears.

---

**Next**: [Image Management →](09-image-management.md)
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
