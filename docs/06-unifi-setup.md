# UniFi Network Setup

## Cloud Key Initial Setup

Access Cloud Key at `https://192.168.1.5:8443` (default IP if DHCP).

1. Create admin account
2. Configure site name (e.g., "Legacy EdTech HQ")
3. Update firmware to latest stable

## USG-3P Configuration

### DHCP Options for PXE

Navigate to **Settings > Networks > LAN > DHCP**:

- **Option 66** (TFTP Server): `192.168.1.10` (Z390 IP)
- **Option 67** (Boot Filename): `pxelinux.0` or `ipxe.efi`

### Port Forwarding (Optional)

For remote access to services.

## Switch and AP Adoption

Adopt devices via Cloud Key UI. Enable PoE on switch ports for APs.

---

**Next**: [osTicket on Pi →](07-osticket-pi.md)
