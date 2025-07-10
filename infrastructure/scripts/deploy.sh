#!/bin/bash

# MSP Platform Infrastructure Deployment Script
# Supports multiple deployment scenarios: development, production, client, kubernetes

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/deploy.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS] DEPLOYMENT_TYPE

Deployment types:
  dev         - Development deployment (single-instance services)
  prod        - Production deployment (high-availability services)
  client      - Client-side deployment (lightweight infrastructure)
  kubernetes  - Kubernetes cluster deployment
  
Options:
  -h, --help      Show this help message
  -v, --verbose   Enable verbose logging
  -d, --dry-run   Show what would be deployed without executing
  -f, --force     Force deployment even if services are running
  -c, --config    Specify custom configuration file
  -e, --env       Specify environment file
  
Examples:
  $0 dev                              # Deploy development environment
  $0 prod -e production.env           # Deploy production with custom env
  $0 client -c client-config.yml      # Deploy client with custom config
  $0 kubernetes --dry-run             # Preview Kubernetes deployment
  
EOF
}

# Check dependencies
check_dependencies() {
    log "Checking dependencies..."
    
    # Check Docker
    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first."
    fi
    
    # Check Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
    fi
    
    # Check for running Docker daemon
    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker service."
    fi
    
    log "Dependencies check passed"
}

# Check Kubernetes dependencies
check_kubernetes_dependencies() {
    log "Checking Kubernetes dependencies..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        error "kubectl is not installed. Please install kubectl first."
    fi
    
    # Check cluster connectivity
    if ! kubectl cluster-info &> /dev/null; then
        error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    fi
    
    # Check Helm (optional but recommended)
    if ! command -v helm &> /dev/null; then
        warn "Helm is not installed. Some features may not be available."
    fi
    
    log "Kubernetes dependencies check passed"
}

# Generate default environment file
generate_env_file() {
    local env_file="$1"
    
    log "Generating default environment file: $env_file"
    
    cat > "$env_file" << EOF
# MSP Platform Configuration
# Generated on $(date)

# Database Configuration
POSTGRES_PASSWORD=$(openssl rand -base64 32)
POSTGRES_REPLICATION_PASSWORD=$(openssl rand -base64 32)
REDIS_PASSWORD=$(openssl rand -base64 32)

# AWX Configuration
AWX_SECRET_KEY=$(openssl rand -base64 32)
AWX_ADMIN_USER=admin
AWX_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Vault Configuration
VAULT_ROOT_TOKEN=$(openssl rand -base64 32)
VAULT_CONFIG='{"storage": {"raft": {"path": "/vault/data"}}, "listener": {"tcp": {"address": "0.0.0.0:8200", "tls_disable": true}}, "ui": true}'

# WireGuard Configuration
WIREGUARD_SERVERURL=localhost
WIREGUARD_PEERS=10

# Monitoring Configuration
GRAFANA_PASSWORD=$(openssl rand -base64 16)
GRAFANA_USER=admin

# Client Configuration
CLIENT_ID=default
COMPLIANCE_LEVEL=level2
TZ=UTC

# Backup Configuration
BACKUP_SCHEDULE="0 2 * * *"
BACKUP_RETENTION=30

# Network Configuration
MSP_DOMAIN=localhost
MSP_API_URL=http://localhost:8080
EOF
    
    log "Environment file generated. Please review and update as needed."
}

# Development deployment
deploy_development() {
    local compose_file="$PROJECT_ROOT/../msp-infrastructure/docker-compose.yml"
    local env_file="${ENV_FILE:-$PROJECT_ROOT/../msp-infrastructure/.env}"
    
    log "Deploying development environment..."
    
    # Check if compose file exists
    if [[ ! -f "$compose_file" ]]; then
        error "Docker Compose file not found: $compose_file"
    fi
    
    # Generate environment file if it doesn't exist
    if [[ ! -f "$env_file" ]]; then
        generate_env_file "$env_file"
    fi
    
    # Deploy services
    cd "$(dirname "$compose_file")"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run - would execute: docker-compose -f $(basename "$compose_file") up -d"
        return 0
    fi
    
    log "Starting services..."
    docker-compose -f "$(basename "$compose_file")" up -d
    
    # Wait for services to start
    log "Waiting for services to start..."
    sleep 30
    
    # Check service health
    check_service_health "development"
    
    log "Development deployment completed successfully!"
    log "Access AWX at: http://localhost:8080"
    log "Access Vault at: http://localhost:8200"
}

