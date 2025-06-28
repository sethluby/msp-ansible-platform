#!/bin/bash
# MSP Client Bootstrap Script - Bastion Host Architecture
# Prepares an Alpine Linux bastion host for WireGuard VPN connectivity to MSP infrastructure
# Usage: ./bootstrap-bastion-host.sh <client_name> <msp_hub_endpoint> <client_subnet> <msp_public_key>

set -euo pipefail

# Configuration
CLIENT_NAME="${1:-}"
MSP_HUB_ENDPOINT="${2:-}"
CLIENT_SUBNET="${3:-}"
MSP_PUBLIC_KEY="${4:-}"
SCRIPT_LOG="/tmp/msp-bastion-bootstrap-$(date +%Y%m%d-%H%M%S).log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$SCRIPT_LOG"
}

# Error handling
error_exit() {
    log "ERROR: $1"
    exit 1
}

# Validate input parameters
validate_parameters() {
    log "Validating bastion bootstrap parameters..."
    
    [[ -z "$CLIENT_NAME" ]] && error_exit "Client name is required as first parameter"
    [[ -z "$MSP_HUB_ENDPOINT" ]] && error_exit "MSP hub endpoint is required as second parameter"
    [[ -z "$CLIENT_SUBNET" ]] && error_exit "Client subnet is required as third parameter (e.g., 10.100.1.1/28)"
    [[ -z "$MSP_PUBLIC_KEY" ]] && error_exit "MSP public key is required as fourth parameter"
    
    # Validate client name format
    if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
        error_exit "Client name must contain only alphanumeric characters and underscores"
    fi
    
    # Validate subnet format
    if [[ ! "$CLIENT_SUBNET" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$ ]]; then
        error_exit "Client subnet must be in CIDR format (e.g., 10.100.1.1/28)"
    fi
    
    log "Parameters validated successfully"
}

# Detect and verify Alpine Linux
detect_os() {
    log "Detecting operating system..."
    
    if [[ ! -f /etc/alpine-release ]]; then
        error_exit "This script is designed for Alpine Linux only"
    fi
    
    ALPINE_VERSION=$(cat /etc/alpine-release)
    log "Detected Alpine Linux version: $ALPINE_VERSION"
    
    # Check if running on minimal resources
    MEMORY_MB=$(free -m | awk 'NR==2{print $2}')
    if [[ $MEMORY_MB -lt 256 ]]; then
        log "WARNING: Low memory detected ($MEMORY_MB MB). Minimum 256MB recommended for bastion host."
    fi
}

# Update system and install packages
install_packages() {
    log "Updating Alpine packages and installing requirements..."
    
    # Update package index
    apk update || error_exit "Failed to update package index"
    
    # Upgrade existing packages
    apk upgrade || error_exit "Failed to upgrade packages"
    
    # Install required packages
    apk add --no-cache \
        wireguard-tools \
        openssh \
        openssh-server \
        python3 \
        py3-pip \
        ansible-core \
        curl \
        htop \
        nano \
        bash \
        iptables \
        iptables-openrc \
        openrc \
        dcron \
        logrotate || error_exit "Failed to install required packages"
    
    log "Package installation completed"
}

# Configure WireGuard
configure_wireguard() {
    log "Configuring WireGuard VPN..."
    
    # Generate WireGuard keys
    wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
    chmod 600 /etc/wireguard/private.key
    chmod 644 /etc/wireguard/public.key
    
    PRIVATE_KEY=$(cat /etc/wireguard/private.key)
    PUBLIC_KEY=$(cat /etc/wireguard/public.key)
    
    log "Generated WireGuard key pair"
    log "Public key (add this to MSP hub): $PUBLIC_KEY"
    
    # Create WireGuard configuration
    cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $CLIENT_SUBNET
DNS = 8.8.8.8, 1.1.1.1
PostUp = echo "WireGuard started for $CLIENT_NAME" | logger -t MSP-VPN
PostDown = echo "WireGuard stopped for $CLIENT_NAME" | logger -t MSP-VPN
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT 2>/dev/null || true; iptables -D FORWARD -o wg0 -j ACCEPT 2>/dev/null || true

[Peer]
PublicKey = $MSP_PUBLIC_KEY
AllowedIPs = 10.100.0.0/24
Endpoint = $MSP_HUB_ENDPOINT:51820
PersistentKeepalive = 25
EOF
    
    chmod 600 /etc/wireguard/wg0.conf
    log "WireGuard configuration created"
}

