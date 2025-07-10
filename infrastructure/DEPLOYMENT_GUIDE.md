# MSP Platform Infrastructure Deployment Guide

## Overview

This guide provides comprehensive instructions for deploying the MSP Ansible Infrastructure Management Platform using multiple deployment methods:

- **Docker Compose**: For development and small-scale deployments
- **Kubernetes**: For enterprise-scale production deployments
- **Hybrid**: Client-side lightweight deployments

## Prerequisites

### System Requirements

#### MSP Hub Infrastructure
- **CPU**: 8+ cores recommended
- **Memory**: 32GB+ RAM recommended
- **Storage**: 500GB+ SSD storage
- **Network**: High-speed internet connection with static IP
- **OS**: Ubuntu 22.04 LTS, RHEL 9, or Rocky Linux 9

#### Client Infrastructure
- **CPU**: 2+ cores minimum
- **Memory**: 4GB+ RAM minimum
- **Storage**: 50GB+ SSD storage
- **Network**: Reliable internet connection
- **OS**: Ubuntu 20.04+, RHEL 8+, or Rocky Linux 8+

### Software Dependencies

#### All Deployments
```bash
# Docker and Docker Compose
curl -fsSL https://get.docker.com | sh
sudo systemctl enable --now docker
sudo usermod -aG docker $USER

# Docker Compose v2
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

#### Kubernetes Deployment
```bash
# kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

## Deployment Methods

### 1. Docker Compose Deployment

#### MSP Hub Deployment

1. **Clone the repository**:
```bash
git clone https://github.com/your-org/msp-ansible-platform.git
cd msp-ansible-platform/infrastructure
```

2. **Create environment file**:
```bash
cp .env.example .env
nano .env
```

3. **Required environment variables**:
```env
# Database passwords
POSTGRES_PASSWORD=your_secure_postgres_password
POSTGRES_REPLICATION_PASSWORD=your_replication_password
REDIS_PASSWORD=your_redis_password

# AWX configuration
AWX_SECRET_KEY=your_awx_secret_key
AWX_ADMIN_USER=admin
AWX_ADMIN_PASSWORD=your_admin_password

# Vault configuration
VAULT_ROOT_TOKEN=your_vault_root_token
VAULT_CONFIG='{"storage": {"raft": {"path": "/vault/data"}}, "listener": {"tcp": {"address": "0.0.0.0:8200", "tls_disable": false}}, "ui": true}'

# WireGuard VPN
WIREGUARD_SERVERURL=your.domain.com
WIREGUARD_PEERS=10

# Monitoring
GRAFANA_PASSWORD=your_grafana_password
GRAFANA_USER=admin

# Client settings
CLIENT_ID=default
COMPLIANCE_LEVEL=level2
```

4. **Deploy the infrastructure**:
```bash
# Production deployment
docker-compose -f docker-compose.production.yml up -d

# Development deployment
docker-compose -f msp-infrastructure/docker-compose.yml up -d
```

5. **Initialize services**:
```bash
# Initialize Vault
./scripts/init-vault.sh

# Initialize AWX
./scripts/init-awx.sh

# Setup WireGuard
./scripts/setup-wireguard.sh
```

#### Client Deployment

1. **Prepare client environment**:
```bash
# On client system
mkdir -p /opt/msp-client
cd /opt/msp-client
```

2. **Download client configuration**:
```bash
# Get client configuration from MSP hub
curl -O https://your-msp-hub.com/client-config.tar.gz
tar -xzf client-config.tar.gz
```

3. **Configure client environment**:
```bash
cp client.env.example client.env
nano client.env
```

4. **Deploy client infrastructure**:
```bash
docker-compose -f docker-compose.client.yml up -d
```

### 2. Kubernetes Deployment

#### Prerequisites

1. **Kubernetes cluster**: Version 1.24+
2. **Storage classes**: `fast-ssd` and `nfs-client`
3. **Ingress controller**: nginx-ingress
4. **Cert-manager**: For TLS certificates

#### Deployment Steps

1. **Create namespaces**:
```bash
kubectl apply -f k8s/namespace.yaml
```

2. **Deploy secrets**:
```bash
# Create TLS certificates
kubectl create secret tls msp-platform-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n msp-platform

# Create application secrets
kubectl create secret generic postgres-secrets \
  --from-literal=postgres-password=your_password \
  --from-literal=replication-password=your_replication_password \
  -n msp-platform

kubectl create secret generic awx-secrets \
  --from-literal=awx-secret-key=your_secret_key \
  --from-literal=awx-admin-password=your_admin_password \
  --from-literal=redis-password=your_redis_password \
  -n msp-platform

kubectl create secret generic vault-secrets \
  --from-literal=vault-root-token=your_root_token \
  --from-literal=vault-unseal-key=your_unseal_key \
  -n msp-platform

kubectl create secret generic grafana-secrets \
  --from-literal=admin-password=your_grafana_password \
  -n msp-monitoring
```

