# Image Management

## Windows 11 EDU Image Preparation

### Download Windows 11 ISO

```bash
# Use Microsoft Media Creation Tool or direct download
# Place ISO in /srv/images/
```

### Extract and Customize WIM

```bash
# Install DISM tools
sudo apt install -y wimtools

# Mount ISO
sudo mkdir -p /mnt/win11-iso
sudo mount -o loop /srv/images/Win11_EDU.iso /mnt/win11-iso

# Extract install.wim
sudo mkdir -p /srv/images/win11-extracted
sudo wimlib-imagex extract /mnt/win11-iso/sources/install.wim 1 /srv/images/win11-extracted

# Create autounattend.xml for domain join
# (See scripts/prep-win11-image.sh for full automation)
```

## Ubuntu Golden Image

### Create Preseed Configuration

```bash
# Create preseed for automated Ubuntu install
sudo tee /srv/images/ubuntu-preseed.cfg << 'EOF'
d-i auto-install/enable boolean true
d-i netcfg/choose_interface select auto
d-i netcfg/get_hostname string ubuntu-client
d-i netcfg/get_domain string legacyedtech.local
d-i passwd/user-fullname string Legacy User
d-i passwd/username string legacyuser
d-i passwd/user-password password changeme
d-i passwd/user-password-again password changeme
tasksel tasksel/first multiselect ubuntu-desktop
d-i finish-install/reboot_in_progress note
EOF
```

---

**Next**: [Social Playbook →](10-social-playbook.md)
