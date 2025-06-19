# Getting Started with MSP CMMC Compliance Automation

**Author**: thndrchckn  
**Last Updated**: 2025-06-19  
**Tags**: `#deployment` `#setup` `#quickstart`

This guide provides step-by-step instructions for deploying the MSP CMMC Compliance Automation framework, from initial setup through first client onboarding.

## Prerequisites

### System Requirements

#### MSP Infrastructure (Control Plane)
- **Operating System**: RHEL 8/9, Ubuntu 20.04/22.04, or Rocky Linux 8/9
- **CPU**: Minimum 4 vCPU, Recommended 8 vCPU
- **Memory**: Minimum 8GB RAM, Recommended 16GB RAM
- **Storage**: Minimum 100GB SSD, Recommended 500GB SSD
- **Network**: Static IP address, internet connectivity

#### Client Bastion Requirements
- **Operating System**: RHEL 8/9, Ubuntu 20.04/22.04, or Rocky Linux 8/9  
- **CPU**: Minimum 2 vCPU
- **Memory**: Minimum 4GB RAM
- **Storage**: Minimum 50GB SSD
- **Network**: Reliable internet connection (10Mbps minimum)

### Software Prerequisites

#### Required Software
```bash
# Ansible and related tools
ansible-core >= 2.12
python3 >= 3.8
git >= 2.20
ssh-client

# Container platform
docker-ce >= 20.10
docker-compose >= 2.0

# Security tools  
openssl >= 1.1.1
gnupg >= 2.2
```

#### Optional Software
```bash
# For advanced deployments
terraform >= 1.0     # Infrastructure as Code
vault >= 1.8         # HashiCorp Vault for secrets
kubernetes >= 1.24   # Container orchestration (alternative to Docker Compose)
```

## Installation Steps

### Step 1: Repository Setup

#### Clone the Repository
```bash
# Clone the main repository
git clone ssh://git@git.lan.sethluby.com:222/thndrchckn/cmmc-ansible.git
cd cmmc-ansible

# Verify repository structure
ls -la
```

#### Configure Git Credentials
```bash
# Configure git for your environment
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Add SSH key for repository access (if not already configured)
ssh-keygen -t ed25519 -C "your.email@example.com"
# Add public key to Gitea account
```

### Step 2: Environment Configuration

#### Set Up Directory Variables
```bash
# Copy example configuration
cp ansible/group_vars/all/directory_structure.yml.example \
   ansible/group_vars/all/directory_structure.yml

# Customize paths if needed (optional - defaults work for most deployments)
vim ansible/group_vars/all/directory_structure.yml
```

#### Configure Ansible
```bash
# Install Ansible if not already installed
# RHEL/CentOS
sudo dnf install ansible-core python3-pip

# Ubuntu
sudo apt update && sudo apt install ansible python3-pip

# Verify installation
ansible --version
```

#### Create Ansible Configuration
```bash
# Create ansible.cfg in project root
cat > ansible.cfg << 'EOF'
[defaults]
inventory = ./ansible/inventory/
host_key_checking = False
timeout = 30
forks = 10
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_fact_cache
fact_caching_timeout = 86400
retry_files_enabled = False
roles_path = ./ansible/roles
collections_paths = ./ansible/collections
remote_user = ansible-service
private_key_file = ~/.ssh/ansible_rsa

[ssh_connection]
ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
EOF
```

### Step 3: SSH Key Management

#### Generate Service Account Keys
```bash
# Create dedicated SSH key for Ansible automation
ssh-keygen -t ed25519 -f ~/.ssh/ansible_rsa -C "ansible-service@msp.local"

# Set proper permissions
chmod 600 ~/.ssh/ansible_rsa
chmod 644 ~/.ssh/ansible_rsa.pub

# Display public key for deployment to target systems
echo "=== Ansible Service Public Key ==="
cat ~/.ssh/ansible_rsa.pub
echo "=================================="
```

#### Create Service Account on Target Systems
```bash
# Run this on each target system (bastion hosts and client systems)
sudo useradd -m -s /bin/bash ansible-service
sudo mkdir -p /home/ansible-service/.ssh
sudo chmod 700 /home/ansible-service/.ssh

# Add public key to authorized_keys
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExampleKey ansible-service@msp.local" | \
sudo tee /home/ansible-service/.ssh/authorized_keys

sudo chmod 600 /home/ansible-service/.ssh/authorized_keys
sudo chown -R ansible-service:ansible-service /home/ansible-service/.ssh

# Grant sudo privileges for automation
echo "ansible-service ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/ansible-service
sudo chmod 440 /etc/sudoers.d/ansible-service
```

