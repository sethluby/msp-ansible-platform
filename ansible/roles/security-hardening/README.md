# Security Hardening Role

This role implements CIS (Center for Internet Security) benchmarks and industry security best practices to provide a hardened baseline for systems requiring CMMC compliance. It serves as a foundation layer that can operate independently or in conjunction with the CMMC compliance role.

## Purpose

The Security Hardening role provides comprehensive system-level security configurations that form the foundation for CMMC compliance. It implements proven security controls from industry standards while maintaining system functionality and supporting graceful disconnection scenarios.

## Author
**thndrchckn** - MSP CMMC Automation Framework

## Implemented Security Standards

### CIS Benchmarks
- **CIS Controls v8**: Implementation of critical security controls
- **CIS Distribution-Specific Benchmarks**: OS-specific hardening guides
  - RHEL/CentOS 7/8/9 benchmarks
  - Ubuntu 18.04/20.04/22.04 benchmarks
  - SLES 12/15 benchmarks

### Security Categories

#### System Access Controls
- SSH daemon hardening with secure ciphers and authentication
- User account management and privilege restrictions
- Login banner configuration and access warnings
- Session timeout and concurrent login limits

#### Network Security
- Firewall configuration and rule management
- Network service hardening and unnecessary service removal
- Protocol security (disable insecure protocols)
- Network parameter tuning for security

#### File System Security
- File and directory permission hardening
- Mount option security (noexec, nosuid, nodev)
- Temporary directory security configurations
- Critical file access controls

#### Kernel Hardening
- Kernel parameter tuning for security
- Address space layout randomization (ASLR)
- Control flow integrity mechanisms
- Memory protection features

#### Audit and Logging
- Comprehensive audit rule configuration
- Log file security and rotation
- Security event monitoring setup
- Audit trail protection mechanisms

## Role Variables

### Core Configuration
```yaml
# Security hardening level (basic, intermediate, advanced)
security_hardening_level: "intermediate"

# Client identification for multi-tenant environments
security_client_id: "{{ client_id | default('default') }}"

# Enable/disable major security categories
security_enable_ssh_hardening: true
security_enable_network_hardening: true
security_enable_filesystem_hardening: true
security_enable_kernel_hardening: true
security_enable_audit_hardening: true
```

### SSH Hardening Configuration
```yaml
# SSH security settings aligned with CIS benchmarks
security_ssh_port: 2022                    # Non-standard SSH port
security_ssh_protocol: 2                   # Force SSH protocol version 2
security_ssh_max_auth_tries: 3             # Maximum authentication attempts
security_ssh_client_alive_interval: 300    # Client keepalive interval
security_ssh_client_alive_count_max: 0     # Maximum keepalive messages
security_ssh_login_grace_time: 60           # Login timeout period
security_ssh_permit_root_login: "no"       # Disable root login
security_ssh_permit_empty_passwords: "no"  # Disable empty passwords
security_ssh_password_authentication: "no" # Disable password authentication
security_ssh_pubkey_authentication: "yes"  # Enable public key authentication
security_ssh_x11_forwarding: "no"          # Disable X11 forwarding
security_ssh_allow_tcp_forwarding: "no"    # Disable TCP forwarding

# Allowed SSH cipher suites (FIPS 140-2 compatible)
security_ssh_ciphers:
  - "chacha20-poly1305@openssh.com"
  - "aes256-gcm@openssh.com"
  - "aes128-gcm@openssh.com"
  - "aes256-ctr"
  - "aes192-ctr"
  - "aes128-ctr"

# Allowed MAC algorithms
security_ssh_macs:
  - "hmac-sha2-256-etm@openssh.com"
  - "hmac-sha2-512-etm@openssh.com"
  - "hmac-sha2-256"
  - "hmac-sha2-512"

# Allowed key exchange algorithms
security_ssh_kex_algorithms:
  - "curve25519-sha256@libssh.org"
  - "ecdh-sha2-nistp256"
  - "ecdh-sha2-nistp384"
  - "ecdh-sha2-nistp521"
  - "diffie-hellman-group-exchange-sha256"
```

