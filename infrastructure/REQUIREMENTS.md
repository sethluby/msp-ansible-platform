# Required Infrastructure Specifications

## Minimum Infrastructure Requirements

### MSP Data Center Components

#### Core Control Plane
- **Ansible Tower/AWX Controller**
  - CPU: 4 vCPU minimum, 8 vCPU recommended
  - Memory: 8GB minimum, 16GB recommended  
  - Storage: 100GB SSD minimum
  - OS: RHEL 8/9 or Ubuntu 20.04/22.04 LTS

- **HashiCorp Vault Cluster**
  - CPU: 2 vCPU per node (3-node cluster)
  - Memory: 4GB per node minimum
  - Storage: 50GB SSD per node
  - Network: Low-latency between nodes (<10ms)

#### Regional Bastion Infrastructure
- **Bastion Host (per region/client cluster)**
  - CPU: 2 vCPU minimum
  - Memory: 4GB minimum
  - Storage: 50GB SSD
  - OS: RHEL 8/9 or Ubuntu 20.04/22.04 LTS
  - Docker Engine 20.10+

### Client Site Requirements

#### Lightweight Client Bastion
- **Minimal Docker Host**
  - CPU: 2 vCPU
  - Memory: 4GB RAM
  - Storage: 50GB SSD minimum
  - Network: Reliable internet (10Mbps minimum)
  - OS: RHEL 8/9, Ubuntu 20.04/22.04, or Rocky Linux 8/9

#### Docker Service Stack
```yaml
# Resource allocation per service
services:
  ansible-awx:
    memory: 2GB
    cpu: 1.0
  
  vault:
    memory: 1GB  
    cpu: 0.5
    
  postgres:
    memory: 512MB
    cpu: 0.3
    
  redis:
    memory: 256MB
    cpu: 0.2
```

### Network Requirements

#### Connectivity
- **VPN Tunnels**: IPSec or WireGuard between MSP and clients
- **SSH Access**: Port 22 (or custom) from MSP bastions only
- **Management Ports**: 
  - AWX Web UI: 8080 (internal only)
  - Vault API: 8200 (internal only)
  - Node Exporter: 9100 (optional monitoring)

#### Security
- **Firewall Rules**: Restrictive ingress, open egress for updates
- **Certificate Management**: PKI infrastructure for mutual TLS
- **Key Management**: Vault-managed SSH keys and certificates

### Software Dependencies

#### MSP Infrastructure
- **Container Platform**: Docker Engine 20.10+ or Podman 4.0+
- **Orchestration**: Docker Compose 2.0+ or Kubernetes 1.24+
- **VPN Software**: StrongSwan (IPSec) or WireGuard
- **Monitoring**: Prometheus + Grafana (optional)
- **Logging**: ELK Stack or similar (optional)

#### Client Infrastructure  
- **Base OS**: RHEL 8/9, Ubuntu 20.04/22.04, Rocky Linux 8/9
- **Container Runtime**: Docker Engine 20.10+ 
- **Docker Compose**: Version 2.0+
- **Python**: 3.8+ (for Ansible)
- **SSH**: OpenSSH 8.0+

### Storage Requirements

#### MSP Data Center
- **Ansible Tower DB**: 100GB minimum, 500GB recommended
- **Vault Storage**: 50GB per node minimum  
- **Log Storage**: 1TB minimum for centralized logs
- **Backup Storage**: 2x production data minimum

#### Client Sites
- **Local Storage**: 50GB minimum for containers and logs
- **Backup Space**: 10GB for local configuration backups
- **Temporary Space**: 5GB for update processes

### Backup and Recovery

#### Recovery Time Objectives (RTO)
- **MSP Infrastructure**: 1 hour maximum downtime
- **Client Bastion**: 30 minutes maximum downtime  
- **Client Services**: 15 minutes maximum downtime

#### Recovery Point Objectives (RPO)
- **Configuration Data**: 15 minutes maximum data loss
- **Compliance Data**: 5 minutes maximum data loss
- **Audit Logs**: No data loss acceptable

### Scalability Considerations

#### Growth Planning
- **10-50 clients**: Single MSP data center sufficient
- **50-200 clients**: Regional bastion hosts required
- **200+ clients**: Multi-data center deployment

#### Performance Targets
- **Playbook Execution**: <5 minutes for 10 hosts
- **SSH Connection**: <2 seconds via bastion
- **Compliance Scan**: <3 minutes per host
- **Configuration Deployment**: <1 minute per host

### Security Hardening Requirements

#### CMMC Level 2 Baseline
- **Access Control**: Certificate-based authentication only
- **Audit Logging**: Comprehensive system and application logs
- **Configuration Management**: All changes tracked and auditable
- **Incident Response**: Automated containment capabilities
- **System Protection**: SELinux/AppArmor enforcing mode

#### CMMC Level 3 Additional
- **Advanced Persistent Threat Protection**: Enhanced monitoring
- **Privileged Access Management**: Just-in-time access controls
- **Data Loss Prevention**: Automated data classification
- **Advanced Audit**: Real-time security event correlation

### Cost Estimates

#### MSP Infrastructure (Monthly)
- **Control Plane**: $500-1000/month (cloud hosting)
- **Regional Bastions**: $100-200/month each
- **Networking**: $200-500/month (VPN, DNS, certificates)
- **Total MSP**: $800-1700/month for 10-50 clients

#### Per-Client Infrastructure
- **Client Bastion**: $50-100/month (cloud) or existing hardware
- **VPN Licensing**: $10-25/month per tunnel
- **Total Per Client**: $60-125/month

### Deployment Options

#### Cloud Providers
- **AWS**: EC2 instances with VPC and Direct Connect
- **Azure**: Virtual Machines with Express Route
- **GCP**: Compute Engine with Cloud Interconnect
- **Hybrid**: MSP in cloud, clients on-premises

#### On-Premises Options
- **MSP Data Center**: Physical or virtualized infrastructure
- **Client Sites**: Local hardware or VM deployment
- **Edge Computing**: Lightweight bastion deployments

### Compliance Considerations

#### Data Residency
- **CUI Data**: Must remain within client environment
- **Configuration Data**: Can be centrally managed with encryption
- **Audit Logs**: Must maintain chain of custody

#### Certification Requirements
- **CMMC Level 2**: Self-assessment allowed
- **CMMC Level 3**: Third-party assessment required
- **FedRAMP**: Additional controls for cloud deployments

This infrastructure specification provides the foundation for deploying a scalable, secure, and compliant MSP automation platform while maintaining the flexibility for clients to operate independently when needed.