### Step 4: Inventory Configuration

#### Create Basic Inventory
```bash
# Create inventory directory structure
mkdir -p ansible/inventory/group_vars/{all,msp_infrastructure,client_bastions}
mkdir -p ansible/inventory/host_vars

# Create basic hosts.yml
cat > ansible/inventory/hosts.yml << 'EOF'
---
all:
  children:
    msp_infrastructure:
      hosts:
        ansible-controller:
          ansible_host: 10.0.1.10
          ansible_user: ansible-service
    
    client_bastions:
      hosts:
        client-001-bastion:
          ansible_host: 192.168.100.10
          ansible_user: ansible-service
          client_id: client_001
          cmmc_level: level2
          
        client-002-bastion:
          ansible_host: 192.168.200.10
          ansible_user: ansible-service
          client_id: client_002
          cmmc_level: level3
EOF
```

#### Configure Group Variables
```bash
# Configure global variables
cat > ansible/inventory/group_vars/all/main.yml << 'EOF'
---
# Global MSP Configuration
msp_organization: "Your MSP Company"
msp_contact_email: "support@yourmsP.com"
msp_emergency_phone: "+1-555-MSP-HELP"

# Default CMMC Configuration
cmmc_level: "level2"
cmmc_environment: "production"
cmmc_reporting_enabled: true
cmmc_local_management_mode: false

# Security defaults
security_hardening_level: "intermediate"
security_enable_all_categories: true

# Backup configuration
backup_enabled: true
backup_retention_days: 90
backup_encryption_enabled: true
EOF
```

### Step 5: Deploy Control Plane Infrastructure

#### Install Required Python Dependencies
```bash
# Install Python requirements for Ansible modules
pip3 install --user -r requirements.txt

# Create requirements.txt if it doesn't exist
cat > requirements.txt << 'EOF'
ansible>=6.0.0
docker>=6.0.0
cryptography>=3.4.8
pyyaml>=6.0
jinja2>=3.0.0
netaddr>=0.8.0
EOF
```

#### Deploy MSP Infrastructure
```bash
# Test connectivity to infrastructure hosts
ansible msp_infrastructure -m ping

# Deploy base infrastructure
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/deploy-msp-infrastructure.yml

# Verify deployment
ansible msp_infrastructure -m setup -a "filter=ansible_hostname"
```

### Step 6: Deploy First Client Bastion

#### Prepare Client Configuration
```bash
# Create client-specific variables
mkdir -p ansible/inventory/group_vars/client_001

cat > ansible/inventory/group_vars/client_001/main.yml << 'EOF'
---
# Client 001 Configuration
client_id: "client_001"
client_name: "Example Defense Contractor"
client_contact: "admin@client001.com"

# CMMC Configuration
cmmc_level: "level2"
cmmc_environment: "production"

# Custom directory structure (if needed)
# cmmc_base_dir: "/opt/client_001/cmmc"
# cmmc_log_base_dir: "/var/log/client_001/cmmc"

# Network configuration
client_network_range: "192.168.100.0/24"
bastion_ip: "192.168.100.10"
EOF
```

#### Deploy Client Bastion
```bash
# Test connectivity to client bastion
ansible client-001-bastion -m ping

# Deploy Docker-based bastion infrastructure
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/deploy-client-bastion.yml \
  --limit client-001-bastion

# Verify services are running
ansible client-001-bastion -m shell -a "docker ps"
```

### Step 7: Implement CMMC Compliance

#### Run Compliance Deployment
```bash
# Deploy CMMC compliance controls
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/implement-cmmc-compliance.yml \
  --limit client-001-bastion

# Run compliance validation
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-compliance.yml \
  --limit client-001-bastion
```

#### Verify Compliance Status
```bash
# Check compliance validation results
ansible client-001-bastion -m shell -a \
  "/usr/local/bin/cmmc_validator.py --output summary"

# View detailed compliance report
ansible client-001-bastion -m fetch -a \
  "src=/var/log/cmmc/reports/latest_compliance_report.json dest=./reports/"
```

