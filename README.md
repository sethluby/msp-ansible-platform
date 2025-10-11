# MSP Ansible Infrastructure Management Platform

## Architecture At-a-Glance

```text
[MSP Control Plane]
  AWX/Controller + Vault + CI/CD + SIEM
       |  Connectivity per client (choose one or mix)
       +-- Pull (HTTPS)      -> clients pull playbooks; run locally
       +-- WireGuard Bastion -> AWX SSH/WinRM via VPN to client networks
       +-- Reverse SSH       -> client agents maintain tunnels; AWX via loopback
  Targets: Azure | AWS | GCP (VMs, Kubernetes nodes, selected PaaS*)
  *PaaS coverage depends on available modules and access model
```

A comprehensive Ansible-based infrastructure management solution for Managed Service Providers. Provides centralized automation with secure client connectivity and flexible compliance framework support.

## ⚠️ Important Notice: Testing and Validation Platform

**This is a comprehensive testing and validation platform, not a production-ready solution.** This project provides:
- Complete testing frameworks for MSP automation concepts
- Comprehensive validation tools for compliance and security automation
- Pilot testing infrastructure for controlled MSP partner evaluation
- Research framework for business model validation

**For Production Use**: Extensive testing, security auditing, and compliance validation would be required before any production deployment. This platform is designed for research, testing, and pilot program evaluation.

## MSP Architecture (Azure/AWS/GCP)

The platform is cloud-agnostic with three client connectivity patterns. From the MSP’s perspective you operate a single control plane that safely automates tenants across Azure, AWS, and GCP.

```text
+--------------------------------------------------------------+
| MSP Control Plane                                            |
|                                                              |
|  GitHub (Ansible repo, IaC)  ->  CI/CD (lint/test)           |
|                \                                              |
|                 \                                             |
|  Ansible AWX/Controller  <-->  Vault (secrets)               |
|          |                         |                          |
|          +---- Reports/Artifacts --+--> SIEM/Log Store        |
+--------------------------------------------------------------+

Client Connectivity Patterns (choose per-tenant, mix as needed)

  [1] Pull-Based (outbound-only)
      Client cron/systemd timer -> HTTPS pull from Git repo
      Client runs Ansible locally; ships logs to MSP SIEM (HTTPS)

  [2] Bastion (WireGuard hub-and-spoke)
      AWX -> MSP WireGuard Hub ==VPN== Client WireGuard Peer -> Nodes (SSH/WinRM)

  [3] Reverse Tunnel (outbound-only)
      Client reverse-SSH agent ==> MSP Tunnel Host; AWX connects via loopback ports

Legend: 'outbound-only' means no inbound rules on client networks.
```

### Architecture Decision Matrix

- Pull-Based (HTTPS-only)
  - Choose when: outbound-only networks, high client autonomy, air-gapped/partially connected.
  - Pros: no inbound rules, simple operations, scales with Git, resilient to MSP outages.
  - Considerations: local timers/agents, slower control loop, local secret bootstrap required.

- Bastion (WireGuard hub-and-spoke)
  - Choose when: need real-time operations, interactive troubleshooting, central execution from AWX.
  - Pros: direct access over VPN, low-latency jobs, centralized secrets in Vault/AWX.
  - Considerations: manage WG keys/peers, small per-tenant VM, network change control for VPN.

- Reverse Tunnel (SSH)
  - Choose when: zero inbound allowed, strict compliance, ephemeral just-in-time access.
  - Pros: zero inbound exposure, granular port forwards, strong audit trail of access paths.
  - Considerations: tunnel host operations, agent resilience, port-forward allocation/scale.

### End-to-End Architecture (MSP + Clients)

