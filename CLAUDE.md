# MSP Ansible Infrastructure Management Platform

## Project Overview
Comprehensive Ansible-based infrastructure management solution for Managed Service Providers (MSPs). Provides centralized automation orchestration with secure WireGuard connectivity to client Linux environments. CMMC compliance capabilities included as premium service tier.

## Quick Commands
```bash
# Development setup
ansible-playbook setup.yml                    # Initialize MSP infrastructure
ansible-playbook client-onboard.yml -e client=newcorp  # Onboard new client

# Daily operations
ansible-playbook security-hardening.yml       # Apply security baselines
ansible-playbook patch-management.yml         # Staged security updates
ansible-playbook compliance-audit.yml         # Run compliance validation

# Client management
ansible-inventory --list                      # View multi-tenant inventory
ansible all -m ping --limit client_newcorp   # Test client connectivity
ansible-vault edit group_vars/client_newcorp/vault.yml  # Manage client secrets
```

## Core Architecture

### MSP Infrastructure (Hub)
- **Ansible Tower/AWX**: Centralized automation orchestration
- **HashiCorp Vault**: Secrets management and PKI
- **WireGuard Hub**: Secure client connectivity
- **Multi-tenant isolation**: Complete client separation

### Client Infrastructure (Spoke)
- **WireGuard endpoint**: Secure tunnel to MSP infrastructure
- **Local network preservation**: No disruption to existing networking
- **Minimal footprint**: Agent-less Ansible management
- **Self-contained**: Graceful MSP disconnection capability

## Service Tiers

### Foundation Tier ($35-50/server/month)
- Basic system monitoring and alerting
- Automated security patching
- System hardening (CIS benchmarks)
- Configuration management

### Professional Tier ($65-89/server/month)
- Everything in Foundation plus:
- Advanced compliance frameworks (SOC2, HIPAA, PCI-DSS)
- Incident response automation
- Custom playbook development
- 24/7 monitoring and alerting

### Enterprise Tier ($95-125/server/month)
- Everything in Professional plus:
- CMMC Level 2/3 compliance automation
- Advanced threat detection and response
- Disaster recovery orchestration
- Dedicated compliance reporting

## Code Style & Standards

### Ansible Best Practices
- Use fully qualified collection names (ansible.builtin.*)
- Implement idempotency for all tasks
- Use ansible-vault for all sensitive data
- Follow YAML formatting with 2-space indentation
- Tag all tasks for selective execution

### Directory Structure
```
roles/
├── common/              # Base system configuration
├── security/            # Security hardening roles
├── compliance/          # Compliance frameworks (CMMC, SOC2, etc.)
└── client-specific/     # Client customizations

playbooks/
├── site.yml            # Master playbook
├── client-onboard.yml  # Client onboarding automation
└── compliance/         # Compliance-specific playbooks

inventory/
├── production/         # Multi-client production inventory
├── staging/           # Staging environment
└── group_vars/        # Client-specific variables
```

### Testing Requirements
```bash
# Always run before commits
ansible-lint playbooks/    # Lint all playbooks
ansible-playbook --check   # Dry-run validation
molecule test             # Role testing (where applicable)
```

## Supported Environments
- **Operating Systems**: RHEL/CentOS/Rocky 7-9, Ubuntu 18.04-24.04, SLES 12-15
- **Scale**: 5-500+ Linux systems per client
- **Network**: WireGuard VPN, firewall automation, network segmentation
- **Cloud Platforms**: AWS, Azure, GCP, on-premises

## Client Onboarding Workflow

### Prerequisites
- Client Linux systems with SSH access
- Network connectivity for WireGuard (UDP 51820)
- Sudo/root access for initial setup

### Automated Setup Process
1. **WireGuard Deployment**: Secure tunnel establishment
2. **Ansible Bootstrap**: Install Python and SSH keys
3. **Inventory Integration**: Add to multi-tenant inventory
4. **Security Baseline**: Apply CIS benchmarks and hardening
5. **Monitoring Setup**: Deploy agents and configure alerting

## Development Environment

### Local Setup
```bash
# Install dependencies
pip install ansible ansible-lint molecule
ansible-galaxy install -r requirements.yml

# Configure vault password
echo "your-vault-password" > .vault_pass

# Test connectivity
ansible all -m ping
```

### Git Workflow
- Feature branches for all development
- Ansible-lint must pass before merge
- All secrets encrypted with ansible-vault
- Commit messages follow conventional commits

## Security Considerations

### Network Security
- WireGuard with rotating PSKs
- Client network isolation via VRF
- Firewall automation with fail-safe defaults
- Certificate-based authentication

### Data Protection
- Secrets stored in HashiCorp Vault
- Encryption in transit and at rest
- Audit logging for all operations
- Client data isolation (multi-tenancy)

## Compliance Frameworks

### CMMC (Cybersecurity Maturity Model Certification)
- Level 2 and Level 3 automation
- 17 domain coverage (AC, AU, CM, IA, SC, SI, etc.)
- Continuous monitoring and validation
- Gap analysis and remediation

### Other Supported Frameworks
- SOC 2 Type II
- HIPAA/HITECH
- PCI-DSS
- NIST 800-53
- ISO 27001

## Performance Optimization
- Parallel execution with strategy: linear
- Connection pooling and persistent connections
- Inventory caching for large deployments
- Selective task execution with tags

## Troubleshooting

### Common Issues
- **WireGuard connectivity**: Check firewall rules and NAT
- **Ansible timeouts**: Increase timeout values in ansible.cfg
- **Vault decryption**: Verify .vault_pass file permissions
- **SSH key authentication**: Use ansible-playbook -vvv for debugging

### Debug Commands
```bash
# Connection testing
ansible all -m ping -vvv

# Inventory debugging
ansible-inventory --list --yaml

# Playbook debugging
ansible-playbook site.yml --check --diff -vvv
```

## Migration to Public GitHub

### Repository Preparation
- Remove all sensitive data (IPs, passwords, certificates)
- Sanitize commit history if needed
- Update documentation for public consumption
- Add comprehensive README.md

### Public Repository Benefits
- Community contributions and feedback
- Portfolio showcase for MSP automation expertise
- Open-source credibility for enterprise sales
- Industry thought leadership positioning

## Changelog

### 2025-06-27 - Strategic Pivot and Public Release Preparation
- **✅ COMPLETED: Scope expansion** - Pivoted from CMMC-only to comprehensive MSP platform
- **✅ COMPLETED: Architecture redesign** - WireGuard-based client connectivity model
- **✅ COMPLETED: Service tier restructuring** - Foundation/Professional/Enterprise pricing model
- **✅ COMPLETED: CLAUDE.md restructure** - Following Claude Code best practices for maintainability
- **🚀 PLANNED: Public GitHub migration** - Prepare for open-source community engagement

### 2025-06-19 - Initial CMMC Implementation
- **Core CMMC compliance roles** - AC, AU, CM, IA, SC, SI control families
- **Security hardening framework** - CIS benchmarks with multiple security levels
- **Compliance validation system** - Independent Python validator
- **Multi-client infrastructure** - Dynamic inventory with Vault integration

### Earlier 2025-06-19 - Project Foundation
- **Initial architecture design** - Hub-and-spoke with bastion hosts
- **Git repository setup** - Version control and automated backups
- **Documentation framework** - Technical and business documentation structure