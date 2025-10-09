# MSP Ansible Infrastructure Management Platform

A comprehensive Ansible-based infrastructure management solution for Managed Service Providers. Provides centralized automation with secure client connectivity and flexible compliance framework support.

## ⚠️ Important Notice: Testing and Validation Platform

**This is a comprehensive testing and validation platform, not a production-ready solution.** This project provides:
- Complete testing frameworks for MSP automation concepts
- Comprehensive validation tools for compliance and security automation
- Pilot testing infrastructure for controlled MSP partner evaluation
- Research framework for business model validation

**For Production Use**: Extensive testing, security auditing, and compliance validation would be required before any production deployment. This platform is designed for research, testing, and pilot program evaluation.

## Quick Start

### Repository Setup
```bash
# Clone and setup
git clone https://github.com/sethluby/msp-ansible-platform.git
cd msp-ansible-platform

# Initial setup
ansible-galaxy install -r requirements.yml
cp .env.example .env
# Edit .env with your configuration
```

### Usage Paths: Baseline vs CMMC Overlay

- Baseline MSP (common operations)
  - Patching: `ansible-playbook ansible/playbooks/system-update.yml -e client_name=acme`
  - Users: `ansible-playbook ansible/playbooks/user-management.yml -e client_name=acme -e user_operation=audit`
  - Backup/Monitoring: include `backup` and `monitoring` roles per client vars

- CMMC Overlay (selected controls)
  - ansible-lockdown integration: `ansible-playbooks/integrate-lockdown-compliance.yml -e client_name=acme -e client_compliance_framework=cis`
  - Validation: `ansible-playbooks/validate-compliance.yml -e cmmc_level=level2 -e cmmc_client_id=acme`
  - Control mapping: see `docs/cmmc-control-mapping.md`

### Quickstart Demo

Run a local Molecule demo of the default scenario (Docker required):

```bash
make quickstart-demo
# Cleanup when done
make quickstart-destroy
```

## Architecture Overview

### Core Design Principles
- **Maximum Modularity** - Docker-based services for easy deployment/removal
- **Graceful Disconnection** - Clients can operate independently after MSP departure
- **Minimal Infrastructure** - Lightweight bastion hosts (2 vCPU, 4GB RAM)
- **Compliance Ready** - Modular framework supporting multiple compliance standards

### Essential Services Stack
```yaml
# MSP infrastructure deployment
services:
  ansible-awx:     # Automation orchestration
  vault:           # Secrets management  
  redis:           # AWX dependency
  postgres:        # AWX database
```

<!-- Archived business model content moved to docs/BUSINESS_MODEL_RESEARCH.md -->

## Project Structure

```
msp-ansible-platform/
├── docs/                       # Architecture and deployment guides
├── bootstrap/                  # Client bootstrap scripts for all architectures
│   ├── bootstrap-pull-based.sh       # Pull-based architecture setup
│   ├── bootstrap-bastion-host.sh     # WireGuard bastion deployment
│   └── bootstrap-reverse-tunnel.sh   # SSH reverse tunnel setup
├── ansible/                    # Core automation playbooks and roles
│   ├── roles/                 # Reusable automation roles
│   │   ├── msp-infrastructure/        # MSP platform deployment
│   │   ├── client-pull-infrastructure/ # Pull-based client setup
│   │   ├── bastion-infrastructure/    # WireGuard bastion configuration
│   │   └── reverse-tunnel-infrastructure/ # SSH tunnel setup
│   ├── playbooks/             # Enterprise automation playbooks (10 complete)
│   │   ├── deploy-msp-infrastructure.yml    # MSP platform deployment
│   │   ├── deploy-client-infrastructure.yml # Multi-architecture client deployment
│   │   ├── system-update.yml             # Multi-OS patch management
│   │   ├── disa-stig-compliance.yml      # DISA STIG automation
│   │   ├── cmmc-compliance.yml           # CMMC Level 2/3 implementation
│   │   └── [5 additional enterprise playbooks]
│   ├── inventory/             # Multi-client inventory management
│   └── group_vars/            # Client-specific variables
├── client-templates/          # Service tier templates
├── msp-infrastructure/        # MSP core services deployment
└── compliance/                # Compliance framework implementations
```

### Example Inventory (optional)

See `ansible/inventory/examples/hosts.yml` and `ansible/inventory/examples/group_vars/client_acme/main.yml` for a minimal client layout you can copy into your environment.

### Lab Setup Guide
For a step-by-step MSP lab walk‑through (baseline and connectivity paths), see `docs/LAB_SETUP_GUIDE.md`.

## Current Status

Status: Testing and validation platform; pilot-ready components.

### Implemented Playbooks
- **system-update.yml** - Multi-OS patch management (RHEL, Ubuntu, SUSE) with maintenance windows
- **disa-stig-compliance.yml** - 10+ DISA security controls with client exceptions
- **cmmc-compliance.yml** - CMMC Level 2/3 automation across 8+ security domains
- **user-management.yml** - Complete lifecycle (create, modify, remove, audit) with client isolation
- **firewall-management.yml** - Multi-distribution support (firewalld, ufw, iptables)
- **security-hardening.yml** - CIS benchmarks with auto-detection and profile-based hardening
- **monitoring-alerting.yml** - Prometheus + custom metrics with client-specific thresholds
- **backup-recovery.yml** - Comprehensive data protection with encryption and verification
- **service-management.yml** - Systemd service lifecycle with policy-based automation
- **inventory-collection.yml** - Asset management with multiple output formats
- **onboard-client.yml** - ✨ **NEW** - Automated client onboarding with VPN, SSH keys, and tier-based configuration
- **prepare-disconnection.yml** - ✨ **NEW** - Graceful client disconnection with independence validation

