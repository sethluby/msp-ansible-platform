# Client Deployment Architectures

## Overview

This document outlines **three optional deployment models** for MSP client connectivity. These architectures can be deployed independently or in combination to meet diverse client requirements. Each option addresses different security, network, and operational needs while maintaining identical core automation capabilities.

## Flexible Deployment Strategy

**Key Principle**: Clients can choose any combination of these architectures based on their specific requirements:

- **Single Architecture**: Deploy one model across all client systems
- **Hybrid Deployment**: Use different models for different client environments
- **Migration Path**: Start with one model and migrate to another as needs evolve
- **Client Choice**: Each client can select their preferred connectivity model

All architectures execute the same Ansible playbooks and maintain identical MSP operational capabilities.

## Architecture Comparison

| Architecture | Security Level | Network Requirements | MSP Control | Client Control | Deployment Complexity |
|--------------|----------------|---------------------|-------------|----------------|----------------------|
| Pull-Based | Medium | Outbound HTTPS only | Low | High | Low |
| Bastion Host | High | WireGuard (UDP 51820) | Medium | Medium | Medium |
| Reverse Tunnel | Highest | SSH reverse tunnel | High | Low | High |

## 1. Pull-Based Architecture (Ansible Pull)

### Overview
Client systems autonomously pull and execute playbooks from a secured Git repository every 15 minutes. This architecture provides maximum client autonomy while maintaining centralized policy management.

### Architecture Diagram
```
MSP Infrastructure                 Client Infrastructure
┌─────────────────┐               ┌──────────────────────┐
│ Git Repository  │◄──────────────│ Client Systems       │
│ - Playbooks     │  HTTPS Pull   │ - ansible-pull       │
│ - Policies      │  (15 min)     │ - Local execution    │
│ - Configurations│               │ - Autonomous operation│
└─────────────────┘               └──────────────────────┘
┌─────────────────┐               ┌──────────────────────┐
│ Monitoring      │◄──────────────│ Metrics & Logs      │
│ - Prometheus    │  Push/Pull    │ - Local collection   │
│ - Grafana       │               │ - Local storage      │
│ - Alerting      │               │ - Periodic sync      │
└─────────────────┘               └──────────────────────┘
```

### Key Features
- **Autonomous Operation**: Clients operate independently without real-time MSP connectivity
- **Minimal Network Requirements**: Only outbound HTTPS (port 443) required
- **Graceful Degradation**: Continues operation even during MSP service interruptions
- **Client Control**: Clients can disable or modify automation locally
- **Scheduled Execution**: Predictable 15-minute automation cycles

### Security Model
- **Authentication**: SSH keys for Git repository access
- **Authorization**: Client-specific repository branches with limited access
- **Encryption**: HTTPS for repository access, local ansible-vault for secrets
- **Audit**: Local logging with periodic centralized sync

### Implementation Components

#### 1. MSP Git Repository Structure
```
msp-ansible-git-repo/
├── clients/
│   ├── acme_corp/
│   │   ├── playbooks/           # Client-specific playbooks
│   │   ├── group_vars/          # Client configuration
│   │   ├── inventory/           # Local inventory
│   │   └── requirements.yml     # Ansible dependencies
│   └── beta_inc/
│       ├── playbooks/
│       ├── group_vars/
│       ├── inventory/
│       └── requirements.yml
├── shared/
│   ├── playbooks/              # Common playbooks
│   └── roles/                  # Shared roles
└── templates/
    ├── ansible-pull.service    # Systemd service template
    ├── ansible.cfg             # Ansible configuration
    └── logging.conf            # Logging configuration
```

