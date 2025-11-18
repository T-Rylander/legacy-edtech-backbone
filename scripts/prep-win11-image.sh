#!/usr/bin/env bash
#
# prep-win11-image.sh - Prepare Windows 11 EDU Image for PXE Deployment
#
# Phase 2: Windows golden image with post-boot password injection
# Security: No plaintext passwords in autounattend.xml
#
# Usage: sudo ./prep-win11-image.sh /path/to/Win11.iso
#

set -euo pipefail

# Check arguments
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 /path/to/Win11.iso"
    exit 1
fi

ISO_PATH=$1
EXTRACT_DIR="/srv/images/windows/win11-extracted"
MOUNT_DIR="/mnt/win11-iso"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root${NC}"
   exit 1
fi

# Verify ISO exists
if [[ ! -f "$ISO_PATH" ]]; then
    echo -e "${RED}Error: ISO file not found: $ISO_PATH${NC}"
    exit 1
fi

# Load environment for domain info
ENV_FILE="$(dirname "$0")/../.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
fi

echo -e "${GREEN}Preparing Windows 11 EDU image for PXE deployment${NC}"
echo ""

# Install required packages
echo -e "${YELLOW}[1/6] Installing required packages...${NC}"
apt install -y wimtools genisoimage

# Create directories
mkdir -p "$MOUNT_DIR" "$EXTRACT_DIR"

# Mount ISO
echo -e "${YELLOW}[2/6] Mounting ISO...${NC}"
mount -o loop "$ISO_PATH" "$MOUNT_DIR"

# Extract install.wim
echo -e "${YELLOW}[3/6] Extracting install.wim...${NC}"
if [[ -f "$MOUNT_DIR/sources/install.wim" ]]; then
    wimlib-imagex info "$MOUNT_DIR/sources/install.wim"
    echo ""
    read -p "Select image index (usually 1 for Windows 11 EDU): " IMAGE_INDEX
    wimlib-imagex extract "$MOUNT_DIR/sources/install.wim" "$IMAGE_INDEX" "$EXTRACT_DIR"
else
    echo -e "${RED}Error: install.wim not found in ISO${NC}"
    umount "$MOUNT_DIR"
    exit 1
fi

# Create secure autounattend.xml (password deferred to post-install script)
echo -e "${YELLOW}[4/6] Creating autounattend.xml (secure mode)...${NC}"
cat > "$EXTRACT_DIR/autounattend.xml" <<'EOF'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-International-Core-WinPE" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <SetupUILanguage>
                <UILanguage>en-US</UILanguage>
            </SetupUILanguage>
            <InputLocale>en-US</InputLocale>
            <SystemLocale>en-US</SystemLocale>
            <UILanguage>en-US</UILanguage>
            <UserLocale>en-US</UserLocale>
        </component>
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <UserData>
                <AcceptEula>true</AcceptEula>
                <ProductKey>
                    <Key></Key>  <!-- Use KMS or MAK key -->
                </ProductKey>
            </UserData>
            <DiskConfiguration>
                <Disk wcm:action="add">
                    <CreatePartitions>
                        <CreatePartition wcm:action="add">
                            <Order>1</Order>
                            <Type>Primary</Type>
                            <Extend>true</Extend>
                        </CreatePartition>
                    </CreatePartitions>
                    <ModifyPartitions>
                        <ModifyPartition wcm:action="add">
                            <Active>true</Active>
                            <Format>NTFS</Format>
                            <Label>Windows</Label>
                            <Order>1</Order>
                            <PartitionID>1</PartitionID>
                        </ModifyPartition>
                    </ModifyPartitions>
                    <DiskID>0</DiskID>
                    <WillWipeDisk>true</WillWipeDisk>
                </Disk>
            </DiskConfiguration>
            <ImageInstall>
                <OSImage>
                    <InstallFrom>
                        <MetaData wcm:action="add">
                            <Key>/IMAGE/INDEX</Key>
                            <Value>1</Value>
                        </MetaData>
                    </InstallFrom>
                    <InstallTo>
                        <DiskID>0</DiskID>
                        <PartitionID>1</PartitionID>
                    </InstallTo>
                </OSImage>
            </ImageInstall>
        </component>
    </settings>
    <settings pass="specialize">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <ComputerName>Legacy-PC-%RAND:4%</ComputerName>
            <TimeZone>Eastern Standard Time</TimeZone>
        </component>
        <component name="Microsoft-Windows-UnattendedJoin" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <Identification>
                <JoinDomain>${REALM:-LEGACYEDTECH.LOCAL}</JoinDomain>
                <DomainAdmin>administrator</DomainAdmin>
                <!-- Password handled by post-install script for security -->
            </Identification>
        </component>
    </settings>
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <NetworkLocation>Work</NetworkLocation>
                <ProtectYourPC>1</ProtectYourPC>
            </OOBE>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>powershell.exe -ExecutionPolicy Bypass -File C:\Windows\Setup\Scripts\domain-join.ps1</CommandLine>
                    <Order>1</Order>
                    <Description>Post-install domain join with secure credentials</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
EOF

# Create post-install PowerShell script for secure domain join
echo -e "${YELLOW}[5/6] Creating post-install domain join script...${NC}"
mkdir -p "$EXTRACT_DIR/Windows/Setup/Scripts"
cat > "$EXTRACT_DIR/Windows/Setup/Scripts/domain-join.ps1" <<'PSEOF'
# Secure domain join script - reads password from environment
# Deployed via autounattend.xml FirstLogonCommands

$domain = "$ENV:USERDOMAIN"
$password = $ENV:ADMIN_PASSWORD

if ([string]::IsNullOrEmpty($password)) {
    # Fallback: Prompt for password if not in environment
    $securePass = Read-Host "Enter domain admin password" -AsSecureString
} else {
    $securePass = ConvertTo-SecureString $password -AsPlainText -Force
}

$credential = New-Object System.Management.Automation.PSCredential("administrator@$domain", $securePass)

try {
    Add-Computer -DomainName $domain -Credential $credential -Force -Restart
    Write-Host "Domain join successful - rebooting..."
} catch {
    Write-Host "Domain join failed: $_"
    Read-Host "Press Enter to continue..."
}
PSEOF

# Unmount ISO
echo -e "${YELLOW}[6/6] Cleaning up...${NC}"
umount "$MOUNT_DIR"

echo ""
echo -e "${GREEN}==================================${NC}"
echo -e "${GREEN}Windows 11 Image Prepared${NC}"
echo -e "${GREEN}==================================${NC}"
echo ""
echo "Image location: $EXTRACT_DIR"
echo "Autounattend.xml: $EXTRACT_DIR/autounattend.xml"
echo "Post-install script: $EXTRACT_DIR/Windows/Setup/Scripts/domain-join.ps1"
echo ""
echo "Security notes:"
echo "  - Domain admin password NOT stored in XML"
echo "  - Password injected via environment variable at runtime"
echo "  - Post-install script handles secure domain join"
echo ""
echo "Next steps:"
echo "1. Review and customize autounattend.xml for your environment"
echo "2. Add Windows product key if not using KMS"
echo "3. Test deployment on a VM before production"
echo "4. Copy image to /srv/images/windows/ for PXE access"
echo ""
echo "Deploy command:"
echo "  sudo rsync -av $EXTRACT_DIR/ /srv/images/windows/win11/"
echo ""
