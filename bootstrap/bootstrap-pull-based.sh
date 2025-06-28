#!/bin/bash
# MSP Client Bootstrap Script - Pull-Based Architecture
# Prepares a system for MSP management using ansible-pull architecture
# Usage: ./bootstrap-pull-based.sh <client_name> <git_repo_url> <ssh_private_key_content>

set -euo pipefail

# Configuration
CLIENT_NAME="${1:-}"
GIT_REPO_URL="${2:-}"
SSH_KEY_CONTENT="${3:-}"
MSP_BASE_DIR="/opt/msp"
MSP_LOG_DIR="/var/log/msp"
SCRIPT_LOG="/tmp/msp-bootstrap-$(date +%Y%m%d-%H%M%S).log"

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
    log "Validating bootstrap parameters..."
    
    [[ -z "$CLIENT_NAME" ]] && error_exit "Client name is required as first parameter"
    [[ -z "$GIT_REPO_URL" ]] && error_exit "Git repository URL is required as second parameter"
    [[ -z "$SSH_KEY_CONTENT" ]] && error_exit "SSH private key content is required as third parameter"
    
    # Validate client name format (alphanumeric and underscores only)
    if [[ ! "$CLIENT_NAME" =~ ^[a-zA-Z0-9_]+$ ]]; then
        error_exit "Client name must contain only alphanumeric characters and underscores"
    fi
    
    log "Parameters validated successfully"
}

# Detect operating system and version
detect_os() {
    log "Detecting operating system..."
    
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        source /etc/os-release
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
        OS_FAMILY="$ID_LIKE"
    else
        error_exit "Cannot detect operating system - /etc/os-release not found"
    fi
    
    log "Detected OS: $OS_ID $OS_VERSION (Family: ${OS_FAMILY:-unknown})"
}

# Install required packages
install_packages() {
    log "Installing required packages..."
    
    case "$OS_ID" in
        rhel|centos|rocky|almalinux|fedora)
            if command -v dnf >/dev/null 2>&1; then
                PKG_MGR="dnf"
            else
                PKG_MGR="yum"
            fi
            
            log "Using package manager: $PKG_MGR"
            $PKG_MGR update -y
            $PKG_MGR install -y ansible git openssh-clients python3 python3-pip crontabs
            
            # Enable and start crond
            systemctl enable crond
            systemctl start crond
            ;;
            
        ubuntu|debian)
            export DEBIAN_FRONTEND=noninteractive
            apt-get update
            apt-get install -y ansible git openssh-client python3 python3-pip cron
            
            # Enable and start cron
            systemctl enable cron
            systemctl start cron
            ;;
            
        sles|opensuse*)
            zypper refresh
            zypper install -y ansible git openssh python3 python3-pip cron
            
            # Enable and start cron
            systemctl enable cron
            systemctl start cron
            ;;
            
        alpine)
            apk update
            apk add ansible git openssh-client python3 py3-pip dcron
            
            # Enable and start crond
            rc-update add dcron
            service dcron start
            ;;
            
        *)
            error_exit "Unsupported operating system: $OS_ID"
            ;;
    esac
    
    log "Package installation completed"
}

# Create MSP directory structure
create_directories() {
    log "Creating MSP directory structure..."
    
    # Create base directories with proper permissions
    mkdir -p "$MSP_BASE_DIR"/{config,playbooks,cache,logs}
    mkdir -p "$MSP_LOG_DIR/$CLIENT_NAME"
    mkdir -p /etc/msp-config/"$CLIENT_NAME"
    mkdir -p /var/backups/msp/"$CLIENT_NAME"
    
    # Set permissions
    chmod 755 "$MSP_BASE_DIR"
    chmod 700 "$MSP_BASE_DIR"/config
    chmod 755 "$MSP_BASE_DIR"/{playbooks,cache,logs}
    chmod 755 "$MSP_LOG_DIR"
    chmod 755 "$MSP_LOG_DIR/$CLIENT_NAME"
    
    log "Directory structure created successfully"
}

# Configure SSH key for Git access
configure_git_access() {
    log "Configuring Git repository access..."
    
    # Create SSH key file
    SSH_KEY_FILE="$MSP_BASE_DIR/config/git_deploy_key"
    echo "$SSH_KEY_CONTENT" > "$SSH_KEY_FILE"
    chmod 600 "$SSH_KEY_FILE"
    
    # Configure SSH for Git
    mkdir -p /root/.ssh
    cat > /root/.ssh/config << EOF
Host git-msp
    HostName $(echo "$GIT_REPO_URL" | sed -E 's|^git@([^:]+):.*|\1|')
    User git
    IdentityFile $SSH_KEY_FILE
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF
    
    chmod 600 /root/.ssh/config
    
    # Test Git access
    log "Testing Git repository access..."
    if timeout 30 git ls-remote "$GIT_REPO_URL" >/dev/null 2>&1; then
        log "Git repository access verified"
    else
        error_exit "Cannot access Git repository - check SSH key and repository URL"
    fi
}