# Configure SSH server
configure_ssh() {
    log "Configuring SSH server for MSP access..."
    
    # Generate SSH host keys if they don't exist
    ssh-keygen -A
    
    # Create SSH directory for MSP keys
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    # Create placeholder for MSP SSH key (to be replaced by MSP)
    cat > /root/.ssh/authorized_keys << EOF
# MSP Management Key - Replace with actual key during deployment
# ssh-rsa AAAAB3NzaC1yc2E... msp-management-key
EOF
    chmod 600 /root/.ssh/authorized_keys
    
    # Configure SSH daemon
    cat > /etc/ssh/sshd_config << EOF
# MSP Bastion Host SSH Configuration
Port 22
Protocol 2
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Security settings
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 30

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes

# Logging
LogLevel INFO
SyslogFacility AUTH

# Access restrictions
AllowUsers root
DenyGroups wheel

# Disable unused features
X11Forwarding no
PrintMotd no
PrintLastLog yes
Banner /etc/ssh/banner

# Subsystem
Subsystem sftp /usr/lib/ssh/sftp-server
EOF
    
    # Create SSH banner
    cat > /etc/ssh/banner << EOF

WARNING: MSP Bastion Host for $CLIENT_NAME
===========================================

This system is restricted to authorized MSP personnel only.
All activities are monitored and logged.
Unauthorized access is prohibited and will be prosecuted.

Client: $CLIENT_NAME
Role: WireGuard VPN Bastion Host
Architecture: Bastion Host with VPN Connectivity

EOF
    
    log "SSH server configured"
}

# Configure firewall
configure_firewall() {
    log "Configuring iptables firewall..."
    
    # Create firewall rules
    cat > /etc/iptables/rules-save << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established and related connections
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
-A INPUT -p tcp --dport 22 -j ACCEPT

# Allow WireGuard
-A INPUT -p udp --dport 51820 -j ACCEPT

# Allow WireGuard forwarding
-A FORWARD -i wg0 -j ACCEPT
-A FORWARD -o wg0 -j ACCEPT

# Allow ICMP (ping)
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT

COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:INPUT ACCEPT [0:0]
:OUTPUT ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]
COMMIT
EOF
    
    # Load firewall rules
    iptables-restore < /etc/iptables/rules-save
    
    # Enable iptables service
    rc-update add iptables
    
    log "Firewall configured and enabled"
}

# Create monitoring scripts
create_monitoring() {
    log "Creating monitoring and health check scripts..."
    
    mkdir -p /opt/msp/scripts
    
    # WireGuard monitoring script
    cat > /opt/msp/scripts/wireguard-monitor.sh << 'EOFSCRIPT'
#!/bin/bash
# WireGuard tunnel monitoring script

CLIENT_NAME="$1"
LOG_FILE="/var/log/msp-bastion.log"

# Check WireGuard interface status
if wg show wg0 >/dev/null 2>&1; then
    PEER_COUNT=$(wg show wg0 peers | wc -l)
    LATEST_HANDSHAKE=$(wg show wg0 latest-handshakes | awk '{print $2}')
    CURRENT_TIME=$(date +%s)
    
    if [[ -n "$LATEST_HANDSHAKE" ]] && [[ $LATEST_HANDSHAKE -gt 0 ]]; then
        TIME_DIFF=$((CURRENT_TIME - LATEST_HANDSHAKE))
        if [[ $TIME_DIFF -lt 300 ]]; then
            STATUS="CONNECTED"
        else
            STATUS="STALE"
        fi
    else
        STATUS="NO_HANDSHAKE"
    fi
    
    echo "$(date): WireGuard tunnel: $STATUS | Peers: $PEER_COUNT | Last handshake: ${TIME_DIFF:-unknown}s ago" >> "$LOG_FILE"
else
    echo "$(date): WireGuard tunnel: DOWN" >> "$LOG_FILE"
    # Attempt to restart WireGuard
    wg-quick up wg0 2>/dev/null
fi

# Check connectivity to MSP hub
if timeout 5 ping -c 1 10.100.0.1 >/dev/null 2>&1; then
    echo "$(date): MSP hub connectivity: OK" >> "$LOG_FILE"
else
    echo "$(date): MSP hub connectivity: FAILED" >> "$LOG_FILE"
fi

# Log system stats
echo "$(date): Load: $(uptime | awk '{print $NF}') Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}') Disk: $(df / | awk 'NR==2 {print $5}')" >> "$LOG_FILE"
EOFSCRIPT

    chmod +x /opt/msp/scripts/wireguard-monitor.sh
    
    # System health monitoring script
    cat > /opt/msp/scripts/system-health.sh << 'EOFSCRIPT'
#!/bin/bash
# System health monitoring for bastion host

CLIENT_NAME="$1"
LOG_FILE="/var/log/msp-bastion.log"

# Check SSH daemon
if pgrep -x sshd >/dev/null; then
    echo "$(date): SSH daemon: RUNNING" >> "$LOG_FILE"
else
    echo "$(date): SSH daemon: STOPPED - restarting" >> "$LOG_FILE"
    service sshd start
fi

# Check WireGuard service
if pgrep -f wg-quick >/dev/null; then
    echo "$(date): WireGuard service: RUNNING" >> "$LOG_FILE"
else
    echo "$(date): WireGuard service: STOPPED - restarting" >> "$LOG_FILE"
    wg-quick up wg0
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 80 ]; then
    echo "$(date): Disk usage: WARNING ($DISK_USAGE%)" >> "$LOG_FILE"
    # Cleanup old logs
    find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
