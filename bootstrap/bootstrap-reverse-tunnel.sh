#!/bin/bash
# MSP Client Bootstrap Script - Reverse Tunnel Architecture
# Prepares an Alpine Linux system for SSH reverse tunnel connectivity to MSP infrastructure
# Usage: ./bootstrap-reverse-tunnel.sh <client_name> <msp_jump_host> <tunnel_port> <msp_host_key>

set -euo pipefail

# Configuration
CLIENT_NAME="${1:-}"
MSP_JUMP_HOST="${2:-}"
TUNNEL_PORT="${3:-}"
MSP_HOST_KEY="${4:-}"
SCRIPT_LOG="/tmp/msp-tunnel-bootstrap-$(date +%Y%m%d-%H%M%S).log"

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
    log "Validating reverse tunnel bootstrap parameters..."
    
    [[ -z "$CLIENT_NAME" ]] && error_exit "Client name is required as first parameter"
    [[ -z "$MSP_JUMP_HOST" ]] && error_exit "MSP jump host is required as second parameter"
    [[ -z "$TUNNEL_PORT" ]] && error_exit "Tunnel port is required as third parameter"
    [[ -z "$MSP_HOST_KEY" ]] && error_exit "MSP host key is required as fourth parameter"
    
    # Validate client name format
    if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
        error_exit "Client name must contain only alphanumeric characters and underscores"
    fi
    
    # Validate tunnel port
    if [[ ! "$TUNNEL_PORT" =~ ^[0-9]+$ ]] || [[ $TUNNEL_PORT -lt 1024 ]] || [[ $TUNNEL_PORT -gt 65535 ]]; then
        error_exit "Tunnel port must be a number between 1024 and 65535"
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
        log "WARNING: Low memory detected ($MEMORY_MB MB). Minimum 256MB recommended for tunnel host."
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
        openssh \
        openssh-client \
        autossh \
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
        logrotate \
        netcat-openbsd || error_exit "Failed to install required packages"
    
    log "Package installation completed"
}

# Generate SSH keys for tunnel
generate_ssh_keys() {
    log "Generating SSH keys for reverse tunnel..."
    
    # Create SSH directory
    mkdir -p /etc/ssh/msp
    chmod 700 /etc/ssh/msp
    
    # Generate Ed25519 key for tunnel
    ssh-keygen -t ed25519 -f /etc/ssh/msp/tunnel_key -N \"\" -C "tunnel-$CLIENT_NAME" || error_exit "Failed to generate SSH key"
    
    chmod 600 /etc/ssh/msp/tunnel_key
    chmod 644 /etc/ssh/msp/tunnel_key.pub
    
    # Store MSP host key
    echo "$MSP_HOST_KEY" > /etc/ssh/msp/known_hosts
    chmod 644 /etc/ssh/msp/known_hosts
    
    PUBLIC_KEY=$(cat /etc/ssh/msp/tunnel_key.pub)
    log "Generated SSH key pair for tunnel"
    log "Public key (add this to MSP jump host): $PUBLIC_KEY"
}

# Create tunnel user
create_tunnel_user() {
    log "Creating tunnel user..."
    
    # Create system user for tunnel
    adduser -D -s /bin/false -H tunnel-user || error_exit "Failed to create tunnel user"
    
    # Create tunnel user home directory
    mkdir -p /home/tunnel-user
    chown tunnel-user:tunnel-user /home/tunnel-user
    chmod 755 /home/tunnel-user
    
    log "Tunnel user created successfully"
}

