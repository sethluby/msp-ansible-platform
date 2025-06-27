# CMMC Compliance Role

This role implements the core CMMC (Cybersecurity Maturity Model Certification) controls required for defense contractor compliance. It provides automated implementation, validation, and reporting for CMMC Level 2 and Level 3 requirements.

## Purpose

The CMMC Compliance role serves as the central orchestrator for implementing cybersecurity controls across all control families. It focuses on the specific requirements outlined in the CMMC framework while maintaining flexibility for client-specific needs and supporting graceful disconnection scenarios.

## CMMC Control Families Implemented

### Access Control (AC)
- **AC.1.001**: Limit information system access to authorized users
- **AC.1.002**: Limit information system access to authorized transactions
- **AC.1.003**: Control information posted or processed on publicly accessible systems

### Audit and Accountability (AU)  
- **AU.1.006**: Create and retain audit records with specific content
- **AU.1.012**: Provide audit record generation capability for defined events

### Configuration Management (CM)
- **CM.1.073**: Establish and maintain baseline configurations and inventories

### Identification and Authentication (IA)
- **IA.1.076**: Identify users and authenticate them before allowing access
- **IA.1.077**: Use multi-factor authentication for privileged accounts

### System and Communications Protection (SC)
- **SC.1.175**: Protect the confidentiality of CUI at rest and in transit
- **SC.1.176**: Implement cryptographic mechanisms for CUI protection
- **SC.1.178**: Employ architectural designs and configurations

### System and Information Integrity (SI)
- **SI.1.210**: Identify, report, and correct system flaws in a timely manner
- **SI.1.214**: Monitor system security alerts and advisories

## Role Variables

### Core Configuration
```yaml
# CMMC compliance level (level1, level2, level3)
cmmc_level: "level2"

# Client identification for multi-tenant environments
cmmc_client_id: "{{ client_id | default('default') }}"

# Environment designation (production, staging, development)
cmmc_environment: "{{ environment | default('production') }}"
```

### Control Family Enablement
```yaml
# Enable/disable specific control families
cmmc_enable_access_control: true        # AC controls
cmmc_enable_audit_accountability: true  # AU controls
cmmc_enable_config_management: true     # CM controls
cmmc_enable_identification_auth: true   # IA controls
cmmc_enable_system_protection: true     # SC controls
cmmc_enable_system_integrity: true      # SI controls
```

### Access Control Configuration
```yaml
# SSH configuration for AC.1.001 compliance
cmmc_ac_ssh_port: 2022                 # Non-standard SSH port
cmmc_ac_disable_password_auth: true     # Force key-based authentication
cmmc_ac_require_pubkey_auth: true       # Require public key authentication
cmmc_ac_max_auth_tries: 3               # Limit authentication attempts
cmmc_ac_login_grace_time: 60            # Login timeout in seconds

# Authorized user list for system access
cmmc_ac_allowed_users:
  - ansible-service                      # Service account for automation
  - "{{ ansible_user | default('admin') }}"  # Primary administrative user
```

### Audit Configuration
```yaml
# Audit system configuration for AU.1.006 compliance
cmmc_au_enable_auditd: true             # Enable Linux audit daemon
cmmc_au_log_retention_days: 90          # Audit log retention period
cmmc_au_max_log_file_size: 100          # Maximum log file size in MB
cmmc_au_space_left_action: "email"      # Action when disk space low
cmmc_au_admin_space_left_action: "suspend"  # Emergency action for space
```

### Reporting Configuration
```yaml
# Compliance reporting settings
cmmc_reporting_enabled: true            # Enable compliance reporting
cmmc_reporting_format: "json"           # Report format (json, yaml, html)
cmmc_reporting_destination: "/var/log/cmmc"  # Local report storage
cmmc_send_reports_to_msp: true          # Send reports to MSP (graceful disconnect)
cmmc_msp_reporting_endpoint: "{{ msp_reporting_url | default('') }}"
```

## Dependencies

This role depends on the following roles:
- `common`: Base system configuration and utilities
- `security-hardening`: CIS benchmarks and security baseline (optional but recommended)

## Usage Examples

### Basic CMMC Level 2 Implementation
```yaml
- hosts: client_servers
  vars:
    cmmc_level: "level2"
    cmmc_client_id: "client_001"
    cmmc_environment: "production"
  roles:
    - cmmc-compliance
```

### CMMC Level 3 with Custom Configuration
```yaml
- hosts: high_security_servers
  vars:
    cmmc_level: "level3"
    cmmc_client_id: "client_002"
    cmmc_ac_ssh_port: 2222
    cmmc_au_log_retention_days: 180
    cmmc_ia_password_min_length: 16
  roles:
    - cmmc-compliance
```

### Graceful Disconnection Preparation
```yaml
- hosts: client_infrastructure
  vars:
    cmmc_send_reports_to_msp: false      # Disable MSP reporting
    cmmc_msp_reporting_endpoint: ""      # Clear MSP endpoint
    cmmc_local_management_mode: true     # Enable local-only mode
  roles:
    - cmmc-compliance
```

## File Structure

```
cmmc-compliance/
├── README.md                    # This documentation
├── meta/main.yml               # Role metadata and dependencies
├── defaults/main.yml           # Default variable values
├── vars/main.yml              # Role-specific variables
├── tasks/
│   ├── main.yml               # Main task orchestration
│   ├── access_control.yml     # AC control implementation
│   ├── audit_accountability.yml  # AU control implementation
│   ├── config_management.yml  # CM control implementation
│   ├── identification_auth.yml   # IA control implementation
│   ├── system_protection.yml  # SC control implementation
│   ├── system_integrity.yml   # SI control implementation
│   ├── validation.yml         # Compliance validation tasks
│   └── reporting.yml          # Report generation tasks
├── handlers/main.yml          # Service restart and notification handlers
├── templates/
│   ├── audit.rules.j2         # Audit system configuration
│   ├── sshd_config.j2         # SSH daemon configuration
│   ├── compliance_report.j2   # Compliance report template
│   └── baseline_config.j2     # System baseline configuration
├── files/
│   ├── compliance_validator.py  # Python compliance validation script
│   ├── cmmc_controls.yaml     # CMMC control definitions
│   └── security_policies/     # Security policy templates
└── molecule/                  # Testing scenarios for role validation
```

