# MSP Platform - ansible-lockdown Integration

## Overview

This MSP platform integrates proven [ansible-lockdown](https://github.com/ansible-lockdown) community roles to provide enterprise-grade security compliance. Rather than recreating security controls, we leverage the community's expertise while adding MSP-specific multi-tenant capabilities.

## Supported Frameworks

### CIS Benchmarks
- **RHEL 8/9**: `ansible-lockdown.RHEL8-CIS`, `ansible-lockdown.RHEL9-CIS`
- **Ubuntu 20.04/22.04**: `ansible-lockdown.UBUNTU20-CIS`, `ansible-lockdown.UBUNTU22-CIS`

### DISA STIG
- **RHEL 8/9**: `ansible-lockdown.RHEL8-STIG`, `ansible-lockdown.RHEL9-STIG`

## Integration Architecture

### Variable Mapping
Our platform maps client-specific requirements to ansible-lockdown role variables:

```yaml
# MSP Client Configuration
client_name: "acme-corp"
client_compliance_framework: "cis"  # cis, stig
client_compliance_level: "level1"   # level1, level2
client_profile: "server"           # server, workstation

# Automatic mapping to ansible-lockdown variables
rhel8cis_level_1: "{{ (client_compliance_level == 'level1') | bool }}"
rhel8cis_server: "{{ (client_profile == 'server') | bool }}"
rhel8cis_disruption_high: "{{ client_allow_disruption | default(false) }}"
```

### Tagging Strategy
Following ansible-lockdown patterns with MSP enhancements:

- **Framework tags**: `cis`, `stig`
- **OS tags**: `rhel8`, `rhel9`, `ubuntu20`, `ubuntu22`
- **Category tags**: `hardening`, `dod`, `monitoring`
- **Client tags**: `{{ client_name }}`

### MSP Enhancements

1. **Multi-tenant isolation**: Each client gets dedicated compliance reporting
2. **Service integration**: Automatic integration with monitoring and backup roles
3. **Reporting standardization**: Unified compliance reports across frameworks
4. **Selective deployment**: Role-based application based on client tier

## Usage Examples

### Basic CIS Hardening
```bash
ansible-playbook integrate-lockdown-compliance.yml \
  -e client_name=acme-corp \
  -e client_compliance_framework=cis \
  -e client_compliance_level=level1 \
  -e client_profile=server
```

### STIG Compliance for Defense Contractors
```bash
ansible-playbook integrate-lockdown-compliance.yml \
  -e client_name=defense-contractor \
  -e client_compliance_framework=stig \
  -e client_cat1_controls=true \
  -e client_cat2_controls=true
```

### Selective Application with Tags
```bash
ansible-playbook integrate-lockdown-compliance.yml \
  -e client_name=test-client \
  --tags "cis,rhel8,monitoring"
```

## Client Configuration Variables

### Framework Selection
| Variable | Default | Options | Description |
|----------|---------|---------|-------------|
| `client_compliance_framework` | `cis` | `cis`, `stig` | Compliance framework to apply |
| `client_compliance_level` | `level1` | `level1`, `level2` | Compliance strictness level |
| `client_profile` | `server` | `server`, `workstation` | System profile type |

### Control Granularity
| Variable | Default | Description |
|----------|---------|-------------|
| `client_allow_disruption` | `false` | Allow high-disruption controls |
| `client_cat1_controls` | `true` | Apply Category I (high severity) controls |
| `client_cat2_controls` | `true` | Apply Category II (medium severity) controls |
| `client_cat3_controls` | `false` | Apply Category III (low severity) controls |

### MSP Integration
| Variable | Default | Description |
|----------|---------|-------------|
| `msp_enable_monitoring` | `true` | Integrate with MSP monitoring role |
| `msp_enable_backup` | `true` | Integrate with MSP backup role |

## Output and Reporting

### Compliance Reports
Reports are generated at: `/var/log/msp/{{ client_name }}/compliance/`

Example report structure:
```json
{
  "client": "acme-corp",
  "framework": "cis",
  "level": "level1",
  "profile": "server",
  "timestamp": "2025-07-09T14:30:00Z",
  "os_info": {
    "family": "RedHat",
    "distribution": "Rocky",
    "version": "9.2"
  },
  "roles_applied": [
    "ansible-lockdown.RHEL9-CIS",
    "monitoring",
    "backup"
  ]
}
```

## Best Practices

### Variable Management
1. Use client-specific variable files in `group_vars/client_{{ client_name }}/`
2. Leverage ansible-lockdown's disruption controls for production safety
3. Always test in development environments before production deployment

### Role Dependencies
1. Install ansible-lockdown roles via `requirements.yml`
2. Ensure proper role ordering (compliance → monitoring → backup)
3. Use tags for selective execution during maintenance windows

### Security Considerations
1. Review ansible-lockdown role documentation for impact assessment
2. Use `disruption_high: false` for production systems
3. Implement proper change management for compliance updates

## Integration with MSP Service Tiers

### Foundation Tier
- CIS Level 1 Server profile
- Basic monitoring integration
- Standard backup inclusion

### Professional Tier
- CIS Level 2 or STIG CAT II/III
- Advanced monitoring with alerting
- Enhanced backup with compliance config retention

### Enterprise Tier
- Full STIG implementation (CAT I/II/III)
- Custom compliance reporting
- Dedicated compliance validation

## Troubleshooting

### Common Issues
1. **Role not found**: Ensure `ansible-galaxy install -r requirements.yml` was run
2. **OS incompatibility**: Check supported distributions in ansible-lockdown README
3. **Variable conflicts**: Review variable precedence and client-specific overrides

### Debug Mode
```bash
ansible-playbook integrate-lockdown-compliance.yml \
  -e client_name=debug-client \
  --check --diff -vv
```

## Contributing

When enhancing the integration:
1. Follow ansible-lockdown variable naming conventions
2. Maintain backward compatibility with existing client configurations
3. Add appropriate tags for selective execution
4. Update this documentation with new features

## References

- [ansible-lockdown GitHub Organization](https://github.com/ansible-lockdown)
- [CIS Benchmarks](https://www.cisecurity.org/cis-benchmarks)
- [DISA STIG Library](https://public.cyber.mil/stigs/)
- [MSP Platform Documentation](./README.md)