# osTicket on Raspberry Pi 5

## Overview

Deploy osTicket helpdesk on Raspberry Pi 5 for support ticket management.

## Quick Start

See the [osTicket Pi Demo repo](https://github.com/T-Rylander/osticket-pi-demo) for complete Docker-based deployment with:

- ARM64-compatible osTicket build
- MariaDB 11.2 backend
- AI-powered ticket classification (DistilBERT)
- systemd integration
- Production-ready security

## Basic Setup

```bash
# Clone osTicket Pi repo
git clone https://github.com/T-Rylander/osticket-pi-demo.git
cd osticket-pi-demo

# Configure environment
cp .env.example .env
nano .env

# Deploy with Docker Compose
docker compose up -d

# Access at http://192.168.1.20:8080
```

---

**Next**: [PXE Setup →](08-pxe-setup.md)