### Architecture Highlights
- **Multi-tenant isolation** - Client-specific variables, logging, and session tracking
- **MSP operational excellence** - Centralized logging, rollback capabilities, error handling
- **Security compliance** - DISA STIG, CMMC Level 2/3, CIS benchmarks automated
- **Production hardening** - Maintenance windows, verification, audit trails
- **Comprehensive documentation** - 50+ page playbook reference, operational guides
- **✨ Complete Ansible Role Suite** - 7 production roles: client-onboarding, graceful-disconnection, common, monitoring, backup, user-management, network-security

### Infrastructure Deployment
- **deploy-msp-infrastructure.yml** - Complete MSP platform deployment with monitoring stack
- **deploy-client-infrastructure.yml** - Multi-architecture client deployment automation
- **Bootstrap scripts** - Production-ready setup for all three deployment architectures
- **Infrastructure roles** - Reusable components for MSP and client infrastructure
- **Three deployment architectures** - Client choice between pull-based, bastion host, or reverse tunnel

### 🚀 **Three Optional Client Deployment Architectures**
1. **Pull-Based Architecture** - Client systems autonomously pull automation every 15 minutes
   - Maximum client control and autonomy
   - Minimal network requirements (HTTPS only)
   - Air-gap compatible with periodic sync
   - Bootstrap: `bootstrap/bootstrap-pull-based.sh`

2. **Bastion Host Architecture** - Lightweight WireGuard VPN connectivity
   - Real-time monitoring and immediate response
   - Alpine Linux bastion hosts (512MB RAM)
   - Secure VPN tunnels with network segmentation
   - Bootstrap: `bootstrap/bootstrap-bastion-host.sh`

3. **Reverse Tunnel Architecture** - Maximum security SSH reverse tunnels
   - Zero inbound connections to client networks
   - Certificate-based authentication and audit trails
   - Highest security for regulated environments
   - Bootstrap: `bootstrap/bootstrap-reverse-tunnel.sh`

**Key Innovation**: Clients can choose ANY combination of these architectures based on their specific security, network, and operational requirements.

## Feature Highlights

### New Major Features
- **Automated Client Onboarding** - End-to-end client setup
  - Interactive playbook with service tier selection (Foundation/Professional/Enterprise)
  - Automated WireGuard VPN deployment with pre-shared keys
  - SSH key generation and distribution
  - Client-specific directory structure and configuration
  - Tier-based compliance framework initialization
  - Generated documentation and handover packages

- **Graceful Client Disconnection** - MSP independence workflow
  - Automated removal of MSP-specific endpoints and credentials
  - Local-only operation configuration with independence validation
  - Generated emergency procedures and local operations guide
  - Complete handover documentation with troubleshooting guides
  - Compliance tool preservation for continued independent operation

- **📊 Master Site Orchestration** - Centralized multi-client management
  - Single playbook orchestrates all MSP operations across clients
  - Service tier filtering and bulk operations support
  - Health monitoring and resource management
  - Comprehensive operation reporting and audit logging

### Testing & CI/CD Coverage
- **✨ Molecule testing framework** - Comprehensive automated role testing with Docker containers
- **✨ GitHub Actions CI/CD** - Full pipeline with lint, syntax check, security scan, and integration tests
- **✨ Development toolkit** - Makefile with 25+ commands for development, testing, and deployment
- **✨ Code quality tools** - ansible-lint, yamllint, security scanning, and documentation generation

### Implemented Capabilities
- Complete client onboarding automation with service tiers
- Graceful disconnection with independence validation
- Comprehensive Ansible role suite (7 roles)
- Master site orchestration playbook
- Multi-tenant client isolation with tier-based configurations
- Compliance framework automation (CMMC, DISA STIG, CIS)
- Documentation and operational guides
- Molecule testing framework for automated role validation
- CI/CD pipeline with security scanning and quality gates
- Development toolkit for testing and deployment

## Development Workflow

### Documentation Standards
- Keep README current with project status
- Document architectural decisions and trade-offs
- Version control all changes
- Update changelog for significant changes

### Git Workflow
- **Public Repository**: `https://github.com/sethluby/msp-ansible-platform`
- Main branch for stable releases
- Feature branches for development
- Pull requests for code review

## Market Opportunity

- **Growing MSP market** seeking automation and compliance solutions
- **Linux infrastructure complexity** requiring specialized expertise
- **Multiple compliance frameworks** across industries (healthcare, finance, government)
- **Security-first architecture** addressing modern threat landscape

## Getting Started

1. **Review Documentation**: Read `docs/` for detailed architecture
2. **Setup Environment**: Follow infrastructure requirements
3. **Deploy MSP Infrastructure**: Use `msp-infrastructure/docker-compose.yml`
4. **Configure Ansible**: Setup roles and playbooks
5. **Validate Compliance**: Run compliance framework checks

## External Resources

### Community Ansible Roles
The project leverages proven patterns from established community roles:
- **Security Hardening**: ansible-lockdown CIS/STIG roles, dev-sec SSH hardening
- **Audit Configuration**: willshersystems auditd role for comprehensive logging
- **User Management**: debops user management for access control implementation
- **Monitoring**: cloudalchemy Prometheus stack for observability

See project wiki for complete integration details and implementation guides.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact & Support

- **Repository**: [GitHub Issues and Discussions](https://github.com/sethluby/msp-ansible-platform)
- **Documentation**: Comprehensive guides in docs/ directory
- **Contributing**: See CONTRIBUTING.md for development guidelines
- **License**: MIT License for maximum flexibility and community collaboration