#### 2. Client-Side Installation Script
```bash
#!/bin/bash
# MSP Ansible Pull Client Installation
# Usage: ./install-msp-client.sh <client_name> <git_repo_url> <ssh_key_path>

CLIENT_NAME="$1"
GIT_REPO_URL="$2"
SSH_KEY_PATH="$3"

# Install Ansible
if command -v dnf >/dev/null 2>&1; then
    dnf install -y ansible git
elif command -v apt >/dev/null 2>&1; then
    apt update && apt install -y ansible git
fi

# Create MSP directory structure
mkdir -p /opt/msp/{config,logs,playbooks}
mkdir -p /var/log/msp/"$CLIENT_NAME"

# Configure Git repository access
cp "$SSH_KEY_PATH" /opt/msp/config/git_deploy_key
chmod 600 /opt/msp/config/git_deploy_key

# Create ansible-pull systemd service
cat > /etc/systemd/system/msp-ansible-pull.service << EOF
[Unit]
Description=MSP Ansible Pull for $CLIENT_NAME
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
User=root
WorkingDirectory=/opt/msp/playbooks
Environment=ANSIBLE_CONFIG=/opt/msp/config/ansible.cfg
ExecStartPre=/usr/bin/git pull origin main
ExecStart=/usr/bin/ansible-pull \\
    -U $GIT_REPO_URL \\
    -C clients/$CLIENT_NAME \\
    -i inventory/local.yml \\
    --private-key=/opt/msp/config/git_deploy_key \\
    --extra-vars="client_name=$CLIENT_NAME" \\
    playbooks/site.yml
ExecStartPost=/bin/systemctl --no-block start msp-log-sync.service

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

[Install]
WantedBy=timers.target
EOF

# Enable and start services
systemctl daemon-reload
systemctl enable msp-ansible-pull.timer
systemctl start msp-ansible-pull.timer

echo "MSP Ansible Pull client installed for $CLIENT_NAME"
echo "Service will run every 15 minutes"
echo "Check status: systemctl status msp-ansible-pull.timer"
```

#### 3. Client Ansible Configuration
```ini
# /opt/msp/config/ansible.cfg
[defaults]
inventory = inventory/local.yml
host_key_checking = False
stdout_callback = yaml
log_path = /var/log/msp/%CLIENT_NAME%/ansible.log
retry_files_enabled = False
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /opt/msp/cache/facts
fact_caching_timeout = 3600

[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s -o UserKnownHostsFile=/dev/null
pipelining = True
```

### Deployment Steps

1. **MSP Setup**
   - Create client-specific Git repository branches
   - Configure client playbooks and variables
   - Set up SSH key authentication
   - Configure monitoring endpoints

2. **Client Installation**
   - Run installation script on each client system
   - Verify systemd timer is active
   - Test initial ansible-pull execution
   - Configure local logging and monitoring

3. **Operational Verification**
   - Monitor ansible-pull execution logs
   - Verify playbook execution success
   - Check metric collection and reporting
   - Test graceful degradation scenarios

## 2. Bastion Host Architecture (WireGuard VPN)

### Overview
Lightweight bastion hosts deployed at client sites establish secure WireGuard VPN tunnels to MSP infrastructure. This provides secure real-time connectivity while maintaining network segmentation.

### Architecture Diagram
```
MSP Infrastructure                 Client Infrastructure
┌─────────────────┐               ┌──────────────────────┐
│ AWX/Tower       │               │ Bastion Host         │
│ - Orchestration │◄──WireGuard───┤ - Alpine Linux       │
│ - Job scheduling│  VPN Tunnel   │ - 512MB RAM          │
│ - Web UI        │               │ - WireGuard client   │
└─────────────────┘               │ - SSH tunnel         │
┌─────────────────┐               └──────┬───────────────┘
│ Monitoring      │                      │ SSH/Ansible
│ - Prometheus    │◄─────────────────────┤
│ - Grafana       │  Metrics Collection  │
│ - Alerting      │                      ▼
└─────────────────┘               ┌──────────────────────┐
┌─────────────────┐               │ Client Systems       │
│ WireGuard Hub   │               │ - Production servers │
│ - VPN server    │               │ - Isolated network   │
│ - Certificate   │               │ - No direct internet │
│ - Routing       │               │ - Local management   │
└─────────────────┘               └──────────────────────┘
```

### Key Features
- **Network Segmentation**: Client production systems remain isolated
- **Minimal Attack Surface**: Only bastion host exposed to VPN
- **Real-time Connectivity**: Immediate MSP access when needed
- **Lightweight Deployment**: Minimal resource requirements
- **Centralized Management**: MSP-controlled orchestration

