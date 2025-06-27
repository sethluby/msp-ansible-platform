# MSP Client Pull Architecture - Vision & Design

**Version**: 1.0  
**Status**: Design Phase  
**Priority**: Core Architecture Foundation

## Executive Summary

The MSP Ansible Platform uses a **secure client-pull architecture** where clients initiate outbound-only connections to retrieve and execute automation tasks. This eliminates VPN complexity, reduces MSP attack surface, and provides strong client isolation while maintaining centralized management control.

## Core Principles

### 1. **Outbound-Only Client Connections**
- Clients connect TO MSP services, never vice versa
- No persistent tunnels or VPN infrastructure required
- Uses standard HTTPS with proper authentication

### 2. **Zero MSP Attack Surface**
- Clients cannot reach MSP internal infrastructure
- Compromised clients cannot access other clients
- MSP controls all distributed content and permissions

### 3. **Authenticated & Authorized Access**
- **Not publicly accessible** - All MSP data requires authentication
- Client-specific API keys with scoped permissions
- Cryptographically signed automation content
- Comprehensive audit logging

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          CLIENT NETWORK                         │
│  ┌────────────────┐   ┌──────────────────┐   ┌────────────────┐ │
│  │ MSP Client     │   │ Local Ansible    │   │ Client Systems │ │
│  │ Pull Runner    │──▶│ Execution        │──▶│ (managed)      │ │
│  │ (systemd timer)│   │ Environment      │   │                │ │
│  └────────────────┘   └──────────────────┘   └────────────────┘ │
│           │                                                     │
│           │ HTTPS API Calls (outbound only)                     │
│           │ • Check for updates                                 │
│           │ • Download playbooks                                │
│           │ • Report status                                     │
└───────────┼─────────────────────────────────────────────────────┘
            │
            ▼
┌───────────┼─────────────────────────────────────────────────────┐
│           │              MSP DISTRIBUTION SERVICES              │
│  ┌────────▼────────┐   ┌──────────────────┐   ┌────────────────┐ │
│  │ API Gateway     │   │ Content Store    │   │ MSP Internal   │ │
│  │ • Authentication│──▶│ • Signed         │   │ Infrastructure │ │
│  │ • Authorization │   │   Playbooks      │   │ • AWX/Tower    │ │
│  │ • Rate Limiting │   │ • Client Configs │   │ • Vault        │ │
│  │ • Audit Logging │   │ • Version Control│   │ • Monitoring   │ │
│  └─────────────────┘   └──────────────────┘   └────────────────┘ │
│                                                       ▲          │
│                          MSP Team Access ────────────┘          │
└─────────────────────────────────────────────────────────────────┘
```

## Security Model

### Client Authentication & Authorization
- **API Keys**: Unique per client, scoped to specific resources
- **Client Certificates**: Mutual TLS for high-security environments  
- **Signed Content**: All automation content cryptographically signed
- **Permission Scoping**: Clients can only access their assigned content

### Data Protection
- **Encrypted Transit**: All API communication over HTTPS/TLS 1.3
- **Content Signing**: GPG signatures on all distributed playbooks
- **Audit Trail**: Complete logging of all client pull requests
- **Client Isolation**: No cross-client data access possible

### Network Security
- **No Inbound Connections**: MSP never connects TO client networks
- **Standard Ports**: Uses HTTPS (443) - no special firewall rules needed
- **Public Internet**: Distribution point accessible via internet (authenticated)
- **Air-Gapped Support**: Offline mode for high-security environments

## Client Pull Workflow

### 1. **Client Registration**
```bash
# MSP generates client credentials
msp-client register --client-id "defense-contractor-001" \
  --service-tier enterprise \
  --compliance-frameworks cmmc,nist