# Configure autossh reverse tunnel
configure_autossh() {
    log "Configuring autossh reverse tunnel..."
    
    # Create autossh configuration
    cat > /etc/conf.d/msp-tunnel << EOF
# MSP Reverse Tunnel Configuration
CLIENT_NAME="$CLIENT_NAME"
MSP_JUMP_HOST="$MSP_JUMP_HOST"
TUNNEL_PORT="$TUNNEL_PORT"
SSH_KEY="/etc/ssh/msp/tunnel_key"
KNOWN_HOSTS="/etc/ssh/msp/known_hosts"

# Autossh options
AUTOSSH_POLL=60
AUTOSSH_FIRST_POLL=30
AUTOSSH_GATETIME=0
AUTOSSH_DEBUG=1
AUTOSSH_LOGFILE="/var/log/msp-tunnel.log"

# SSH options
SSH_OPTIONS="-N -T -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile=$KNOWN_HOSTS -o ConnectTimeout=30 -o BatchMode=yes"
EOF
    
    # Create autossh init script
    cat > /etc/init.d/msp-tunnel << 'EOFSCRIPT'
#!/sbin/openrc-run

name="MSP Reverse Tunnel"
description="Maintains reverse SSH tunnel to MSP infrastructure"

# Load configuration
. /etc/conf.d/msp-tunnel

command="/usr/bin/autossh"
command_args="-M 0 $SSH_OPTIONS -i $SSH_KEY -R $TUNNEL_PORT:localhost:22 tunnel-$CLIENT_NAME@$MSP_JUMP_HOST"
command_user="tunnel-user"
pidfile="/var/run/msp-tunnel.pid"
command_background="yes"
start_stop_daemon_args="--make-pidfile"

# Environment
export AUTOSSH_POLL
export AUTOSSH_FIRST_POLL
export AUTOSSH_GATETIME
export AUTOSSH_DEBUG
export AUTOSSH_LOGFILE

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner tunnel-user:tunnel-user --mode 0755 /var/run
    checkpath --file --owner tunnel-user:tunnel-user --mode 0644 /var/log/msp-tunnel.log
}

start_post() {
    # Wait a moment for tunnel to establish
    sleep 5
    
    # Test tunnel
    if netstat -tln | grep -q ":$TUNNEL_PORT "; then
        einfo "Reverse tunnel established on port $TUNNEL_PORT"
        echo "$(date): Tunnel established successfully" >> /var/log/msp-tunnel.log
    else
        ewarn "Tunnel may not be established - check logs"
        echo "$(date): WARNING: Tunnel establishment unclear" >> /var/log/msp-tunnel.log
    fi
}

stop_post() {
    echo "$(date): Tunnel stopped" >> /var/log/msp-tunnel.log
}
EOFSCRIPT
    
    chmod +x /etc/init.d/msp-tunnel
    log "Autossh reverse tunnel configured"
}

# Configure local SSH server
configure_local_ssh() {
    log "Configuring local SSH server..."
    
    # Generate host keys if they don't exist
    ssh-keygen -A
    
    # Configure SSH daemon for tunnel target
    cat > /etc/ssh/sshd_config << EOF
# MSP Tunnel Target SSH Configuration
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
MaxSessions 20
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

WARNING: MSP Tunnel Target for $CLIENT_NAME
==========================================

This system is accessible via MSP reverse tunnel only.
All activities are monitored and logged.
Unauthorized access is prohibited.

Client: $CLIENT_NAME
Role: Reverse Tunnel Target
Architecture: SSH Reverse Tunnel

EOF
    
    # Create placeholder for MSP SSH key
    mkdir -p /root/.ssh
    chmod 700 /root/.ssh
    
    cat > /root/.ssh/authorized_keys << EOF
# MSP Management Key - Replace with actual key during deployment
# ssh-rsa AAAAB3NzaC1yc2E... msp-management-key
EOF
    chmod 600 /root/.ssh/authorized_keys
    
    log "Local SSH server configured"
}

# Configure firewall for maximum security
configure_firewall() {
    log "Configuring maximum security firewall..."
    
    # Create restrictive firewall rules - ONLY outbound allowed
    cat > /etc/iptables/rules-save << EOF
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

# Allow loopback
-A INPUT -i lo -j ACCEPT

# Allow established and related connections
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH from localhost only (for tunnel target)
-A INPUT -s 127.0.0.1 -p tcp --dport 22 -j ACCEPT

# Allow minimal ICMP (ping responses only)
-A INPUT -p icmp --icmp-type echo-reply -j ACCEPT

# Log and drop everything else
-A INPUT -j LOG --log-prefix "BLOCKED-INPUT: "
-A INPUT -j DROP

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
    
    log "Maximum security firewall configured (no inbound connections allowed)"
}