### Security Model
- **Network Encryption**: WireGuard VPN with rotating keys
- **Host Isolation**: Bastion host separate from production systems
- **Certificate-based Authentication**: Mutual authentication
- **Network Policies**: Restricted routing and firewall rules
- **Audit Logging**: Complete connection and command logging

### Implementation Components

#### 1. Bastion Host Specification
```yaml
# Recommended bastion host specifications
hardware:
  cpu: 1 vCPU
  memory: 512MB RAM
  storage: 8GB SSD
  network: 1 Gbps Ethernet

software:
  os: Alpine Linux 3.18+
  packages:
    - wireguard-tools
    - openssh-server
    - python3
    - ansible-core
    - docker (optional)
```

#### 2. WireGuard Configuration Template
```ini
# MSP Hub Configuration (/etc/wireguard/wg0.conf)
[Interface]
PrivateKey = <MSP_HUB_PRIVATE_KEY>
Address = 10.100.0.1/24
ListenPort = 51820
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE

# Client: acme_corp
[Peer]
PublicKey = <ACME_CORP_BASTION_PUBLIC_KEY>
AllowedIPs = 10.100.1.0/28
Endpoint = acme-corp-bastion.example.com:51820
PersistentKeepalive = 25

# Client: beta_inc
[Peer]
PublicKey = <BETA_INC_BASTION_PUBLIC_KEY>
AllowedIPs = 10.100.2.0/28
Endpoint = beta-inc-bastion.example.com:51820
PersistentKeepalive = 25
```

```ini
# Client Bastion Configuration (/etc/wireguard/wg0.conf)
[Interface]
PrivateKey = <CLIENT_BASTION_PRIVATE_KEY>
Address = 10.100.1.1/28
DNS = 8.8.8.8

[Peer]
PublicKey = <MSP_HUB_PUBLIC_KEY>
AllowedIPs = 10.100.0.0/24
Endpoint = msp-wireguard.example.com:51820
PersistentKeepalive = 25
```

#### 3. Bastion Host Setup Script
```bash
#!/bin/bash
# MSP Bastion Host Setup Script
# Usage: ./setup-bastion.sh <client_name> <msp_hub_endpoint> <client_subnet>

CLIENT_NAME="$1"
MSP_HUB_ENDPOINT="$2"
CLIENT_SUBNET="$3"

# Update Alpine packages
apk update && apk upgrade

# Install required packages
apk add wireguard-tools openssh python3 py3-pip ansible-core curl htop

# Generate WireGuard keys
wg genkey | tee /etc/wireguard/private.key | wg pubkey > /etc/wireguard/public.key
chmod 600 /etc/wireguard/private.key

PRIVATE_KEY=$(cat /etc/wireguard/private.key)
PUBLIC_KEY=$(cat /etc/wireguard/public.key)

# Create WireGuard configuration
cat > /etc/wireguard/wg0.conf << EOF
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $CLIENT_SUBNET
DNS = 8.8.8.8
PostUp = echo "WireGuard started for $CLIENT_NAME" | logger
PostDown = echo "WireGuard stopped for $CLIENT_NAME" | logger

[Peer]
PublicKey = <MSP_HUB_PUBLIC_KEY>
AllowedIPs = 10.100.0.0/24
Endpoint = $MSP_HUB_ENDPOINT:51820
PersistentKeepalive = 25
EOF

# Configure SSH for MSP access
mkdir -p /root/.ssh
cat > /root/.ssh/authorized_keys << EOF
# MSP Management Key
<MSP_PUBLIC_SSH_KEY>
EOF

# Harden SSH configuration
cat > /etc/ssh/sshd_config << EOF
Port 22
Protocol 2
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers root
Banner /etc/ssh/banner
EOF

# Create SSH banner
cat > /etc/ssh/banner << EOF
WARNING: MSP Bastion Host for $CLIENT_NAME
Authorized access only. All activity is monitored and logged.
EOF

# Enable services
rc-update add sshd
rc-update add wg-quick@wg0

# Start services
service sshd start
wg-quick up wg0

# Create monitoring script
cat > /opt/bastion-monitor.sh << 'EOF'
#!/bin/bash
# Bastion host monitoring script

CLIENT_NAME="$1"
LOG_FILE="/var/log/bastion-monitor.log"

# Check WireGuard status
if wg show wg0 >/dev/null 2>&1; then
    echo "$(date): WireGuard tunnel active" >> "$LOG_FILE"
else
    echo "$(date): WireGuard tunnel DOWN" >> "$LOG_FILE"
    wg-quick up wg0
fi

# Check SSH connectivity to MSP
if timeout 5 nc -z 10.100.0.1 22 >/dev/null 2>&1; then
    echo "$(date): MSP connectivity OK" >> "$LOG_FILE"
else
    echo "$(date): MSP connectivity FAILED" >> "$LOG_FILE"
fi

# Log system stats
echo "$(date): Load: $(uptime | awk '{print $NF}') Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')" >> "$LOG_FILE"
EOF

chmod +x /opt/bastion-monitor.sh

# Schedule monitoring
echo "*/5 * * * * /opt/bastion-monitor.sh $CLIENT_NAME" | crontab -

echo "Bastion host setup complete for $CLIENT_NAME"
echo "Public key for MSP hub configuration:"
cat /etc/wireguard/public.key
```

