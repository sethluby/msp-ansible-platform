# Ansible Playbook Reference

## Overview

This document provides comprehensive reference for all Ansible playbooks in the MSP Infrastructure Management Platform. Each playbook is designed with multi-tenant architecture, client isolation, and MSP operational patterns.

## Core Playbooks

### 1. System Update Management
**File**: `ansible/playbooks/system-update.yml`

Comprehensive patch management for RHEL, Ubuntu, and SLES systems with client-specific policies.

#### Usage
```bash
# Security updates only for specific client
ansible-playbook system-update.yml -e client_name=acme_corp -e update_mode=security

# Full system updates with reboot (if needed)
ansible-playbook system-update.yml -e client_name=acme_corp -e update_mode=all -e allow_reboot=true

# Target specific hosts
ansible-playbook system-update.yml -e client_name=acme_corp -e target_hosts=client_acme_corp_web
```

#### Key Features
- **Multi-OS Support**: RHEL/CentOS, Ubuntu/Debian, SUSE/SLES
- **Update Modes**: security, all, critical
- **Client Isolation**: Client-specific logging and policies
- **LVM Snapshots**: Pre-update system snapshots for rollback
- **Maintenance Windows**: Configurable time-based restrictions
- **Centralized Logging**: MSP syslog integration

#### Client Variables
```yaml
# group_vars/client_acme_corp/main.yml
client_update_policy: "security"           # security, all, critical
client_maintenance_window: "02:00-04:00"   # Update window
client_snapshot_enabled: true              # LVM snapshot before updates
client_max_update_time: 3600               # Timeout in seconds
client_notification_email: "admin@acme.com"
```

### 2. DISA STIG Compliance
**File**: `ansible/playbooks/disa-stig-compliance.yml`

Implements Defense Information Systems Agency Security Technical Implementation Guides.

#### Usage
```bash
# Apply DISA STIG compliance for RHEL 8
ansible-playbook disa-stig-compliance.yml -e client_name=acme_corp -e client_stig_profile=rhel8_stig

# Apply with client-specific exceptions
ansible-playbook disa-stig-compliance.yml -e client_name=acme_corp -e client_stig_exceptions='["V-230235"]'

# Compliance check only (no changes)
ansible-playbook disa-stig-compliance.yml -e client_name=acme_corp --check
```

#### Implemented STIG Controls
- **V-230221**: DoD logon banner configuration
- **V-230222**: SSH banner configuration  
- **V-230223**: SSH session timeout (10 minutes)
- **V-230224**: Disable host-based authentication
- **V-230225**: Disable SSH user environment options
- **V-230235**: FIPS 140-2 cryptographic policy
- **V-230264**: Address Space Layout Randomization (ASLR)
- **V-230320**: Audit system configuration for account management
- **V-230469**: Disable blank passwords
- **V-230470**: Password complexity enforcement

#### Client Variables
```yaml
# group_vars/client_acme_corp/main.yml
client_stig_profile: "rhel8_stig"          # rhel8_stig, rhel9_stig, ubuntu_stig
client_compliance_level: "CAT_II"          # CAT_I, CAT_II, CAT_III
client_stig_exceptions: []                 # List of STIG IDs to skip
```

### 3. User Management
**File**: `ansible/playbooks/user-management.yml`

Comprehensive user account lifecycle management with client isolation.

#### Usage
```bash
# Create new users
ansible-playbook user-management.yml -e client_name=acme_corp -e user_operation=create -e target_users='[{"username":"jdoe","fullname":"John Doe","groups":["wheel"],"ssh_keys":["ssh-rsa AAAA..."]}]'

# Modify existing users
ansible-playbook user-management.yml -e client_name=acme_corp -e user_operation=modify -e target_users='[{"username":"jdoe","groups":["wheel","docker"]}]'

# Remove users with data archival
ansible-playbook user-management.yml -e client_name=acme_corp -e user_operation=remove -e target_users='[{"username":"jdoe","remove_home":true}]'

# Audit all client users
ansible-playbook user-management.yml -e client_name=acme_corp -e user_operation=audit

# List client-managed users
ansible-playbook user-management.yml -e client_name=acme_corp -e user_operation=list
```

#### Operations Supported
- **create**: Add new user accounts with SSH keys and sudo access
- **modify**: Update existing user properties and access
- **remove**: Remove users with optional data archival
- **audit**: Generate comprehensive user audit reports
- **list**: Display all client-managed users

#### Client Variables
```yaml
# group_vars/client_acme_corp/main.yml
client_user_policy: "standard"             # standard, restricted, admin
client_password_policy:
  max_age: 90                              # Password expiration days
  min_age: 1                               # Minimum password age
  warn_age: 7                              # Warning days before expiration
  enforce_aging: true
client_sudo_policy: "restricted"           # restricted, standard, admin
```

### 4. Firewall Management
**File**: `ansible/playbooks/firewall-management.yml`

Centralized firewall configuration supporting firewalld, ufw, and iptables.

#### Usage
```bash
# Configure restrictive firewall policy
ansible-playbook firewall-management.yml -e client_name=acme_corp -e client_firewall_policy=restrictive

# Add client-specific port access
ansible-playbook firewall-management.yml -e client_name=acme_corp -e client_allowed_ports='[{"port":"8080","protocol":"tcp","description":"Web App"}]'

# Block specific IP addresses
ansible-playbook firewall-management.yml -e client_name=acme_corp -e client_blocked_ips='["192.168.1.100","10.0.0.50"]'
```

#### Firewall Services Supported
- **firewalld**: RHEL/CentOS/Rocky Linux (default)
- **ufw**: Ubuntu/Debian systems
- **iptables**: Legacy systems and custom configurations