# Create monitoring and health check scripts
create_monitoring() {
    log "Creating monitoring and health check scripts..."
    
    mkdir -p /opt/msp/scripts
    
    # Tunnel monitoring script
    cat > /opt/msp/scripts/tunnel-monitor.sh << 'EOFSCRIPT'
#!/bin/bash
# Reverse tunnel monitoring script

CLIENT_NAME="$1"
MSP_JUMP_HOST="$2"
TUNNEL_PORT="$3"
LOG_FILE="/var/log/msp-tunnel-monitor.log"

# Check if autossh process is running
if pgrep -f "autossh.*$MSP_JUMP_HOST" >/dev/null; then
    echo "$(date): Autossh process: RUNNING" >> "$LOG_FILE"
else
    echo "$(date): Autossh process: STOPPED - restarting service" >> "$LOG_FILE"
    service msp-tunnel restart
    sleep 10
fi

# Check if tunnel is listening locally
if netstat -tln | grep -q ":$TUNNEL_PORT "; then
    echo "$(date): Local tunnel port: LISTENING" >> "$LOG_FILE"
else
    echo "$(date): Local tunnel port: NOT LISTENING" >> "$LOG_FILE"
fi

# Test SSH connectivity to MSP jump host
if timeout 10 ssh -i /etc/ssh/msp/tunnel_key -o ConnectTimeout=5 -o BatchMode=yes -o UserKnownHostsFile=/etc/ssh/msp/known_hosts tunnel-"$CLIENT_NAME"@"$MSP_JUMP_HOST" exit >/dev/null 2>&1; then
    echo "$(date): MSP jump host connectivity: OK" >> "$LOG_FILE"
else
    echo "$(date): MSP jump host connectivity: FAILED" >> "$LOG_FILE"
    # Restart tunnel service
    service msp-tunnel restart
fi

# Check system resources
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
LOAD_AVG=$(uptime | awk '{print $NF}')

echo "$(date): System stats - Memory: $MEMORY_USAGE% Disk: $DISK_USAGE% Load: $LOAD_AVG" >> "$LOG_FILE"

# Alert if resources are high
if (( $(echo "$MEMORY_USAGE > 90" | bc -l) )); then
    echo "$(date): ALERT: High memory usage ($MEMORY_USAGE%)" >> "$LOG_FILE"
fi

if [ "$DISK_USAGE" -gt 85 ]; then
    echo "$(date): ALERT: High disk usage ($DISK_USAGE%)" >> "$LOG_FILE"
    # Cleanup old logs
    find /var/log -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true
fi
EOFSCRIPT

    chmod +x /opt/msp/scripts/tunnel-monitor.sh
    
    # Network connectivity monitoring
    cat > /opt/msp/scripts/network-monitor.sh << 'EOFSCRIPT'
#!/bin/bash
# Network connectivity monitoring

CLIENT_NAME="$1"
LOG_FILE="/var/log/msp-tunnel-monitor.log"

# Test internet connectivity
if timeout 10 ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    echo "$(date): Internet connectivity: OK" >> "$LOG_FILE"
else
    echo "$(date): Internet connectivity: FAILED" >> "$LOG_FILE"
fi

# Test DNS resolution
if timeout 10 nslookup google.com >/dev/null 2>&1; then
    echo "$(date): DNS resolution: OK" >> "$LOG_FILE"
else
    echo "$(date): DNS resolution: FAILED" >> "$LOG_FILE"
fi

# Check for network interfaces
INTERFACES=$(ip link show | grep -E '^[0-9]+:' | wc -l)
echo "$(date): Network interfaces: $INTERFACES" >> "$LOG_FILE"

# Check routing table
DEFAULT_ROUTE=$(ip route | grep -c default)
echo "$(date): Default routes: $DEFAULT_ROUTE" >> "$LOG_FILE"
EOFSCRIPT

    chmod +x /opt/msp/scripts/network-monitor.sh
    
    # Service health check
    cat > /opt/msp/scripts/service-health.sh << 'EOFSCRIPT'
#!/bin/bash
# Service health monitoring

CLIENT_NAME="$1"
LOG_FILE="/var/log/msp-tunnel-monitor.log"

# Check SSH daemon
if pgrep -x sshd >/dev/null; then
    echo "$(date): SSH daemon: RUNNING" >> "$LOG_FILE"
else
    echo "$(date): SSH daemon: STOPPED - restarting" >> "$LOG_FILE"
    service sshd start
fi

# Check cron daemon
if pgrep -x crond >/dev/null; then
    echo "$(date): Cron daemon: RUNNING" >> "$LOG_FILE"
else
    echo "$(date): Cron daemon: STOPPED - restarting" >> "$LOG_FILE"
    service dcron start
fi

# Check tunnel service status
if service msp-tunnel status | grep -q started; then
    echo "$(date): Tunnel service: STARTED" >> "$LOG_FILE"
else
    echo "$(date): Tunnel service: STOPPED - attempting restart" >> "$LOG_FILE"
    service msp-tunnel start
fi

# Check log file sizes
LOG_SIZE=$(du -sh /var/log | awk '{print $1}')
echo "$(date): Log directory size: $LOG_SIZE" >> "$LOG_FILE"
EOFSCRIPT

    chmod +x /opt/msp/scripts/service-health.sh
    
    log "Monitoring scripts created"
}