### Network Hardening Configuration
```yaml
# Network security parameters
security_disable_ipv6: false               # IPv6 configuration
security_enable_syn_cookies: true          # SYN flood protection
security_disable_source_routing: true      # Disable source routing
security_disable_redirect_acceptance: true # Disable ICMP redirects
security_enable_reverse_path_filtering: true # Enable reverse path filtering
security_disable_send_redirects: true      # Disable sending redirects

# Firewall configuration
security_firewall_default_policy: "drop"   # Default firewall policy
security_firewall_allowed_services:        # Allowed services
  - ssh
  - https
  - ntp

# Network services to disable
security_disable_network_services:
  - rsh
  - rlogin
  - telnet
  - ftp
  - tftp
  - finger
  - echo
  - discard
  - daytime
  - chargen
```

### File System Hardening Configuration
```yaml
# File system security settings
security_tmp_noexec: true                  # Mount /tmp with noexec
security_tmp_nosuid: true                  # Mount /tmp with nosuid
security_tmp_nodev: true                   # Mount /tmp with nodev
security_var_tmp_bind: true                # Bind /var/tmp to /tmp
security_dev_shm_noexec: true              # Mount /dev/shm with noexec
security_dev_shm_nosuid: true              # Mount /dev/shm with nosuid
security_dev_shm_nodev: true               # Mount /dev/shm with nodev

# Sticky bit configuration
security_set_sticky_bit_world_writable: true # Set sticky bit on world-writable directories

# File permission settings
security_shadow_perms: "0000"              # /etc/shadow permissions
security_passwd_perms: "0644"              # /etc/passwd permissions
security_group_perms: "0644"               # /etc/group permissions
security_gshadow_perms: "0000"             # /etc/gshadow permissions
```

### Kernel Hardening Configuration
```yaml
# Kernel security parameters
security_kernel_randomize_va_space: 2      # Full ASLR
security_kernel_exec_shield: 1             # Executable space protection
security_kernel_dmesg_restrict: 1          # Restrict dmesg access
security_kernel_kptr_restrict: 2           # Restrict kernel pointer access
security_kernel_yama_ptrace_scope: 1       # Restrict ptrace usage
security_kernel_core_uses_pid: 1           # Core dump naming
security_kernel_core_pattern: "core"       # Core dump pattern

# Memory protection
security_kernel_disable_core_dumps: true   # Disable core dumps
security_kernel_suid_dumpable: 0           # Disable SUID core dumps

# Network stack hardening
security_kernel_tcp_syncookies: 1          # Enable SYN cookies
security_kernel_icmp_echo_ignore_broadcasts: 1 # Ignore broadcast ICMP
security_kernel_icmp_ignore_bogus_error_responses: 1 # Ignore bogus ICMP
security_kernel_tcp_rfc1337: 1             # Enable RFC 1337 protection
```

### Audit Configuration
```yaml
# Audit system configuration
security_audit_log_retention: 90           # Audit log retention in days
security_audit_max_log_file: 100           # Maximum audit log file size (MB)
security_audit_space_left_action: "email"  # Action when disk space low
security_audit_admin_space_left_action: "suspend" # Emergency space action
security_audit_max_log_file_action: "rotate" # Action when log file full

# Audit rules categories
security_audit_time_change: true           # Monitor time changes
security_audit_user_group_change: true     # Monitor user/group changes
security_audit_network_environment: true   # Monitor network changes
security_audit_login_logout: true          # Monitor login events
security_audit_session_initiation: true    # Monitor session events
security_audit_discretionary_access_control: true # Monitor DAC changes
security_audit_unsuccessful_file_access: true # Monitor failed file access
security_audit_privileged_commands: true   # Monitor privileged commands
security_audit_successful_file_system_mounts: true # Monitor mount events
security_audit_file_deletion: true         # Monitor file deletions
security_audit_sudo_usage: true            # Monitor sudo usage
security_audit_kernel_module_loading: true # Monitor kernel module changes
```

## Dependencies

This role has minimal dependencies to ensure it can operate independently:
- `common` role (optional): Provides base system utilities and configurations

