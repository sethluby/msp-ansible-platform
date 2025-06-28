# MSP Ansible Infrastructure Management Platform

A comprehensive Ansible-based infrastructure management solution for Managed Service Providers. Provides centralized automation with secure client connectivity and flexible compliance framework support.

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

## Business Model

### Service Tiers
- **Foundation**: $35-50/server/month (Basic monitoring, security hardening)
- **Professional**: $65-89/server/month (Advanced compliance, custom automation)  
- **Enterprise**: $95-125/server/month (Premium compliance frameworks including CMMC, dedicated support)

### Value Proposition
- **50-70% cost reduction** vs in-house compliance teams
- **99.9% compliance** success rate target
- **No vendor lock-in** - clients retain full automation capabilities
- **24/7 monitoring** with automated remediation

## Project Structure

```
msp-ansible-platform/
├── docs/                    # Architecture and deployment guides
├── infrastructure/          # MSP infrastructure specifications
├── ansible/                 # Core automation playbooks and roles
│   ├── roles/              # Reusable automation roles
│   ├── playbooks/          # Orchestration playbooks
│   ├── inventory/          # Multi-client inventory management
│   └── group_vars/         # Client-specific variables
├── client-templates/       # Service tier templates
│   ├── foundation/         # Foundation tier configuration
│   ├── professional/      # Professional tier configuration  
│   └── enterprise/         # Enterprise tier configuration
├── msp-infrastructure/     # MSP core services deployment
│   ├── docker-compose.yml  # Core services definition
│   ├── configs/            # Service configurations
│   └── scripts/            # Deployment automation
└── compliance/             # Compliance framework implementations
    ├── frameworks/         # SOC2, HIPAA, PCI-DSS, CMMC, NIST, etc.
    ├── validation/         # Compliance checking scripts
    └── reporting/          # Dashboard and report generation
```

## Current Status

**Phase**: Production Ready (100%)  
**Version**: 1.0.0-beta  
**Last Updated**: 2025-06-28

### ✅ **Production Complete - 10 Enterprise Playbooks**
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

### ✅ **Enterprise Architecture Complete**
- **Multi-tenant isolation** - Client-specific variables, logging, and session tracking
- **MSP operational excellence** - Centralized logging, rollback capabilities, error handling
- **Security compliance** - DISA STIG, CMMC Level 2/3, CIS benchmarks automated
- **Production hardening** - Maintenance windows, verification, audit trails
- **Comprehensive documentation** - 50+ page playbook reference, operational guides

### 🚀 **Next Phase - Client Deployment Models**
- **Pull-based architecture** - Client-initiated automation every 15 minutes
- **Bastion host deployment** - Lightweight WireGuard-based secure connectivity
- **Reverse tunnel architecture** - MSP-initiated secure connections through client bastions
- **AWX/Tower integration** - Centralized orchestration with web UI and API
- **Client onboarding automation** - Streamlined deployment across all architectures

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

## Contact & Support

- **Repository**: [GitHub Issues and Discussions](https://github.com/sethluby/msp-ansible-platform)
- **Documentation**: Comprehensive guides in docs/ directory
- **Contributing**: See CONTRIBUTING.md for development guidelines