# Client receives:
# - Unique API key
# - MSP distribution endpoint URL  
# - Client certificate (optional)
# - Initial configuration
```

### 2. **Automated Pull Cycle** (Every 15-30 minutes)
```bash
# Client-side automation (systemd timer)
/opt/msp-client/bin/pull-runner
├── 1. Check MSP API for updates
├── 2. Download new/updated playbooks  
├── 3. Verify cryptographic signatures
├── 4. Execute ansible-playbook locally
├── 5. Report execution status to MSP
└── 6. Update local state tracking
```

### 3. **Content Distribution**
```yaml
# MSP distributes client-specific content:
client-defense-contractor-001/:
  playbooks/:
    - security-hardening.yml      # CIS benchmarks
    - compliance-validation.yml   # CMMC controls
    - patch-management.yml        # Security updates
  inventory/:
    - production.yml             # Client systems inventory
  group_vars/:
    - client-specific.yml        # Custom configuration
```

## Service Tiers Integration

### Foundation Tier ($35-50/server/month)
- **Pull Frequency**: Every 30 minutes
- **Content**: Basic security hardening, patch management
- **Support**: Standard monitoring and alerting

### Professional Tier ($65-89/server/month)  
- **Pull Frequency**: Every 15 minutes
- **Content**: Advanced compliance, custom automation
- **Support**: Priority incident response

### Enterprise Tier ($95-125/server/month)
- **Pull Frequency**: Every 5 minutes (configurable)
- **Content**: CMMC compliance, advanced threat detection
- **Support**: Dedicated compliance reporting, 24/7 monitoring

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] MSP Distribution Point API design
- [ ] Client authentication system
- [ ] Basic content store with versioning
- [ ] Client pull runner implementation

### Phase 2: Security & Compliance
- [ ] Content signing and verification
- [ ] Audit logging and monitoring
- [ ] Compliance framework integration
- [ ] Client isolation verification

### Phase 3: Production Features
- [ ] Multi-tier service implementation
- [ ] Advanced client management
- [ ] Monitoring and alerting integration
- [ ] Graceful disconnection procedures

## Benefits Over Traditional MSP Models

### For MSPs:
- **Reduced Attack Surface**: No client access to MSP infrastructure
- **Simplified Networking**: No VPN management overhead
- **Better Scalability**: Stateless client connections
- **Compliance Friendly**: Clear audit trails and client isolation

### For Clients:
- **Network Security**: No inbound connections required
- **Firewall Friendly**: Standard HTTPS outbound only
- **Graceful Independence**: Can operate without MSP if needed
- **Transparent Operations**: Full visibility into automation being executed

## Technical Requirements

### MSP Infrastructure:
- **API Gateway**: Authentication, authorization, rate limiting
- **Content Store**: Versioned, signed automation content
- **Audit System**: Comprehensive logging and monitoring
- **Client Registry**: Configuration and state management

### Client Requirements:
- **Linux Systems**: RHEL/CentOS/Ubuntu/Rocky Linux
- **Ansible Core**: Local execution environment
- **Internet Access**: HTTPS outbound to MSP distribution point
- **SystemD/Cron**: Scheduled pull automation

## Compliance & Audit

### Audit Trail Components:
- Client authentication events
- Content pull requests and responses
- Playbook execution results
- Configuration changes and drift detection
- Compliance validation reports

### Compliance Framework Support:
- **CMMC Level 2/3**: Automated control implementation and validation
- **SOC 2 Type II**: Continuous monitoring and reporting
- **NIST 800-53**: Control mapping and evidence collection
- **HIPAA/PCI-DSS**: Industry-specific compliance automation

---

## Development Vision Statement

**This Client Pull Architecture serves as the foundational design for all MSP Ansible Platform development. Every feature, component, and integration should align with these core principles of security, simplicity, and client isolation.**

**Key Decision Points:**
- ✅ Outbound-only client connections
- ✅ Authenticated (not public) MSP distribution services
- ✅ Cryptographically signed automation content
- ✅ Strong client isolation and MSP protection
- ✅ Standard networking (HTTPS) with no VPN complexity

This document will be referenced and updated throughout development to ensure architectural consistency and security best practices.