3. **Deploy infrastructure components**:
```bash
# Deploy PostgreSQL
kubectl apply -f k8s/postgres.yaml

# Deploy Vault
kubectl apply -f k8s/vault.yaml

# Deploy AWX
kubectl apply -f k8s/awx.yaml

# Deploy monitoring
kubectl apply -f k8s/monitoring.yaml

# Deploy ingress
kubectl apply -f k8s/ingress.yaml
```

4. **Verify deployment**:
```bash
# Check all pods are running
kubectl get pods -n msp-platform
kubectl get pods -n msp-monitoring

# Check services
kubectl get svc -n msp-platform
kubectl get svc -n msp-monitoring

# Check ingress
kubectl get ingress -n msp-platform
```

5. **Initialize services**:
```bash
# Initialize Vault cluster
kubectl exec -it vault-0 -n msp-platform -- vault operator init

# Initialize AWX
kubectl exec -it awx-web-0 -n msp-platform -- awx-manage migrate
kubectl exec -it awx-web-0 -n msp-platform -- awx-manage create_preload_data
```

### 3. Configuration Management

#### AWX Configuration

1. **Access AWX web interface**:
   - URL: `https://awx.msp.example.com`
   - Username: `admin`
   - Password: From environment variable

2. **Configure projects**:
   - Create Git-based projects pointing to your Ansible playbooks
   - Set up credential types for client authentication
   - Configure job templates for client operations

3. **Set up inventory**:
   - Create dynamic inventory sources
   - Configure client groups and variables
   - Set up inventory synchronization

#### Vault Configuration

1. **Access Vault web interface**:
   - URL: `https://vault.msp.example.com`
   - Token: From environment variable

2. **Configure authentication**:
   - Enable Kubernetes auth method
   - Set up client authentication backends
   - Configure policy-based access control

3. **Set up secrets engines**:
   - Enable KV v2 for client secrets
   - Configure PKI for certificate management
   - Set up database secrets engine

#### Monitoring Configuration

1. **Access Grafana**:
   - URL: `https://grafana.msp.example.com`
   - Username: `admin`
   - Password: From environment variable

2. **Configure dashboards**:
   - Import MSP platform dashboards
   - Set up client environment monitoring
   - Configure alerting rules

3. **Set up data sources**:
   - Configure Prometheus data source
   - Set up log aggregation
   - Configure client metrics collection

## Client Onboarding

### Automated Onboarding

1. **Run onboarding playbook**:
```bash
# From MSP hub
ansible-playbook -i inventory/production playbooks/onboard-client.yml \
  -e client_name=newcorp \
  -e client_tier=professional \
  -e client_contact_email=admin@newcorp.com
```

2. **Generate client package**:
```bash
# Creates client deployment package
./scripts/generate-client-package.sh newcorp
```

3. **Deploy on client site**:
```bash
# On client system
tar -xzf newcorp-client-package.tar.gz
cd newcorp-client
./deploy.sh
```

### Manual Onboarding

1. **Create client configuration**:
```bash
# Create client-specific variables
mkdir -p inventory/group_vars/client_newcorp
cat > inventory/group_vars/client_newcorp/main.yml << EOF
client_name: newcorp
client_tier: professional
client_domain: newcorp.com
client_network: 10.100.0.0/16
compliance_level: level2
EOF
```

2. **Generate certificates**:
```bash
# Generate client certificates
./scripts/generate-client-certs.sh newcorp
```

3. **Configure WireGuard**:
```bash
# Add client to WireGuard config
./scripts/add-wireguard-client.sh newcorp
```

## Security Hardening

### Network Security

1. **Firewall configuration**:
```bash
# MSP hub firewall rules
ufw allow 51820/udp  # WireGuard
ufw allow 80/tcp     # HTTP (redirect to HTTPS)
ufw allow 443/tcp    # HTTPS
ufw allow 22/tcp     # SSH (restrict to admin IPs)
ufw enable

# Client firewall rules
ufw allow 51820/udp  # WireGuard
ufw allow 80/tcp     # Local web interface
ufw allow 443/tcp    # Local web interface
ufw allow 22/tcp     # SSH (restrict to MSP and admin IPs)
ufw enable
```

2. **Network segmentation**:
```bash
# Create isolated Docker networks
docker network create --driver bridge --subnet=172.20.0.0/16 msp-internal
docker network create --driver bridge --subnet=172.21.0.0/16 msp-external
```

### Access Control

1. **Role-based access control**:
```yaml
# AWX RBAC configuration
roles:
  - name: "MSP Administrator"
    permissions:
      - "admin"
  - name: "Client Manager"
    permissions:
      - "client_manage"
  - name: "Compliance Officer"
    permissions:
      - "compliance_view"
```

2. **Vault policies**:
```hcl
# Client-specific policy
path "secret/data/client/{{identity.entity.aliases.auth_kubernetes_xxx.metadata.service_account_namespace}}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "pki/issue/client-{{identity.entity.aliases.auth_kubernetes_xxx.metadata.service_account_namespace}}" {
  capabilities = ["create", "update"]
}
```

