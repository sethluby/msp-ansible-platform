#!/bin/bash

# CMMC Bastion Deployment Script
# Deploys self-contained client infrastructure for graceful disconnection capability

set -euo pipefail

# Configuration - MSP sets these during client deployment
INSTALL_BASE="/opt/cmmc-automation"
CLIENT_ID="${CLIENT_ID:-$(hostname -s)}"  # Default to hostname if not set
COMPLIANCE_LEVEL="${COMPLIANCE_LEVEL:-level2}"
ENVIRONMENT="${ENVIRONMENT:-production}"

# Standard paths on client system
BASTION_DIR="$INSTALL_BASE/bastion"
ANSIBLE_DIR="$INSTALL_BASE/ansible" 
CONFIG_DIR="$INSTALL_BASE/config"
LOG_DIR="/var/log/cmmc"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check if Docker is installed and running
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker."
    fi
    
    # Check if Docker Compose is available
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose."
    fi
    
    # Check system resources
    AVAILABLE_MEMORY=$(free -g | awk 'NR==2{print $7}')
    if [ "$AVAILABLE_MEMORY" -lt 4 ]; then
        warn "Less than 4GB RAM available. Performance may be impacted."
    fi
    
    success "Prerequisites check passed"
}

# Generate secure passwords if not provided
generate_secrets() {
    log "Generating secure configuration..."
    
    ENV_FILE="${BASTION_DIR}/.env"
    
    if [ ! -f "$ENV_FILE" ]; then
        cat > "$ENV_FILE" << EOF
# CMMC Bastion Configuration
# Generated: $(date)

# Client Configuration
CLIENT_ID=${CLIENT_ID}
COMPLIANCE_LEVEL=${COMPLIANCE_LEVEL}
ENVIRONMENT=${ENVIRONMENT}

# Database Configuration
POSTGRES_PASSWORD=$(openssl rand -base64 32)

# Redis Configuration  
REDIS_PASSWORD=$(openssl rand -base64 32)

# AWX Configuration
AWX_SECRET_KEY=$(openssl rand -base64 50)
AWX_ADMIN_USER=admin
AWX_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Vault Configuration
VAULT_ROOT_TOKEN=$(openssl rand -base64 32)

# Network Configuration
BASTION_SUBNET=172.20.0.0/24
EXTERNAL_SUBNET=172.21.0.0/24
EOF
        
        chmod 600 "$ENV_FILE"
        success "Generated secure configuration in $ENV_FILE"
    else
        log "Using existing configuration from $ENV_FILE"
    fi
}

# Create necessary directories and configurations
setup_directories() {
    log "Setting up directory structure..."
    
    # Create config directories
    mkdir -p "${BASTION_DIR}/configs/"{postgres,redis,awx,vault}
    mkdir -p "${BASTION_DIR}/data/"{postgres,redis,awx,vault}
    mkdir -p "${BASTION_DIR}/logs"
    
    # Create minimal configurations
    create_postgres_config
    create_redis_config
    create_vault_config
    create_awx_config
    
    success "Directory structure created"
}

create_postgres_config() {
    cat > "${BASTION_DIR}/configs/postgres/postgresql.conf" << 'EOF'
# PostgreSQL Configuration for CMMC Compliance
listen_addresses = '*'
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
maintenance_work_mem = 64MB

# Logging for audit compliance
log_statement = 'mod'
log_duration = on
log_line_prefix = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
log_min_duration_statement = 1000

# Security settings
ssl = off  # Handled by container network isolation
password_encryption = scram-sha-256
EOF
}

create_redis_config() {
    cat > "${BASTION_DIR}/configs/redis/redis.conf" << 'EOF'
# Redis Configuration for CMMC Compliance
bind 127.0.0.1
port 6379
timeout 0
tcp-keepalive 300

# Persistence
save 900 1
save 300 10
save 60 10000
rdbcompression yes
rdbchecksum yes

# Security
rename-command FLUSHDB ""
rename-command FLUSHALL ""
rename-command DEBUG ""
rename-command CONFIG "CONFIG_a8b2c3d4e5f6"

# Logging
loglevel notice
syslog-enabled yes
syslog-ident redis
EOF
}

create_vault_config() {
    cat > "${BASTION_DIR}/configs/vault/vault.hcl" << 'EOF'
storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = true
}

api_addr = "http://0.0.0.0:8200"
cluster_addr = "http://0.0.0.0:8201"
ui = true

default_lease_ttl = "168h"
max_lease_ttl = "720h"

# Audit logging for CMMC compliance
audit {
  file {
    file_path = "/vault/logs/audit.log"
  }
}
EOF
}

create_awx_config() {
    cat > "${BASTION_DIR}/configs/awx/settings.py" << 'EOF'
# AWX Settings for CMMC Compliance

import os

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.postgresql',
        'NAME': os.getenv('DATABASE_NAME', 'awx'),
        'USER': os.getenv('DATABASE_USER', 'awx'),
        'PASSWORD': os.getenv('DATABASE_PASSWORD'),
        'HOST': os.getenv('DATABASE_HOST', 'postgres'),
        'PORT': '5432',
    }
}

# Cache
CACHES = {
    'default': {
        'BACKEND': 'django_redis.cache.RedisCache',
        'LOCATION': f"redis://:{os.getenv('REDIS_PASSWORD')}@redis:6379/0",
        'OPTIONS': {
            'CLIENT_CLASS': 'django_redis.client.DefaultClient',
        }
    }
}