## Task Flow

### Main Task Execution Order
1. **Validation**: Check system compatibility and prerequisites
2. **Access Control**: Implement AC.1.001-003 controls
3. **Audit Setup**: Configure AU.1.006-012 compliance
4. **Configuration Management**: Establish CM.1.073 baseline
5. **Authentication**: Configure IA.1.076-077 mechanisms  
6. **System Protection**: Implement SC.1.175-178 controls
7. **Integrity Monitoring**: Set up SI.1.210-214 monitoring
8. **Compliance Validation**: Verify all controls are properly implemented
9. **Reporting**: Generate compliance status reports

### Handler Execution
- Service restarts triggered by configuration changes
- Audit log rotation after audit configuration updates
- Firewall reload after security rule modifications
- Compliance report generation after any control changes

## Validation and Testing

### Pre-deployment Checks
```bash
# Validate role syntax
ansible-playbook --syntax-check --check playbooks/cmmc-compliance.yml

# Test against single host
ansible-playbook --limit test_host playbooks/cmmc-compliance.yml --check

# Validate variable definitions
ansible-inventory --list --vars
```

### Post-deployment Validation
```bash
# Run compliance validation
ansible-playbook playbooks/validate-cmmc.yml

# Generate compliance report
ansible-playbook playbooks/generate-cmmc-report.yml

# Check specific control implementation
ansible-playbook playbooks/cmmc-compliance.yml --tags "access_control" --check
```

### Molecule Testing
```bash
# Run all test scenarios
molecule test

# Test specific scenario
molecule test -s level2_compliance

# Debug test environment
molecule converge && molecule login
```

## Compliance Validation

The role includes automated validation for all implemented controls:

### Access Control Validation
- Verify SSH configuration matches CMMC requirements
- Check user access restrictions are properly enforced
- Validate authentication mechanisms are correctly configured

### Audit Validation
- Confirm audit daemon is running with proper configuration
- Verify audit rules capture required security events
- Check log retention and rotation policies

### Configuration Management Validation
- Validate baseline configuration is established and maintained
- Check configuration change tracking is operational
- Verify system inventory is current and accurate

## Reporting

### Compliance Reports
- **Daily**: Automated compliance status summary
- **Weekly**: Detailed control implementation report
- **Monthly**: Executive compliance dashboard
- **On-Demand**: Real-time compliance validation

### Report Formats
- **JSON**: Machine-readable for integration with monitoring systems
- **YAML**: Human-readable for configuration review
- **HTML**: Executive dashboard with visual indicators

### Report Distribution
- Local storage: `/var/log/cmmc/reports/`
- MSP integration: Configurable webhook endpoint
- Email notifications: Critical compliance failures
- Dashboard integration: Real-time status updates

## Graceful Disconnection Support

This role is designed to support graceful disconnection from MSP management:

### Local Operation Mode
```yaml
# Configure for independent operation
cmmc_local_management_mode: true
cmmc_send_reports_to_msp: false
cmmc_msp_integration_enabled: false
```

### Self-Contained Features
- All control implementations remain functional
- Local reporting and validation continue
- Configuration baselines maintained locally
- Audit logging remains compliant
- Emergency procedures remain accessible

### Disconnection Checklist
1. Set `cmmc_local_management_mode: true`
2. Clear MSP reporting endpoints
3. Validate local validation scripts function
4. Confirm local backup procedures work
5. Test emergency response procedures
6. Generate final compliance report
7. Archive MSP integration configurations

## Troubleshooting

### Common Issues

#### SSH Configuration Problems
```bash
# Check SSH service status
systemctl status sshd

# Validate SSH configuration
sshd -T | grep -E "(PasswordAuthentication|PubkeyAuthentication)"

# Test SSH connectivity
ssh -o PasswordAuthentication=no -o PubkeyAuthentication=yes user@host
```

#### Audit System Issues
```bash
# Check auditd status
systemctl status auditd

# Verify audit rules
auditctl -l

# Check audit log permissions
ls -la /var/log/audit/
```

#### Compliance Validation Failures
```bash
# Run validation script manually
python3 /usr/local/bin/cmmc_validator.py --verbose

# Check compliance report generation
ansible-playbook playbooks/generate-cmmc-report.yml --verbose

# Validate specific control
ansible-playbook playbooks/cmmc-compliance.yml --tags "audit_accountability" --check
```

### Debug Mode
Enable debug logging by setting:
```yaml
cmmc_debug_enabled: true
cmmc_verbose_logging: true
```

## Integration Points

### AWX/Tower Integration
- Job templates for CMMC compliance deployment
- Scheduled compliance validation runs
- Workflow templates for multi-stage deployments
- Notification integration for compliance failures

### Vault Integration
- Secure storage of sensitive compliance configurations
- Dynamic secret generation for authentication mechanisms
- Certificate management for encryption requirements
- Key rotation automation for security controls

### Monitoring Integration
- Metrics collection for compliance status
- Alert generation for control failures
- Dashboard integration for real-time status
- SLA monitoring for compliance maintenance

This role provides comprehensive CMMC compliance implementation while maintaining the flexibility needed for diverse client environments and supporting graceful disconnection scenarios where clients can maintain compliance independently.