#### 4. MSP Ansible Inventory for Bastion Architecture
```yaml
# inventory/bastions.yml
all:
  children:
    msp_bastions:
      hosts:
        acme-corp-bastion:
          ansible_host: 10.100.1.1
          client_name: acme_corp
          client_subnet: 10.100.1.0/28
          tunnel_endpoint: acme-corp-bastion.example.com
        beta-inc-bastion:
          ansible_host: 10.100.2.1
          client_name: beta_inc
          client_subnet: 10.100.2.0/28
          tunnel_endpoint: beta-inc-bastion.example.com
    
    client_acme_corp:
      hosts:
        acme-web-01:
          ansible_host: 192.168.1.10
          ansible_ssh_common_args: '-o ProxyJump=root@10.100.1.1'
        acme-db-01:
          ansible_host: 192.168.1.20
          ansible_ssh_common_args: '-o ProxyJump=root@10.100.1.1'
      vars:
        client_name: acme_corp
        
    client_beta_inc:
      hosts:
        beta-app-01:
          ansible_host: 10.0.1.10
          ansible_ssh_common_args: '-o ProxyJump=root@10.100.2.1'
        beta-app-02:
          ansible_host: 10.0.1.11
          ansible_ssh_common_args: '-o ProxyJump=root@10.100.2.1'
      vars:
        client_name: beta_inc
```

### Deployment Steps

1. **MSP Hub Setup**
   - Deploy WireGuard server with client peer configurations
   - Configure routing and firewall rules
   - Set up monitoring and alerting for VPN connections
   - Create client-specific network segments

2. **Bastion Host Deployment**
   - Deploy lightweight Alpine Linux hosts at client sites
   - Run bastion setup script with client-specific parameters
   - Configure WireGuard client and SSH access
   - Test VPN connectivity and SSH proxy jumps

3. **Client Integration**
   - Configure Ansible inventory with proxy jump settings
   - Test automation execution through bastion hosts
   - Verify network segmentation and security controls
   - Set up monitoring for bastion host health

## 3. Reverse Tunnel Architecture (SSH Reverse Tunnel)

### Overview
Client bastions establish outbound SSH reverse tunnels to MSP infrastructure, allowing MSP-initiated connections through client firewalls. Provides highest security with MSP-controlled access.

### Architecture Diagram
```
MSP Infrastructure                 Client Infrastructure
┌─────────────────┐               ┌──────────────────────┐
│ SSH Jump Host   │◄──SSH Reverse │ Bastion Host         │
│ - Connection    │   Tunnel      │ - Alpine Linux       │
│   aggregation   │  (port 2222)  │ - Outbound SSH only  │
│ - Access control│               │ - Auto-reconnect     │
└─────────────────┘               │ - Certificate auth   │
         │                        └──────┬───────────────┘
         ▼                               │ SSH/Ansible
┌─────────────────┐                      │
│ AWX/Tower       │                      ▼
│ - Job execution │               ┌──────────────────────┐
│ - Orchestration │               │ Client Systems       │
│ - Web interface │               │ - Air-gapped network │
└─────────────────┘               │ - No inbound access  │
┌─────────────────┐               │ - Maximum security   │
│ Monitoring      │               │ - Compliance ready   │
│ - Metrics       │               └──────────────────────┘
│ - Alerting      │
│ - Dashboards    │
└─────────────────┘
```

