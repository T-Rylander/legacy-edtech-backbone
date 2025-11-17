# Backup & Disaster Recovery

## Overview

Samba AD requires special backup procedures since it uses an internal LDB database. This guide covers offline backups, restore procedures, and disaster recovery planning.

## Automated Backup Script

Use the provided script for daily backups:

```bash
# Run backup manually
sudo ./scripts/backup-samba.sh

# Schedule with cron (daily at 2 AM)
sudo crontab -e
# Add: 0 2 * * * /path/to/scripts/backup-samba.sh
```

## Manual Backup Procedures

### Offline Backup (Recommended)

```bash
# Stop Samba services
sudo systemctl stop samba-ad-dc

# Create backup directory
BACKUP_DIR="/srv/backups/samba-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p $BACKUP_DIR

# Backup Samba database
sudo samba-tool domain backup offline \
  --targetdir=$BACKUP_DIR

# Backup configuration
sudo cp -r /etc/samba $BACKUP_DIR/etc-samba
sudo cp /etc/krb5.conf $BACKUP_DIR/

# Restart Samba
sudo systemctl start samba-ad-dc

# Compress backup
sudo tar -czf ${BACKUP_DIR}.tar.gz -C /srv/backups $(basename $BACKUP_DIR)
sudo rm -rf $BACKUP_DIR

# Verify archive
tar -tzf ${BACKUP_DIR}.tar.gz | head
```

### Online Backup (Alternative)

For minimal downtime:

```bash
# Create backup directory
BACKUP_DIR="/srv/backups/samba-online-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p $BACKUP_DIR

# Online backup (service stays running)
sudo samba-tool domain backup online \
  --targetdir=$BACKUP_DIR \
  --server=localhost

# Compress and verify
sudo tar -czf ${BACKUP_DIR}.tar.gz -C /srv/backups $(basename $BACKUP_DIR)
```

## Restore Procedures

### Full Restore

```bash
# Extract backup
cd /srv/backups
sudo tar -xzf samba-20251117-020000.tar.gz

# Stop Samba
sudo systemctl stop samba-ad-dc

# Remove old database (BACKUP FIRST!)
sudo mv /var/lib/samba /var/lib/samba.old

# Restore from backup
cd samba-20251117-020000
sudo samba-tool domain backup restore \
  --backup-file=*.tar.bz2 \
  --newservername=dc01 \
  --targetdir=/var/lib/samba

# Restore config files
sudo cp -r etc-samba/* /etc/samba/
sudo cp krb5.conf /etc/krb5.conf

# Fix permissions
sudo chown -R root:root /var/lib/samba

# Start Samba
sudo systemctl start samba-ad-dc

# Verify
sudo samba-tool dbcheck
wbinfo -u
```

## Disaster Recovery Plan

### Scenario 1: Hardware Failure

**Symptoms**: Z390 won't boot, disk failure

**Recovery**:
1. Replace failed hardware
2. Reinstall Ubuntu 24.04 LTS
3. Configure same hostname and IP
4. Restore from most recent backup
5. Verify DNS and Kerberos functionality
6. Rejoin any clients that lost trust

**RTO (Recovery Time Objective)**: 2-4 hours

### Scenario 2: Accidental Deletion

**Symptoms**: User/OU deleted by mistake

**Recovery**:
```bash
# For recent deletions, check recycle bin
sudo samba-tool domain tombstones expunge --help

# Or restore specific object from backup
# (Extract backup, mount read-only, query with ldapsearch)
```

### Scenario 3: Corruption

**Symptoms**: Samba won't start, database errors

**Recovery**:
```bash
# Check database integrity
sudo samba-tool dbcheck

# Attempt repair
sudo samba-tool dbcheck --fix

# If repair fails, restore from backup
```

## Backup Storage

### Local Storage

```bash
# Create backup directory
sudo mkdir -p /srv/backups
sudo chmod 700 /srv/backups

# Retention policy: keep 30 days
find /srv/backups -name "samba-*.tar.gz" -mtime +30 -delete
```

### Remote Storage (Recommended)

```bash
# Option 1: rsync to remote server
rsync -avz --delete /srv/backups/ \
  backup-server:/backups/dc01/

# Option 2: S3-compatible storage (if available)
# Install rclone
sudo apt install -y rclone

# Configure remote
rclone config

# Sync backups
rclone sync /srv/backups/ remote:dc01-backups/
```

## Testing Backups

### Monthly Restore Test

```bash
# Test restore to temporary location
TEST_DIR="/tmp/samba-restore-test-$(date +%Y%m%d)"
mkdir -p $TEST_DIR

# Extract and verify
tar -xzf /srv/backups/samba-latest.tar.gz -C $TEST_DIR

# Check contents
ls -lah $TEST_DIR

# Verify tar file integrity
tar -tzf /srv/backups/samba-latest.tar.gz > /dev/null
echo "Backup integrity: OK"

# Cleanup
rm -rf $TEST_DIR
```

## Monitoring

### Backup Health Check

```bash
# Check last backup age
LAST_BACKUP=$(ls -t /srv/backups/samba-*.tar.gz | head -1)
BACKUP_AGE=$(($(date +%s) - $(stat -c %Y "$LAST_BACKUP")))

if [ $BACKUP_AGE -gt 86400 ]; then
  echo "WARNING: Last backup is $(($BACKUP_AGE / 3600)) hours old"
fi
```

### Backup Size Monitoring

```bash
# Check backup sizes
du -sh /srv/backups/samba-*.tar.gz | sort -h

# Alert if backup size changes significantly
# (May indicate database growth or corruption)
```

## Documentation Checklist

- [ ] Backup script tested and scheduled
- [ ] Restore procedure verified in test environment
- [ ] Backup retention policy documented
- [ ] Remote backup destination configured
- [ ] Team trained on restore procedures
- [ ] Administrator password documented (secure location)
- [ ] Monthly restore test scheduled

---

**Next Step**: [Security & Monitoring →](05-security-monitoring.md)
