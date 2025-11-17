# Hardware Specifications

## Overview

This project uses repurposed consumer and prosumer hardware to build an enterprise-grade edtech stack. Total hardware cost for a complete setup: **~$500-800** (using refurbished gear).

## Core Components

### Z390 Domain Controller & PXE Server

**Primary Role**: Samba AD Domain Controller, PXE network boot server

| Component | Specification | Notes |
|-----------|--------------|-------|
| **Motherboard** | Z390 chipset | Must support RAID if using hardware RAID |
| **CPU** | Intel Core i5-9400 or better | 6+ cores recommended for multi-tenant loads |
| **RAM** | 16GB DDR4 (32GB recommended) | ECC not required but preferred |
| **Storage** | 2x 500GB SSD (RAID1) | OS + Samba database |
| **Storage** | 1TB+ HDD/SSD | PXE images and backups |
| **NIC** | Gigabit Ethernet | Dual NICs recommended for PXE isolation |
| **OS** | Ubuntu 24.04 LTS Server | Use latest point release |

**BIOS Configuration**:
```bash
# Enable XMP for RAM stability
# Disable Secure Boot (optional, for broader PXE compatibility)
# Enable AHCI for storage
# Set boot order: SSD first
```

**Baseline Performance** (verify with `lscpu` and `free -h`):
```bash
# Expected output:
Architecture:            x86_64
CPU(s):                  6
Thread(s) per core:      1
Model name:              Intel(R) Core(TM) i5-9400 CPU @ 2.90GHz
MemTotal:                16GB
```

### Raspberry Pi 5 (osTicket Helpdesk)

**Primary Role**: osTicket web application + MariaDB

| Component | Specification | Notes |
|-----------|--------------|-------|
| **Model** | Raspberry Pi 5 (8GB RAM) | 4GB minimum, 8GB recommended |
| **Storage** | 128GB+ microSD (Class 10/A2) | Or NVMe via HAT for production |
| **Power** | Official 27W USB-C PSU | Crucial for stability under load |
| **Cooling** | Active cooler with fan | Required for sustained PHP/MySQL |
| **Case** | Ventilated case | Airflow essential for Pi 5 thermals |
| **OS** | Raspberry Pi OS Lite (64-bit) | Or Ubuntu Server 24.04 ARM64 |

**Thermal Monitoring**:
```bash
# Check CPU temp (should stay <70°C under load)
vcgencmd measure_temp

# Continuous monitoring
watch -n 2 vcgencmd measure_temp
```

### UniFi Network Infrastructure

**Primary Role**: Managed LAN/WLAN with VLAN support

| Device | Model | Quantity | Purpose |
|--------|-------|----------|---------|
| **Controller** | UniFi Cloud Key Gen2 Plus | 1 | Network management + NVR |
| **Gateway** | UniFi Security Gateway (USG-3P) | 1 | Routing, firewall, DHCP |
| **Switch** | UniFi Switch 8 (60W PoE) | 1+ | Layer 2 switching, PoE for APs |
| **Access Point** | UniFi AP AC Lite | 2-4 | Dual-band WiFi coverage |

**Firmware Versions** (as of Nov 2025):
- Cloud Key: 2.4.27+
- USG: 4.4.57+
- Switch: 6.5.59+
- AP: 6.5.55+

!!! warning "Update Before Production"
    Always update UniFi devices to latest stable firmware before provisioning. Use Cloud Key UI or SSH with `upgrade` command.

## Optional Components

### Secondary Domain Controller (Future)

For high-availability in production:

- Raspberry Pi 5 (8GB) as read-only DC
- Syncs from Z390 primary every 15 minutes
- Configured post-pilot validation

### Monitoring Server (Optional)

Dedicated device for Prometheus + Grafana:

- Raspberry Pi 4 (4GB) or spare x86 machine
- 64GB+ storage for time-series data
- Connects to all nodes for metrics scraping

## Network Topology

```
                  ┌─────────────┐
                  │  Internet   │
                  └──────┬──────┘
                         │
                  ┌──────▼──────┐
                  │ USG-3P      │◄─── DDNS (No-IP)
                  │ 192.168.1.1 │
                  └──────┬──────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌────▼────┐
    │ Z390 DC │    │ Pi5       │   │ Cloud   │
    │ .1.10   │    │ osTicket  │   │ Key     │
    │         │    │ .1.20     │   │ .1.5    │
    └────┬────┘    └───────────┘   └─────────┘
         │
    ┌────▼────────────┐
    │ US-8-60W Switch │
    │ (PoE)           │
    └────┬───────┬────┘
         │       │
    ┌────▼────┐ ┌▼────────┐
    │ UAP-AC  │ │ UAP-AC  │
    │ Lite #1 │ │ Lite #2 │
    └─────────┘ └─────────┘
         │           │
      [Clients] [Clients]
```

## Purchase Recommendations

### New vs. Refurbished

| Component | Buy New | Buy Refurb | Notes |
|-----------|---------|------------|-------|
| Z390 Board | ❌ | ✅ | eBay/Amazon ~$150-200 |
| RAM | ❌ | ✅ | Test with memtest86+ |
| SSDs | ✅ | ❌ | Wear matters for databases |
| Pi 5 | ✅ | ❌ | Current gen, wide availability |
| UniFi Gear | ❌ | ✅ | Ubiquiti refurb store or eBay |

### Estimated Costs (Nov 2025)

- **Z390 Bundle**: $300 (board + CPU + RAM + case, refurb)
- **Storage**: $120 (2x 500GB SSD + 1TB HDD)
- **Pi 5 Kit**: $120 (8GB + case + cooler + power)
- **UniFi Core**: $400 (Cloud Key + USG + 1 switch + 2 APs, refurb)
- **Cables/Misc**: $60
- **Total**: ~$1,000 (or $600 if you already have Z390/UniFi gear)

## Pre-Deployment Checklist

Before proceeding to OS installation:

- [ ] Z390 boots to BIOS, RAM detected, storage visible
- [ ] Pi 5 boots with official PSU, temps <60°C idle
- [ ] UniFi devices adopt to Cloud Key (reset if needed)
- [ ] Gigabit Ethernet verified between all nodes (`iperf3` test)
- [ ] Spare cables, power strips, and KVM switch available

---

**Next Step**: [OS Installation →](02-os-install.md)
