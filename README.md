# Legacy EdTech Backbone

**Zero-Touch IT Stack for EdTech-Print Bundles**

Samba AD Domain Controller + PXE imaging on repurposed hardware. Built for operational reality—stable auth for print bundles, zero-touch imaging for lab rollouts.

## 🎯 Project Goals

- **Repurposed Hardware**: Z390 workstation as AD DC, Raspberry Pi 5 for osTicket
- **Zero-Touch Deployment**: PXE network boot for mass imaging (30-min deploys, auto-domain join)
- **Operational Resilience**: RAID1-backed storage, automated backups, health monitoring
- **Modular Documentation**: MkDocs site with practical guides and tested configurations

## 🏗️ Architecture Overview

### Three Pillars

**Pillar 1: Foundation - Network & Auth Core** (~80% Complete)
- Samba AD Domain Controller (Z390, Ubuntu 24.04 LTS, RFC2307 POSIX)
- UniFi infrastructure (Cloud Key, USG-3P, switches, APs with DDNS)
- Pi5 osTicket for lightweight ticketing
- **Goal**: <50ms auth latency, client joins tested

**Pillar 2: Automation - Imaging Workflows**
- PXE proxy on Z390 (dnsmasq/iPXE, NFS-locked images)
- Golden WIMs (Win11 EDU first, Ubuntu preseed second)
- USG DHCP options (66/67) for chainload
- **Goal**: 30-min deploys, 80% auto-success rate

**Pillar 3: Resilience & Scale**
- RAID1 for Samba storage, cron'd backups
- UFW hardening, fail2ban, health scripts
- Future: Multi-DC (Pi5 secondary), IaC (Ansible port)
- **Goal**: SPOF alerts, easy disaster recovery

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/T-Rylander/legacy-edtech-backbone.git
cd legacy-edtech-backbone

# Populate secrets
cp .env.example .env && vim .env
# Set: REALM, DOMAIN, ADMIN_PASSWORD, DNS_FORWARDER, DC_IP, IMAGES_DISK

# Provision DC (includes optional PXE flag)
sudo ./scripts/provision-dc.sh

# Populate Ubuntu ISO for NFS boot (optional helper)
sudo ./scripts/fix-pxe-loop.sh   # or pass a local ISO path

# Preview documentation
mkdocs serve  # http://localhost:8000
```

**Phases**: [Foundation](docs/01-hardware-specs.md) → [Automation](docs/08-pxe-setup.md) → [Resilience](docs/04-backup-dr.md)

## 📚 Documentation

**Foundation (Pillar 1)**
- [Hardware Specs](docs/01-hardware-specs.md) - Z390 BIOS, Pi5 setup, CPU baselines
- [OS Installation](docs/02-os-install.md) - Ubuntu 24.04 + RAID1 setup
- [Samba AD DC](docs/03-samba-provision.md) - Domain provisioning, client joins
- [UniFi Setup](docs/06-unifi-setup.md) - Cloud Key, USG DHCP options
- [osTicket on Pi](docs/07-osticket-pi.md) - Raspberry Pi 5 helpdesk

**Automation (Pillar 2)**
- [PXE Setup](docs/08-pxe-setup.md) - iPXE + nginx + NFS (proxy DHCP)
- [Image Management](docs/09-image-management.md) - WIM capture, golden images

**Resilience (Pillar 3)**
- [Backup & DR](docs/04-backup-dr.md) - Offline backups, restore procedures
- [Security & Monitoring](docs/05-security-monitoring.md) - UFW, fail2ban, health checks
- [Troubleshooting](docs/10-troubleshooting.md) - Common issues, emergency procedures

Full documentation: [GitHub Pages](https://t-rylander.github.io/legacy-edtech-backbone/)

## 🛠️ Project Structure

```
legacy-edtech-backbone/
├── docs/                      # MkDocs documentation source
├── scripts/                   # Bash automation scripts
│   ├── provision-dc.sh       # Samba AD DC setup
│   ├── fix-pxe-loop.sh       # Populate Ubuntu ISO, regenerate iPXE, validate
│   ├── raid-setup.sh         # RAID1 mirror configuration
│   ├── prep-win11-image.sh   # Windows 11 image preparation
│   ├── health-check.sh       # System health monitoring
│   ├── backup-samba.sh       # Automated AD backups
│   └── update-pxe-menu.sh    # PXE boot menu generation (legacy)
├── .github/workflows/        # CI/CD automation
│   └── validate-scripts.yml  # Shellcheck validation
├── mkdocs.yml               # Documentation site config
├── .env.example             # Environment variable template
└── .gitignore              # Git exclusions
```

## 🎓 Who This Is For

- **School IT departments** needing zero-touch lab imaging
- **Small MSPs** offering bundled edtech + print services
- **Systems administrators** building lean AD/PXE infrastructure
- **Technical learners** wanting hands-on domain controller experience

## 🤝 Contributing

This project welcomes contributions! See our documentation for:
- Code style guidelines (Google Shell Style Guide)
- Testing requirements (Ubuntu 24.04 LTS)
- Security best practices (secrets management, hardening)

## 📄 License

MIT License - See LICENSE file for details

## 🔗 Issues & Questions

- **Bugs/Features**: [GitHub Issues](https://github.com/T-Rylander/legacy-edtech-backbone/issues)
- **Documentation**: [All Guides](https://t-rylander.github.io/legacy-edtech-backbone/)
- **Contributions**: See [CONTRIBUTING.md](CONTRIBUTING.md)

---

**Status**: Foundation (Pillar 1) ~80% complete | PXE scripting in progress