else
    echo "$(date): Disk usage: OK ($DISK_USAGE%)" >> "$LOG_FILE"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
echo "$(date): Memory usage: $MEMORY_USAGE%" >> "$LOG_FILE"

# Check network connectivity
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "$(date): Internet connectivity: OK" >> "$LOG_FILE"
else
    echo "$(date): Internet connectivity: FAILED" >> "$LOG_FILE"
fi
EOFSCRIPT

    chmod +x /opt/msp/scripts/system-health.sh
    
    log "Monitoring scripts created"
}

# Configure services and startup
configure_services() {
    log "Configuring system services..."
    
    # Enable required services
    rc-update add sshd
    rc-update add dcron
    rc-update add wg-quick@wg0
    
    # Start services
    service sshd start
    service dcron start
    wg-quick up wg0
    
    # Add monitoring to crontab
    (crontab -l 2>/dev/null; echo "*/2 * * * * /opt/msp/scripts/wireguard-monitor.sh $CLIENT_NAME") | crontab -
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/msp/scripts/system-health.sh $CLIENT_NAME") | crontab -
    
    # Configure log rotation
    cat > /etc/logrotate.d/msp-bastion << EOF
/var/log/msp-bastion.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
    
    log "Services configured and started"
}

# Create bastion information file
create_bastion_info() {
    log "Creating bastion host information file..."
    
    mkdir -p /etc/msp-config
    
    cat > /etc/msp-config/bastion-info.json << EOF
{
  "client_name": "$CLIENT_NAME",
  "deployment_architecture": "bastion-host",
  "bootstrap_timestamp": "$(date -Iseconds)",
  "wireguard": {
    "interface": "wg0",
    "client_subnet": "$CLIENT_SUBNET",
    "msp_hub_endpoint": "$MSP_HUB_ENDPOINT",
    "public_key": "$(cat /etc/wireguard/public.key)",
    "config_file": "/etc/wireguard/wg0.conf"
  },
  "ssh": {
    "port": 22,
    "authorized_keys": "/root/.ssh/authorized_keys",
    "config_file": "/etc/ssh/sshd_config"
  },
  "monitoring": {
    "scripts_dir": "/opt/msp/scripts",
    "log_file": "/var/log/msp-bastion.log",
    "cron_schedule": "*/2 * * * *"
  },
  "system": {
    "os": "Alpine Linux",
    "version": "$(cat /etc/alpine-release)",
    "memory_mb": $(free -m | awk 'NR==2{print $2}'),
    "disk_gb": $(df / | awk 'NR==2{printf "%.1f", $2/1024/1024}')
  },
  "status": "ready_for_msp_deployment"
}
EOF
    
    log "Bastion information file created"
}

