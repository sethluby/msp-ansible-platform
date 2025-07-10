# MSP Platform Infrastructure

## Overview

This directory contains comprehensive infrastructure components for the MSP Ansible Platform, supporting multiple deployment scenarios from development to enterprise-scale production deployments.

## Directory Structure

```
infrastructure/
├── README.md                           # This file
├── REQUIREMENTS.md                     # Infrastructure requirements
├── DEPLOYMENT_GUIDE.md                # Comprehensive deployment guide
├── docker-compose.production.yml      # Production Docker Compose (HA)
├── docker-compose.client.yml          # Client-side Docker Compose
├── configs/                           # Configuration files
│   ├── awx/                          # AWX configuration
│   ├── vault/                        # Vault configuration
│   ├── postgres/                     # PostgreSQL configuration
│   ├── redis/                        # Redis configuration
│   ├── nginx/                        # Nginx configuration
│   ├── haproxy/                      # HAProxy configuration
│   ├── prometheus/                   # Prometheus configuration
│   ├── grafana/                      # Grafana configuration
│   └── fluent-bit/                   # Log collection configuration
├── k8s/                              # Kubernetes manifests
│   ├── namespace.yaml                # Namespace definitions
│   ├── postgres.yaml                 # PostgreSQL cluster
│   ├── vault.yaml                    # Vault cluster
│   ├── awx.yaml                      # AWX deployment
│   ├── monitoring.yaml               # Monitoring stack
│   └── ingress.yaml                  # Ingress and networking
├── compliance/                       # Compliance service
│   ├── Dockerfile                    # MSP compliance validator
│   ├── Dockerfile.client             # Client compliance scanner
│   └── requirements.txt              # Python dependencies
├── backup/                           # Backup services
│   ├── Dockerfile                    # MSP backup service
│   ├── Dockerfile.client             # Client backup agent
│   └── requirements.txt              # Python dependencies
├── health/                           # Health monitoring
│   ├── Dockerfile.client             # Client health checker
│   └── requirements.txt              # Python dependencies
├── disconnection/                    # Graceful disconnection
│   ├── Dockerfile                    # Disconnection service
│   └── requirements.txt              # Python dependencies
└── scripts/                          # Deployment scripts
    ├── deploy.sh                     # Main deployment script
    ├── init-vault.sh                 # Vault initialization
    ├── init-awx.sh                   # AWX initialization
    ├── setup-wireguard.sh            # WireGuard setup
    └── generate-client-package.sh    # Client package generation
```

## Quick Start

### 1. Development Deployment

```bash
# Use existing Docker Compose in parent directory
cd ../msp-infrastructure
docker-compose up -d
```

### 2. Production Deployment

```bash
# Use high-availability Docker Compose
cp .env.example .env
# Edit .env with your configuration
docker-compose -f docker-compose.production.yml up -d
```

### 3. Client Deployment

```bash
# Deploy client-side infrastructure
cp client.env.example client.env
# Edit client.env with your configuration
docker-compose -f docker-compose.client.yml up -d
```

### 4. Kubernetes Deployment

```bash
# Deploy to Kubernetes cluster
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/postgres.yaml
kubectl apply -f k8s/vault.yaml
kubectl apply -f k8s/awx.yaml
kubectl apply -f k8s/monitoring.yaml
kubectl apply -f k8s/ingress.yaml
```

## Deployment Options

### Docker Compose Options

1. **Development**: `../msp-infrastructure/docker-compose.yml`
   - Single-instance services
   - Suitable for development and testing
   - Minimal resource requirements

2. **Production**: `docker-compose.production.yml`
   - High-availability services
   - Load balancing and clustering
   - Enterprise-grade monitoring

3. **Client**: `docker-compose.client.yml`
   - Lightweight client infrastructure
   - Independent operation capability
   - Graceful MSP disconnection

### Kubernetes Options

1. **Enterprise**: Full Kubernetes deployment
   - Horizontal pod autoscaling
   - StatefulSets for data persistence
   - Network policies and security

