# Security & Monitoring

## Firewall Configuration (UFW)

```bash
# Install UFW
sudo apt install -y ufw

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH
sudo ufw allow 22/tcp

# Allow Samba AD DC ports
sudo ufw allow 53,88,135,137,138,139,389,445,464,636,3268,3269/tcp
sudo ufw allow 53,88,137,138,389,464/udp

# Enable firewall
sudo ufw enable
```

## Fail2ban Configuration

```bash
# Install fail2ban
sudo apt install -y fail2ban

# Create jail for SSH
sudo tee /etc/fail2ban/jail.local << EOF
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

# Restart fail2ban
sudo systemctl restart fail2ban

# Check status
sudo fail2ban-client status sshd
```

## Health Check Script

See `scripts/health-check.sh` for automated monitoring.

---

**Next**: [UniFi Setup →](06-unifi-setup.md)