```text
+------------------------------------- MSP Control Plane -------------------------------------+
| GitHub (repo)  CI/CD   |   AWX/Controller   |   Vault (per-tenant secrets)   |   SIEM/Logs   |
|         \              |         |          |                |                |              |
|          \             |     +---+----+    |          +-----+-----+        +--+--+          |
|           \            |     |  WG Hub |<=========>   | Tunnel Host |<=====> Port Forwards   |
|            \           |     +--------+                +-----------+        (reverse-SSH)    |
+------------------------+---------------------------------------------------------------------------
                         |                         |                         |
                         |                         |                         |
                (B) Bastion VPN             (C) Reverse Tunnels        (A) Pull-Based
                         |                         |                         |
+------------------------v-------------------------v-------------------------v------------------+
|                                   Clients (Multi-Cloud Tenants)                               |
|  Client A (Azure)                 Client B (AWS)                    Client C (GCP)            |
|  +------------------+            +------------------+               +------------------+      |
|  | Bastion (WG peer)|<==========>| AWX via WG       |               | Reverse agents   |=====>|
|  | (optional)       |            | (optional)       |               | to Tunnel Host   |      |
|  +--+-----------+---+            +----+--------+----+               +----+--------+----+      |
|     |           |                     |        |                          |        |          |
|   SSH/WinRM   HTTPS (pull)         SSH/WinRM  HTTPS (pull)              SSH/WinRM  HTTPS (pull)|
|     |           |                     |        |                          |        |          |
|  Targets: VMs, AKS nodes,        Targets: EC2, EKS nodes,           Targets: GCE, GKE nodes,   |
|           PaaS (supported)                PaaS (supported)                  PaaS (supported)   |
|                                                                                               |
| Notes:                                                                                        |
| - Pull-Based: nodes/agents pull playbooks from Git (HTTPS) and run locally.                   |
| - Bastion: AWX reaches targets over WireGuard via client bastion peer.                        |
| - Reverse: client agents maintain reverse-SSH to MSP Tunnel Host; AWX uses loopback ports.    |
+------------------------------------------------------------------------------------------------+

Operational model: multi-tenant inventories and per-client secrets in Vault; connectivity per-client.
```

#### Tenant Isolation & Inventory Model
- Separate inventory groups per client (see `ansible/inventory/examples/hosts.yml`).
- Client-specific configuration under `ansible/inventory/examples/group_vars/client_<name>/`.
- Per-tenant secrets isolated in Vault (KV pathing by client); AWX templates map vars to secrets.
- Network isolation via dedicated WG peers or independent reverse tunnels per client.

#### Identity & RBAC (AWX, optional IdP/SSO)
- IdP/SSO: Integrate AWX/Controller with OIDC or SAML (e.g., Entra ID/Azure AD, Okta, Google Workspace).
- Tenancy model: One AWX Organization per client; Projects/Inventories scoped to that Org.
- RBAC: Teams per client with least-privilege roles (e.g., Execute on Job Templates, limited Inventory).
- Credentials: Store per-tenant credentials in AWX and Vault; avoid embedding secrets in projects.
- Approvals: Use Workflow Job Templates with approval gates for sensitive operations.
- Audit: Forward AWX logs/events to SIEM; ensure IdP group-to-role mappings are auditable.

#### Client Lifecycle & Data Flows
- Onboarding: `ansible/playbooks/onboard-client.yml` provisions keys, optional VPN, monitoring, docs.
- Operations: AWX job templates target client groups; modules use SSH/WinRM (or local for pull-based).
- Compliance/Reporting: playbooks run controls; logs route to SIEM and client’s native logging if desired.
- Graceful Disconnection: `ansible/playbooks/prepare-disconnection.yml` removes MSP endpoints and hands off.

### Azure (Tenant) – MSP View

```text
+------------------------------- Azure Subscription (Tenant) -------------------------------+
|                                                                                           |
|  VNet(s) & Subnets                                                                        |
|   +----------------------+     +----------------------+     +---------------------------+  |
|   | Linux/Windows VMs    |     | AKS worker nodes     |     | PaaS (optional targets)   |  |
|   +----------+-----------+     +----------+-----------+     +-------------+-------------+  |
|              |                            |                               |                |
|              |                            |                               |                |
|   (opt) Azure Arc/Automation*  (opt) guest mgmt agents*                  (opt) APIs*       |
|              |                            |                               |                |
|   (A) Pull-Based: VMs/Nodes pull playbooks from Git (HTTPS)                               |
|   (B) Bastion:    Small VM runs WireGuard Peer  <== VPN ==>  MSP WireGuard Hub            |
|                   AWX -> SSH/WinRM via WG IPs to targets                                   |
|   (C) Reverse:    Reverse-SSH agents on targets  ==>  MSP Tunnel Host -> AWX loopback      |
|                                                                                           |
|   Optional client-native services: Key Vault (secrets), Log Analytics (logs)               |
+-------------------------------------------------------------------------------------------+

MSP Control Plane: AWX/Controller, Vault, CI/CD, SIEM (multi-tenant feeds)
*Azure-native integrations are optional; default path is SSH/WinRM over WG or reverse tunnel.
```