# Create Ansible configuration
create_ansible_config() {
    log "Creating Ansible configuration..."
    
    cat > "$MSP_BASE_DIR/config/ansible.cfg" << EOF
[defaults]
inventory = inventory/local.yml
host_key_checking = False
stdout_callback = yaml
log_path = $MSP_LOG_DIR/$CLIENT_NAME/ansible.log
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = $MSP_BASE_DIR/cache/facts
fact_caching_timeout = 3600
timeout = 30
force_valid_group_names = ignore

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no
pipelining = True
control_path = /tmp/ansible-%%h-%%p-%%r

[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml
EOF
    
    chmod 644 "$MSP_BASE_DIR/config/ansible.cfg"
    log "Ansible configuration created"
}

# Create systemd service for ansible-pull
create_systemd_service() {
    log "Creating systemd service for ansible-pull..."
    
    cat > /etc/systemd/system/msp-ansible-pull.service << EOF
[Unit]
Description=MSP Ansible Pull for $CLIENT_NAME
Wants=network-online.target
After=network-online.target
StartLimitIntervalSec=0

[Service]
Type=oneshot
User=root
WorkingDirectory=$MSP_BASE_DIR/playbooks
Environment=ANSIBLE_CONFIG=$MSP_BASE_DIR/config/ansible.cfg
Environment=CLIENT_NAME=$CLIENT_NAME
ExecStartPre=/usr/bin/git -C $MSP_BASE_DIR/playbooks pull origin main || /usr/bin/git clone $GIT_REPO_URL $MSP_BASE_DIR/playbooks
ExecStart=/usr/bin/ansible-pull \\
    -U $GIT_REPO_URL \\
    -C clients/$CLIENT_NAME \\
    -i inventory/local.yml \\
    --private-key=$MSP_BASE_DIR/config/git_deploy_key \\
    --extra-vars="client_name=$CLIENT_NAME" \\
    --extra-vars="bootstrap_mode=false" \\
    playbooks/site.yml
ExecStartPost=/bin/systemctl --no-block start msp-log-sync.service
Restart=on-failure
RestartSec=300

[Install]
WantedBy=multi-user.target
EOF

    # Create systemd timer for 15-minute execution
    cat > /etc/systemd/system/msp-ansible-pull.timer << EOF
[Unit]
Description=Run MSP Ansible Pull every 15 minutes
Requires=msp-ansible-pull.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=15min
RandomizedDelaySec=300
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Reload systemd and enable services
    systemctl daemon-reload
    systemctl enable msp-ansible-pull.timer
    
    log "Systemd service and timer created"
}

# Create log synchronization service
create_log_sync_service() {
    log "Creating log synchronization service..."
    
    cat > /etc/systemd/system/msp-log-sync.service << EOF
[Unit]
Description=Sync MSP logs to central server
After=network-online.target

[Service]
Type=oneshot
User=root
ExecStart=/opt/msp/scripts/sync-logs.sh $CLIENT_NAME
Restart=on-failure
RestartSec=60
EOF

    # Create log sync script
    mkdir -p "$MSP_BASE_DIR/scripts"
    cat > "$MSP_BASE_DIR/scripts/sync-logs.sh" << 'EOFSCRIPT'
#!/bin/bash
# Log synchronization script
CLIENT_NAME="$1"
LOG_DIR="/var/log/msp/$CLIENT_NAME"

# Create compressed log archive
ARCHIVE_NAME="logs-$CLIENT_NAME-$(date +%Y%m%d-%H%M%S).tar.gz"
tar -czf "/tmp/$ARCHIVE_NAME" -C "$LOG_DIR" .

# Log sync attempt (placeholder - implement based on MSP infrastructure)
logger -t MSP-LOG-SYNC "Created log archive: $ARCHIVE_NAME for client: $CLIENT_NAME"

# Cleanup old archives (keep last 5)
find /tmp -name "logs-$CLIENT_NAME-*.tar.gz" -type f -mtime +5 -delete 2>/dev/null || true
EOFSCRIPT

    chmod +x "$MSP_BASE_DIR/scripts/sync-logs.sh"
    systemctl daemon-reload
    
    log "Log synchronization service created"
}

# Create monitoring and health check script
create_monitoring() {
    log "Creating monitoring and health check scripts..."
    
    cat > "$MSP_BASE_DIR/scripts/health-check.sh" << 'EOFSCRIPT'
#!/bin/bash
# MSP Client Health Check Script
CLIENT_NAME="$1"
LOG_FILE="/var/log/msp/$CLIENT_NAME/health-check.log"

# Check ansible-pull timer status
if systemctl is-active --quiet msp-ansible-pull.timer; then
    echo "$(date): ansible-pull timer: ACTIVE" >> "$LOG_FILE"
else
    echo "$(date): ansible-pull timer: INACTIVE" >> "$LOG_FILE"
    systemctl start msp-ansible-pull.timer
fi

# Check Git repository connectivity
if timeout 10 git ls-remote "$GIT_REPO_URL" >/dev/null 2>&1; then
    echo "$(date): Git connectivity: OK" >> "$LOG_FILE"
else
    echo "$(date): Git connectivity: FAILED" >> "$LOG_FILE"
fi

# Check disk space
DISK_USAGE=$(df /var/log | awk 'NR==2 {print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 85 ]; then
    echo "$(date): Disk usage: WARNING ($DISK_USAGE%)" >> "$LOG_FILE"
else
    echo "$(date): Disk usage: OK ($DISK_USAGE%)" >> "$LOG_FILE"
fi

# Log system stats
echo "$(date): Load: $(uptime | awk '{print $NF}') Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')" >> "$LOG_FILE"
EOFSCRIPT

    chmod +x "$MSP_BASE_DIR/scripts/health-check.sh"
    
    # Add health check to crontab
    (crontab -l 2>/dev/null; echo "*/5 * * * * $MSP_BASE_DIR/scripts/health-check.sh $CLIENT_NAME") | crontab -
    
    log "Monitoring scripts created and scheduled"
}

# Perform initial ansible-pull
initial_ansible_pull() {
    log "Performing initial ansible-pull execution..."
    
    cd "$MSP_BASE_DIR/playbooks" || error_exit "Cannot change to playbooks directory"
    
    # Clone repository if it doesn't exist
    if [[ ! -d .git ]]; then
        git clone "$GIT_REPO_URL" . || error_exit "Failed to clone Git repository"
    fi
    
    # Set ANSIBLE_CONFIG environment variable
    export ANSIBLE_CONFIG="$MSP_BASE_DIR/config/ansible.cfg"
    
    # Run initial ansible-pull with bootstrap mode
    log "Running initial ansible-pull with bootstrap mode..."
    if ansible-pull \
        -U "$GIT_REPO_URL" \
        -C "clients/$CLIENT_NAME" \
        -i inventory/local.yml \
        --private-key="$MSP_BASE_DIR/config/git_deploy_key" \
        --extra-vars="client_name=$CLIENT_NAME" \
        --extra-vars="bootstrap_mode=true" \
        playbooks/bootstrap.yml; then
        log "Initial ansible-pull completed successfully"
    else
        log "WARNING: Initial ansible-pull failed, but bootstrap will continue"
    fi
}

# Start services
start_services() {
    log "Starting MSP services..."
    
    systemctl start msp-ansible-pull.timer
    systemctl status msp-ansible-pull.timer --no-pager
    
    log "Services started successfully"
}

# Generate bootstrap report
generate_report() {
    log "Generating bootstrap report..."
    
    REPORT_FILE="$MSP_LOG_DIR/$CLIENT_NAME/bootstrap-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$REPORT_FILE" << EOF
{
  "client_name": "$CLIENT_NAME",
  "deployment_architecture": "pull-based",
  "bootstrap_timestamp": "$(date -Iseconds)",
  "operating_system": {
    "id": "$OS_ID",
    "version": "$OS_VERSION",
    "family": "${OS_FAMILY:-unknown}"
  },
  "services": {
    "ansible_pull_timer": "$(systemctl is-active msp-ansible-pull.timer)",
    "cron": "$(systemctl is-active cron crond dcron 2>/dev/null | head -1)"
  },
  "directories": {
    "msp_base": "$MSP_BASE_DIR",
    "logs": "$MSP_LOG_DIR/$CLIENT_NAME",
    "config": "/etc/msp-config/$CLIENT_NAME"
  },
  "git_repository": "$GIT_REPO_URL",
  "bootstrap_status": "completed",
  "next_ansible_pull": "$(date -d '+15 minutes' -Iseconds)"
}
EOF
    
    log "Bootstrap report generated: $REPORT_FILE"
}

# Main execution
main() {
    log "Starting MSP client bootstrap for pull-based architecture"
    log "Script log: $SCRIPT_LOG"
    
    validate_parameters
    detect_os
    install_packages
    create_directories
    configure_git_access
    create_ansible_config
    create_systemd_service
    create_log_sync_service
    create_monitoring
    initial_ansible_pull
    start_services
    generate_report
    
    log "Bootstrap completed successfully!"
    log "Client $CLIENT_NAME is now ready for MSP management"
    log "Ansible-pull will run every 15 minutes via systemd timer"
    log "Check status with: systemctl status msp-ansible-pull.timer"
    log "View logs: journalctl -u msp-ansible-pull.service -f"
    
    # Copy script log to MSP log directory
    cp "$SCRIPT_LOG" "$MSP_LOG_DIR/$CLIENT_NAME/bootstrap.log"
}

# Execute main function
main "$@"