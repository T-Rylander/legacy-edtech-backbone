# Troubleshooting

## Common Issues

### Samba AD DC Issues

#### Domain Provision Fails

**Symptoms**: `samba-tool domain provision` exits with error

**Solutions**:
```bash
# Check DNS resolution
host -t A $(hostname) 127.0.0.1

# Verify no conflicting services
netstat -tlnp | grep -E ':(53|88|389|445)'

# Check disk space
df -h /var/lib/samba

# Review logs
journalctl -u samba-ad-dc -n 50
```

#### Clients Can't Join Domain

**Symptoms**: Windows clients fail to join with "Domain not found" error

**Solutions**:
```bash
# Verify DNS SRV records
host -t SRV _ldap._tcp.legacyedtech.local 192.168.1.10

# Test from client
nslookup dc01.legacyedtech.local 192.168.1.10

# Check firewall
sudo ufw status | grep -E '(53|88|389|445)'
```

#### Kerberos Authentication Fails

**Symptoms**: `kinit` fails with "Clock skew too great"

**Solutions**:
```bash
# Sync time (critical for Kerberos)
sudo systemctl restart systemd-timesyncd
timedatectl status

# Verify time difference
date && ssh client-machine date

# Check NTP
timedatectl show-timesync --all
```

### PXE Boot Issues

#### Clients Don't PXE Boot

**Symptoms**: Clients boot to local disk instead of network

**Solutions**:
```bash
# Verify DHCP options on USG
# Option 66: TFTP server IP
# Option 67: Boot filename (pxelinux.0)

# Check dnsmasq status
sudo systemctl status dnsmasq
journalctl -u dnsmasq -n 50

# Test TFTP
sudo apt install tftp-hpa
tftp 192.168.1.10
> get pxelinux.0
> quit
```

#### PXE Menu Doesn't Appear

**Symptoms**: PXE boot starts but hangs or shows blank screen

**Solutions**:
```bash
# Check TFTP root contents
ls -la /srv/tftp/
ls -la /srv/tftp/pxelinux.cfg/

# Verify file permissions
sudo chmod -R 755 /srv/tftp
sudo chown -R nobody:nogroup /srv/tftp

# Test menu config
cat /srv/tftp/pxelinux.cfg/default
```

### RAID Issues

#### RAID Array Degraded

**Symptoms**: `/proc/mdstat` shows degraded array

**Solutions**:
```bash
# Check array status
cat /proc/mdstat
sudo mdadm --detail /dev/md0

# Identify failed disk
sudo mdadm --detail /dev/md0 | grep -A1 "failed"

# Remove failed disk and add replacement
sudo mdadm /dev/md0 --fail /dev/sdb1 --remove /dev/sdb1
# Replace physical disk
sudo mdadm /dev/md0 --add /dev/sdc1

# Monitor rebuild
watch cat /proc/mdstat
```

### Network Issues

#### UniFi Devices Won't Adopt

**Symptoms**: Devices stuck in "Pending Adoption"

**Solutions**:
```bash
# SSH to device
ssh ubnt@192.168.1.x  # Default: ubnt/ubnt

# Set inform URL
set-inform http://192.168.1.5:8080/inform

# Reset if needed
syswrapper.sh restore-default
```

#### DDNS Not Updating

**Symptoms**: No-IP hostname not resolving to current IP

**Solutions**:
```bash
# Check Cloud Key DDNS status
# Settings > Internet > WAN Networks > Dynamic DNS

# Verify external IP
curl -4 ifconfig.me

# Test resolution
host yoursite.ddns.net
```

### Performance Issues

#### High CPU Usage

**Symptoms**: `top` shows high CPU usage on DC

**Solutions**:
```bash
# Identify process
top -o %CPU

# Check Samba load
smbstatus
sudo killall -USR1 smbd  # Gentle process cleanup

# Review AD database
sudo samba-tool dbcheck
```

#### Slow Authentication

**Symptoms**: Domain logins take >30 seconds

**Solutions**:
```bash
# Test auth speed
time wbinfo -a testuser%password

# Check DNS latency
dig dc01.legacyedtech.local @192.168.1.10

# Review network path
mtr 192.168.1.10
```

## Log Locations

```bash
# Samba AD DC
journalctl -u samba-ad-dc
/var/log/samba/log.*

# PXE/dnsmasq
journalctl -u dnsmasq
/var/log/daemon.log

# System
journalctl -xe
dmesg | tail -50

# RAID
dmesg | grep -i raid
/var/log/syslog | grep mdadm
```

## Emergency Procedures

### Restore from Backup

```bash
# See docs/04-backup-dr.md for detailed steps

# Quick restore
sudo systemctl stop samba-ad-dc
cd /srv/backups
sudo tar -xzf samba-YYYYMMDD-HHMMSS.tar.gz
sudo samba-tool domain backup restore --backup-file=*.tar.bz2
sudo systemctl start samba-ad-dc
```

### Force RAID Rebuild

```bash
# Only if array is corrupted
sudo mdadm --stop /dev/md0
sudo mdadm --assemble --force /dev/md0 /dev/sda1 /dev/sdb1
```

### Reset Samba (Nuclear Option)

```bash
# WARNING: Destroys domain! Backup first!
sudo systemctl stop samba-ad-dc
sudo rm -rf /var/lib/samba/*
sudo rm /etc/samba/smb.conf
# Re-run provision-dc.sh
```

## Health Check Commands

```bash
# Quick status overview
sudo systemctl status samba-ad-dc dnsmasq
cat /proc/mdstat
wbinfo -u | wc -l  # User count
sudo ufw status
df -h

# Comprehensive check
sudo ./scripts/health-check.sh
```

## Getting Help

- **GitHub Issues**: [Report bugs](https://github.com/T-Rylander/legacy-edtech-backbone/issues)
- **Documentation**: Review [all guides](index.md)
- **Logs**: Always include relevant logs when asking for help

---

**Still stuck?** Open an issue with:
1. Error messages (full output)
2. Relevant logs (use `journalctl`)
3. System info (`lsb_release -a`, `uname -a`)
4. Steps to reproduce
