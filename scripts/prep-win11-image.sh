#!/usr/bin/env bash
#
# prep-win11-image.sh - Prepare Windows 11 EDU Image for PXE Deployment
#
# Usage: sudo ./prep-win11-image.sh /path/to/Win11.iso
#
# This script extracts a Windows 11 ISO and prepares it for PXE deployment
# with automated installation and domain join.
#

set -euo pipefail

# Check arguments
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/Win11.iso"
    exit 1
fi

ISO_PATH=$1
EXTRACT_DIR="/srv/images/win11-extracted"
MOUNT_DIR="/mnt/win11-iso"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root"
   exit 1
fi

# Verify ISO exists
if [[ ! -f "$ISO_PATH" ]]; then
    echo "Error: ISO file not found: $ISO_PATH"
    exit 1
fi

# Install required packages
echo "Installing required packages..."
apt install -y wimtools

# Create directories
mkdir -p "$MOUNT_DIR" "$EXTRACT_DIR"

# Mount ISO
echo "Mounting ISO..."
mount -o loop "$ISO_PATH" "$MOUNT_DIR"

# Extract install.wim
echo "Extracting install.wim..."
wimlib-imagex extract "$MOUNT_DIR/sources/install.wim" 1 "$EXTRACT_DIR"

# Create autounattend.xml
echo "Creating autounattend.xml..."
cat > "$EXTRACT_DIR/autounattend.xml" << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup">
            <UserData>
                <AcceptEula>true</AcceptEula>
                <ProductKey>
                    <Key><!-- EDU KMS Key --></Key>
                </ProductKey>
            </UserData>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-UnattendedJoin">
            <Identification>
                <JoinDomain>legacyedtech.local</JoinDomain>
                <DomainAdmin>administrator</DomainAdmin>
                <DomainAdminPassword><!-- Password from .env --></DomainAdminPassword>
            </Identification>
        </component>
    </settings>
</unattend>
EOF

# Unmount ISO
echo "Unmounting ISO..."
umount "$MOUNT_DIR"

echo "Windows 11 image prepared at: $EXTRACT_DIR"
echo "Next steps:"
echo "1. Edit autounattend.xml with your domain credentials"
echo "2. Copy to PXE server: /srv/tftp/images/win11/"
echo "3. Update PXE menu to reference this image"