### AWS (Tenant) – MSP View

```text
+-------------------------------------- AWS Account (Tenant) --------------------------------------+
|                                                                                                  |
|  VPC, private subnets                                                                             |
|   +----------------------+    +----------------------+    +-----------------------------------+  |
|   | EC2 Linux/Windows    |    | EKS worker nodes     |    | RDS/ElastiCache/etc (optional)    |  |
|   +----------+-----------+    +----------+-----------+    +--------------------+---------------+  |
|              |                           |                                   |                  |
|              |                           |                                   |                  |
|   (opt) SSM Agent* (RunCommand/Patch)    |                                   |                  |
|              |                           |                                   |                  |
|   (A) Pull-Based: Instances pull from Git (HTTPS); logs to CloudWatch -> MSP SIEM (optional)     |
|   (B) Bastion:    Small EC2 runs WireGuard Peer <== VPN ==> MSP WireGuard Hub;                   |
|                   AWX -> SSH/WinRM over WG to targets                                            |
|   (C) Reverse:    Reverse-SSH agents on targets ==> MSP Tunnel Host -> AWX loopback               |
|                                                                                                  |
|   Optional client-native services: Secrets Manager/Parameter Store (client-owned), CloudWatch     |
+--------------------------------------------------------------------------------------------------+

MSP Control Plane: AWX/Controller, Vault, CI/CD, SIEM (multi-tenant feeds)
*SSM can be used by agreement for patch/exec; default path is SSH/WinRM via WG or reverse tunnel.
```

### GCP (Tenant) – MSP View

```text
+---------------------------------------- GCP Project (Tenant) ---------------------------------------+
|                                                                                                      |
|  VPC, private subnets                                                                                 |
|   +----------------------+    +----------------------+    +---------------------------------------+   |
|   | GCE Linux/Windows    |    | GKE worker nodes     |    | Cloud SQL/Memorystore (optional)      |   |
|   +----------+-----------+    +----------+-----------+    +----------------------+----------------+   |
|              |                           |                                 |                        |
|              |                           |                                 |                        |
|   (opt) OS Config/OS Inventory*         |                                 |                        |
|              |                           |                                 |                        |
|   (A) Pull-Based: Instances pull from Git (HTTPS); logs to Cloud Logging -> MSP SIEM (optional)      |
|   (B) Bastion:    Small GCE runs WireGuard Peer <== VPN ==> MSP WireGuard Hub;                       |
|                   AWX -> SSH/WinRM over WG to targets                                                |
|   (C) Reverse:    Reverse-SSH agents on targets ==> MSP Tunnel Host -> AWX loopback                   |
|                                                                                                      |
|   Optional client-native services: Secret Manager (client-owned), Cloud Logging/Monitoring            |
+------------------------------------------------------------------------------------------------------+ 

MSP Control Plane: AWX/Controller, Vault, CI/CD, SIEM (multi-tenant feeds)
*OS Config can be used for inventory/patch; default path is SSH/WinRM via WG or reverse tunnel.
```

### On-Prem (vSphere) – MSP View

```text
+--------------------------------------- vSphere (On‑Prem Tenant) ---------------------------------------+
|                                                                                                        |
|  vCenter + ESXi hosts                                                                                  |
|   +----------------------+   +----------------------+    +-----------------------------------------+   |
|   | Linux/Windows VMs    |   | k3s worker nodes     |    | Optional services (vSphere CSI/NSX)     |   |
|   +----------+-----------+   +----------+-----------+    +----------------------+------------------+   |
|              |                          |                                      |                      |
|              |                          |                                      |                      |
|  (A) Pull-Based: nodes pull from Git (HTTPS)                                    |                      |
|  (B) Bastion: WireGuard peer VM <== VPN ==> MSP WG Hub; AWX -> SSH/WinRM over WG IPs                  |
|  (C) Reverse: reverse-SSH agents ==> MSP Tunnel Host -> AWX loopback                                   |
|                                                                                                        |
|  Optional on‑prem analogs to cloud services:                                                           |
|  - ACR  -> Harbor (registry)                                                                           |
|  - Blob -> MinIO (S3-compatible)                                                                       |
|  - KeyVault -> HashiCorp Vault                                                                         |
|  - AKS  -> k3s (3 VMs) with NGINX Ingress + cert-manager + storage (Longhorn or NFS provisioner)       |
|  - Redis/Postgres: VMs or Helm charts with persistent volumes                                          |
+--------------------------------------------------------------------------------------------------------+

MSP Control Plane (self‑hosted on k3s): AWX (Operator), Harbor, MinIO, Vault, Redis, Postgres, Ingress
```

