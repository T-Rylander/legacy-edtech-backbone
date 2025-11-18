#!/usr/bin/env bash
#
# provision-dc.sh - Automated Samba AD Domain Controller Provisioning
#
# Usage: sudo ./provision-dc.sh
#
# Prerequisites:
#   - Ubuntu 24.04 LTS
#   - Static IP configured
#   - .env file with REALM, DOMAIN, ADMIN_PASSWORD, DNS_FORWARDER
#

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Load environment variables
ENV_FILE="${BASH_SOURCE%/*}/../.env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    echo "Copy .env.example to .env and populate values"
    exit 1
fi

# Source .env
set -a
source "$ENV_FILE"
set +a

# Validate required variables
: "${REALM:?Error: REALM not set in .env}"
: "${DOMAIN:?Error: DOMAIN not set in .env}"
: "${ADMIN_PASSWORD:?Error: ADMIN_PASSWORD not set in .env}"
: "${DNS_FORWARDER:?Error: DNS_FORWARDER not set in .env}"

echo -e "${GREEN}Starting Samba AD DC Provisioning${NC}"
echo "Realm: $REALM"
echo "Domain: $DOMAIN"
echo "DNS Forwarder: $DNS_FORWARDER"
echo ""

# Update system
echo -e "${YELLOW}[1/8] Updating system packages...${NC}"
apt update && apt upgrade -y

# Install required packages
echo -e "${YELLOW}[2/8] Installing Samba and dependencies...${NC}"
DEBIAN_FRONTEND=noninteractive apt install -y \
    samba \
    smbclient \
    winbind \
    libpam-winbind \
    libnss-winbind \
    krb5-user \
    krb5-config \
    libpam-krb5 \
    dnsutils

# Stop and disable default services
echo -e "${YELLOW}[3/8] Stopping default Samba services...${NC}"
systemctl stop smbd nmbd winbind 2>/dev/null || true
systemctl disable smbd nmbd winbind 2>/dev/null || true
systemctl mask smbd nmbd winbind 2>/dev/null || true

# Backup original config
echo -e "${YELLOW}[4/8] Backing up smb.conf...${NC}"
if [[ -f /etc/samba/smb.conf ]]; then
    mv /etc/samba/smb.conf "/etc/samba/smb.conf.orig.$(date +%Y%m%d)"
fi

# Provision domain
echo -e "${YELLOW}[5/8] Provisioning domain...${NC}"
samba-tool domain provision \
    --realm="$REALM" \
    --domain="$DOMAIN" \
    --adminpass="$ADMIN_PASSWORD" \
    --server-role=dc \
    --dns-backend=SAMBA_INTERNAL \
    --use-rfc2307

# Configure DNS forwarder
echo -e "${YELLOW}[6/8] Configuring DNS forwarder...${NC}"
sed -i "/\[global\]/a \\\tdns forwarder = $DNS_FORWARDER" /etc/samba/smb.conf

# Copy Kerberos config
echo -e "${YELLOW}[7/8] Configuring Kerberos...${NC}"
cp /var/lib/samba/private/krb5.conf /etc/krb5.conf

# Start Samba AD DC
echo -e "${YELLOW}[8/8] Starting Samba AD DC...${NC}"
systemctl unmask samba-ad-dc 2>/dev/null || true
systemctl enable samba-ad-dc
systemctl start samba-ad-dc

# Wait for services to start
sleep 5

# Verify installation
echo ""
echo -e "${GREEN}Verifying installation...${NC}"

# Test DNS
echo -n "Testing DNS resolution... "
if host -t A "$(hostname).$REALM" 127.0.0.1 &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

# Test Kerberos
echo -n "Testing Kerberos... "
echo "$ADMIN_PASSWORD" | kinit administrator@"$REALM" 2>/dev/null
if klist &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
    kdestroy
else
    echo -e "${RED}FAILED${NC}"
fi

# Test Winbind
echo -n "Testing Winbind... "
if wbinfo -u &>/dev/null; then
    echo -e "${GREEN}OK${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

