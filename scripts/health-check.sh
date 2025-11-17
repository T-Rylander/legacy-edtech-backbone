#!/usr/bin/env bash
#
# health-check.sh - Samba AD DC Health Monitoring
#
# Usage: ./health-check.sh
#
# Checks Samba AD DC health and sends alerts if issues detected.
# Can be run via cron or monitoring system.
#

set -euo pipefail

# Configuration
ALERT_EMAIL="${ALERT_EMAIL:-admin@localhost}"
HOSTNAME=$(hostname)
EXIT_CODE=0

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Check function
check() {
    local name=$1
    local command=$2
    
    echo -n "Checking $name... "
    
    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
        return 0
    else
        echo -e "${RED}FAILED${NC}"
        EXIT_CODE=1
        return 1
    fi
}

echo "Samba AD DC Health Check - $(date)"
echo "========================================"

# Check if Samba is running
check "Samba service" "systemctl is-active --quiet samba-ad-dc"

# Check DNS resolution
check "DNS (forward lookup)" "host -t A $HOSTNAME 127.0.0.1"

# Check Kerberos
check "Kerberos" "echo 'password' | kinit -V administrator 2>&1 | grep -q 'Ticket cache'"

# Check LDAP
check "LDAP connectivity" "ldapsearch -H ldap://localhost -x -b '' -s base"

# Check database integrity
check "Database integrity" "sudo samba-tool dbcheck --cross-ncs"

# Check replication (if secondary DC exists)
# check "AD Replication" "sudo samba-tool drs showrepl"

# Check disk space
DISK_USAGE=$(df -h /var/lib/samba | awk 'NR==2 {print $5}' | sed 's/%//')
echo -n "Checking disk space... "
if [[ $DISK_USAGE -lt 90 ]]; then
    echo -e "${GREEN}OK (${DISK_USAGE}% used)${NC}"
else
    echo -e "${RED}WARNING (${DISK_USAGE}% used)${NC}"
    EXIT_CODE=1
fi

# Check memory usage
MEM_USAGE=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
echo -n "Checking memory usage... "
if [[ $MEM_USAGE -lt 90 ]]; then
    echo -e "${GREEN}OK (${MEM_USAGE}% used)${NC}"
else
    echo -e "${YELLOW}WARNING (${MEM_USAGE}% used)${NC}"
fi

echo "========================================"

if [[ $EXIT_CODE -eq 0 ]]; then
    echo -e "${GREEN}All checks passed${NC}"
else
    echo -e "${RED}Some checks failed - review output above${NC}"
    
    # Send alert email (if configured)
    if command -v mail &>/dev/null && [[ -n "$ALERT_EMAIL" ]]; then
        echo "Samba AD DC health check failed on $HOSTNAME at $(date)" | \
            mail -s "ALERT: Samba Health Check Failed" "$ALERT_EMAIL"
    fi
fi

exit $EXIT_CODE
