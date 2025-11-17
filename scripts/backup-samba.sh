#!/usr/bin/env bash
#
# backup-samba.sh - Automated Samba AD DC Backup
#
# Usage: sudo ./backup-samba.sh
#
# This script performs an offline backup of the Samba AD database
# and compresses it for storage. Schedule with cron for daily backups.
#

set -euo pipefail

# Configuration
BACKUP_ROOT="/srv/backups"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-30}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="$BACKUP_ROOT/samba-$TIMESTAMP"

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo "Error: This script must be run as root"
   exit 1
fi

# Create backup directory
mkdir -p "$BACKUP_DIR"

echo "Starting Samba AD DC backup..."
echo "Backup directory: $BACKUP_DIR"

# Stop Samba services
echo "Stopping Samba services..."
systemctl stop samba-ad-dc

# Perform offline backup
echo "Creating offline backup..."
samba-tool domain backup offline --targetdir="$BACKUP_DIR"

# Backup configuration files
echo "Backing up configuration..."
mkdir -p "$BACKUP_DIR/etc-samba"
cp -r /etc/samba/* "$BACKUP_DIR/etc-samba/"
cp /etc/krb5.conf "$BACKUP_DIR/"

# Restart Samba
echo "Restarting Samba services..."
systemctl start samba-ad-dc

# Compress backup
echo "Compressing backup..."
tar -czf "${BACKUP_DIR}.tar.gz" -C "$BACKUP_ROOT" "$(basename "$BACKUP_DIR")"

# Remove uncompressed directory
rm -rf "$BACKUP_DIR"

# Calculate backup size
BACKUP_SIZE=$(du -h "${BACKUP_DIR}.tar.gz" | cut -f1)

echo "Backup complete: ${BACKUP_DIR}.tar.gz ($BACKUP_SIZE)"

# Cleanup old backups
echo "Cleaning up backups older than $RETENTION_DAYS days..."
find "$BACKUP_ROOT" -name "samba-*.tar.gz" -mtime +"$RETENTION_DAYS" -delete

echo "Backup process finished successfully"