### Key Features
- **Maximum Security**: No inbound connections to client networks
- **Compliance Ready**: Ideal for air-gapped and high-security environments
- **MSP-Controlled Access**: All connections initiated from MSP side
- **Automatic Recovery**: Self-healing tunnel connections
- **Audit Trail**: Complete connection and command logging

### Security Model
- **Certificate-based Authentication**: Mutual certificate authentication
- **Connection Multiplexing**: Single tunnel for multiple connections
- **Network Isolation**: Complete inbound connection blocking
- **Session Recording**: All SSH sessions recorded and audited
- **Access Control**: Time-based and role-based access controls

### Implementation Components

#### 1. MSP SSH Jump Host Configuration
```bash
# /etc/ssh/sshd_config for jump host
Port 22
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysCommand /opt/msp/bin/get-authorized-keys.sh
AuthorizedKeysCommandUser nobody
ClientAliveInterval 60
ClientAliveCountMax 3
GatewayPorts yes
MaxSessions 100
MaxStartups 20:30:100

# Logging configuration
LogLevel VERBOSE
SyslogFacility AUTH

# Client tunnel restrictions
Match User tunnel-*
    ForceCommand /opt/msp/bin/tunnel-handler.sh
    PermitTTY no
    X11Forwarding no
    PermitTunnel no
    GatewayPorts no
```

#### 2. Client Bastion Reverse Tunnel Setup
```bash
#!/bin/bash
# MSP Reverse Tunnel Client Setup
# Usage: ./setup-reverse-tunnel.sh <client_name> <msp_jump_host> <tunnel_port>

CLIENT_NAME="$1"
MSP_JUMP_HOST="$2"
TUNNEL_PORT="$3"

# Install required packages
apk add openssh-client autossh python3 ansible-core

# Generate SSH client keys
ssh-keygen -t ed25519 -f /etc/ssh/msp_tunnel_key -N "" -C "tunnel-$CLIENT_NAME"

# Create tunnel user
adduser -D -s /bin/false tunnel-user

# Create autossh tunnel service
cat > /etc/init.d/msp-tunnel << 'EOF'
#!/sbin/openrc-run

name="MSP Reverse Tunnel"
description="Maintains reverse SSH tunnel to MSP infrastructure"

command="/usr/bin/autossh"
command_args="-M 0 -N -T -o ServerAliveInterval=60 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no -i /etc/ssh/msp_tunnel_key -R ${TUNNEL_PORT}:localhost:22 tunnel-${CLIENT_NAME}@${MSP_JUMP_HOST}"
command_user="tunnel-user"
pidfile="/var/run/msp-tunnel.pid"
command_background="yes"

depend() {
    need net
    after firewall
}

start_pre() {
    checkpath --directory --owner tunnel-user:tunnel-user --mode 0755 /var/run
}
EOF

# Configure environment variables
cat > /etc/conf.d/msp-tunnel << EOF
CLIENT_NAME="$CLIENT_NAME"
MSP_JUMP_HOST="$MSP_JUMP_HOST"
TUNNEL_PORT="$TUNNEL_PORT"
EOF

# Create tunnel monitoring script
cat > /opt/tunnel-monitor.sh << 'EOF'
#!/bin/bash
# Monitor tunnel connectivity and auto-repair

CLIENT_NAME="$1"
MSP_JUMP_HOST="$2"
LOG_FILE="/var/log/tunnel-monitor.log"

# Check if tunnel process is running
if ! pgrep -f "autossh.*$MSP_JUMP_HOST" >/dev/null; then
    echo "$(date): Tunnel process not found, restarting..." >> "$LOG_FILE"
    service msp-tunnel restart
    sleep 10
fi

# Test tunnel connectivity
if timeout 5 ssh -i /etc/ssh/msp_tunnel_key -o ConnectTimeout=5 -o BatchMode=yes tunnel-"$CLIENT_NAME"@"$MSP_JUMP_HOST" exit >/dev/null 2>&1; then
    echo "$(date): Tunnel connectivity OK" >> "$LOG_FILE"
else
    echo "$(date): Tunnel connectivity FAILED, restarting..." >> "$LOG_FILE"
    service msp-tunnel restart
fi

# Log system health
echo "$(date): Load: $(uptime | awk '{print $NF}') Memory: $(free -m | awk 'NR==2{printf "%.1f%%", $3*100/$2}')" >> "$LOG_FILE"
EOF

chmod +x /opt/tunnel-monitor.sh

# Schedule monitoring
echo "*/2 * * * * /opt/tunnel-monitor.sh $CLIENT_NAME $MSP_JUMP_HOST" | crontab -

# Enable and start tunnel service
rc-update add msp-tunnel
service msp-tunnel start

echo "Reverse tunnel setup complete for $CLIENT_NAME"
echo "Public key for MSP jump host:"
cat /etc/ssh/msp_tunnel_key.pub
echo ""
echo "Configure this key on MSP jump host for user: tunnel-$CLIENT_NAME"
EOF
```

