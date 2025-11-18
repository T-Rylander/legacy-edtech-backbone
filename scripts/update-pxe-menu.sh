#!/usr/bin/env bash
#
# update-pxe-menu.sh - Generate iPXE boot menu (boot.ipxe)
#
# Usage: sudo ./scripts/update-pxe-menu.sh
#
# Renders /srv/tftp/boot.ipxe using DC_IP from .env or autodetected IP.

set -euo pipefail

BOOT_IPXE="/srv/tftp/boot.ipxe"

if [[ $EUID -ne 0 ]]; then
  echo "Error: This script must be run as root"; exit 1
fi

# Load .env if present
ENV_FILE="${BASH_SOURCE%/*}/../.env"
# shellcheck source=/dev/null
if [[ -f "$ENV_FILE" ]]; then set -a; source "$ENV_FILE"; set +a; fi
DC_IP=${DC_IP:-$(hostname -I | awk '{print $1}')}

mkdir -p /srv/tftp

cat > "$BOOT_IPXE" <<'EOF'
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

sed -i "s/DC_IP_HERE/${DC_IP}/g" "$BOOT_IPXE"
chmod 644 "$BOOT_IPXE"

echo "iPXE menu updated: $BOOT_IPXE"
echo "Points NFS to: nfs://${DC_IP}/srv/images/linux/ubuntu"