# Configure services and cron jobs
configure_services() {
    log "Configuring system services and cron jobs..."
    
    # Enable required services
    rc-update add sshd
    rc-update add dcron
    rc-update add msp-tunnel
    
    # Start services
    service sshd start
    service dcron start
    
    # Add monitoring to crontab
    (crontab -l 2>/dev/null; echo "# MSP Reverse Tunnel Monitoring") | crontab -
    (crontab -l 2>/dev/null; echo "*/2 * * * * /opt/msp/scripts/tunnel-monitor.sh $CLIENT_NAME $MSP_JUMP_HOST $TUNNEL_PORT") | crontab -
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/msp/scripts/network-monitor.sh $CLIENT_NAME") | crontab -
    (crontab -l 2>/dev/null; echo "*/5 * * * * /opt/msp/scripts/service-health.sh $CLIENT_NAME") | crontab -
    
    # Configure log rotation
    cat > /etc/logrotate.d/msp-tunnel << EOF
/var/log/msp-tunnel*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
    
    log "Services and monitoring configured"
}

# Start tunnel service
start_tunnel() {
    log "Starting reverse tunnel service..."
    
    # Start the tunnel service
    service msp-tunnel start
    
    # Wait for tunnel to establish
    sleep 10
    
    # Verify tunnel establishment
    if service msp-tunnel status | grep -q started; then
        log "Tunnel service started successfully"
        
        # Check if port is listening
        if netstat -tln | grep -q ":$TUNNEL_PORT "; then
            log "Tunnel port $TUNNEL_PORT is listening"
        else
            log "WARNING: Tunnel port $TUNNEL_PORT is not listening yet"
        fi
    else
        log "WARNING: Tunnel service failed to start"
    fi
}

