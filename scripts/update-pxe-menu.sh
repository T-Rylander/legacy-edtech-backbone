#!/usr/bin/env bash
#
# update-pxe-menu.sh - Generate iPXE Boot Menu
#
# Usage: ./update-pxe-menu.sh
#
# Generates PXE boot menu based on available images in /srv/tftp/images/
#

set -euo pipefail

PXE_MENU="/srv/tftp/pxelinux.cfg/default"
IMAGE_DIR="/srv/images"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root"
   exit 1
fi

echo "Generating PXE boot menu..."

# Create menu header
cat > "$PXE_MENU" << 'EOF'
DEFAULT menu.c32
PROMPT 0
TIMEOUT 300
MENU TITLE Legacy EdTech PXE Boot Menu

LABEL local
  MENU LABEL ^Boot from Local Disk (Default)
  MENU DEFAULT
  LOCALBOOT 0

EOF

# Add Windows 11 if available
if [[ -d "$IMAGE_DIR/win11-extracted" ]]; then
    cat >> "$PXE_MENU" << 'EOF'
LABEL win11-edu
  MENU LABEL Windows 11 EDU - Auto Install + Domain Join
  KERNEL memdisk
  INITRD images/win11.iso
  APPEND iso raw

EOF
fi

# Add Ubuntu if available
if [[ -d "$IMAGE_DIR/ubuntu" ]]; then
    cat >> "$PXE_MENU" << 'EOF'
LABEL ubuntu-install
  MENU LABEL Ubuntu 24.04 LTS - Automated Install
  KERNEL ubuntu/vmlinuz
  APPEND initrd=ubuntu/initrd boot=casper netboot=nfs nfsroot=192.168.1.10:/srv/nfs/ubuntu

EOF
fi

# Add diagnostic tools
cat >> "$PXE_MENU" << 'EOF'
LABEL memtest
  MENU LABEL Memory Test (Memtest86+)
  KERNEL memtest

LABEL reboot
  MENU LABEL Reboot
  COM32 reboot.c32

LABEL poweroff
  MENU LABEL Power Off
  COM32 poweroff.c32
EOF

echo "PXE menu updated: $PXE_MENU"
echo "Available options:"
grep "MENU LABEL" "$PXE_MENU" | sed 's/.*MENU LABEL /  - /'