#### Client Variables
```yaml
# group_vars/client_acme_corp/main.yml
client_firewall_policy: "restrictive"      # restrictive, standard, permissive
client_allowed_ports:
  - port: "80"
    protocol: "tcp"
    description: "HTTP Web Server"
  - port: "443"
    protocol: "tcp"
    description: "HTTPS Web Server"
client_blocked_ips: []                     # IP addresses to block
client_allowed_networks:                   # Trusted networks
  - "192.168.1.0/24"
```

### 5. Inventory Collection
**File**: `ansible/playbooks/inventory-collection.yml`

Comprehensive system inventory and asset management with multiple output formats.

#### Usage
```bash
# Full inventory collection
ansible-playbook inventory-collection.yml -e client_name=acme_corp -e inventory_scope=full

# Security-focused inventory
ansible-playbook inventory-collection.yml -e client_name=acme_corp -e inventory_scope=security

# Compliance-specific data collection
ansible-playbook inventory-collection.yml -e client_name=acme_corp -e inventory_scope=compliance -e collection_format=yaml

# Basic system information only
ansible-playbook inventory-collection.yml -e client_name=acme_corp -e inventory_scope=basic
```

#### Collection Scopes
- **full**: Complete system, software, security, and compliance data
- **basic**: Essential system information only
- **security**: Security configuration and status
- **compliance**: Compliance-specific data points

#### Output Formats
- **json**: Machine-readable JSON format (default)
- **yaml**: Human-readable YAML format
- **csv**: Tabular data for spreadsheet import

## Global MSP Variables

### Required Variables
All playbooks require these variables to be set:

```yaml
# group_vars/all/main.yml
client_name: "{{ client_name | mandatory }}"                    # Client identifier
msp_syslog_server: "syslog.msp.company.com"                    # Central logging
msp_management_networks: ["10.0.0.0/8", "172.16.0.0/12"]      # MSP access networks

# Default policies (overridden by client-specific settings)
msp_default_update_policy: "security"
msp_default_maintenance_window: "02:00-04:00"
msp_default_firewall_policy: "restrictive"
```

### Optional Variables
```yaml
# Email notifications
msp_security_team_email: "security@msp.company.com"
send_notifications: false
notify_security_team: false

# Asset management integration
msp_asset_database: "https://assets.msp.company.com"
msp_api_token: "{{ vault_msp_api_token }}"

# Advanced features
enforce_maintenance_window: false
hide_sensitive_logs: true
reset_firewall: false
archive_user_data: true
```

## Client-Specific Configuration

### Directory Structure
```
ansible/
├── group_vars/
│   ├── all/
│   │   └── main.yml                    # Global MSP settings
│   └── client_acme_corp/
│       ├── main.yml                    # Client configuration
│       └── vault.yml                   # Encrypted secrets
└── inventory/
    └── production.yml                  # Multi-client inventory
```

### Sample Client Configuration
```yaml
# group_vars/client_acme_corp/main.yml
---
# Client identification
client_name: "acme_corp"
client_notification_email: "admin@acme.com"

# Update management
client_update_policy: "security"
client_maintenance_window: "03:00-05:00"
client_snapshot_enabled: true
client_max_update_time: 7200

# Security policies
client_stig_profile: "rhel8_stig"
client_compliance_level: "CAT_II"
client_firewall_policy: "standard"

# User management
client_user_policy: "standard"
client_sudo_policy: "restricted"

# Monitoring
client_allowed_ports:
  - port: "22"
    protocol: "tcp"
    description: "SSH Access"
  - port: "80"
    protocol: "tcp"
    description: "HTTP"
  - port: "443"
    protocol: "tcp"
    description: "HTTPS"

client_allowed_networks:
  - "192.168.100.0/24"    # Client internal network
```

## Logging and Reporting

### Log Locations
All playbooks create client-specific logs:
```
/var/log/msp/
└── {client_name}/
    ├── system-updates/
    ├── stig-compliance/
    ├── user-management/
    ├── firewall/
    └── inventory/
```

### Centralized Logging
When `msp_syslog_server` is configured, all operations log to central syslog with structured format:
```
MSP-UPDATE: Client: acme_corp | Host: web01 | Session: 1640995200-acme_corp | Status: COMPLETED
MSP-STIG: Client: acme_corp | Host: web01 | Session: 1640995200-acme_corp-stig | Findings: 5
MSP-USER: Client: acme_corp | Host: web01 | Operation: create | Users: 3
```

## Security Considerations

### Client Isolation
- Each client has dedicated group_vars directory
- Client-specific logging directories with restricted permissions
- Session IDs include client name for tracking
- User groups prefixed with client name

### Secrets Management
- Use ansible-vault for sensitive data
- Store client secrets in separate vault files
- Rotate vault passwords regularly
- Never commit unencrypted secrets

### Access Control
- MSP management networks defined globally
- Client-specific firewall rules
- Audit all privileged operations
- Log all user management activities

## Best Practices

### Variable Management
1. Use descriptive variable names with client_ prefix
2. Provide sensible defaults in group_vars/all/
3. Document all client-specific variables
4. Use ansible-vault for sensitive data

### Error Handling
1. All playbooks include validation tasks
2. Use ignore_errors sparingly and document why
3. Implement rollback procedures where possible
4. Log all failures to central syslog

### Testing
1. Always use --check mode first
2. Test in staging environment
3. Validate client-specific configurations
4. Monitor logs for errors and warnings

### Documentation
1. Keep this reference updated
2. Document client-specific configurations
3. Maintain changelog for major changes
4. Include troubleshooting guides