# Generate bootstrap report
generate_report() {
    log "Generating bootstrap report..."
    
    REPORT_FILE="/var/log/msp-bastion-bootstrap-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$REPORT_FILE" << EOF
{
  "client_name": "$CLIENT_NAME",
  "deployment_architecture": "bastion-host",
  "bootstrap_timestamp": "$(date -Iseconds)",
  "operating_system": {
    "distribution": "Alpine Linux",
    "version": "$(cat /etc/alpine-release)"
  },
  "services": {
    "sshd": "$(service sshd status | grep -q 'started' && echo 'running' || echo 'stopped')",
    "wireguard": "$(wg show wg0 >/dev/null 2>&1 && echo 'active' || echo 'inactive')",
    "cron": "$(service dcron status | grep -q 'started' && echo 'running' || echo 'stopped')"
  },
  "wireguard_config": {
    "interface": "wg0",
    "client_subnet": "$CLIENT_SUBNET",
    "msp_hub_endpoint": "$MSP_HUB_ENDPOINT",
    "public_key": "$(cat /etc/wireguard/public.key)"
  },
  "network": {
    "connectivity_test": "$(ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && echo 'success' || echo 'failed')",
    "msp_hub_test": "$(timeout 5 ping -c 1 10.100.0.1 >/dev/null 2>&1 && echo 'success' || echo 'failed')"
  },
  "monitoring": {
    "scripts_installed": "$(ls -1 /opt/msp/scripts/*.sh 2>/dev/null | wc -l)",
    "cron_jobs": "$(crontab -l | grep -c msp 2>/dev/null || echo 0)"
  },
  "bootstrap_status": "completed",
  "next_steps": [
    "Add bastion public key to MSP WireGuard hub configuration",
    "Add MSP management SSH public key to /root/.ssh/authorized_keys",
    "Test connectivity from MSP infrastructure",
    "Deploy production systems behind bastion host",
    "Configure Ansible inventory with ProxyJump settings"
  ]
}
EOF
    
    log "Bootstrap report generated: $REPORT_FILE"
    
    # Copy script log
    cp "$SCRIPT_LOG" "/var/log/msp-bastion-bootstrap.log"
}

# Display completion information
display_completion_info() {
    echo ""
    echo "=================================================================================="
    echo "MSP Bastion Host Bootstrap Completed Successfully!"
    echo "=================================================================================="
    echo ""
    echo "Client Name: $CLIENT_NAME"
    echo "Architecture: Bastion Host (WireGuard VPN)"
    echo "Subnet: $CLIENT_SUBNET"
    echo "MSP Hub: $MSP_HUB_ENDPOINT"
    echo ""
    echo "IMPORTANT: Add this public key to your MSP WireGuard hub configuration:"
    echo "$(cat /etc/wireguard/public.key)"
    echo ""
    echo "Next Steps:"
    echo "1. Add the above public key to MSP hub peer configuration"
    echo "2. Add MSP management SSH key to /root/.ssh/authorized_keys"
    echo "3. Test VPN connectivity: ping 10.100.0.1"
    echo "4. Test SSH connectivity from MSP: ssh root@<bastion-ip>"
    echo "5. Deploy production systems and configure with ProxyJump"
    echo ""
    echo "Monitoring:"
    echo "- WireGuard status: wg show wg0"
    echo "- Service status: service sshd status && service dcron status"
    echo "- Logs: tail -f /var/log/msp-bastion.log"
    echo ""
    echo "Configuration files:"
    echo "- WireGuard: /etc/wireguard/wg0.conf"
    echo "- SSH: /etc/ssh/sshd_config"
    echo "- Info: /etc/msp-config/bastion-info.json"
    echo ""
    echo "=================================================================================="
}

# Main execution
main() {
    log "Starting MSP bastion host bootstrap for WireGuard VPN architecture"
    log "Script log: $SCRIPT_LOG"
    
    validate_parameters
    detect_os
    install_packages
    configure_wireguard
    configure_ssh
    configure_firewall
    create_monitoring
    configure_services
    create_bastion_info
    generate_report
    display_completion_info
    
    log "Bootstrap completed successfully!"
}

# Execute main function
main "$@"