# Security
SECRET_KEY = os.getenv('SECRET_KEY')
ALLOWED_HOSTS = ['*']
USE_TZ = True

# Logging for CMMC compliance
LOGGING = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'verbose': {
            'format': '{levelname} {asctime} {module} {process:d} {thread:d} {message}',
            'style': '{',
        },
    },
    'handlers': {
        'file': {
            'level': 'INFO',
            'class': 'logging.FileHandler',
            'filename': '/var/log/tower/tower.log',
            'formatter': 'verbose',
        },
    },
    'root': {
        'handlers': ['file'],
        'level': 'INFO',
    },
}

# CMMC Compliance Settings
SYSTEM_TASK_ABS_TIMEOUT = 3600
ANSIBLE_STDOUT_MAX_BYTES_DISPLAY = 1048576
EOF
}

# Deploy the infrastructure
deploy_infrastructure() {
    log "Deploying CMMC bastion infrastructure..."
    
    cd "$BASTION_DIR"
    
    # Pull latest images
    log "Pulling Docker images..."
    docker-compose pull
    
    # Start services
    log "Starting services..."
    docker-compose up -d
    
    # Wait for services to be healthy
    log "Waiting for services to become healthy..."
    sleep 30
    
    # Check service status
    check_service_health
    
    success "CMMC bastion infrastructure deployed successfully"
}

# Check service health
check_service_health() {
    log "Checking service health..."
    
    # Check AWX
    if curl -f -s http://localhost:8080/api/v2/ping/ > /dev/null; then
        success "AWX is healthy"
    else
        warn "AWX may not be fully ready yet"
    fi
    
    # Check Vault
    if curl -f -s http://localhost:8200/v1/sys/health > /dev/null; then
        success "Vault is healthy"
    else
        warn "Vault may not be fully ready yet"
    fi
    
    # Show running containers
    log "Running containers:"
    docker-compose ps
}

# Initialize Vault
initialize_vault() {
    log "Initializing Vault..."
    
    # Wait for Vault to be ready
    until curl -f -s http://localhost:8200/v1/sys/health > /dev/null; do
        log "Waiting for Vault to be ready..."
        sleep 5
    done
    
    # Initialize Vault (if not already initialized)
    if ! curl -s http://localhost:8200/v1/sys/init | grep -q '"initialized":true'; then
        log "Initializing new Vault instance..."
        VAULT_INIT=$(curl -s -X POST -d '{"secret_shares":5,"secret_threshold":3}' http://localhost:8200/v1/sys/init)
        echo "$VAULT_INIT" > "${BASTION_DIR}/vault-init.json"
        chmod 600 "${BASTION_DIR}/vault-init.json"
        warn "Vault keys saved to vault-init.json - SECURE THIS FILE!"
    else
        log "Vault already initialized"
    fi
}

# Setup CMMC compliance monitoring
setup_compliance_monitoring() {
    log "Setting up CMMC compliance monitoring..."
    
    # Create compliance directory structure
    mkdir -p "${PROJECT_DIR}/compliance/"{scripts,reports,policies}
    
    # Copy compliance validation scripts
    if [ -d "${PROJECT_DIR}/compliance/validation" ]; then
        cp -r "${PROJECT_DIR}/compliance/validation/"* "${BASTION_DIR}/compliance/" 2>/dev/null || true
    fi
    
    success "Compliance monitoring configured"
}

# Display deployment summary
show_deployment_summary() {
    log "Deployment Summary"
    echo
    echo "CMMC Bastion Services:"
    echo "  • AWX Web UI: http://localhost:8080"
    echo "  • Vault UI: http://localhost:8200"
    echo "  • Client ID: $CLIENT_ID"
    echo "  • Compliance Level: $COMPLIANCE_LEVEL"
    echo
    echo "Important Files:"
    echo "  • Configuration: ${BASTION_DIR}/.env"
    echo "  • Vault Keys: ${BASTION_DIR}/vault-init.json (if created)"
    echo "  • Logs: ${BASTION_DIR}/logs/"
    echo
    echo "Next Steps:"
    echo "  1. Access AWX at http://localhost:8080"
    echo "  2. Configure Ansible projects and inventory"
    echo "  3. Set up CMMC compliance playbooks"
    echo "  4. Test graceful disconnection procedures"
    echo
    success "Deployment completed successfully!"
}

# Cleanup function
cleanup() {
    if [ $? -ne 0 ]; then
        error "Deployment failed. Check logs for details."
        echo "To clean up partial deployment: docker-compose down -v"
    fi
}

# Main deployment function
main() {
    trap cleanup EXIT
    
    log "Starting CMMC Bastion deployment..."
    log "Client ID: $CLIENT_ID"
    log "Compliance Level: $COMPLIANCE_LEVEL"
    log "Environment: $ENVIRONMENT"
    
    check_prerequisites
    generate_secrets
    setup_directories
    deploy_infrastructure
    initialize_vault
    setup_compliance_monitoring
    show_deployment_summary
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --client-id)
            CLIENT_ID="$2"
            shift 2
            ;;
        --compliance-level)
            COMPLIANCE_LEVEL="$2"
            shift 2
            ;;
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --help)
            echo "Usage: $0 [OPTIONS]"
            echo "Options:"
            echo "  --client-id ID          Set client identifier"
            echo "  --compliance-level LVL  Set CMMC compliance level (level2/level3)"
            echo "  --environment ENV       Set environment (production/staging/development)"
            echo "  --help                  Show this help message"
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Run main deployment
main "$@"