# Ansible Roles for CMMC Compliance

This directory contains modular Ansible roles designed to implement and maintain CMMC (Cybersecurity Maturity Model Certification) compliance across client environments. Each role is designed for maximum modularity and can operate independently or as part of the complete compliance framework.

## Role Structure

### Core Roles

#### `common/`
**Purpose**: Base system configuration and utilities required by all other roles
- System package management and updates
- Basic security hardening (firewall, SSH basics)
- Time synchronization and logging setup
- User account management foundation
- Directory structure creation for compliance artifacts

#### `security-hardening/`
**Purpose**: Implements CIS benchmarks and security best practices
- SSH configuration hardening (key-only auth, cipher restrictions)
- Kernel parameter tuning for security
- Service hardening and unnecessary service removal
- File system permissions and mount options
- Network security configuration

#### `cmmc-compliance/`
**Purpose**: Core CMMC control implementation and validation
- Access Control (AC) - User access restrictions and monitoring
- Audit and Accountability (AU) - Comprehensive logging and audit trails
- Configuration Management (CM) - Change tracking and baseline maintenance
- Identification and Authentication (IA) - Strong authentication mechanisms
- System and Communications Protection (SC) - Encryption and secure communications
- System and Information Integrity (SI) - File integrity and intrusion detection

#### `monitoring/`
**Purpose**: Observability and health monitoring
- System metrics collection (CPU, memory, disk, network)
- Log aggregation and forwarding to central systems
- Health check endpoints and service monitoring
- Performance baseline establishment
- Alert configuration for security events

#### `backup/`
**Purpose**: Data protection and recovery capabilities  
- Configuration backup automation
- System state snapshots
- Backup validation and restore testing
- Retention policy management
- Encrypted backup storage

#### `user-management/`
**Purpose**: Centralized user account and access management
- User provisioning and deprovisioning
- SSH key management and rotation
- Sudo privilege management
- Account auditing and compliance reporting
- Multi-factor authentication setup

#### `network-security/`
**Purpose**: Network-level security controls
- Firewall rule management
- Network segmentation enforcement
- VPN client configuration
- Intrusion detection system setup
- Network monitoring and logging

## Role Dependencies

```
common (base)
├── security-hardening (depends on common)
├── user-management (depends on common)
├── network-security (depends on common)
└── cmmc-compliance (depends on common, security-hardening)
    ├── monitoring (optional)
    └── backup (optional)
```

## Usage Patterns

### Full CMMC Deployment
```yaml
- hosts: all
  roles:
    - common
    - security-hardening
    - user-management
    - network-security
    - cmmc-compliance
    - monitoring
    - backup
```

### Minimal Compliance Setup
```yaml
- hosts: all
  roles:
    - common
    - cmmc-compliance
```

### Security Hardening Only
```yaml
- hosts: all
  roles:
    - common
    - security-hardening
```

## Configuration Variables

Each role uses a consistent variable naming convention:
- `<role_name>_<feature>_<setting>` (e.g., `cmmc_ac_ssh_port`)
- Client-specific overrides via `group_vars/client_<id>/`
- Environment-specific settings via `group_vars/<environment>/`

## Compliance Mapping

### CMMC Level 2 Controls
- **AC.1.001-003**: Access Control implementation
- **AU.1.006-012**: Audit and logging configuration  
- **CM.1.073**: Configuration management
- **IA.1.076-077**: Authentication mechanisms
- **SC.1.175-178**: System protection and encryption
- **SI.1.210-214**: System integrity monitoring

### CMMC Level 3 Additional Controls
- Enhanced monitoring and threat detection
- Advanced access controls and zero-trust implementation
- Real-time security event correlation
- Advanced persistent threat protection

## Validation and Testing

### Pre-deployment Validation
```bash
# Syntax check
ansible-playbook --syntax-check site.yml

# Dry run
ansible-playbook --check site.yml

# Limited scope test
ansible-playbook --limit test_group site.yml
```

### Post-deployment Validation
```bash
# Run compliance validation
ansible-playbook playbooks/validate-compliance.yml

# Generate compliance report
ansible-playbook playbooks/generate-report.yml
```

## Development Guidelines

### Role Development Standards
1. **Idempotency**: All tasks must be idempotent and safe to run multiple times
2. **Documentation**: Every role, task, and variable must be documented
3. **Testing**: Include molecule tests for each role
4. **Modularity**: Roles should be loosely coupled and highly cohesive
5. **Security**: Follow least-privilege principles and secure defaults

### File Structure Requirements
```
role_name/
├── README.md                 # Role-specific documentation
├── meta/main.yml            # Role metadata and dependencies
├── defaults/main.yml        # Default variables (lowest precedence)
├── vars/main.yml           # Role variables (high precedence)
├── tasks/main.yml          # Main task list
├── tasks/
│   ├── install.yml         # Installation tasks
│   ├── configure.yml       # Configuration tasks
│   ├── validate.yml        # Validation tasks
│   └── cleanup.yml         # Cleanup tasks
├── handlers/main.yml       # Service restart handlers
├── templates/              # Jinja2 templates
├── files/                  # Static files to copy
└── molecule/               # Test scenarios
```

### Variable Precedence
1. Extra vars (command line)
2. Task vars
3. Block vars
4. Role vars
5. Play vars
6. Host facts
7. Host vars
8. Group vars
9. Role defaults

## Security Considerations

### Secrets Management
- All sensitive data stored in Ansible Vault
- Vault keys managed through HashiCorp Vault integration
- No plaintext secrets in version control
- Key rotation procedures documented

### Access Control
- Role-based access control (RBAC) for Ansible Tower
- Client-specific credential isolation
- Audit logging for all automation activities
- Emergency access procedures documented

## Troubleshooting

### Common Issues
1. **Permission Errors**: Check ansible_user privileges and sudo configuration
2. **Network Connectivity**: Verify SSH access and firewall rules
3. **Package Installation**: Ensure package repositories are accessible
4. **Service Failures**: Check systemd service dependencies and configurations

### Debug Mode
```bash
# Enable verbose output
ansible-playbook -vvv site.yml

# Debug specific tasks
ansible-playbook --start-at-task="task name" site.yml

# Check variable resolution
ansible-playbook --list-hosts --list-tasks site.yml
```

## Integration Points

### AWX/Tower Integration
- Dynamic inventory from external sources
- Job templates for each compliance scenario
- Workflow templates for complex deployments
- Notification hooks for compliance alerts

### Vault Integration
- Secret injection for sensitive configurations
- Dynamic credential generation
- Certificate management automation
- Encryption key rotation

### Monitoring Integration
- Metrics collection for compliance status
- Alert routing for security events
- Dashboard integration for compliance reporting
- SLA monitoring and reporting

This role structure provides the foundation for scalable, maintainable CMMC compliance automation while ensuring maximum flexibility for client-specific requirements and graceful disconnection capabilities.