## Usage Examples

### Basic Security Hardening
```yaml
- hosts: all
  vars:
    security_hardening_level: "basic"
    security_client_id: "client_001"
  roles:
    - security-hardening
```

### Advanced Hardening for High-Security Environments
```yaml
- hosts: sensitive_systems
  vars:
    security_hardening_level: "advanced"
    security_disable_ipv6: true
    security_kernel_disable_core_dumps: true
    security_audit_log_retention: 365
  roles:
    - security-hardening
```

### Custom SSH Configuration
```yaml
- hosts: dmz_systems
  vars:
    security_ssh_port: 2222
    security_ssh_client_alive_interval: 600
    security_ssh_allow_tcp_forwarding: "local"
  roles:
    - security-hardening
```

### Minimal Hardening for Development
```yaml
- hosts: dev_systems
  vars:
    security_hardening_level: "basic"
    security_enable_kernel_hardening: false
    security_audit_log_retention: 30
  roles:
    - security-hardening
```

## File Structure

```
security-hardening/
├── README.md                     # This comprehensive documentation
├── meta/main.yml                # Role metadata and dependencies
├── defaults/main.yml            # Default variable values with comments
├── vars/main.yml               # Role-specific variables and constants
├── tasks/
│   ├── main.yml                # Main task orchestration with detailed comments
│   ├── ssh_hardening.yml       # SSH daemon security configuration
│   ├── network_hardening.yml   # Network stack and firewall hardening
│   ├── filesystem_hardening.yml # File system permissions and mount options
│   ├── kernel_hardening.yml    # Kernel parameter security tuning
│   ├── audit_hardening.yml     # Audit system configuration
│   ├── service_hardening.yml   # Service management and hardening
│   ├── user_hardening.yml      # User account and authentication hardening
│   └── validation.yml          # Security configuration validation
├── handlers/main.yml           # Service restart and reload handlers
├── templates/
│   ├── sshd_config.j2          # Hardened SSH daemon configuration
│   ├── audit.rules.j2          # Comprehensive audit rules
│   ├── sysctl_security.conf.j2 # Kernel security parameters
│   ├── firewall_rules.j2       # Firewall rule templates
│   ├── login_banner.j2         # Security warning banners
│   └── security_limits.conf.j2 # User resource limits
├── files/
│   ├── security_validation.sh   # Security configuration validation script
│   ├── cis_benchmark_check.py  # CIS benchmark compliance checker
│   ├── hardening_report.py     # Security hardening status reporter
│   └── security_policies/      # Security policy templates
└── molecule/                   # Testing scenarios for validation
    ├── default/               # Default test scenario
    ├── advanced/              # Advanced hardening test
    └── minimal/               # Minimal hardening test
```

## Implementation Details

### Task Execution Flow
1. **Pre-hardening Validation**: System compatibility and prerequisite checks
2. **SSH Hardening**: Secure SSH daemon configuration and key management
3. **Network Hardening**: Firewall, network services, and protocol security
4. **File System Hardening**: Permissions, mount options, and access controls
5. **Kernel Hardening**: Security parameters and memory protection
6. **Audit Hardening**: Comprehensive logging and monitoring setup
7. **Service Hardening**: Unnecessary service removal and configuration
8. **User Hardening**: Account policies and authentication mechanisms
9. **Post-hardening Validation**: Configuration verification and testing
10. **Security Reporting**: Generate hardening status and compliance reports

### Security Validation

#### Automated Validation Checks
- SSH configuration syntax and security settings verification
- Firewall rule validation and connectivity testing
- File permission and ownership verification
- Kernel parameter confirmation
- Audit rule syntax and functionality validation
- Service status and configuration verification

#### Compliance Verification
- CIS benchmark compliance scoring
- Security control implementation status
- Configuration drift detection
- Baseline deviation reporting

### Integration with CMMC Compliance

This role serves as a foundation for CMMC compliance by implementing:
- **AC (Access Control)**: User access restrictions and SSH hardening
- **AU (Audit and Accountability)**: Comprehensive audit logging
- **SC (System and Communications Protection)**: Encryption and secure communications
- **SI (System and Information Integrity)**: File integrity and system monitoring

