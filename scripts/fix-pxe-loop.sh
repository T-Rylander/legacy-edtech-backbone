#!/usr/bin/env bash
# fix-pxe-loop.sh - Populate Ubuntu NFS payload, ensure exports, regenerate iPXE, and validate
# Usage:
#   sudo ./scripts/fix-pxe-loop.sh [optional:/path/to/ubuntu-24.04-desktop-amd64.iso]
#
# This addresses the PXE retry loop where iPXE cannot fetch boot.ipxe over HTTP
# or NFS lacks the Ubuntu casper payload. Idempotent and safe to re-run.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
  echo -e "${RED}Error: Run as root${NC}"; exit 1
fi

# Load .env for DC_IP and IMAGES_DISK
ENV_FILE="${BASH_SOURCE%/*}/../.env"
# shellcheck source=/dev/null
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi
DC_IP=${DC_IP:-$(hostname -I | awk '{print $1}')}

UBUNTU_DIR="/srv/images/linux/ubuntu"
ISO_ARG="${1:-}"
# Prefer numbered noble release path; can override via UBUNTU_ISO_URL in .env
ISO_URL=${UBUNTU_ISO_URL:-"https://releases.ubuntu.com/noble/ubuntu-24.04.1-desktop-amd64.iso"}
TMP_ISO="/tmp/ubuntu-24.04.1-desktop-amd64.iso"
MNT="/mnt/ubuntu-iso"

mkdir -p "$UBUNTU_DIR" "$MNT"

# 1) Populate Ubuntu NFS payload (if casper missing)
if [[ ! -f "$UBUNTU_DIR/casper/vmlinuz" || ! -f "$UBUNTU_DIR/casper/initrd" ]]; then
  echo -e "${YELLOW}[1/5] Populating Ubuntu ISO into $UBUNTU_DIR...${NC}"
  if [[ -n "$ISO_ARG" && -f "$ISO_ARG" ]]; then
    ISO_PATH="$ISO_ARG"
  else
    echo -e "${YELLOW}Downloading Ubuntu 24.04.1 LTS ISO (~6GB)...${NC}"
    if ! curl -L -o "$TMP_ISO" "$ISO_URL"; then
      echo -e "${RED}ERROR: Download failed. Check URL or network: $ISO_URL${NC}"
      exit 1
    fi
    # Validate size > 5GB to avoid saving an HTML error page
    ISO_SIZE=$(stat -f%z "$TMP_ISO" 2>/dev/null || stat -c%s "$TMP_ISO" 2>/dev/null || echo 0)
    if [[ "$ISO_SIZE" -lt 5000000000 ]]; then
      echo -e "${RED}ERROR: Downloaded file too small (${ISO_SIZE} bytes). Likely an error page.${NC}"
      echo "URL: $ISO_URL"
      rm -f "$TMP_ISO"
      exit 1
    fi
    echo -e "${GREEN}Download complete (${ISO_SIZE} bytes).${NC}"
    ISO_PATH="$TMP_ISO"
  fi
  # Clean any existing mounts and mount read-only
  umount "$MNT" 2>/dev/null || true
  mount -o loop,ro "$ISO_PATH" "$MNT" || {
    echo -e "${RED}ERROR: Failed to mount ISO. It may be corrupted.${NC}"
    echo "Try removing $TMP_ISO and re-running."
    exit 1
  }
  rsync -a --delete "$MNT/" "$UBUNTU_DIR/"
  umount "$MNT"
  [[ -f "$TMP_ISO" ]] && rm -f "$TMP_ISO"
  ls -lh "$UBUNTU_DIR/casper/"{vmlinuz,initrd}
else
  echo -e "${GREEN}Ubuntu payload already present (casper found).${NC}"
fi

# 2) Ensure NFS export for Ubuntu path
echo -e "${YELLOW}[2/5] Ensuring NFS export...${NC}"
if ! grep -q "^/srv/images/linux/ubuntu " /etc/exports; then
  echo "/srv/images/linux/ubuntu 192.168.1.0/24(ro,sync,no_subtree_check,no_root_squash)" >> /etc/exports
fi
exportfs -ra
showmount -e localhost | grep -q /srv/images/linux/ubuntu && echo -e "${GREEN}NFS export OK${NC}" || echo -e "${RED}NFS export missing${NC}"

# 3) Regenerate boot.ipxe with DC_IP
echo -e "${YELLOW}[3/5] Regenerating iPXE menu...${NC}"
cat > /srv/tftp/boot.ipxe <<'EOF'
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
chmod 644 /srv/tftp/boot.ipxe
sed -i "s/DC_IP_HERE/${DC_IP}/g" /srv/tftp/boot.ipxe

# 4) Ensure nginx is serving /srv/tftp and dnsmasq chainload points to DC_IP
echo -e "${YELLOW}[4/5] Verifying nginx and dnsmasq config...${NC}"
if ! systemctl is-active --quiet nginx; then
  apt update; apt install -y nginx
fi
cat > /etc/nginx/sites-available/pxe <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /srv/tftp;
    server_name _;
    location / { autoindex on; }
    location ~ \.ipxe$ { add_header Content-Type application/ipxe; }
}
NGINX
ln -sf /etc/nginx/sites-available/pxe /etc/nginx/sites-enabled/pxe
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

INTERFACE=$(ip -o link show up | awk -F': ' '{print $2}' | grep -v lo | head -1)
cat > /etc/dnsmasq.d/pxe.conf <<EOF
interface=${INTERFACE}
bind-interfaces
dhcp-range=192.168.1.0,proxy

# Identify client architecture
dhcp-match=set:bios,option:client-arch,0
dhcp-match=set:efi32,option:client-arch,6
dhcp-match=set:efi64,option:client-arch,7
dhcp-match=set:efibc,option:client-arch,9

# Detect iPXE second stage
dhcp-userclass=set:ipxe,iPXE

# Second-stage iPXE fetches HTTP menu
dhcp-boot=tag:ipxe,http://DC_IP_HERE/boot.ipxe

# First-stage bootloaders via TFTP
dhcp-boot=tag:bios,undionly.kpxe
dhcp-boot=tag:efi32,ipxe.efi
dhcp-boot=tag:efi64,ipxe.efi
dhcp-boot=tag:efibc,ipxe.efi

enable-tftp
tftp-root=/srv/tftp
log-dhcp
EOF
sed -i "s/DC_IP_HERE/${DC_IP}/g" /etc/dnsmasq.d/pxe.conf
systemctl restart dnsmasq

# 5) Validation
echo -e "${YELLOW}[5/5] Validating end-to-end...${NC}"
showmount -e localhost | grep /srv/images/linux/ubuntu && echo -e "${GREEN}NFS: OK${NC}" || echo -e "${RED}NFS: FAIL${NC}"
if curl -sf "http://${DC_IP}/boot.ipxe" >/dev/null; then echo -e "${GREEN}HTTP: OK${NC}"; else echo -e "${RED}HTTP: FAIL${NC}"; fi
systemctl is-active --quiet dnsmasq && echo -e "${GREEN}dnsmasq: OK${NC}" || echo -e "${RED}dnsmasq: FAIL${NC}"
systemctl is-active --quiet nginx && echo -e "${GREEN}nginx: OK${NC}" || echo -e "${RED}nginx: FAIL${NC}"

echo -e "${GREEN}Fix applied. PXE chainload should now present the iPXE menu.\n${NC}"