# Production deployment
deploy_production() {
    local compose_file="$PROJECT_ROOT/docker-compose.production.yml"
    local env_file="${ENV_FILE:-$PROJECT_ROOT/.env}"
    
    log "Deploying production environment..."
    
    # Check if compose file exists
    if [[ ! -f "$compose_file" ]]; then
        error "Docker Compose file not found: $compose_file"
    fi
    
    # Generate environment file if it doesn't exist
    if [[ ! -f "$env_file" ]]; then
        generate_env_file "$env_file"
    fi
    
    # Deploy services
    cd "$PROJECT_ROOT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run - would execute: docker-compose -f docker-compose.production.yml up -d"
        return 0
    fi
    
    log "Starting production services..."
    docker-compose -f docker-compose.production.yml up -d
    
    # Wait for services to start
    log "Waiting for services to start..."
    sleep 60
    
    # Initialize services
    log "Initializing services..."
    if [[ -f "$SCRIPT_DIR/init-vault.sh" ]]; then
        bash "$SCRIPT_DIR/init-vault.sh"
    fi
    
    if [[ -f "$SCRIPT_DIR/init-awx.sh" ]]; then
        bash "$SCRIPT_DIR/init-awx.sh"
    fi
    
    # Check service health
    check_service_health "production"
    
    log "Production deployment completed successfully!"
    log "Access AWX at: https://awx.${MSP_DOMAIN:-localhost}"
    log "Access Vault at: https://vault.${MSP_DOMAIN:-localhost}"
    log "Access Grafana at: https://grafana.${MSP_DOMAIN:-localhost}"
}

# Client deployment
deploy_client() {
    local compose_file="$PROJECT_ROOT/docker-compose.client.yml"
    local env_file="${ENV_FILE:-$PROJECT_ROOT/client.env}"
    
    log "Deploying client environment..."
    
    # Check if compose file exists
    if [[ ! -f "$compose_file" ]]; then
        error "Docker Compose file not found: $compose_file"
    fi
    
    # Generate environment file if it doesn't exist
    if [[ ! -f "$env_file" ]]; then
        generate_env_file "$env_file"
        # Add client-specific variables
        cat >> "$env_file" << EOF

# Client-specific Configuration
MSP_HUB_URL=https://msp.example.com
MSP_WIREGUARD_SERVER=msp.example.com
WIREGUARD_CLIENT_KEY=$(openssl rand -base64 32)
WIREGUARD_CLIENT_PSK=$(openssl rand -base64 32)
MSP_UPLOAD_ENABLED=false
MSP_SYNC_ENABLED=false
MSP_REPORTING_ENABLED=true
EOF
    fi
    
    # Deploy services
    cd "$PROJECT_ROOT"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run - would execute: docker-compose -f docker-compose.client.yml up -d"
        return 0
    fi
    
    log "Starting client services..."
    docker-compose -f docker-compose.client.yml up -d
    
    # Wait for services to start
    log "Waiting for services to start..."
    sleep 30
    
    # Check service health
    check_service_health "client"
    
    log "Client deployment completed successfully!"
    log "Access client interface at: http://localhost:80"
    log "Access AWX at: http://localhost:8080"
    log "Access Vault at: http://localhost:8200"
}

# Kubernetes deployment
deploy_kubernetes() {
    local k8s_dir="$PROJECT_ROOT/k8s"
    
    log "Deploying to Kubernetes cluster..."
    
    # Check if Kubernetes manifests exist
    if [[ ! -d "$k8s_dir" ]]; then
        error "Kubernetes manifests directory not found: $k8s_dir"
    fi
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run - would deploy Kubernetes manifests from: $k8s_dir"
        return 0
    fi
    
    # Create namespaces
    log "Creating namespaces..."
    kubectl apply -f "$k8s_dir/namespace.yaml"
    
    # Wait for namespaces to be ready
    kubectl wait --for=condition=Ready namespace/msp-platform --timeout=60s
    kubectl wait --for=condition=Ready namespace/msp-monitoring --timeout=60s
    
    # Deploy PostgreSQL
    log "Deploying PostgreSQL..."
    kubectl apply -f "$k8s_dir/postgres.yaml"
    
    # Deploy Vault
    log "Deploying Vault..."
    kubectl apply -f "$k8s_dir/vault.yaml"
    
    # Deploy AWX
    log "Deploying AWX..."
    kubectl apply -f "$k8s_dir/awx.yaml"
    
    # Deploy monitoring
    log "Deploying monitoring stack..."
    kubectl apply -f "$k8s_dir/monitoring.yaml"
    
    # Deploy ingress
    log "Deploying ingress..."
    kubectl apply -f "$k8s_dir/ingress.yaml"
    
    # Wait for deployments to be ready
    log "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available deployment --all -n msp-platform --timeout=300s
    kubectl wait --for=condition=available deployment --all -n msp-monitoring --timeout=300s
    
    # Check service health
    check_kubernetes_health
    
    log "Kubernetes deployment completed successfully!"
    log "Check ingress for external access URLs"
}