### Graceful Disconnection Support

The security hardening role is designed to continue providing protection after MSP disconnection:

#### Self-Contained Features
- All security configurations remain active and functional
- Local validation scripts for ongoing security verification
- Independent audit logging and monitoring
- Standalone security policy enforcement

#### Local Management Capabilities
```yaml
# Configure for independent operation
security_local_management: true
security_msp_integration: false
security_local_validation_enabled: true
```

#### Disconnection Preparation
1. Enable local validation scripts
2. Configure local security monitoring
3. Establish local audit log management
4. Validate independent security policy enforcement
5. Generate final security hardening report
6. Archive MSP-specific configurations

## Testing and Validation

### Pre-deployment Testing
```bash
# Syntax validation
ansible-playbook --syntax-check playbooks/security-hardening.yml

# Dry run testing
ansible-playbook --check playbooks/security-hardening.yml

# Limited scope testing
ansible-playbook --limit test_group playbooks/security-hardening.yml
```

### Post-deployment Validation
```bash
# Run security validation
ansible-playbook playbooks/validate-security.yml

# CIS benchmark compliance check
/usr/local/bin/cis_benchmark_check.py --level intermediate

# Security configuration verification
/usr/local/bin/security_validation.sh --full-check
```

### Molecule Testing
```bash
# Run comprehensive tests
molecule test

# Test specific hardening level
molecule test -s advanced

# Debug test environment
molecule converge -s default && molecule login -s default
```

## Troubleshooting

### Common Issues

#### SSH Connection Problems After Hardening
```bash
# Check SSH service status
systemctl status sshd

# Validate SSH configuration
sshd -t

# Review SSH logs
journalctl -u sshd -n 50

# Test SSH connectivity with verbose output
ssh -vvv -p 2022 user@host
```

#### Firewall Connectivity Issues
```bash
# Check firewall status
systemctl status firewalld  # RHEL/CentOS
ufw status                   # Ubuntu

# List active firewall rules
iptables -L -n

# Check network connectivity
netstat -tuln | grep LISTEN
```

#### Audit System Problems
```bash
# Check auditd status
systemctl status auditd

# Validate audit rules
auditctl -l

# Check audit log permissions and space
df -h /var/log/audit/
ls -la /var/log/audit/
```

#### Kernel Parameter Issues
```bash
# Check current kernel parameters
sysctl -a | grep -E "(randomize_va_space|exec_shield|dmesg_restrict)"

# Reload sysctl configuration
sysctl -p /etc/sysctl.d/99-security.conf

# Verify kernel module restrictions
lsmod | grep security
```

### Debug Mode
Enable detailed logging for troubleshooting:
```yaml
security_debug_mode: true
security_verbose_logging: true
security_preserve_original_configs: true
```

### Recovery Procedures

#### SSH Access Recovery
```bash
# Boot from rescue media or console access
# Restore original SSH configuration
cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
systemctl restart sshd
```

#### Firewall Access Recovery
```bash
# Emergency firewall rule addition
iptables -I INPUT -p tcp --dport 22 -j ACCEPT
# Make permanent after testing
```

## Integration Points

### AWX/Tower Integration
- Job templates for security hardening deployment
- Scheduled compliance validation runs
- Workflow templates for staged hardening implementation
- Notification hooks for security policy violations

### Vault Integration
- Secure storage of SSH keys and certificates
- Dynamic secret generation for authentication
- Encryption key management for data protection
- Automated certificate rotation for services

### Monitoring Integration
- Security metrics collection and alerting
- Configuration drift detection and notification
- Compliance status dashboard integration
- Security event correlation and response

### Backup Integration
- Security configuration backup before changes
- Rollback procedures for failed hardening
- Configuration version control and history
- Emergency recovery configurations

This security hardening role provides a comprehensive, modular foundation for system security that supports both centralized MSP management and independent client operation. The extensive documentation and validation capabilities ensure reliable deployment and ongoing security maintenance.