### SSL/TLS Configuration

1. **Generate certificates**:
```bash
# Generate root CA
openssl genrsa -out ca.key 4096
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt

# Generate server certificates
openssl genrsa -out server.key 2048
openssl req -new -key server.key -out server.csr
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365
```

2. **Configure TLS in services**:
```yaml
# Vault TLS configuration
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_cert_file = "/vault/tls/server.crt"
  tls_key_file = "/vault/tls/server.key"
  tls_client_ca_file = "/vault/tls/ca.crt"
  tls_min_version = "tls12"
}
```

## Monitoring and Maintenance

### Health Checks

1. **Service health monitoring**:
```bash
# Check all services
docker-compose ps

# Check specific service logs
docker-compose logs awx-web
docker-compose logs vault
docker-compose logs postgres
```

2. **Kubernetes health checks**:
```bash
# Check pod health
kubectl get pods -n msp-platform -o wide

# Check service endpoints
kubectl get endpoints -n msp-platform

# Check ingress status
kubectl describe ingress msp-platform-ingress -n msp-platform
```

### Backup and Recovery

1. **Automated backups**:
```bash
# PostgreSQL backup
pg_dump -h postgres-primary -U awx -d awx > awx-backup-$(date +%Y%m%d).sql

# Vault backup
vault operator raft snapshot save vault-backup-$(date +%Y%m%d).snap

# AWX projects backup
tar -czf awx-projects-$(date +%Y%m%d).tar.gz /var/lib/awx/projects/
```

2. **Recovery procedures**:
```bash
# PostgreSQL recovery
psql -h postgres-primary -U awx -d awx < awx-backup-20231201.sql

# Vault recovery
vault operator raft snapshot restore vault-backup-20231201.snap

# AWX projects recovery
tar -xzf awx-projects-20231201.tar.gz -C /var/lib/awx/projects/
```

### Updates and Upgrades

1. **Update Docker images**:
```bash
# Pull latest images
docker-compose pull

# Restart services with new images
docker-compose up -d
```

2. **Update Kubernetes deployments**:
```bash
# Update images
kubectl set image deployment/awx-web awx-web=quay.io/ansible/awx:latest -n msp-platform

# Rolling update
kubectl rollout restart deployment/awx-web -n msp-platform
```

## Troubleshooting

### Common Issues

1. **Database connection errors**:
```bash
# Check PostgreSQL logs
docker-compose logs postgres-primary

# Test database connection
psql -h postgres-primary -U awx -d awx -c "SELECT 1;"
```

2. **Vault seal issues**:
```bash
# Check Vault status
vault status

# Unseal Vault
vault operator unseal

# Check Vault logs
docker-compose logs vault
```

3. **AWX job execution failures**:
```bash
# Check AWX task logs
docker-compose logs awx-task

# Check inventory synchronization
awx-manage inventory_import --inventory-id 1 --source /path/to/inventory

# Check job execution
awx-manage run_job --job-template-id 1
```

### Performance Optimization

1. **Database optimization**:
```sql
-- PostgreSQL performance tuning
ALTER SYSTEM SET shared_buffers = '256MB';
ALTER SYSTEM SET effective_cache_size = '1GB';
ALTER SYSTEM SET maintenance_work_mem = '64MB';
SELECT pg_reload_conf();
```

2. **AWX optimization**:
```python
# AWX settings optimization
SYSTEM_TASK_ABS_CPU = 6
SYSTEM_TASK_ABS_MEM = 2048
SYSTEM_TASK_FORKS = 4
AWX_TASK_ENV['ANSIBLE_FORCE_COLOR'] = 'false'
```

3. **Kubernetes resource optimization**:
```yaml
# Resource limits and requests
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

## Support and Maintenance

### Log Analysis

1. **Centralized logging**:
```bash
# View aggregated logs
docker-compose logs -f --tail=100

# Filter by service
docker-compose logs -f awx-web | grep ERROR

# Kubernetes logs
kubectl logs -f deployment/awx-web -n msp-platform
```

2. **Log rotation**:
```bash
# Configure log rotation
cat > /etc/logrotate.d/docker-compose << EOF
/var/lib/docker/containers/*/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    create 0644 root root
    postrotate
        /usr/bin/docker kill -s USR1 $(docker ps -q) 2>/dev/null || true
    endscript
}
EOF
```

### Monitoring Integration

1. **Prometheus metrics**:
```yaml
# Prometheus configuration
- job_name: 'msp-platform'
  static_configs:
    - targets: ['awx-web:8052', 'vault:8200', 'postgres:5432']
```

2. **Grafana dashboards**:
```bash
# Import dashboard
curl -X POST \
  http://admin:password@grafana:3000/api/dashboards/db \
  -H 'Content-Type: application/json' \
  -d @dashboard.json
```

This deployment guide provides comprehensive instructions for deploying and managing the MSP platform infrastructure across different deployment scenarios and environments.