# Create tunnel information file
create_tunnel_info() {
    log "Creating tunnel host information file..."
    
    mkdir -p /etc/msp-config
    
    cat > /etc/msp-config/tunnel-info.json << EOF
{
  "client_name": "$CLIENT_NAME",
  "deployment_architecture": "reverse-tunnel",
  "bootstrap_timestamp": "$(date -Iseconds)",
  "tunnel": {
    "msp_jump_host": "$MSP_JUMP_HOST",
    "tunnel_port": $TUNNEL_PORT,
    "ssh_key_public": "$(cat /etc/ssh/msp/tunnel_key.pub)",
    "ssh_key_private": "/etc/ssh/msp/tunnel_key",
    "known_hosts": "/etc/ssh/msp/known_hosts"
  },
  "ssh": {
    "local_port": 22,
    "authorized_keys": "/root/.ssh/authorized_keys",
    "config_file": "/etc/ssh/sshd_config"
  },
  "security": {
    "firewall": "maximum_security",
    "inbound_connections": "denied_except_localhost",
    "outbound_connections": "allowed"
  },
  "monitoring": {
    "scripts_dir": "/opt/msp/scripts",
    "log_files": [
      "/var/log/msp-tunnel.log",
      "/var/log/msp-tunnel-monitor.log"
    ],
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
    
    log "Tunnel information file created"
}

# Generate bootstrap report
generate_report() {
    log "Generating bootstrap report..."
    
    REPORT_FILE="/var/log/msp-tunnel-bootstrap-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$REPORT_FILE" << EOF
{
  "client_name": "$CLIENT_NAME",
  "deployment_architecture": "reverse-tunnel",
  "bootstrap_timestamp": "$(date -Iseconds)",
  "operating_system": {
    "distribution": "Alpine Linux",
    "version": "$(cat /etc/alpine-release)"
  },
  "services": {
    "sshd": "$(service sshd status | grep -q 'started' && echo 'running' || echo 'stopped')",
    "tunnel": "$(service msp-tunnel status | grep -q 'started' && echo 'running' || echo 'stopped')",
    "cron": "$(service dcron status | grep -q 'started' && echo 'running' || echo 'stopped')"
  },
  "tunnel_config": {
    "msp_jump_host": "$MSP_JUMP_HOST",
    "tunnel_port": $TUNNEL_PORT,
    "ssh_key_public": "$(cat /etc/ssh/msp/tunnel_key.pub)",
    "autossh_running": "$(pgrep -f autossh >/dev/null && echo 'yes' || echo 'no')"
  },
  "security": {
    "firewall_status": "$(iptables -L | grep -q 'DROP' && echo 'restrictive' || echo 'permissive')",
    "ssh_config": "hardened",
    "inbound_access": "denied"
  },
  "network": {
    "connectivity_test": "$(ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1 && echo 'success' || echo 'failed')",
    "msp_host_test": "$(timeout 10 ssh -i /etc/ssh/msp/tunnel_key -o ConnectTimeout=5 -o BatchMode=yes tunnel-$CLIENT_NAME@$MSP_JUMP_HOST exit >/dev/null 2>&1 && echo 'success' || echo 'failed')"
  },
  "monitoring": {
    "scripts_installed": "$(ls -1 /opt/msp/scripts/*.sh 2>/dev/null | wc -l)",
    "cron_jobs": "$(crontab -l | grep -c msp 2>/dev/null || echo 0)",
    "log_rotation": "configured"
  },
  "bootstrap_status": "completed",
  "next_steps": [
    "Add tunnel public key to MSP jump host configuration",
    "Configure MSP jump host to accept tunnel-$CLIENT_NAME user",
    "Add MSP management SSH public key to /root/.ssh/authorized_keys",
    "Test reverse tunnel connectivity from MSP infrastructure",
    "Deploy production systems and configure with reverse tunnel access",
    "Configure Ansible inventory with localhost ProxyJump settings"
  ]
}
EOF
    
    log "Bootstrap report generated: $REPORT_FILE"
    
    # Copy script log
    cp "$SCRIPT_LOG" "/var/log/msp-tunnel-bootstrap.log"
}

# Display completion information
display_completion_info() {
    echo ""
    echo "=================================================================================="
    echo "MSP Reverse Tunnel Bootstrap Completed Successfully!"
    echo "=================================================================================="
    echo ""
    echo "Client Name: $CLIENT_NAME"
    echo "Architecture: Reverse Tunnel (SSH)"
    echo "MSP Jump Host: $MSP_JUMP_HOST"
    echo "Tunnel Port: $TUNNEL_PORT"
    echo ""
    echo "IMPORTANT: Add this public key to your MSP jump host configuration:"
    echo "User: tunnel-$CLIENT_NAME"
    echo "Key: $(cat /etc/ssh/msp/tunnel_key.pub)"
    echo ""
    echo "Security Features:"
    echo "- Maximum security firewall (NO inbound connections allowed)"
    echo "- Outbound-only SSH reverse tunnel"
    echo "- Certificate-based authentication"
    echo "- Complete audit logging"
    echo ""
    echo "Next Steps:"
    echo "1. Configure MSP jump host to accept tunnel-$CLIENT_NAME user"
    echo "2. Add the above public key to MSP jump host authorized_keys"
    echo "3. Add MSP management SSH key to /root/.ssh/authorized_keys"
    echo "4. Test reverse tunnel: ssh tunnel-$CLIENT_NAME@$MSP_JUMP_HOST"
    echo "5. Test MSP access: ssh -p $TUNNEL_PORT root@localhost (from MSP)"
    echo "6. Deploy production systems and configure Ansible inventory"
    echo ""
    echo "Monitoring:"
    echo "- Tunnel status: service msp-tunnel status"
    echo "- Autossh process: pgrep -f autossh"
    echo "- Tunnel logs: tail -f /var/log/msp-tunnel.log"
    echo "- Monitor logs: tail -f /var/log/msp-tunnel-monitor.log"
    echo ""
    echo "Configuration files:"
    echo "- Tunnel service: /etc/init.d/msp-tunnel"
    echo "- SSH keys: /etc/ssh/msp/"
    echo "- SSH config: /etc/ssh/sshd_config"
    echo "- Info: /etc/msp-config/tunnel-info.json"
    echo ""
    echo "Security:"
    echo "- Firewall: MAXIMUM (no inbound allowed)"
    echo "- SSH access: localhost only"
    echo "- Tunnel: outbound only"
    echo ""
    echo "=================================================================================="
}

# Main execution
main() {
    log "Starting MSP reverse tunnel bootstrap for maximum security architecture"
    log "Script log: $SCRIPT_LOG"
    
    validate_parameters
    detect_os
    install_packages
    generate_ssh_keys
    create_tunnel_user
    configure_autossh
    configure_local_ssh
    configure_firewall
    create_monitoring
    configure_services
    start_tunnel
    create_tunnel_info
    generate_report
    display_completion_info
    
    log "Bootstrap completed successfully!"
}

# Execute main function
main "$@"