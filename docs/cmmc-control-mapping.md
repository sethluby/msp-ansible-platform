# CMMC Control Mapping (Overview)

This document provides a high-level mapping between selected CMMC Level 2/3 control families and this repository’s playbooks/roles. It is illustrative, not exhaustive, and should be validated for each environment.

- Access Control (AC)
  - SSH hardening, key management → `ansible/playbooks/user-management.yml`, `willshersystems.sshd` (via `requirements.yml`)
  - Least privilege (sudo) → `user-management` role, sudo tasks
  - Network segmentation (host level) → firewall tasks in `network-security` role

- Audit and Accountability (AU)
  - Auditd install/config → `disa-stig-compliance-enhanced.yml`, `willshersystems.auditd`
  - Log routing/centralization → `msp-logging` role + SIEM integration points

- Configuration Management (CM)
  - Baseline configurations → `common` role, `system-update.yml` for patch baselines
  - Immutable templates (docs/examples) → `client-templates/`

- System and Information Integrity (SI)
  - Patch management → `system-update.yml`
  - Monitoring/alerting → `monitoring` role (Prometheus, Alertmanager, Grafana)

- Security Assessment (CA)
  - Post-implementation validation → `validate-compliance.yml` (validator hooks)
  - ansible-lockdown integration → `integrate-lockdown-compliance.yml`

Notes
- For DISA STIG/CIS specifics, see `ANSIBLE_LOCKDOWN_INTEGRATION.md`.
- Client-specific exceptions should live in `ansible/group_vars/<client>/` with tags for selective runs.
- Always test in non-production; controls vary by OS and mission requirements.