### Step 8: Configure Monitoring and Reporting

#### Set Up Monitoring
```bash
# Deploy monitoring stack (if enabled)
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/deploy-monitoring.yml \
  --limit client-001-bastion

# Configure alerting
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/configure-alerting.yml \
  --limit client-001-bastion
```

#### Test Reporting
```bash
# Generate test compliance report
ansible client-001-bastion -m shell -a \
  "/usr/local/bin/cmmc_validator.py --verbose"

# Check report delivery (if MSP integration enabled)
curl -X GET "https://your-msp-dashboard.com/api/v1/compliance/client_001/latest"
```

## Validation and Testing

### Pre-Production Validation

#### Connectivity Testing
```bash
# Test all connectivity
ansible all -m ping

# Test SSH configuration
ansible all -m shell -a "whoami && sudo whoami"

# Test service status
ansible client_bastions -m shell -a "systemctl is-active sshd auditd"
```

#### Security Validation
```bash
# Run security validation
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/validate-security.yml

# Check firewall status
ansible all -m shell -a "iptables -L -n | head -20"

# Verify SSH hardening
ansible all -m shell -a "sshd -T | grep -E '(PasswordAuthentication|PubkeyAuthentication)'"
```

#### Compliance Testing
```bash
# Full compliance validation
ansible client_bastions -m shell -a \
  "/usr/local/bin/cmmc_validator.py --config-dir /etc/cmmc --verbose"

# Test graceful disconnection capability
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/test-disconnection.yml \
  --limit client-001-bastion
```

## Post-Deployment Configuration

### Backup Configuration
```bash
# Configure automated backups
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/configure-backups.yml

# Test backup functionality
ansible client_bastions -m shell -a \
  "/usr/local/bin/backup-cmmc-config.sh --test"
```

### Certificate Management
```bash
# Generate client certificates
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/generate-certificates.yml \
  --extra-vars "client_id=client_001"

# Configure certificate rotation
ansible client-001-bastion -m cron -a \
  "name='Certificate renewal' minute=0 hour=2 job='/usr/local/bin/renew-certificates.sh'"
```

### Documentation Generation
```bash
# Generate client-specific documentation
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/generate-documentation.yml \
  --extra-vars "client_id=client_001"

# Create client handover package
ansible-playbook -i ansible/inventory/hosts.yml \
  ansible/playbooks/create-handover-package.yml \
  --extra-vars "client_id=client_001"
```

## Troubleshooting Common Issues

### SSH Connection Problems
```bash
# Debug SSH connectivity
ssh -vvv ansible-service@client-bastion-ip

# Check SSH service on target
ansible target-host -m shell -a "systemctl status sshd" -u root

# Verify SSH key permissions
ansible target-host -m shell -a "ls -la ~/.ssh/" -u ansible-service
```

### Ansible Execution Issues
```bash
# Run with maximum verbosity
ansible-playbook playbook.yml -vvv

# Check Python interpreter
ansible all -m shell -a "which python3 && python3 --version"

# Verify sudo permissions
ansible all -m shell -a "sudo -l" -u ansible-service
```

### Service Deployment Problems
```bash
# Check Docker status
ansible client_bastions -m shell -a "systemctl status docker"

# Verify container status
ansible client_bastions -m shell -a "docker ps -a"

# Check container logs
ansible client_bastions -m shell -a "docker logs cmmc-awx-web"
```

## Next Steps

After successful deployment:

1. **[Client Onboarding](Client-Onboarding)** - Add additional clients
2. **[Monitoring Setup](Monitoring-Alerting)** - Configure comprehensive monitoring
3. **[Backup Configuration](Backup-Recovery)** - Implement backup strategies
4. **[Performance Tuning](Performance-Tuning)** - Optimize for scale
5. **[Security Hardening](Security-Hardening)** - Additional security measures

## Support Resources

- **[Troubleshooting Guide](Troubleshooting)** - Common problems and solutions
- **[FAQ](FAQ)** - Frequently asked questions
- **[Architecture Overview](Architecture-Overview)** - System design details
- **[API Documentation](API-Documentation)** - Integration endpoints

---

**Need Help?** Create an issue in the repository or consult the [Support Procedures](Support-Procedures) page.