echo ""
echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}Samba AD DC Provisioning Complete!${NC}"
echo -e "${GREEN}==================================${NC}"
echo ""
echo "Domain: $DOMAIN"
echo "Realm: $REALM"
echo "Administrator Password: (see .env file)"
echo ""

# PXE Service Setup (Optional)
echo ""
read -p "Enable PXE imaging stack? (y/N): " ENABLE_PXE
if [[ "$ENABLE_PXE" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}[PXE 1/10] Installing PXE packages...${NC}"
    apt install -y dnsmasq tftpd-hpa nfs-kernel-server wget
    
    # Prereq: Check /dev/sdd1 existence and format
    echo -e "${YELLOW}[PXE 2/10] Checking storage prerequisites...${NC}"
    if [[ ! -b /dev/sdd1 ]]; then
        echo -e "${RED}ERROR: /dev/sdd1 missing—partition and format your HDD first${NC}"
        echo "Example: sudo fdisk /dev/sdd && sudo mkfs.ext4 /dev/sdd1"
        exit 1
    fi
    if ! blkid /dev/sdd1 | grep -q ext4; then
        echo -e "${RED}ERROR: /dev/sdd1 not ext4—format with 'sudo mkfs.ext4 /dev/sdd1'${NC}"
        exit 1
    fi
    
    # Create directory structure
    echo -e "${YELLOW}[PXE 3/10] Creating directory structure...${NC}"
    mkdir -p /srv/tftp/images/{windows,linux}
    mkdir -p /srv/images
    chown -R tftp:tftp /srv/tftp
    chmod 755 /srv/images
    
    # Mount images HDD (idempotent)
    echo -e "${YELLOW}[PXE 4/10] Mounting image storage...${NC}"
    if ! mountpoint -q /srv/images; then
        if ! grep -q "/srv/images" /etc/fstab; then
            echo "/dev/sdd1 /srv/images ext4 defaults 0 2" >> /etc/fstab
        fi
        mount /srv/images || {
            echo -e "${RED}ERROR: Failed to mount /srv/images${NC}"
            exit 1
        }
        echo -e "${GREEN}Mounted /srv/images${NC}"
    else
        echo -e "${GREEN}/srv/images already mounted${NC}"
    fi
    
    # Download iPXE binaries
    echo -e "${YELLOW}[PXE 5/10] Downloading iPXE binaries...${NC}"
    if [[ ! -f /srv/tftp/undionly.kpxe ]]; then
        wget -q -O /srv/tftp/undionly.kpxe http://boot.ipxe.org/undionly.kpxe || {
            echo -e "${RED}ERROR: iPXE download failed—check network connectivity${NC}"
            exit 1
        }
        wget -q -O /srv/tftp/ipxe.efi http://boot.ipxe.org/ipxe.efi
        chown tftp:tftp /srv/tftp/*.kpxe /srv/tftp/*.efi
        echo -e "${GREEN}iPXE binaries downloaded${NC}"
    else
        echo -e "${GREEN}iPXE binaries already present${NC}"
    fi
    
    # Create iPXE boot menu
    echo -e "${YELLOW}[PXE 6/10] Creating iPXE boot menu...${NC}"
    cat > /srv/tftp/boot.ipxe <<'EOF'
#!ipxe

dhcp
menu Legacy EdTech PXE Boot (Phase 1)
item --key u ubuntu Ubuntu 24.04 Live (NFS)
item --key s shell iPXE Shell
item --key l local Boot Local Disk
choose target || goto local

:ubuntu
set nfs-server 192.168.1.11
set nfs-path /srv/images/linux/ubuntu
kernel nfs://${nfs-server}${nfs-path}/casper/vmlinuz boot=casper netboot=nfs nfsroot=${nfs-server}:${nfs-path} || goto shell
initrd nfs://${nfs-server}${nfs-path}/casper/initrd || goto shell
boot || goto shell

:shell
shell

:local
sanboot --no-describe --drive 0x80 || exit
EOF
    chmod 644 /srv/tftp/boot.ipxe
    
    # Auto-detect network interface
    echo -e "${YELLOW}[PXE 7/10] Configuring dnsmasq proxy...${NC}"
    INTERFACE=$(ip -o link show up | awk -F': ' '{print $2}' | grep -v lo | head -1)
    if [[ -z "$INTERFACE" ]]; then
        INTERFACE=eth0
        echo -e "${YELLOW}Warning: Could not auto-detect interface, using eth0${NC}"
    else
        echo -e "${GREEN}Detected interface: $INTERFACE${NC}"
    fi
    
    # Configure dnsmasq as PXE proxy
    cat > /etc/dnsmasq.d/pxe.conf <<EOF
interface=${INTERFACE}
bind-interfaces
dhcp-range=192.168.1.0,proxy
dhcp-boot=tag:!ipxe,undionly.kpxe
dhcp-boot=tag:ipxe,http://192.168.1.11/boot.ipxe
enable-tftp
tftp-root=/srv/tftp
log-dhcp
EOF
    
    # Configure NFS exports (subnet-restricted)
    echo -e "${YELLOW}[PXE 8/10] Configuring NFS exports...${NC}"
    if ! grep -q "/srv/images" /etc/exports; then
        echo "/srv/images 192.168.1.0/24(ro,sync,no_subtree_check,no_root_squash)" >> /etc/exports
    fi
    exportfs -ra
    
    # Configure firewall
    echo -e "${YELLOW}[PXE 9/10] Configuring firewall rules...${NC}"
    ufw allow from 192.168.1.0/24 to any port 69 proto udp comment 'TFTP'
    ufw allow from 192.168.1.0/24 to any port 2049 proto tcp comment 'NFS'
    ufw allow from 192.168.1.0/24 to any port 111 proto tcp comment 'RPC'
    ufw allow from 192.168.1.0/24 to any port 111 proto udp comment 'RPC'
    ufw reload
    
    # Start services with rollback on failure
    echo -e "${YELLOW}[PXE 10/10] Starting PXE services...${NC}"
    systemctl enable --now dnsmasq tftpd-hpa nfs-kernel-server
    sleep 2
    
    if ! systemctl is-active --quiet dnsmasq tftpd-hpa nfs-kernel-server; then
        echo -e "${RED}ERROR: Service start failed—rolling back...${NC}"
        systemctl stop dnsmasq tftpd-hpa nfs-kernel-server
        rm -f /etc/dnsmasq.d/pxe.conf
        exportfs -ra
        exit 1
    fi
    
    # Validation checks
    echo ""
    echo -e "${GREEN}PXE Service Validation:${NC}"
    echo -n "  NFS exports: "
    if showmount -e localhost | grep -q /srv/images; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${YELLOW}Warning: NFS export not visible${NC}"
    fi
    
    echo -n "  TFTP access: "
    if tftp localhost -c get undionly.kpxe /tmp/test.kpxe 2>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        rm -f /tmp/test.kpxe
    else
        echo -e "${YELLOW}Warning: TFTP test failed${NC}"
    fi
    
    echo -n "  dnsmasq proxy: "
    if systemctl is-active --quiet dnsmasq; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}==================================${NC}"
    echo -e "${GREEN}PXE Stack Provisioned!${NC}"
    echo -e "${GREEN}==================================${NC}"
    echo ""
    echo "Monitor logs: sudo tail -f /var/log/syslog | grep -E 'dnsmasq|tftp'"
    echo "NFS status: sudo showmount -e localhost"
    echo "TFTP test: tftp 192.168.1.11 -c get undionly.kpxe /tmp/test"
    echo ""
    echo "Next steps:"
    echo "1. Configure USG DHCP options:"
    echo "   - Option 66 (TFTP Server): 192.168.1.11"
    echo "   - Option 67 (Boot Filename): undionly.kpxe"
    echo "2. Download Ubuntu 24.04 ISO and extract to /srv/images/linux/ubuntu"
    echo "3. Test PXE boot on a client machine"
    echo ""
fi

echo "All services configured!"
echo ""