# Check service health
check_service_health() {
    local deployment_type="$1"
    
    log "Checking service health for $deployment_type deployment..."
    
    case "$deployment_type" in
        "development"|"production")
            # Check AWX health
            if curl -sSf http://localhost:8080/api/v2/ping/ > /dev/null 2>&1; then
                log "✓ AWX is healthy"
            else
                warn "✗ AWX health check failed"
            fi
            
            # Check Vault health
            if curl -sSf http://localhost:8200/v1/sys/health > /dev/null 2>&1; then
                log "✓ Vault is healthy"
            else
                warn "✗ Vault health check failed"
            fi
            ;;
        "client")
            # Check client AWX health
            if curl -sSf http://localhost:8080/api/v2/ping/ > /dev/null 2>&1; then
                log "✓ Client AWX is healthy"
            else
                warn "✗ Client AWX health check failed"
            fi
            ;;
    esac
}

# Check Kubernetes health
check_kubernetes_health() {
    log "Checking Kubernetes deployment health..."
    
    # Check pod status
    local unhealthy_pods
    unhealthy_pods=$(kubectl get pods -n msp-platform -o jsonpath='{.items[?(@.status.phase!="Running")].metadata.name}' | wc -w)
    
    if [[ "$unhealthy_pods" -eq 0 ]]; then
        log "✓ All pods in msp-platform namespace are healthy"
    else
        warn "✗ $unhealthy_pods pods in msp-platform namespace are not healthy"
    fi
    
    # Check services
    local services
    services=$(kubectl get svc -n msp-platform -o jsonpath='{.items[*].metadata.name}')
    log "✓ Services deployed: $services"
    
    # Check ingress
    local ingress
    ingress=$(kubectl get ingress -n msp-platform -o jsonpath='{.items[*].metadata.name}')
    if [[ -n "$ingress" ]]; then
        log "✓ Ingress deployed: $ingress"
    else
        warn "✗ No ingress found"
    fi
}

# Cleanup function
cleanup() {
    local deployment_type="$1"
    
    log "Cleaning up $deployment_type deployment..."
    
    case "$deployment_type" in
        "development")
            cd "$PROJECT_ROOT/../msp-infrastructure"
            docker-compose down -v
            ;;
        "production")
            cd "$PROJECT_ROOT"
            docker-compose -f docker-compose.production.yml down -v
            ;;
        "client")
            cd "$PROJECT_ROOT"
            docker-compose -f docker-compose.client.yml down -v
            ;;
        "kubernetes")
            kubectl delete -f "$PROJECT_ROOT/k8s/" --ignore-not-found=true
            ;;
    esac
    
    log "Cleanup completed"
}

# Main function
main() {
    # Default values
    DEPLOYMENT_TYPE=""
    VERBOSE=false
    DRY_RUN=false
    FORCE=false
    CONFIG_FILE=""
    ENV_FILE=""
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -e|--env)
                ENV_FILE="$2"
                shift 2
                ;;
            dev|prod|client|kubernetes)
                DEPLOYMENT_TYPE="$1"
                shift
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Validate deployment type
    if [[ -z "$DEPLOYMENT_TYPE" ]]; then
        error "Deployment type is required. Use -h for help."
    fi
    
    # Enable verbose logging if requested
    if [[ "$VERBOSE" == "true" ]]; then
        set -x
    fi
    
    # Start deployment
    log "Starting MSP Platform deployment..."
    log "Deployment type: $DEPLOYMENT_TYPE"
    log "Dry run: $DRY_RUN"
    log "Force: $FORCE"
    log "Config file: ${CONFIG_FILE:-default}"
    log "Environment file: ${ENV_FILE:-default}"
    
    # Check dependencies
    check_dependencies
    
    if [[ "$DEPLOYMENT_TYPE" == "kubernetes" ]]; then
        check_kubernetes_dependencies
    fi
    
    # Deploy based on type
    case "$DEPLOYMENT_TYPE" in
        "dev")
            deploy_development
            ;;
        "prod")
            deploy_production
            ;;
        "client")
            deploy_client
            ;;
        "kubernetes")
            deploy_kubernetes
            ;;
        *)
            error "Unsupported deployment type: $DEPLOYMENT_TYPE"
            ;;
    esac
    
    log "Deployment completed successfully!"
}

# Trap for cleanup on exit
trap 'log "Script interrupted"; exit 1' INT TERM

# Execute main function
main "$@"