#### 3. MSP Tunnel Management Scripts
```bash
#!/bin/bash
# /opt/msp/bin/tunnel-handler.sh
# Handles incoming tunnel connections and enforces access policies

CLIENT_NAME=$(echo "$SSH_ORIGINAL_COMMAND" | awk '{print $1}')
COMMAND=$(echo "$SSH_ORIGINAL_COMMAND" | cut -d' ' -f2-)

# Log connection
echo "$(date): Tunnel connection from $CLIENT_NAME: $SSH_CLIENT" >> /var/log/msp-tunnels.log

# Validate client
if ! grep -q "^$CLIENT_NAME$" /opt/msp/config/allowed-clients.txt; then
    echo "Unauthorized client: $CLIENT_NAME" >&2
    exit 1
fi

# Check if client is in maintenance window
MAINTENANCE_START=$(grep "^$CLIENT_NAME:" /opt/msp/config/maintenance-windows.conf | cut -d: -f2)
MAINTENANCE_END=$(grep "^$CLIENT_NAME:" /opt/msp/config/maintenance-windows.conf | cut -d: -f3)

if [ -n "$MAINTENANCE_START" ] && [ -n "$MAINTENANCE_END" ]; then
    CURRENT_HOUR=$(date +%H)
    if [ "$CURRENT_HOUR" -lt "$MAINTENANCE_START" ] || [ "$CURRENT_HOUR" -gt "$MAINTENANCE_END" ]; then
        echo "Outside maintenance window for $CLIENT_NAME" >&2
        exit 1
    fi
fi

# Execute approved commands only
case "$COMMAND" in
    "health-check")
        echo "OK: Tunnel healthy for $CLIENT_NAME"
        ;;
    "system-info")
        echo "Client: $CLIENT_NAME, Tunnel: Active, Time: $(date)"
        ;;
    *)
        echo "Command not allowed: $COMMAND" >&2
        exit 1
        ;;
esac
```

```bash
#!/bin/bash
# /opt/msp/bin/get-authorized-keys.sh
# Dynamic authorized keys based on client and time-based access

CLIENT_USER="$1"

# Extract client name from username (format: tunnel-clientname)
CLIENT_NAME=$(echo "$CLIENT_USER" | sed 's/^tunnel-//')

# Check if client exists and is active
if ! grep -q "^$CLIENT_NAME:" /opt/msp/config/clients.conf; then
    exit 1
fi

# Get client's public key
CLIENT_KEY=$(grep "^$CLIENT_NAME:" /opt/msp/config/clients.conf | cut -d: -f2)

# Add restrictions to the key
echo "restrict,command=\"/opt/msp/bin/tunnel-handler.sh $CLIENT_NAME\" $CLIENT_KEY"
```