On‑prem quickstart inventory: `ansible/inventory/lab-vsphere/` (reuses global playbooks).

Key repo entry points for each pattern:
- Pull-Based: `bootstrap/bootstrap-pull-based.sh` (timer-based pull + local apply)
- Bastion (WireGuard): `bootstrap/bootstrap-bastion-host.sh` (client peer) and AWX inventory uses WG IPs
- Reverse Tunnel: `bootstrap/bootstrap-reverse-tunnel.sh` (per-node agent) and AWX connects via loopback

Primary orchestration playbooks:
- MSP core: `ansible/playbooks/deploy-msp-infrastructure.yml`
- Client infra (choose pattern): `ansible/playbooks/deploy-client-infrastructure.yml`

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

### On‑Prem vSphere Quickstart
- Inventory and docs: `ansible/inventory/lab-vsphere/README.md`
- Fill placement and VM specs:
  - `ansible/inventory/lab-vsphere/group_vars/vcenter/main.yml`
  - `ansible/inventory/lab-vsphere/group_vars/all/vsphere_provision.yml`
  - Copy and encrypt secrets: `ansible/inventory/lab-vsphere/vault.sample.yml` → `vault.yml`
- Install Ansible collections/roles:
  - `ansible-galaxy install -r requirements.yml --force`
- Optional preflight summary (templates/networks):
  - `ansible-playbook -i ansible/inventory/lab-vsphere/hosts.yml ansible/playbooks/vsphere-preflight.yml --ask-vault-pass`
- Provision VMs on vCenter:
  - `ansible-playbook -i ansible/inventory/lab-vsphere/hosts.yml ansible/playbooks/vsphere-provision.yml --ask-vault-pass`
  - Playbook used: `ansible/playbooks/vsphere-provision.yml`

- Destroy VMs (careful):
  - Provide list via `vsphere_destroy_names` or reuse names from `vsphere_vms`
  - `ansible-playbook -i ansible/inventory/lab-vsphere/hosts.yml ansible/playbooks/vsphere-destroy.yml -e vsphere_destroy_confirm=true --ask-vault-pass`
  - Playbook used: `ansible/playbooks/vsphere-destroy.yml`

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

⚠️ **Note**: The quickstart demo is currently in development. Some Ansible Galaxy roles referenced in `requirements.yml` are not yet available or configured. For new contributors:

```bash
# First-time setup (creates virtual environment and installs dependencies)
make bootstrap

# After bootstrap, you can run:
make lint          # Code quality checks
make syntax-check  # Playbook syntax validation
make test-quick    # Fast tests (syntax + lint)

# Molecule testing (requires additional configuration)
# make quickstart-demo  # Currently in development
```

For production deployments, see the detailed setup guide in `docs/LAB_SETUP_GUIDE.md`.

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

## Terraform (Azure-First) Scaffolding

- Azure-first Terraform scaffold for MSP landing zones and logging.
- Start here: `msp-infrastructure/terraform/README.md`
- Overview doc: `docs/TERRAFORM_OVERVIEW.md`
- Live examples (safe to plan): `msp-infrastructure/terraform/live/clients/exampleco/dev/`

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Contact & Support

- **Repository**: [GitHub Issues and Discussions](https://github.com/sethluby/msp-ansible-platform)
- **Documentation**: Comprehensive guides in docs/ directory
- **Contributing**: See CONTRIBUTING.md for development guidelines
- **License**: MIT License for maximum flexibility and community collaboration
