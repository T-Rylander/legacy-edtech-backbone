#!/usr/bin/env bash
#
# raid-setup.sh - RAID1 Configuration for Samba Storage
#
# Usage: sudo ./raid-setup.sh /dev/sda /dev/sdb
#
# WARNING: This will destroy all data on the specified drives!
#

set -euo pipefail

# Check arguments
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 /dev/sdX /dev/sdY"
    echo "Example: $0 /dev/sda /dev/sdb"
    exit 1
fi

DISK1=$1
DISK2=$2

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root"
   exit 1
fi

# Verify disks exist
if [[ ! -b "$DISK1" ]] || [[ ! -b "$DISK2" ]]; then
    echo "Error: One or both disks do not exist"
    exit 1
fi

# Confirmation
echo "WARNING: This will erase all data on $DISK1 and $DISK2"
echo "Creating RAID1 array for Samba storage"
read -p "Continue? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then
    echo "Aborted"
    exit 1
fi

# Install mdadm
echo "Installing mdadm..."
apt update && apt install -y mdadm

# Create partitions
echo "Creating partitions..."
parted -s "$DISK1" mklabel gpt
parted -s "$DISK1" mkpart primary 0% 100%
parted -s "$DISK1" set 1 raid on

parted -s "$DISK2" mklabel gpt
parted -s "$DISK2" mkpart primary 0% 100%
parted -s "$DISK2" set 1 raid on

# Create RAID1 array
echo "Creating RAID1 array..."
mdadm --create /dev/md0 --level=1 --raid-devices=2 "${DISK1}1" "${DISK2}1"

# Wait for array to initialize
echo "Waiting for RAID to sync (this may take a while)..."
sleep 5

# Format as ext4
echo "Formatting as ext4..."
mkfs.ext4 -F /dev/md0

# Create mount point
mkdir -p /srv/samba

# Mount RAID array
echo "Mounting RAID array..."
mount /dev/md0 /srv/samba

# Add to fstab
echo "Adding to /etc/fstab..."
UUID=$(blkid -s UUID -o value /dev/md0)
echo "UUID=$UUID /srv/samba ext4 defaults 0 2" >> /etc/fstab

# Save RAID config
echo "Saving RAID configuration..."
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
update-initramfs -u

echo "RAID1 setup complete!"
echo "Array: /dev/md0"
echo "Mount point: /srv/samba"
echo ""
echo "Check status with: cat /proc/mdstat"
