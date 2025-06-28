# Daily Operations Guide

## Overview

This guide covers common daily operational tasks using the implemented Ansible playbooks. All operations are designed with multi-tenant architecture ensuring complete client isolation and comprehensive logging.

## Prerequisites

### Environment Setup
```bash
# Ensure Ansible is properly configured
ansible --version

# Verify inventory access
ansible-inventory --list

# Test connectivity to target client systems
ansible client_acme_corp -m ping
```

### Required Variables
All operations require the `client_name` variable to be set for proper client isolation:
```bash
-e client_name=acme_corp
```

## Common Operational Tasks

### 1. System Updates and Patch Management

#### Security Updates Only (Recommended for Production)
```bash
# Apply security updates to all client systems
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  -e update_mode=security

# Apply security updates to specific host group
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  -e target_hosts=client_acme_corp_web \
  -e update_mode=security
```

#### Full System Updates (Maintenance Windows)
```bash
# Full updates with automatic reboot if required
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  -e update_mode=all \
  -e allow_reboot=true

# Full updates with maintenance window enforcement
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  -e update_mode=all \
  -e enforce_maintenance_window=true
```

#### Check Update Status (Dry Run)
```bash
# Check what updates would be applied without making changes
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  --check --diff
```

### 2. User Account Management

#### Create New Users
```bash
# Create a single user with SSH key
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=create \
  -e 'target_users=[{
    "username":"jdoe",
    "fullname":"John Doe",
    "groups":["wheel"],
    "ssh_keys":["ssh-rsa AAAAB3NzaC1yc2E..."],
    "sudo_access":true
  }]'

# Create multiple users from JSON file
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=create \
  -e @users/acme_corp_new_users.json
```

#### Modify Existing Users
```bash
# Update user groups and shell
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=modify \
  -e 'target_users=[{
    "username":"jdoe",
    "groups":["wheel","docker"],
    "shell":"/bin/zsh"
  }]'

# Remove sudo access for user
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=modify \
  -e 'target_users=[{
    "username":"jdoe",
    "sudo_access":false
  }]'
```

#### Remove Users
```bash
# Remove user account with data archival
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=remove \
  -e 'target_users=[{
    "username":"jdoe",
    "remove_home":true
  }]'

# Force remove user (immediate removal)
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=remove \
  -e 'target_users=[{
    "username":"jdoe",
    "force_removal":true,
    "remove_home":true
  }]'
```

#### User Auditing and Reporting
```bash
# Generate comprehensive user audit
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=audit

# List all client-managed users
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=list
```

### 3. Security Compliance (DISA STIG)

#### Apply DISA STIG Compliance
```bash
# Apply RHEL 8 STIG controls
ansible-playbook ansible/playbooks/disa-stig-compliance.yml \
  -e client_name=acme_corp \
  -e client_stig_profile=rhel8_stig

# Apply Ubuntu STIG controls
ansible-playbook ansible/playbooks/disa-stig-compliance.yml \
  -e client_name=acme_corp \
  -e client_stig_profile=ubuntu_stig

# Apply with client-specific exceptions
ansible-playbook ansible/playbooks/disa-stig-compliance.yml \
  -e client_name=acme_corp \
  -e client_stig_profile=rhel8_stig \
  -e 'client_stig_exceptions=["V-230235","V-230264"]'
```

#### Compliance Checking (No Changes)
```bash
# Check STIG compliance status without making changes
ansible-playbook ansible/playbooks/disa-stig-compliance.yml \
  -e client_name=acme_corp \
  -e client_stig_profile=rhel8_stig \
  --check --diff
```

### 4. Firewall Management

#### Configure Client Firewall Policy
```bash
# Apply restrictive firewall policy
ansible-playbook ansible/playbooks/firewall-management.yml \
  -e client_name=acme_corp \
  -e client_firewall_policy=restrictive

# Apply standard policy with custom ports
ansible-playbook ansible/playbooks/firewall-management.yml \
  -e client_name=acme_corp \
  -e client_firewall_policy=standard \
  -e 'client_allowed_ports=[
    {"port":"8080","protocol":"tcp","description":"Web App"},
    {"port":"9090","protocol":"tcp","description":"Metrics"}
  ]'
```

#### Block Specific IPs or Networks
```bash
# Block suspicious IP addresses
ansible-playbook ansible/playbooks/firewall-management.yml \
  -e client_name=acme_corp \
  -e 'client_blocked_ips=["192.168.1.100","10.0.0.50"]'

# Allow specific client networks
ansible-playbook ansible/playbooks/firewall-management.yml \
  -e client_name=acme_corp \
  -e 'client_allowed_networks=["192.168.100.0/24","10.10.0.0/16"]'
```

### 5. System Inventory and Asset Management

#### Comprehensive Inventory Collection
```bash
# Full system inventory collection
ansible-playbook ansible/playbooks/inventory-collection.yml \
  -e client_name=acme_corp \
  -e inventory_scope=full \
  -e collection_format=json

# Security-focused inventory
ansible-playbook ansible/playbooks/inventory-collection.yml \
  -e client_name=acme_corp \
  -e inventory_scope=security \
  -e collection_format=yaml

# Compliance-specific data collection
ansible-playbook ansible/playbooks/inventory-collection.yml \
  -e client_name=acme_corp \
  -e inventory_scope=compliance
```

#### Basic System Information
```bash
# Quick system overview
ansible-playbook ansible/playbooks/inventory-collection.yml \
  -e client_name=acme_corp \
  -e inventory_scope=basic \
  -e collection_format=csv
```

## Multi-Client Operations

