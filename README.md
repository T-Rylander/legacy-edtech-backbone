# Legacy EdTech Backbone

**Zero-Touch EdTech Stack on Repurposed Gear**

An open-source IT infrastructure project demonstrating how small MSPs and school IT departments can build enterprise-grade edtech services using repurposed hardware and lean automation.

## 🎯 Project Goals

- **Repurposed Hardware First**: Z390 workstation as AD DC, Raspberry Pi 5 for helpdesk
- **Zero-Touch Deployment**: PXE network boot for mass imaging (50+ devices in an afternoon)
- **Human-Led Resilience**: Validate demand via pilots, automate grunt work, scale without vendor sprawl
- **Open Documentation**: MkDocs site with practical guides, config snippets, and decision rationale

## 🏗️ Architecture Overview

### Three Pillars

1. **Network & Authentication** (Weeks 1-2)
   - Samba AD Domain Controller (Z390, Ubuntu 24.04 LTS)
   - UniFi Cloud Key + USG-3P + switches + APs
   - DDNS for remote access (No-IP)
   - Target: 50-user auth latency <50ms

2. **Imaging & Automation** (Weeks 3-4)
   - PXE proxy server (dnsmasq + iPXE)
   - Golden images (Windows 11 EDU, Ubuntu)
   - Auto-domain join via scripts
   - Target: <30 min deploy time per machine

3. **Monitoring & Scale** (Weeks 5+)
   - osTicket on Raspberry Pi 5
   - Uptime Kuma + Prometheus alerts
   - Fail2ban + UFW hardening
   - Target: 20% print upsell, 5+ LinkedIn leads/quarter

## 🚀 Quick Start

```bash
# Clone the repo
git clone https://github.com/T-Rylander/legacy-edtech-backbone.git
cd legacy-edtech-backbone

# Copy environment template
cp .env.example .env
# Edit .env with your secrets (ADMIN_PASSWORD, REALM, etc.)

# Run DC provisioning script
sudo ./scripts/provision-dc.sh

# View documentation site locally
mkdocs serve
# Open http://localhost:8000
```

## 📚 Documentation

- [Hardware Specs](docs/01-hardware-specs.md) - Z390 BIOS, Pi5 setup, CPU baselines
- [OS Installation](docs/02-os-install.md) - Ubuntu 24.04 + RAID1 setup
- [Samba AD DC](docs/03-samba-provision.md) - Domain provisioning, client joins
- [Backup & DR](docs/04-backup-dr.md) - Offline backups, restore procedures
- [Security & Monitoring](docs/05-security-monitoring.md) - UFW, fail2ban, health checks
- [UniFi Setup](docs/06-unifi-setup.md) - Cloud Key, USG DHCP options
- [osTicket on Pi](docs/07-osticket-pi.md) - Raspberry Pi 5 helpdesk deployment
- [PXE Setup](docs/08-pxe-setup.md) - Network boot server configuration
- [Image Management](docs/09-image-management.md) - WIM capture, golden images
- [Social Playbook](docs/10-social-playbook.md) - LinkedIn/X content templates

Full documentation: [GitHub Pages](https://t-rylander.github.io/legacy-edtech-backbone/)

## 🛠️ Project Structure

```
legacy-edtech-backbone/
├── docs/                      # MkDocs documentation source
├── scripts/                   # Bash automation scripts
│   ├── provision-dc.sh       # Samba AD DC setup
│   ├── raid-setup.sh         # RAID1 mirror configuration
│   ├── prep-win11-image.sh   # Windows 11 image preparation
│   ├── health-check.sh       # System health monitoring
│   ├── backup-samba.sh       # Automated AD backups
│   └── update-pxe-menu.sh    # PXE boot menu generation
├── .github/workflows/        # CI/CD automation
│   └── validate-scripts.yml  # Shellcheck validation
├── mkdocs.yml               # Documentation site config
├── .env.example             # Environment variable template
└── .gitignore              # Git exclusions
```

## 🎓 Who This Is For

- **Small MSPs** pivoting to edtech services
- **School IT departments** with limited budgets
- **Technical users** comfortable with CLI and Linux
- **Systems administrators** looking for hands-on infrastructure examples

## 🤝 Contributing

This project welcomes contributions! See our documentation for:
- Code style guidelines (Google Shell Style Guide)
- Testing requirements (Ubuntu 24.04 LTS)
- Security best practices (secrets management, hardening)

## 📄 License

MIT License - See LICENSE file for details

## 🔗 Connect

- Twitter/X: [@MTRad_vis](https://twitter.com/MTRad_vis)
- LinkedIn: [Share your deployment stories]
- Issues: [Report bugs or request features](https://github.com/T-Rylander/legacy-edtech-backbone/issues)

---

**Built with ❤️ for the edtech community** | Powered by repurposed hardware and open-source tools
