# user-management Role

## Description
MSP platform role for user-management functionality.

Status: Experimental. The repository also includes a standalone playbook at `ansible/playbooks/user-management.yml` with more complete, playbook-driven operations. Prefer the playbook for full features until the role reaches parity.

## Requirements
- Ansible 2.10+
- Target systems: RHEL/CentOS 7-9, Ubuntu 18.04-22.04

## Role Variables
See `defaults/main.yml` for available variables.

## Dependencies
None.

## Example Playbook
```yaml
- hosts: servers
  roles:
    - user-management
```

## License
MIT

## Author Information
MSP Platform Development Team