#### 4. MSP Ansible Inventory for Reverse Tunnel
```yaml
# inventory/reverse-tunnels.yml
all:
  children:
    tunnel_clients:
      hosts:
        acme-corp-tunnel:
          ansible_host: localhost
          ansible_port: 2201
          client_name: acme_corp
          tunnel_port: 2201
        beta-inc-tunnel:
          ansible_host: localhost
          ansible_port: 2202
          client_name: beta_inc
          tunnel_port: 2202
    
    client_acme_corp:
      hosts:
        acme-web-01:
          ansible_host: 192.168.1.10
          ansible_ssh_common_args: '-o ProxyJump=root@localhost:2201'
        acme-db-01:
          ansible_host: 192.168.1.20
          ansible_ssh_common_args: '-o ProxyJump=root@localhost:2201'
      vars:
        client_name: acme_corp
        
    client_beta_inc:
      hosts:
        beta-app-01:
          ansible_host: 10.0.1.10
          ansible_ssh_common_args: '-o ProxyJump=root@localhost:2202'
        beta-app-02:
          ansible_host: 10.0.1.11
          ansible_ssh_common_args: '-o ProxyJump=root@localhost:2202'
      vars:
        client_name: beta_inc
```

### Deployment Steps

1. **MSP Jump Host Setup**
   - Configure SSH server with client-specific restrictions
   - Set up dynamic authorized keys and tunnel handlers
   - Configure client access policies and maintenance windows
   - Deploy monitoring for tunnel health and connectivity

2. **Client Bastion Deployment**
   - Deploy bastion hosts with reverse tunnel capabilities
   - Configure autossh for reliable tunnel maintenance
   - Set up monitoring and auto-recovery mechanisms
   - Test tunnel establishment and connectivity

3. **Integration Testing**
   - Verify Ansible execution through reverse tunnels
   - Test failover and recovery scenarios
   - Validate security controls and access restrictions
   - Monitor tunnel performance and reliability

## Architecture Selection Guide

### **OPTIONAL:** Pull-Based Architecture
**Best for clients who prefer:**
- ✅ Maximum operational autonomy
- ✅ Minimal network connectivity requirements
- ✅ Scheduled maintenance windows
- ✅ Local IT team control
- ✅ Air-gapped environments with periodic synchronization

### **OPTIONAL:** Bastion Host Architecture  
**Best for clients who need:**
- ✅ Real-time monitoring and response
- ✅ Immediate incident response capabilities
- ✅ Balanced security with connectivity
- ✅ VPN-compatible network infrastructure
- ✅ Standard enterprise security models

### **OPTIONAL:** Reverse Tunnel Architecture
**Best for clients requiring:**
- ✅ Maximum security compliance
- ✅ Zero inbound network connections
- ✅ Highly regulated environments
- ✅ Complete MSP access control
- ✅ Air-gapped with minimal network exposure

## Hybrid Deployment Examples

### **Multi-Architecture Client**
```
AcmeCorp Infrastructure:
├── Production Servers → Reverse Tunnel (high security)
├── Development Servers → Bastion Host (real-time access)
└── Edge Locations → Pull-Based (autonomous operation)
```

### **Migration Strategy**
```
Phase 1: Pull-Based deployment (quick start)
Phase 2: Add Bastion Host (enhanced monitoring)
Phase 3: Migrate critical systems to Reverse Tunnel (compliance)
```

### **Service Tier Integration**
```
Foundation Tier: Pull-Based architecture (cost-effective)
Professional Tier: Bastion Host option (enhanced capabilities)
Enterprise Tier: All three options available (maximum flexibility)
```

## Conclusion

**No Single Architecture Required**: These three deployment models provide complete flexibility for MSP clients. Each option delivers identical automation capabilities while accommodating different security, network, and operational requirements.

**Client Choice**: Every client can select the architecture(s) that best fit their environment, compliance requirements, and operational preferences. The MSP platform adapts to client needs rather than forcing a single connectivity model.

**Future-Proof**: Clients can start with one architecture and migrate or add others as their requirements evolve, ensuring long-term compatibility with changing business needs.