2. **Hybrid**: Kubernetes hub + Docker clients
   - Centralized Kubernetes management
   - Distributed Docker client deployments
   - Optimal for mixed environments

## Infrastructure Components

### Core Services

1. **AWX/Ansible Tower**
   - Automation orchestration
   - Job scheduling and management
   - Multi-tenant client isolation

2. **HashiCorp Vault**
   - Secrets management
   - PKI infrastructure
   - Client authentication

3. **PostgreSQL**
   - Primary database
   - High availability with replication
   - Backup and recovery

4. **Redis**
   - Caching and job queuing
   - Cluster configuration
   - Session management

### Monitoring Stack

1. **Prometheus**
   - Metrics collection
   - Alerting rules
   - Client monitoring

2. **Grafana**
   - Visualization dashboards
   - Performance monitoring
   - Compliance reporting

3. **Alertmanager**
   - Alert routing
   - Notification management
   - Escalation policies

### Networking

1. **WireGuard VPN**
   - Secure client connections
   - Mesh networking
   - Key management

2. **Load Balancing**
   - HAProxy for production
   - Nginx for static content
   - Kubernetes ingress

3. **Network Policies**
   - Microsegmentation
   - Traffic isolation
   - Security boundaries

## Security Features

### Authentication & Authorization

- **Multi-factor authentication**
- **Role-based access control (RBAC)**
- **Client isolation**
- **Audit logging**

### Network Security

- **VPN encryption**
- **TLS everywhere**
- **Network segmentation**
- **Firewall rules**

### Compliance

- **CMMC Level 2/3 support**
- **SOC 2 Type II compliance**
- **HIPAA/HITECH compliance**
- **PCI-DSS compliance**

## Scalability

### Horizontal Scaling

- **Multi-region deployment**
- **Load balancer clustering**
- **Database read replicas**
- **Redis clustering**

### Vertical Scaling

- **Resource optimization**
- **Performance tuning**
- **Capacity planning**
- **Auto-scaling policies**

## Backup and Recovery

### Automated Backups

- **Database backups**
- **Configuration backups**
- **Encrypted storage**
- **Retention policies**

### Disaster Recovery

- **RTO: 1 hour**
- **RPO: 15 minutes**
- **Failover procedures**
- **Data consistency**

## Monitoring and Alerting

### Health Checks

- **Service availability**
- **Performance metrics**
- **Resource utilization**
- **Error tracking**

### Alerting Rules

- **Service downtime**
- **Resource exhaustion**
- **Security events**
- **Client disconnections**

## Configuration Management

### Environment Variables

Create appropriate environment files:

```bash
# For production deployment
cp .env.example .env

# For client deployment
cp client.env.example client.env
```

### Secrets Management

- **Vault integration**
- **Encrypted at rest**
- **Automatic rotation**
- **Audit trails**

## Troubleshooting

### Common Issues

1. **Database connection failures**
2. **Vault seal issues**
3. **AWX job execution errors**
4. **WireGuard connectivity**

### Debugging Tools

```bash
# View service logs
docker-compose logs -f [service]

# Check service health
docker-compose ps

# Test connectivity
./scripts/test-connectivity.sh
```

## Support

### Documentation

- **DEPLOYMENT_GUIDE.md**: Complete deployment instructions
- **REQUIREMENTS.md**: Infrastructure requirements
- **../docs/**: Additional documentation

### Community

- **GitHub Issues**: Bug reports and feature requests
- **Discussions**: Community support and questions
- **Wiki**: Extended documentation and examples

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Changelog

### v1.0.0 (Current)
- Initial infrastructure release
- Docker Compose support
- Kubernetes manifests
- Client deployment capability
- Monitoring integration
- Security hardening
- Compliance framework integration

### Future Roadmap
- Helm chart packaging
- Terraform modules
- Cloud provider integrations
- Enhanced observability
- Performance optimizations