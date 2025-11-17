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
echo -e "${GREEN}Provisioning Complete!${NC}"
echo -e "${GREEN}==================================${NC}"
echo ""
echo "Domain: $DOMAIN"
echo "Realm: $REALM"
echo "Administrator Password: (see .env file)"
echo ""
echo "Next steps:"
echo "1. Update firewall: sudo ufw allow 53,88,389,445/tcp"
echo "2. Configure DNS on clients to point to this server"
echo "3. Join Windows/Linux clients to domain"
echo "4. Create OUs and users with samba-tool"
echo ""