### Batch Operations Across Multiple Clients
```bash
# Update all clients (use with caution)
for client in acme_corp beta_inc gamma_ltd; do
  ansible-playbook ansible/playbooks/system-update.yml \
    -e client_name=$client \
    -e update_mode=security
done

# Inventory collection for all clients
ansible-playbook ansible/playbooks/inventory-collection.yml \
  -e client_name=all_clients \
  -e inventory_scope=basic
```

### Client-Specific Targeting
```bash
# Target specific client host groups
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  -e target_hosts=client_acme_corp_database \
  -e update_mode=security

# Target specific hosts by pattern
ansible-playbook ansible/playbooks/firewall-management.yml \
  -e client_name=acme_corp \
  -e target_hosts="client_acme_corp_web*"
```

## Monitoring and Logging

### Check Operation Logs
```bash
# View client-specific logs
ls -la /var/log/msp/acme_corp/

# View recent system update logs
tail -f /var/log/msp/acme_corp/system-updates/update-report-*.log

# View STIG compliance reports
cat /var/log/msp/acme_corp/stig-compliance/stig-report-*.json | jq '.'

# View user management logs
tail -f /var/log/msp/acme_corp/user-management/user-report-*.json
```

### Monitor Centralized Syslog
```bash
# Monitor MSP syslog for all clients
journalctl -f | grep "MSP-"

# Filter by specific operations
journalctl -f | grep "MSP-UPDATE"
journalctl -f | grep "MSP-STIG"
journalctl -f | grep "MSP-USER"
```

## Troubleshooting Common Issues

### Connectivity Problems
```bash
# Test client connectivity
ansible client_acme_corp -m ping -vvv

# Check SSH configuration
ansible client_acme_corp -m shell -a "sshd -T" --become

# Verify firewall status
ansible client_acme_corp -m shell -a "systemctl status firewalld" --become
```

### Permission Issues
```bash
# Check sudo configuration
ansible client_acme_corp -m shell -a "sudo -l" --become

# Verify user groups
ansible client_acme_corp -m shell -a "groups username" --become

# Check file permissions
ansible client_acme_corp -m file -a "path=/etc/sudoers.d state=directory" --become
```

### Update Failures
```bash
# Check package manager status
ansible client_acme_corp -m shell -a "dnf check-update" --become
ansible client_acme_corp -m shell -a "apt list --upgradable" --become

# Clear package manager cache
ansible client_acme_corp -m shell -a "dnf clean all" --become
ansible client_acme_corp -m shell -a "apt update" --become
```

## Emergency Procedures

### Emergency User Access
```bash
# Create emergency admin user
ansible-playbook ansible/playbooks/user-management.yml \
  -e client_name=acme_corp \
  -e user_operation=create \
  -e 'target_users=[{
    "username":"emergency_admin",
    "groups":["wheel"],
    "sudo_access":true,
    "nopasswd_sudo":true,
    "ssh_keys":["ssh-rsa YOUR_EMERGENCY_KEY"]
  }]'
```

### Emergency Firewall Reset
```bash
# Reset firewall to permissive mode (emergency only)
ansible-playbook ansible/playbooks/firewall-management.yml \
  -e client_name=acme_corp \
  -e client_firewall_policy=permissive \
  -e reset_firewall=true
```

### System Recovery
```bash
# Rollback using LVM snapshot (if available)
ansible client_acme_corp -m shell -a "lvconvert --merge /dev/vg0/acme_corp-pre-update-*" --become

# Emergency service restart
ansible client_acme_corp -m service -a "name=sshd state=restarted" --become
```

## Performance Optimization

### Parallel Execution
```bash
# Run operations in parallel for faster execution
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  -f 10  # 10 parallel forks

# Use linear strategy for ordered execution
ansible-playbook ansible/playbooks/disa-stig-compliance.yml \
  -e client_name=acme_corp \
  --strategy linear
```

### Selective Task Execution
```bash
# Run only specific tags
ansible-playbook ansible/playbooks/disa-stig-compliance.yml \
  -e client_name=acme_corp \
  --tags "ssh,banner"

# Skip specific tags
ansible-playbook ansible/playbooks/system-update.yml \
  -e client_name=acme_corp \
  --skip-tags "snapshot,reboot"
```

## Scheduling and Automation

### Cron-based Scheduling
```bash
# Daily security updates (add to crontab)
0 2 * * * /usr/bin/ansible-playbook /path/to/ansible/playbooks/system-update.yml -e client_name=acme_corp -e update_mode=security

# Weekly compliance checks
0 6 * * 0 /usr/bin/ansible-playbook /path/to/ansible/playbooks/disa-stig-compliance.yml -e client_name=acme_corp --check

# Monthly inventory collection
0 8 1 * * /usr/bin/ansible-playbook /path/to/ansible/playbooks/inventory-collection.yml -e client_name=acme_corp -e inventory_scope=full
```

### Ansible AWX/Tower Integration
```bash
# Create job templates for common operations
# Configure schedules for routine maintenance
# Set up notifications for operation results
# Implement approval workflows for sensitive operations
```

## Best Practices

### Variable Management
1. Always use client-specific group_vars for configuration
2. Store sensitive data in ansible-vault encrypted files
3. Use descriptive variable names with client_ prefix
4. Document all client-specific configurations

### Error Handling
1. Always test operations with --check first
2. Monitor logs for errors and warnings
3. Have rollback procedures documented
4. Test emergency procedures regularly

### Security Considerations
1. Limit access to playbook execution
2. Use separate SSH keys for different clients
3. Rotate ansible-vault passwords regularly
4. Audit all privileged operations

### Documentation
1. Document all client-specific customizations
2. Maintain operation logs and reports
3. Update procedures when adding new clients
4. Keep troubleshooting guides current

---

*Last updated: 2025-06-28*  
*Covers: system-update.yml, disa-stig-compliance.yml, user-management.yml, firewall-management.yml, inventory-collection.yml*