# MSP Ansible Architecture for CMMC Compliance

## Table of Contents

1. [[#Executive Summary|Executive Summary]]
2. [[#Architecture Overview|Architecture Overview]]
3. [[#Security Framework|Security Framework]]
4. [[#Network Architecture|Network Architecture]]
5. [[#Implementation Details|Implementation Details]]
6. [[#CMMC Compliance Integration|CMMC Compliance Integration]]
7. [[#Operational Procedures|Operational Procedures]]
8. [[#Monitoring and Logging|Monitoring and Logging]]
9. [[#Disaster Recovery|Disaster Recovery]]
10. [[#Performance Optimization|Performance Optimization]]
11. [[#Troubleshooting Guide|Troubleshooting Guide]]
12. [[#Appendices|Appendices]]

---

## Executive Summary

This document outlines a comprehensive architecture for managed service providers (MSPs) to securely manage distributed Linux infrastructure across multiple client sites using Ansible automation while maintaining CMMC (Cybersecurity Maturity Model Certification) compliance requirements.

### Key Design Principles

- **Zero Trust Architecture**: Every connection authenticated and encrypted
- **Defense in Depth**: Multiple security layers with fail-safe mechanisms
- **Least Privilege Access**: Minimal permissions with role-based access control
- **Continuous Compliance**: Automated validation and reporting
- **Scalable Operations**: Support for hundreds of client sites
- **High Availability**: Redundant systems with automated failover

### Business Benefits

- Reduced operational overhead through automation
- Enhanced security posture meeting CMMC Level 2/3 requirements
- Centralized management with client-specific isolation
- Comprehensive audit trails for compliance reporting
- Rapid deployment and consistent configuration management

---

## Architecture Overview

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                    MSP Data Center                              │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Ansible Tower   │  │ HashiCorp Vault │  │ Certificate     │ │
│  │ Primary/DR      │  │ Primary/DR      │  │ Authority       │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐ │
│  │ Regional        │  │ Monitoring      │  │ Log             │ │
│  │ Bastions        │  │ Stack           │  │ Aggregation     │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┼─────────┐
                    │         │         │
┌───────────────────▼──┐ ┌────▼────┐ ┌──▼─────────────────────┐
│   Client Site A      │ │Client B │ │   Client Site C        │
│ ┌─────────────────┐  │ │   ...   │ │ ┌─────────────────────┐│
│ │ Local Bastion   │  │ │         │ │ │ Local Bastion       ││
│ │ (DMZ)           │  │ │         │ │ │ (DMZ)               ││
│ └─────────────────┘  │ │         │ │ └─────────────────────┘│
│ ┌─────────────────┐  │ │         │ │ ┌─────────────────────┐│
│ │ Linux Servers   │  │ │         │ │ │ Linux Servers       ││
│ │ (Management)    │  │ │         │ │ │ (Management)        ││
│ └─────────────────┘  │ │         │ │ └─────────────────────┘│
│ ┌─────────────────┐  │ │         │ │ ┌─────────────────────┐│
│ │ Production      │  │ │         │ │ │ Production          ││
│ │ Systems         │  │ │         │ │ │ Systems             ││
│ └─────────────────┘  │ │         │ │ └─────────────────────┘│
└──────────────────────┘ └─────────┘ └────────────────────────┘
```

### Component Architecture

#### MSP Data Center Components

|Component|Purpose|HA Configuration|CMMC Controls|
|---|---|---|---|
|Ansible Tower/AWX|Automation orchestration|Active/Passive cluster|AC.1.001, AC.1.002|
|HashiCorp Vault|Secrets management|Multi-node cluster|SC.1.175, SC.1.176|
|Certificate Authority|PKI management|Primary/Secondary CA|IA.1.076, IA.1.077|
|Regional Bastions|Secure access gateways|Load-balanced pairs|AC.1.003, SC.1.178|
|Monitoring Stack|Observability platform|Clustered deployment|AU.1.006, SI.1.210|
|Log Aggregation|Centralized logging|Distributed storage|AU.1.006, AU.1.012|

#### Client Site Components

|Component|Purpose|Configuration|Security Controls|
|---|---|---|---|
|Local Bastion|Site access gateway|Hardened RHEL/Ubuntu|AC.1.001, AC.1.003|
|VPN Endpoint|Encrypted connectivity|IPSec/WireGuard|SC.1.175, SC.1.176|
|Ansible Agents|Configuration management|Pull/Push hybrid|CM.1.073, SI.1.210|
|Monitoring Agents|Telemetry collection|Prometheus/Grafana|AU.1.006, SI.1.214|

---

## Security Framework

### Authentication and Authorization

#### Multi-Factor Authentication Stack

```yaml
# Example PAM configuration for MFA
# /etc/pam.d/sshd
auth required pam_google_authenticator.so nullok
auth required pam_unix.so
account required pam_unix.so
session required pam_unix.so
```

#### Certificate-Based Authentication

```bash
# Generate client-specific certificates
#!/bin/bash
# /usr/local/bin/generate-client-cert.sh

CLIENT_ID=$1
CERT_DIR="/etc/pki/ansible/clients"
CA_KEY="/etc/pki/CA/private/ca.key"
CA_CERT="/etc/pki/CA/certs/ca.crt"

# Generate private key
openssl genrsa -out "${CERT_DIR}/${CLIENT_ID}.key" 4096

# Create certificate signing request
openssl req -new -key "${CERT_DIR}/${CLIENT_ID}.key" \
    -out "${CERT_DIR}/${CLIENT_ID}.csr" \
    -subj "/C=US/ST=State/L=City/O=MSP/OU=Ansible/CN=${CLIENT_ID}"

# Sign certificate
openssl x509 -req -in "${CERT_DIR}/${CLIENT_ID}.csr" \
    -CA "${CA_CERT}" -CAkey "${CA_KEY}" \
    -out "${CERT_DIR}/${CLIENT_ID}.crt" \
    -days 365 -sha256 \
    -extensions v3_req
```

#### Role-Based Access Control (RBAC)

```yaml
# Ansible Tower RBAC configuration
---
organizations:
  - name: "Client-{{ client_id }}"
    description: "{{ client_name }} Infrastructure"
    
teams:
  - name: "{{ client_id }}-admins"
    organization: "Client-{{ client_id }}"
    
  - name: "{{ client_id }}-operators"
    organization: "Client-{{ client_id }}"

roles:
  - name: "{{ client_id }}-admin-role"
    permissions:
      - job_template_admin
      - inventory_admin
      - credential_admin
    teams:
      - "{{ client_id }}-admins"
      
  - name: "{{ client_id }}-operator-role"
    permissions:
      - job_template_execute
      - inventory_read
    teams:
      - "{{ client_id }}-operators"
```

### Encryption Standards

#### Data in Transit

- **VPN Tunnels**: IPSec with AES-256-GCM, SHA-256 HMAC
- **SSH Connections**: Ed25519 keys, ChaCha20-Poly1305 cipher
- **API Communications**: TLS 1.3 with ECDHE-RSA-AES256-GCM-SHA384

#### Data at Rest

- **Ansible Vault**: AES-256 encryption for sensitive playbook data
- **Database**: Transparent Data Encryption (TDE) for Tower database
- **Log Storage**: AES-256 encryption with customer-managed keys

```yaml
# Ansible Vault encryption example
---
$ANSIBLE_VAULT;1.1;AES256
66386439653736336464643239373064623263396262343032626330623239343636346532653530
3562643465373265613266343431666131396433303163650a353835633061396264353763316264
31663463633962386464316364633066613464343738383536373438653030663735313431633437
6435326263386235650a653338343234313432663264303632343763303937626237613332316463
```

---

## Network Architecture

### Network Segmentation Strategy

#### MSP Data Center Network

```
MSP Data Center (10.0.0.0/16):
├── Management Network (10.0.1.0/24)
│   ├── Ansible Tower: 10.0.1.10-12
│   ├── Vault Cluster: 10.0.1.20-22
│   └── CA Services: 10.0.1.30-31
├── DMZ Network (10.0.2.0/24)
│   ├── Regional Bastions: 10.0.2.10-50
│   └── VPN Concentrators: 10.0.2.100-110
├── Monitoring Network (10.0.3.0/24)
│   ├── Prometheus: 10.0.3.10-12
│   ├── Grafana: 10.0.3.20-21
│   └── ELK Stack: 10.0.3.30-35
└── Storage Network (10.0.4.0/24)
    ├── NFS Servers: 10.0.4.10-12
    └── Backup Systems: 10.0.4.20-22
```

#### Client Site Network Template

```
Client Site (192.168.0.0/16):
├── DMZ Segment (192.168.100.0/24)
│   ├── Local Bastion: 192.168.100.10
│   ├── VPN Endpoint: 192.168.100.1
│   └── DNS/DHCP: 192.168.100.253-254
├── Management Segment (192.168.101.0/24)
│   ├── Linux Servers: 192.168.101.10-100
│   ├── Monitoring: 192.168.101.200-210
│   └── Backup: 192.168.101.250
├── Production Segment (192.168.102.0/24)
│   ├── Web Servers: 192.168.102.10-50
│   ├── Database Servers: 192.168.102.51-80
│   └── Application Servers: 192.168.102.81-150
└── Secure Segment (192.168.103.0/24)
    ├── CUI Systems: 192.168.103.10-50
    └── Privileged Access: 192.168.103.100-110
```

### Firewall Configuration

#### iptables Rules for Client Bastions

```bash
#!/bin/bash
# /etc/iptables/client-bastion-rules.sh

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default policies
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# Allow loopback
iptables -A INPUT -i lo -j ACCEPT

# Allow established connections
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH from MSP bastions only
iptables -A INPUT -p tcp --dport 22 -s 10.0.2.0/24 -j ACCEPT

# Allow VPN traffic
iptables -A INPUT -p udp --dport 500 -j ACCEPT
iptables -A INPUT -p udp --dport 4500 -j ACCEPT
iptables -A INPUT -p esp -j ACCEPT

# Allow forwarding between networks
iptables -A FORWARD -s 192.168.101.0/24 -d 192.168.102.0/24 -j ACCEPT
iptables -A FORWARD -s 192.168.102.0/24 -d 192.168.101.0/24 -j ACCEPT

# NAT for outbound traffic
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Save rules
iptables-save > /etc/iptables/rules.v4
```

### VPN Configuration

#### IPSec Configuration (StrongSwan)

```bash
# /etc/ipsec.conf
config setup
    charondebug="ike 1, knl 1, cfg 0"
    uniqueids=no

conn %default
    ikelifetime=60m
    keylife=20m
    rekeymargin=3m
    keyingtries=1
    keyexchange=ikev2
    authby=pubkey

conn msp-to-client-template
    left=%defaultroute
    leftid=@msp-regional-bastion
    leftcert=msp-bastion.crt
    leftfirewall=yes
    right=%any
    rightid=@client-*
    rightca=msp-ca.crt
    auto=add
    ike=aes256-sha256-modp2048!
    esp=aes256-sha256!
    leftsubnet=10.0.0.0/16
    compress=no
```

#### WireGuard Alternative Configuration

```ini
# /etc/wireguard/wg0.conf
[Interface]
PrivateKey = <MSP_PRIVATE_KEY>
Address = 172.16.0.1/24
ListenPort = 51820
SaveConfig = true

# Client Site Template
[Peer]
PublicKey = <CLIENT_PUBLIC_KEY>
AllowedIPs = 192.168.0.0/16
Endpoint = client.domain.com:51820
PersistentKeepalive = 25
```

---

## Implementation Details

### Ansible Tower Configuration

#### Project Structure

```
ansible-msp-infrastructure/
├── inventories/
│   ├── production/
│   │   ├── group_vars/
│   │   │   ├── all/
│   │   │   │   ├── main.yml
│   │   │   │   └── vault.yml
│   │   │   └── client_sites/
│   │   │       ├── client_001.yml
│   │   │       └── client_002.yml
│   │   └── hosts.yml
│   └── staging/
├── playbooks/
│   ├── site.yml
│   ├── compliance/
│   │   ├── cmmc-baseline.yml
│   │   ├── audit-config.yml
│   │   └── vulnerability-scan.yml
│   ├── maintenance/
│   │   ├── patching.yml
│   │   ├── backup.yml
│   │   └── monitoring.yml
│   └── emergency/
│       ├── incident-response.yml
│       └── recovery.yml
├── roles/
│   ├── common/
│   ├── security-hardening/
│   ├── monitoring/
│   ├── backup/
│   └── cmmc-compliance/
└── group_vars/
    └── all/
        ├── main.yml
        └── vault.yml
```

#### Dynamic Inventory Configuration

```python
#!/usr/bin/env python3
# dynamic_inventory.py

import json
import sys
import argparse
from vault_client import VaultClient
from tower_api import TowerAPI

class MSPInventory:
    def __init__(self):
        self.vault = VaultClient()
        self.tower = TowerAPI()
        self.inventory = {
            '_meta': {
                'hostvars': {}
            }
        }
    
    def get_clients(self):
        """Retrieve client configurations from Vault"""
        clients = self.vault.read('secret/clients')
        return clients['data']
    
    def build_inventory(self):
        """Build dynamic inventory from client configurations"""
        clients = self.get_clients()
        
        for client_id, config in clients.items():
            # Create client group
            group_name = f"client_{client_id}"
            self.inventory[group_name] = {
                'hosts': [],
                'vars': {
                    'ansible_ssh_common_args': f'-o ProxyJump=bastion-{client_id}.msp.com',
                    'compliance_level': config.get('cmmc_level', 'level_2'),
                    'client_id': client_id,
                    'backup_schedule': config.get('backup_schedule', 'daily')
                }
            }
            
            # Add hosts to client group
            for host in config.get('hosts', []):
                hostname = host['name']
                self.inventory[group_name]['hosts'].append(hostname)
                self.inventory['_meta']['hostvars'][hostname] = {
                    'ansible_host': host['ip'],
                    'ansible_user': 'ansible-service',
                    'host_role': host.get('role', 'generic'),
                    'environment': host.get('environment', 'production')
                }
        
        return self.inventory

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--host', action='store')
    args = parser.parse_args()
    
    inventory = MSPInventory()
    
    if args.list:
        print(json.dumps(inventory.build_inventory(), indent=2))
    elif args.host:
        print(json.dumps(inventory.get_host_vars(args.host), indent=2))
    else:
        sys.exit(1)
```

### Ansible Configuration

#### Main Configuration File

```ini
# ansible.cfg
[defaults]
inventory = ./inventories/production/hosts.yml
host_key_checking = True
timeout = 30
forks = 20
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_fact_cache
fact_caching_timeout = 86400
retry_files_enabled = False
vault_password_file = ~/.vault_pass
roles_path = ./roles
collections_paths = ./collections
remote_user = ansible-service
private_key_file = ~/.ssh/ansible_rsa

[inventory]
enable_plugins = host_list, script, auto, yaml, ini, toml

[ssh_connection]
ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s -o StrictHostKeyChecking=yes
control_path_dir = /tmp/ansible-ssh-%%h-%%p-%%r
control_path = %(control_path_dir)s/%%C
pipelining = True
scp_if_ssh = smart

[persistent_connection]
connect_timeout = 30
command_timeout = 30

[colors]
highlight = white
verbose = blue
warn = bright purple
error = red
debug = dark gray
deprecate = purple
skip = cyan
unreachable = red
ok = green
changed = yellow
diff_add = green
diff_remove = red
diff_lines = cyan
```

#### Core Playbook Structure

```yaml
---
# site.yml - Main orchestration playbook
- name: MSP Infrastructure Management
  hosts: all
  gather_facts: yes
  become: yes
  
  pre_tasks:
    - name: Verify connection and gather facts
      setup:
      tags: always
      
    - name: Check CMMC compliance status
      include_tasks: tasks/compliance-check.yml
      tags: compliance
      
    - name: Validate security baseline
      include_tasks: tasks/security-validation.yml
      tags: security

  roles:
    - role: common
      tags: common
      
    - role: security-hardening
      tags: security
      when: security_hardening_enabled | default(true)
      
    - role: monitoring
      tags: monitoring
      when: monitoring_enabled | default(true)
      
    - role: backup
      tags: backup
      when: backup_enabled | default(true)
      
    - role: cmmc-compliance
      tags: compliance
      when: cmmc_compliance_enabled | default(true)

  post_tasks:
    - name: Generate compliance report
      include_tasks: tasks/generate-report.yml
      tags: always
      
    - name: Send notifications
      include_tasks: tasks/notifications.yml
      tags: always
```

### Security Hardening Role

#### Main Tasks

```yaml
---
# roles/security-hardening/tasks/main.yml
- name: Apply CIS benchmarks
  include_tasks: cis-benchmarks.yml
  tags: cis

- name: Configure SELinux/AppArmor
  include_tasks: mandatory-access-control.yml
  tags: mac

- name: Harden SSH configuration
  include_tasks: ssh-hardening.yml
  tags: ssh

- name: Configure firewall rules
  include_tasks: firewall-config.yml
  tags: firewall

- name: Install and configure AIDE
  include_tasks: file-integrity.yml
  tags: aide

- name: Configure audit system
  include_tasks: audit-config.yml
  tags: audit

- name: Apply kernel hardening
  include_tasks: kernel-hardening.yml
  tags: kernel
```

#### SSH Hardening Tasks

```yaml
---
# roles/security-hardening/tasks/ssh-hardening.yml
- name: Configure SSH daemon
  template:
    src: sshd_config.j2
    dest: /etc/ssh/sshd_config
    backup: yes
    mode: '0600'
    owner: root
    group: root
  notify: restart sshd
  tags: ssh-config

- name: Generate strong SSH host keys
  command: ssh-keygen -t {{ item.type }} -b {{ item.bits }} -f {{ item.path }}
  args:
    creates: "{{ item.path }}"
  loop:
    - { type: 'rsa', bits: 4096, path: '/etc/ssh/ssh_host_rsa_key' }
    - { type: 'ed25519', bits: 256, path: '/etc/ssh/ssh_host_ed25519_key' }
  notify: restart sshd
  tags: ssh-keys

- name: Set proper permissions on SSH host keys
  file:
    path: "{{ item }}"
    mode: '0600'
    owner: root
    group: root
  loop:
    - /etc/ssh/ssh_host_rsa_key
    - /etc/ssh/ssh_host_ed25519_key
  tags: ssh-permissions

- name: Configure SSH client settings
  template:
    src: ssh_config.j2
    dest: /etc/ssh/ssh_config
    backup: yes
    mode: '0644'
    owner: root
    group: root
  tags: ssh-client
```

---

## CMMC Compliance Integration

### Compliance Control Mapping

#### Access Control (AC) Controls

```yaml
---
# roles/cmmc-compliance/vars/ac-controls.yml
ac_controls:
  AC.1.001:
    title: "Limit information system access to authorized users"
    implementation: "ssh_key_auth_only"
    validation: "check_ssh_password_auth_disabled"
    
  AC.1.002:
    title: "Limit information system access to authorized transactions"
    implementation: "sudo_restrictions"
    validation: "check_sudo_configuration"
    
  AC.1.003:
    title: "Control information posted or processed on publicly accessible systems"
    implementation: "dmz_segmentation"
    validation: "check_network_segmentation"
```

#### Implementation Tasks

```yaml
---
# roles/cmmc-compliance/tasks/ac-controls.yml
- name: AC.1.001 - Implement authorized user access only
  block:
    - name: Disable password authentication
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PasswordAuthentication'
        line: 'PasswordAuthentication no'
        state: present
      notify: restart sshd

    - name: Enable public key authentication
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?PubkeyAuthentication'
        line: 'PubkeyAuthentication yes'
        state: present
      notify: restart sshd

    - name: Restrict user access via AllowUsers
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?AllowUsers'
        line: "AllowUsers {{ allowed_ssh_users | join(' ') }}"
        state: present
      notify: restart sshd
  tags: AC.1.001

- name: AC.1.002 - Implement transaction controls
  block:
    - name: Configure sudo restrictions
      template:
        src: sudoers.j2
        dest: /etc/sudoers.d/cmmc-restrictions
        mode: '0440'
        owner: root
        group: root
        validate: 'visudo -cf %s'

    - name: Install and configure pam_tty_audit
      lineinfile:
        path: /etc/pam.d/system-auth
        regexp: '^session.*pam_tty_audit.so'
        line: 'session required pam_tty_audit.so enable=* log_passwd'
        state: present
  tags: AC.1.002
```

### Audit Configuration (AU) Controls

#### Comprehensive Audit Rules

```bash
# templates/audit.rules.j2
# CMMC Audit Rules for {{ inventory_hostname }}

# Delete all existing rules
-D

# Buffer size
-b 8192

# Failure mode (0=silent, 1=printk, 2=panic)
-f 1

# AC.1.001 - Monitor user access
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/shadow -p wa -k identity

# AC.1.002 - Monitor privileged commands
{% for cmd in privileged_commands %}
-w {{ cmd }} -p x -k privileged-commands
{% endfor %}

# AU.1.006 - Monitor system configuration changes
-w /etc/ssh/sshd_config -p wa -k ssh-config
-w /etc/sudoers -p wa -k sudo-config
-w /etc/hosts -p wa -k network-config

# CM.1.073 - Monitor configuration management
-w /etc/ansible -p wa -k ansible-config
-w /var/log/ansible -p wa -k ansible-logs

# IA.1.076 - Monitor authentication events
-w /var/log/auth.log -p wa -k authentication
-w /var/log/secure -p wa -k authentication

# SC.1.175 - Monitor network connections
-a always,exit -F arch=b64 -S socket -k network-connections
-a always,exit -F arch=b32 -S socket -k network-connections

# Lock the configuration
-e 2
```

### System and Communications Protection (SC) Controls

#### Encryption Configuration

```yaml
---
# roles/cmmc-compliance/tasks/sc-controls.yml
- name: SC.1.175 - Implement encryption for data in transit
  block:
    - name: Configure TLS minimum version
      lineinfile:
        path: /etc/ssl/openssl.cnf
        regexp: '^MinProtocol'
        line: 'MinProtocol = TLSv1.2'
        state: present

    - name: Disable weak SSL/TLS ciphers
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?Ciphers'
        line: 'Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr'
        state: present
      notify: restart sshd

    - name: Configure strong MAC algorithms
      lineinfile:
        path: /etc/ssh/sshd_config
        regexp: '^#?MACs'
        line: 'MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512'
        state: present
      notify: restart sshd
  tags: SC.1.175

- name: SC.1.176 - Implement encryption for data at rest
  block:
    - name: Check if LUKS encryption is enabled
      command: lsblk -f
      register: luks_status
      changed_when: false

    - name: Install cryptsetup if not present
      package:
        name: cryptsetup
        state: present

    - name: Configure encrypted swap
      include_tasks: encrypted-swap.yml
      when: configure_encrypted_swap | default(false)
  tags: SC.1.176
```

### Validation and Reporting

#### Compliance Validation Script

```python
#!/usr/bin/env python3
# roles/cmmc-compliance/files/validate_compliance.py

import subprocess
import json
import sys
from datetime import datetime

class CMICComplianceValidator:
    def __init__(self):
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'hostname': subprocess.getoutput('hostname'),
            'controls': {}
        }
    
    def validate_ac_001(self):
        """Validate AC.1.001 - Authorized user access only"""
        try:
            # Check if password authentication is disabled
            with open('/etc/ssh/sshd_config', 'r') as f:
                config = f.read()
            
            password_auth_disabled = 'PasswordAuthentication no' in config
            pubkey_auth_enabled = 'PubkeyAuthentication yes' in config
            
            self.results['controls']['AC.1.001'] = {
                'status': 'PASS' if password_auth_disabled and pubkey_auth_enabled else 'FAIL',
                'details': {
                    'password_auth_disabled': password_auth_disabled,
                    'pubkey_auth_enabled': pubkey_auth_enabled
                }
            }
        except Exception as e:
            self.results['controls']['AC.1.001'] = {
                'status': 'ERROR',
                'error': str(e)
            }
    
    def validate_au_006(self):
        """Validate AU.1.006 - Audit record content"""
        try:
            # Check if auditd is running
            audit_status = subprocess.run(['systemctl', 'is-active', 'auditd'], 
                                        capture_output=True, text=True)
            auditd_running = audit_status.stdout.strip() == 'active'
            
            # Check audit rules
            audit_rules = subprocess.getoutput('auditctl -l')
            required_rules = [
                '/etc/passwd',
                '/etc/shadow',
                '/etc/sudoers',
                'privileged-commands'
            ]
            
            rules_present = all(rule in audit_rules for rule in required_rules)
            
            self.results['controls']['AU.1.006'] = {
                'status': 'PASS' if auditd_running and rules_present else 'FAIL',
                'details': {
                    'auditd_running': auditd_running,
                    'required_rules_present': rules_present,
                    'audit_rules_count': len(audit_rules.split('\n'))
                }
            }
        except Exception as e:
            self.results['controls']['AU.1.006'] = {
                'status': 'ERROR',
                'error': str(e)
            }
    
    def validate_sc_175(self):
        """Validate SC.1.175 - Encryption in transit"""
        try:
            # Check SSH cipher configuration
            with open('/etc/ssh/sshd_config', 'r') as f:
                ssh_config = f.read()
            
            weak_ciphers = ['3des', 'blowfish', 'cast128', 'arcfour']
            strong_ciphers_configured = 'chacha20-poly1305' in ssh_config
            weak_ciphers_disabled = not any(cipher in ssh_config.lower() for cipher in weak_ciphers)
            
            # Check TLS configuration
            tls_min_version = subprocess.getoutput('openssl version')
            
            self.results['controls']['SC.1.175'] = {
                'status': 'PASS' if strong_ciphers_configured and weak_ciphers_disabled else 'FAIL',
                'details': {
                    'strong_ciphers_configured': strong_ciphers_configured,
                    'weak_ciphers_disabled': weak_ciphers_disabled,
                    'openssl_version': tls_min_version
                }
            }
        except Exception as e:
            self.results['controls']['SC.1.175'] = {
                'status': 'ERROR',
                'error': str(e)
            }
    
    def run_all_validations(self):
        """Run all compliance validations"""
        self.validate_ac_001()
        self.validate_au_006()
        self.validate_sc_175()
        
        # Calculate overall compliance score
        total_controls = len(self.results['controls'])
        passed_controls = sum(1 for control in self.results['controls'].values() 
                            if control['status'] == 'PASS')
        
        self.results['compliance_score'] = {
            'total_controls': total_controls,
            'passed_controls': passed_controls,
            'percentage': (passed_controls / total_controls * 100) if total_controls > 0 else 0
        }
        
        return self.results

if __name__ == '__main__':
    validator = CMICComplianceValidator()
    results = validator.run_all_validations()
    print(json.dumps(results, indent=2))
```

---

## Operational Procedures

### Daily Operations Workflow

#### Automated Daily Tasks

```yaml
---
# playbooks/daily-operations.yml
- name: Daily MSP Operations
  hosts: all
  gather_facts: yes
  become: yes
  
  tasks:
    - name: Check system health
      include_tasks: tasks/health-check.yml
      tags: health
      
    - name: Validate compliance status
      include_tasks: tasks/compliance-check.yml
      tags: compliance
      
    - name: Update security definitions
      include_tasks: tasks/security-updates.yml
      tags: security
      
    - name: Backup configuration files
      include_tasks: tasks/config-backup.yml
      tags: backup
      
    - name: Generate daily reports
      include_tasks: tasks/daily-reports.yml
      tags: reporting
      delegate_to: localhost
      run_once: true
```

#### Health Check Tasks

```yaml
---
# tasks/health-check.yml
- name: Check disk space
  shell: df -h | awk '$5 > 80 {print $0}'
  register: disk_usage
  changed_when: false
  failed_when: disk_usage.stdout != ""

- name: Check memory usage
  shell: free | awk 'NR==2{printf "%.2f%%", $3*100/$2}'
  register: memory_usage
  changed_when: false

- name: Check CPU load
  shell: uptime | awk -F'load average:' '{print $2}'
  register: cpu_load
  changed_when: false

- name: Check critical services
  systemd:
    name: "{{ item }}"
    state: started
  loop:
    - sshd
    - auditd
    - rsyslog
    - firewalld
  register: service_status

- name: Check network connectivity
  uri:
    url: "https://{{ msp_monitoring_endpoint }}/health"
    method: GET
    timeout: 10
  register: network_check
  delegate_to: localhost
```

### Patch Management

#### Automated Patching Workflow

```yaml
---
# playbooks/patching.yml
- name: Automated Patch Management
  hosts: all
  gather_facts: yes
  become: yes
  serial: "{{ patch_batch_size | default('25%') }}"
  
  pre_tasks:
    - name: Create pre-patch snapshot
      include_tasks: tasks/create-snapshot.yml
      when: snapshot_enabled | default(true)
      
    - name: Validate system stability
      include_tasks: tasks/stability-check.yml
      
    - name: Notify patch start
      uri:
        url: "{{ webhook_url }}/patch-start"
        method: POST
        body_format: json
        body:
          hostname: "{{ inventory_hostname }}"
          patch_window: "{{ patch_window }}"
      delegate_to: localhost

  tasks:
    - name: Update package cache
      package:
        update_cache: yes
      when: ansible_os_family in ['Debian', 'RedHat']
      
    - name: Install security updates only
      package:
        name: "*"
        state: latest
        security: yes
      when: 
        - patch_type == 'security'
        - ansible_os_family == 'RedHat'
        
    - name: Install all updates
      package:
        name: "*"
        state: latest
      when: patch_type == 'full'
      
    - name: Check if reboot required
      stat:
        path: /var/run/reboot-required
      register: reboot_required
      when: ansible_os_family == 'Debian'
      
    - name: Check if reboot required (RHEL)
      shell: needs-restarting -r
      register: reboot_required_rhel
      failed_when: false
      changed_when: false
      when: ansible_os_family == 'RedHat'

  post_tasks:
    - name: Reboot if required
      reboot:
        reboot_timeout: 300
        connect_timeout: 5
        test_command: uptime
      when: >
        (reboot_required is defined and reboot_required.stat.exists) or
        (reboot_required_rhel is defined and reboot_required_rhel.rc != 0)
        
    - name: Validate services after reboot
      include_tasks: tasks/post-patch-validation.yml
      
    - name: Notify patch completion
      uri:
        url: "{{ webhook_url }}/patch-complete"
        method: POST
        body_format: json
        body:
          hostname: "{{ inventory_hostname }}"
          status: "{{ patch_status | default('success') }}"
          reboot_required: "{{ reboot_performed | default(false) }}"
      delegate_to: localhost
```

### Backup and Recovery

#### Automated Backup Configuration

```yaml
---
# roles/backup/tasks/main.yml
- name: Install backup utilities
  package:
    name:
      - rsync
      - tar
      - gzip
      - duplicity
    state: present

- name: Create backup directories
  file:
    path: "{{ item }}"
    state: directory
    mode: '0750'
    owner: backup
    group: backup
  loop:
    - /opt/backup/scripts
    - /opt/backup/logs
    - /var/backup/local
    - /var/backup/remote

- name: Configure backup script
  template:
    src: backup-script.sh.j2
    dest: /opt/backup/scripts/system-backup.sh
    mode: '0750'
    owner: backup
    group: backup

- name: Schedule backup jobs
  cron:
    name: "{{ item.name }}"
    minute: "{{ item.minute }}"
    hour: "{{ item.hour }}"
    day: "{{ item.day | default('*') }}"
    month: "{{ item.month | default('*') }}"
    weekday: "{{ item.weekday | default('*') }}"
    user: backup
    job: "{{ item.job }}"
  loop:
    - name: "Daily configuration backup"
      minute: "0"
      hour: "2"
      job: "/opt/backup/scripts/system-backup.sh config"
    - name: "Weekly full backup"
      minute: "0"
      hour: "1"
      weekday: "0"
      job: "/opt/backup/scripts/system-backup.sh full"
```

#### Backup Script Template

```bash
#!/bin/bash
# templates/backup-script.sh.j2

set -euo pipefail

BACKUP_TYPE="${1:-config}"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
HOSTNAME=$(hostname -s)
LOCAL_BACKUP_DIR="/var/backup/local"
REMOTE_BACKUP_DIR="{{ backup_remote_path }}"
LOG_FILE="/opt/backup/logs/backup_${TIMESTAMP}.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "${LOG_FILE}"
}

# Configuration backup function
backup_config() {
    log "Starting configuration backup for ${HOSTNAME}"
    
    CONFIG_DIRS=(
        "/etc"
        "/home"
        "/root"
        "/var/log/audit"
        "/var/lib/ansible"
    )
    
    BACKUP_FILE="${LOCAL_BACKUP_DIR}/${HOSTNAME}_config_${TIMESTAMP}.tar.gz"
    
    tar -czf "${BACKUP_FILE}" \
        --exclude="/etc/mtab" \
        --exclude="/etc/fstab.orig" \
        "${CONFIG_DIRS[@]}" 2>>"${LOG_FILE}"
    
    log "Configuration backup completed: ${BACKUP_FILE}"
    
    # Encrypt and transfer to remote location
    gpg --trust-model always --encrypt \
        --recipient "{{ backup_encryption_key }}" \
        --output "${BACKUP_FILE}.gpg" \
        "${BACKUP_FILE}"
    
    rsync -avz --progress "${BACKUP_FILE}.gpg" \
        "{{ backup_user }}@{{ backup_server }}:${REMOTE_BACKUP_DIR}/" \
        >>"${LOG_FILE}" 2>&1
    
    # Cleanup local files older than 7 days
    find "${LOCAL_BACKUP_DIR}" -name "*.tar.gz*" -mtime +7 -delete
}

# Full system backup function
backup_full() {
    log "Starting full system backup for ${HOSTNAME}"
    
    duplicity \
        --encrypt-key "{{ backup_encryption_key }}" \
        --exclude /proc \
        --exclude /sys \
        --exclude /dev \
        --exclude /tmp \
        --exclude /var/tmp \
        / \
        "rsync://{{ backup_user }}@{{ backup_server }}/${REMOTE_BACKUP_DIR}/full/" \
        >>"${LOG_FILE}" 2>&1
    
    log "Full backup completed"
}

# Main execution
case "${BACKUP_TYPE}" in
    "config")
        backup_config
        ;;
    "full")
        backup_full
        ;;
    *)
        log "Invalid backup type: ${BACKUP_TYPE}"
        exit 1
        ;;
esac

# Send notification
curl -X POST "{{ webhook_url }}/backup-status" \
    -H "Content-Type: application/json" \
    -d "{\"hostname\":\"${HOSTNAME}\",\"type\":\"${BACKUP_TYPE}\",\"status\":\"completed\",\"timestamp\":\"${TIMESTAMP}\"}" \
    >>"${LOG_FILE}" 2>&1

log "Backup process completed successfully"
```

---

## Monitoring and Logging

### Prometheus Monitoring Configuration

#### Node Exporter Setup

```yaml
---
# roles/monitoring/tasks/node-exporter.yml
- name: Create node_exporter user
  user:
    name: node_exporter
    system: yes
    shell: /bin/false
    home: /var/lib/node_exporter
    createhome: no

- name: Download and install node_exporter
  unarchive:
    src: "https://github.com/prometheus/node_exporter/releases/download/v{{ node_exporter_version }}/node_exporter-{{ node_exporter_version }}.linux-amd64.tar.gz"
    dest: /opt/
    remote_src: yes
    creates: "/opt/node_exporter-{{ node_exporter_version }}.linux-amd64/node_exporter"
    owner: node_exporter
    group: node_exporter

- name: Create symlink for node_exporter
  file:
    src: "/opt/node_exporter-{{ node_exporter_version }}.linux-amd64/node_exporter"
    dest: /usr/local/bin/node_exporter
    state: link

- name: Create node_exporter systemd service
  template:
    src: node_exporter.service.j2
    dest: /etc/systemd/system/node_exporter.service
    mode: '0644'
  notify:
    - reload systemd
    - restart node_exporter

- name: Start and enable node_exporter
  systemd:
    name: node_exporter
    state: started
    enabled: yes
    daemon_reload: yes
```

#### Prometheus Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

rule_files:
  - "cmmc_rules.yml"
  - "infrastructure_rules.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'client-infrastructure'
    static_configs:
{% for client in groups['all'] %}
      - targets: ['{{ hostvars[client]['ansible_host'] }}:9100']
        labels:
          client_id: '{{ hostvars[client]['client_id'] }}'
          environment: '{{ hostvars[client]['environment'] }}'
          compliance_level: '{{ hostvars[client]['compliance_level'] }}'
{% endfor %}

  - job_name: 'ansible-tower'
    static_configs:
      - targets: ['tower.msp.internal:9090']

  - job_name: 'vault-cluster'
    static_configs:
      - targets: 
        - 'vault-01.msp.internal:8200'
        - 'vault-02.msp.internal:8200'
        - 'vault-03.msp.internal:8200'
```

#### CMMC Compliance Alerting Rules

```yaml
# cmmc_rules.yml
groups:
- name: cmmc_compliance
  rules:
  - alert: UnauthorizedSSHAccess
    expr: increase(node_ssh_logins_total[5m]) > 10
    for: 1m
    labels:
      severity: critical
      cmmc_control: AC.1.001
    annotations:
      summary: "Potential unauthorized SSH access on {{ $labels.instance }}"
      description: "High number of SSH login attempts detected"

  - alert: AuditdServiceDown
    expr: node_systemd_unit_state{name="auditd.service",state="active"} == 0
    for: 0m
    labels:
      severity: critical
      cmmc_control: AU.1.006
    annotations:
      summary: "Auditd service is down on {{ $labels.instance }}"
      description: "Critical audit service is not running"

  - alert: WeakCryptographyDetected
    expr: node_ssh_weak_ciphers_enabled == 1
    for: 0m
    labels:
      severity: high
      cmmc_control: SC.1.175
    annotations:
      summary: "Weak cryptography detected on {{ $labels.instance }}"
      description: "Weak SSH ciphers or protocols are enabled"

  - alert: PrivilegedCommandExecution
    expr: increase(node_audit_privileged_commands_total[5m]) > 50
    for: 2m
    labels:
      severity: warning
      cmmc_control: AC.1.002
    annotations:
      summary: "High privileged command usage on {{ $labels.instance }}"
      description: "Unusual level of privileged command execution detected"
```

### Centralized Logging with ELK Stack

#### Filebeat Configuration

```yaml
# roles/monitoring/templates/filebeat.yml.j2
filebeat.inputs:
- type: log
  enabled: true
  paths:
    - /var/log/auth.log
    - /var/log/secure
  fields:
    log_type: authentication
    client_id: "{{ client_id }}"
    compliance_level: "{{ compliance_level }}"

- type: log
  enabled: true
  paths:
    - /var/log/audit/audit.log
  fields:
    log_type: audit
    client_id: "{{ client_id }}"
    compliance_level: "{{ compliance_level }}"

- type: log
  enabled: true
  paths:
    - /var/log/ansible.log
  fields:
    log_type: ansible
    client_id: "{{ client_id }}"

output.logstash:
  hosts: ["{{ logstash_server }}:5044"]

processors:
- add_host_metadata:
    when.not.contains.tags: forwarded

- add_fields:
    target: cmmc
    fields:
      environment: "{{ environment }}"
      client_id: "{{ client_id }}"
      compliance_level: "{{ compliance_level }}"

logging.level: info
logging.to_files: true
logging.files:
  path: /var/log/filebeat
  name: filebeat
  keepfiles: 7
  permissions: 0644
```

#### Logstash Pipeline Configuration

```ruby
# logstash/pipeline/cmmc-compliance.conf
input {
  beats {
    port => 5044
  }
}

filter {
  if [fields][log_type] == "authentication" {
    grok {
      match => { "message" => "%{SYSLOGTIMESTAMP:timestamp} %{IPORHOST:host} %{WORD:service}\[%{POSINT:pid}\]: %{GREEDYDATA:auth_message}" }
    }
    
    if "Failed password" in [auth_message] {
      mutate {
        add_tag => ["failed_login", "security_event"]
        add_field => { "event_type" => "failed_authentication" }
        add_field => { "cmmc_control" => "AC.1.001" }
      }
    }
    
    if "Accepted publickey" in [auth_message] {
      mutate {
        add_tag => ["successful_login"]
        add_field => { "event_type" => "successful_authentication" }
        add_field => { "cmmc_control" => "AC.1.001" }
      }
    }
  }
  
  if [fields][log_type] == "audit" {
    grok {
      match => { "message" => "type=%{WORD:audit_type} msg=audit\(%{NUMBER:audit_timestamp}:%{NUMBER:audit_serial}\): %{GREEDYDATA:audit_data}" }
    }
    
    if [audit_type] == "SYSCALL" {
      mutate {
        add_tag => ["system_call"]
        add_field => { "cmmc_control" => "AU.1.006" }
      }
    }
    
    if [audit_type] == "USER_CMD" {
      mutate {
        add_tag => ["privileged_command"]
        add_field => { "cmmc_control" => "AC.1.002" }
      }
    }
  }
  
  date {
    match => [ "timestamp", "MMM  d HH:mm:ss", "MMM dd HH:mm:ss" ]
  }
}

output {
  elasticsearch {
    hosts => ["{{ elasticsearch_cluster }}"]
    index => "cmmc-logs-%{+YYYY.MM.dd}"
    template_name => "cmmc-compliance"
    template_pattern => "cmmc-logs-*"
    template => "/etc/logstash/templates/cmmc-template.json"
  }
  
  if "security_event" in [tags] {
    http {
      url => "{{ security_webhook_url }}"
      http_method => "post"
      content_type => "application/json"
      format => "json"
    }
  }
}
```

---

## Disaster Recovery

### Backup and Recovery Strategy

#### Recovery Time Objectives (RTO) and Recovery Point Objectives (RPO)

|System Component|RTO|RPO|Recovery Method|
|---|---|---|---|
|Ansible Tower|1 hour|15 minutes|Hot standby with database replication|
|HashiCorp Vault|30 minutes|5 minutes|Multi-node cluster with auto-failover|
|Client Bastions|2 hours|1 hour|Automated provisioning from templates|
|Configuration Management|4 hours|24 hours|Git repository restoration + playbook execution|
|Monitoring Stack|1 hour|1 hour|Container orchestration with persistent volumes|

#### Disaster Recovery Playbook

```yaml
---
# playbooks/disaster-recovery.yml
- name: Disaster Recovery Procedures
  hosts: localhost
  gather_facts: no
  vars:
    recovery_scenario: "{{ recovery_type | default('partial') }}"
    
  tasks:
    - name: Assess disaster scope
      include_tasks: tasks/disaster-assessment.yml
      
    - name: Activate emergency procedures
      include_tasks: tasks/emergency-activation.yml
      when: recovery_scenario == 'total'
      
    - name: Restore core infrastructure
      include_tasks: tasks/restore-infrastructure.yml
      
    - name: Restore client connectivity
      include_tasks: tasks/restore-connectivity.yml
      
    - name: Validate recovery
      include_tasks: tasks/validate-recovery.yml
      
    - name: Generate recovery report
      include_tasks: tasks/recovery-report.yml
```

#### Infrastructure Restoration Tasks

```yaml
---
# tasks/restore-infrastructure.yml
- name: Deploy emergency Ansible Tower
  aws_ec2:
    name: "ansible-tower-emergency"
    image_id: "{{ emergency_ami_id }}"
    instance_type: "{{ tower_instance_type }}"
    key_name: "{{ emergency_key_pair }}"
    security_groups: "{{ tower_security_groups }}"
    subnet_id: "{{ emergency_subnet_id }}"
    user_data: "{{ lookup('file', 'emergency-bootstrap.sh') }}"
    tags:
      Environment: emergency
      Service: ansible-tower
      Recovery: disaster
  register: emergency_tower

- name: Wait for Tower to be accessible
  wait_for:
    host: "{{ emergency_tower.instances[0].public_ip }}"
    port: 443
    timeout: 300

- name: Restore Tower configuration from backup
  uri:
    url: "https://{{ emergency_tower.instances[0].public_ip }}/api/v2/config/"
    method: POST
    body_format: json
    body: "{{ lookup('file', '/backup/tower-config.json') | from_json }}"
    headers:
      Authorization: "Bearer {{ emergency_api_token }}"
    validate_certs: no

- name: Deploy emergency Vault cluster
  include_tasks: deploy-emergency-vault.yml
  
- name: Restore Vault data from backup
  shell: |
    vault operator unseal {{ vault_unseal_key_1 }}
    vault operator unseal {{ vault_unseal_key_2 }}
    vault operator unseal {{ vault_unseal_key_3 }}
    vault auth -method=userpass username=recovery password={{ recovery_password }}
    vault write secret/recovery/status status=active timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
```

### Business Continuity Procedures

#### Emergency Response Team Contacts

```yaml
---
# Emergency response configuration
emergency_contacts:
  - role: "Incident Commander"
    primary: "+1-555-0101"
    secondary: "+1-555-0102"
    email: "incident-commander@msp.com"
    
  - role: "Technical Lead"
    primary: "+1-555-0201"
    secondary: "+1-555-0202"
    email: "tech-lead@msp.com"
    
  - role: "Client Relations"
    primary: "+1-555-0301"
    secondary: "+1-555-0302"
    email: "client-relations@msp.com"

escalation_procedures:
  level_1: "Initial response team notification"
  level_2: "Management team engagement"
  level_3: "Executive team and client notification"
  level_4: "External vendor and regulatory notification"

communication_channels:
  primary: "Slack #incident-response"
  secondary: "Microsoft Teams Emergency Channel"
  backup: "Conference bridge: +1-555-EMERGENCY"
```

#### Client Notification Automation

```yaml
---
# tasks/client-notification.yml
- name: Determine affected clients
  set_fact:
    affected_clients: "{{ groups['all'] | map('extract', hostvars, 'client_id') | unique | list }}"
  when: disaster_scope == 'global'

- name: Send initial incident notification
  mail:
    to: "{{ item.primary_contact }}"
    cc: "{{ item.secondary_contact }}"
    subject: "URGENT: Service Incident Notification - {{ incident_id }}"
    body: |
      Dear {{ item.client_name }},
      
      We are currently experiencing a service incident that may affect your infrastructure management services.
      
      Incident ID: {{ incident_id }}
      Start Time: {{ incident_start_time }}
      Estimated Resolution: {{ estimated_resolution_time }}
      
      Current Status: {{ incident_status }}
      
      We are actively working to resolve this issue and will provide updates every 30 minutes.
      
      For immediate assistance, please contact our emergency hotline at {{ emergency_hotline }}.
      
      MSP Operations Team
    headers:
      X-Priority: "1"
      X-MSMail-Priority: "High"
      Importance: "high"
  loop: "{{ client_database | selectattr('client_id', 'in', affected_clients) | list }}"
  when: send_client_notifications | default(true)
```

---

## Performance Optimization

### Ansible Performance Tuning

#### Optimized Ansible Configuration

```ini
# ansible.cfg - Performance optimized
[defaults]
# Increase parallelism
forks = 50
host_key_checking = False
gather_timeout = 30
timeout = 60

# Optimize fact gathering
gathering = smart
gather_subset = !all,!any,network,hardware,virtual
fact_caching = redis
fact_caching_connection = redis://redis.msp.internal:6379/0
fact_caching_timeout = 86400
inject_facts_as_vars = False

# Enable pipelining for faster execution
[ssh_connection]
pipelining = True
ssh_args = -C -o ControlMaster=auto -o ControlPersist=300s -o PreferredAuthentications=publickey
control_path_dir = /dev/shm/ansible-ssh-%%h-%%p-%%r
control_path = %(control_path_dir)s/%%C
retries = 3

# Optimize callback plugins
[callback]
callback_whitelist = timer, profile_tasks, cgroup_perf_recap

[inventory]
# Cache inventory for better performance
cache = True
cache_plugin = redis
cache_timeout = 3600
cache_connection = redis://redis.msp.internal:6379/1
```

#### Parallel Execution Strategies

```yaml
---
# playbooks/optimized-execution.yml
- name: High-Performance Infrastructure Management
  hosts: all
  gather_facts: yes
  strategy: free  # Allow hosts to complete independently
  
  # Batch processing for large environments
  serial: 
    - "10%"   # Start with 10% of hosts
    - "25%"   # Then 25%
    - "50%"   # Then 50%
    - "100%"  # Finally all remaining

  tasks:
    - name: Parallel task execution
      block:
        - name: Update package cache
          package:
            update_cache: yes
          async: 300
          poll: 0
          register: cache_update
          
        - name: Install security updates
          package:
            name: "*"
            state: latest
            security: yes
          async: 1800
          poll: 0
          register: security_updates
          
        - name: Configure monitoring
          include_role:
            name: monitoring
          async: 600
          poll: 0
          register: monitoring_config

    - name: Wait for async tasks to complete
      async_status:
        jid: "{{ item.ansible_job_id }}"
      register: job_result
      until: job_result.finished
      retries: 30
      delay: 10
      loop:
        - "{{ cache_update }}"
        - "{{ security_updates }}"
        - "{{ monitoring_config }}"
      when: item.ansible_job_id is defined
```

### Network Optimization

#### Connection Multiplexing Configuration

```bash
# ~/.ssh/config - Optimized for MSP operations
Host bastion-*.msp.com
    User ansible-service
    Port 2022
    IdentityFile ~/.ssh/ansible_rsa
    
    # Connection multiplexing
    ControlMaster auto
    ControlPath ~/.ssh/control-%r@%h:%p
    ControlPersist 24h
    
    # Performance optimizations
    Compression yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    TCPKeepAlive yes
    
    # Security optimizations
    StrictHostKeyChecking yes
    UserKnownHostsFile ~/.ssh/known_hosts
    PreferredAuthentications publickey
    
    # Cipher optimizations
    Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
    MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com
    KexAlgorithms curve25519-sha256@libssh.org,ecdh-sha2-nistp256,ecdh-sha2-nistp384

# Client-specific configurations
Host *.client-001.local
    ProxyJump bastion-client-001.msp.com
    User ansible-service
    IdentityFile ~/.ssh/client-001-key

Host *.client-002.local
    ProxyJump bastion-client-002.msp.com
    User ansible-service
    IdentityFile ~/.ssh/client-002-key
```

#### VPN Performance Tuning

```bash
#!/bin/bash
# /etc/ipsec.d/optimize-ipsec.sh

# Kernel parameter optimizations for IPSec
cat > /etc/sysctl.d/99-ipsec-optimization.conf << 'EOF'
# IPSec optimization
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.core.netdev_max_backlog = 5000
net.ipv4.udp_rmem_min = 8192
net.ipv4.udp_wmem_min = 8192

# TCP optimization
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 65536 16777216
net.ipv4.tcp_congestion_control = bbr
net.core.default_qdisc = fq

# Buffer sizes
net.core.netdev_budget = 600
net.core.netdev_budget_usecs = 5000
EOF

sysctl -p /etc/sysctl.d/99-ipsec-optimization.conf
```

### Database and Storage Optimization

#### PostgreSQL Tuning for Ansible Tower

```postgresql
-- postgresql.conf optimizations
-- Memory settings
shared_buffers = '{{ (ansible_memtotal_mb * 0.25) | int }}MB'
effective_cache_size = '{{ (ansible_memtotal_mb * 0.75) | int }}MB'
work_mem = '{{ (ansible_memtotal_mb / 100) | int }}MB'
maintenance_work_mem = '{{ (ansible_memtotal_mb / 10) | int }}MB'

-- Checkpoint settings
checkpoint_completion_target = 0.9
wal_buffers = 16MB
wal_writer_delay = 200ms

-- Connection settings
max_connections = 200
shared_preload_libraries = 'pg_stat_statements'

-- Logging for performance monitoring
log_statement = 'mod'
log_duration = on
log_min_duration_statement = 1000
```

```yaml
# Database maintenance automation
- name: PostgreSQL performance maintenance
  block:
    - name: Update table statistics
      postgresql_query:
        db: "{{ tower_db_name }}"
        query: "ANALYZE;"
      
    - name: Reindex heavy-use tables
      postgresql_query:
        db: "{{ tower_db_name }}"
        query: "REINDEX TABLE {{ item }};"
      loop:
        - main_job
        - main_jobevent
        - main_inventoryupdate
        - main_projectupdate
      
    - name: Vacuum old data
      postgresql_query:
        db: "{{ tower_db_name }}"
        query: "VACUUM (ANALYZE, VERBOSE) {{ item }};"
      loop:
        - main_job
        - main_jobevent
        - main_unifiedjob
```

---

## Troubleshooting Guide

### Common Issues and Resolutions

#### SSH Connection Issues

**Problem**: SSH connections failing through bastion hosts

```bash
# Diagnostic commands
ssh -vvv -o ConnectTimeout=10 bastion-client-001.msp.com
ssh -o ProxyJump=bastion-client-001.msp.com target-host.client001.local

# Check SSH control master status
ssh -O check bastion-client-001.msp.com

# Clean up stale connections
ssh -O exit bastion-client-001.msp.com
rm -f ~/.ssh/control-*
```

**Resolution Playbook**:

```yaml
---
# troubleshooting/ssh-connectivity.yml
- name: Diagnose SSH connectivity issues
  hosts: localhost
  gather_facts: no
  
  tasks:
    - name: Test bastion connectivity
      command: nc -zv {{ bastion_host }} 2022
      register: bastion_test
      failed_when: false
      
    - name: Check SSH service on bastion
      uri:
        url: "http://{{ bastion_host }}:8080/health"
        timeout: 10
      register: bastion_health
      failed_when: false
      
    - name: Test VPN connectivity
      command: ping -c 3 {{ vpn_endpoint }}
      register: vpn_test
      failed_when: false
      
    - name: Generate connectivity report
      template:
        src: connectivity-report.j2
        dest: "/tmp/connectivity-{{ ansible_date_time.epoch }}.json"
      vars:
        bastion_status: "{{ bastion_test.rc == 0 }}"
        vpn_status: "{{ vpn_test.rc == 0 }}"
        health_status: "{{ bastion_health.status == 200 }}"
```

#### Ansible Performance Issues

**Problem**: Slow playbook execution

```yaml
# Performance diagnostic playbook
- name: Ansible performance diagnostics
  hosts: all
  gather_facts: yes
  
  tasks:
    - name: Check system load
      shell: |
        echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
        echo "Memory Usage: $(free | awk 'NR==2{printf "%.2f%%", $3*100/$2}')"
        echo "Disk I/O: $(iostat -x 1 1 | tail -n +4)"
      register: system_performance
      
    - name: Profile task execution
      debug:
        msg: "Task execution metrics for {{ inventory_hostname }}"
      tags: always
      
    - name: Network latency test
      command: ping -c 5 {{ ansible_host }}
      delegate_to: localhost
      register: latency_test
```

#### Certificate and Authentication Issues

**Problem**: Certificate validation failures

```bash
# Certificate diagnostic script
#!/bin/bash
# troubleshooting/cert-diagnostics.sh

CERT_PATH="/etc/pki/ansible/client.crt"
CA_PATH="/etc/pki/CA/certs/ca.crt"

echo "=== Certificate Diagnostics ==="
echo "Certificate Path: ${CERT_PATH}"
echo "CA Path: ${CA_PATH}"

# Check certificate validity
if openssl x509 -in "${CERT_PATH}" -noout -checkend 86400; then
    echo "✓ Certificate is valid for next 24 hours"
else
    echo "✗ Certificate expires within 24 hours"
fi

# Check certificate chain
if openssl verify -CAfile "${CA_PATH}" "${CERT_PATH}"; then
    echo "✓ Certificate chain is valid"
else
    echo "✗ Certificate chain validation failed"
fi

# Check certificate details
echo "Certificate Details:"
openssl x509 -in "${CERT_PATH}" -noout -subject -issuer -dates

# Check key pair match
CERT_MODULUS=$(openssl x509 -in "${CERT_PATH}" -noout -modulus | md5sum)
KEY_MODULUS=$(openssl rsa -in "${CERT_PATH%.crt}.key" -noout -modulus | md5sum)

if [ "${CERT_MODULUS}" = "${KEY_MODULUS}" ]; then
    echo "✓ Certificate and key pair match"
else
    echo "✗ Certificate and key pair mismatch"
fi
```

#### CMMC Compliance Failures

**Problem**: Compliance validation failures

```yaml
# troubleshooting/compliance-diagnostics.yml
- name: CMMC Compliance Diagnostics
  hosts: all
  become: yes
  
  tasks:
    - name: Check auditd configuration
      block:
        - name: Verify auditd service
          systemd:
            name: auditd
            state: started
          register: auditd_status
          
        - name: Check audit rules
          command: auditctl -l
          register: audit_rules
          
        - name: Validate audit log rotation
          stat:
            path: /var/log/audit/audit.log
          register: audit_log
          
    - name: Check SSH hardening
      block:
        - name: Verify SSH configuration
          shell: sshd -T | grep -E "(passwordauthentication|pubkeyauthentication|permitrootlogin)"
          register: ssh_config
          
        - name: Check SSH ciphers
          shell: sshd -T | grep -E "(ciphers|macs|kexalgorithms)"
          register: ssh_crypto
          
    - name: Check SELinux/AppArmor status
      block:
        - name: Check SELinux status
          command: getenforce
          register: selinux_status
          when: ansible_os_family == "RedHat"
          
        - name: Check AppArmor status
          command: aa-status
          register: apparmor_status
          when: ansible_os_family == "Debian"
          
    - name: Generate compliance diagnostics report
      template:
        src: compliance-diagnostics.j2
        dest: "/tmp/compliance-diagnostics-{{ inventory_hostname }}.json"
```

### Emergency Procedures

#### Incident Response Automation

```yaml
---
# emergency/incident-response.yml
- name: Automated Incident Response
  hosts: all
  gather_facts: yes
  become: yes
  
  vars:
    incident_id: "{{ incident_id | default('INC-' + ansible_date_time.epoch) }}"
    isolation_mode: "{{ isolation_mode | default(false) }}"
    
  tasks:
    - name: Create incident directory
      file:
        path: "/var/log/incidents/{{ incident_id }}"
        state: directory
        mode: '0750'
        
    - name: Collect system state
      block:
        - name: Capture network connections
          shell: netstat -tuln > /var/log/incidents/{{ incident_id }}/netstat.log
          
        - name: Capture running processes
          shell: ps auxf > /var/log/incidents/{{ incident_id }}/processes.log
          
        - name: Capture system logs
          shell: |
            journalctl --since "1 hour ago" > /var/log/incidents/{{ incident_id }}/journal.log
            tail -1000 /var/log/auth.log > /var/log/incidents/{{ incident_id }}/auth.log
            
        - name: Capture audit logs
          shell: ausearch -ts recent > /var/log/incidents/{{ incident_id }}/audit.log
          
    - name: Implement isolation if required
      block:
        - name: Block suspicious IPs
          iptables:
            chain: INPUT
            source: "{{ item }}"
            jump: DROP
          loop: "{{ suspicious_ips | default([]) }}"
          
        - name: Disable non-essential services
          systemd:
            name: "{{ item }}"
            state: stopped
          loop: "{{ non_essential_services | default([]) }}"
          
      when: isolation_mode | bool
      
    - name: Send incident notification
      uri:
        url: "{{ incident_webhook_url }}"
        method: POST
        body_format: json
        body:
          incident_id: "{{ incident_id }}"
          hostname: "{{ inventory_hostname }}"
          timestamp: "{{ ansible_date_time.iso8601 }}"
          isolation_enabled: "{{ isolation_mode }}"
          client_id: "{{ client_id }}"
      delegate_to: localhost
```

#### Recovery Validation

```yaml
---
# emergency/recovery-validation.yml
- name: Post-Recovery Validation
  hosts: all
  gather_facts: yes
  become: yes
  
  tasks:
    - name: Validate core services
      systemd:
        name: "{{ item }}"
        state: started
      loop:
        - sshd
        - auditd
        - rsyslog
        - firewalld
        - node_exporter
      register: service_validation
      
    - name: Test network connectivity
      uri:
        url: "https://{{ monitoring_endpoint }}/health"
        method: GET
        timeout: 10
      register: connectivity_test
      
    - name: Validate CMMC compliance
      script: files/validate_compliance.py
      register: compliance_validation
      
    - name: Check certificate validity
      openssl_certificate:
        path: /etc/pki/ansible/client.crt
        provider: assertonly
        valid_in: 86400  # 24 hours
      register: cert_validation
      
    - name: Generate recovery validation report
      template:
        src: recovery-validation.j2
        dest: "/tmp/recovery-validation-{{ ansible_date_time.epoch }}.json"
      vars:
        services_status: "{{ service_validation }}"
        connectivity_status: "{{ connectivity_test.status == 200 }}"
        compliance_status: "{{ compliance_validation.stdout | from_json }}"
        certificate_status: "{{ cert_validation is succeeded }}"
      delegate_to: localhost
```

---

## Appendices

### Appendix A: CMMC Control Implementation Matrix

|CMMC Control|Implementation Method|Ansible Role|Validation Method|Frequency|
|---|---|---|---|---|
|AC.1.001|SSH key-only auth|security-hardening|SSH config check|Daily|
|AC.1.002|Sudo restrictions|security-hardening|Sudo config audit|Daily|
|AC.1.003|Network segmentation|firewall-config|Network scan|Weekly|
|AU.1.006|Comprehensive audit|audit-config|Audit rule check|Daily|
|AU.1.012|Log aggregation|monitoring|Log flow test|Daily|
|CM.1.073|Config management|ansible-tower|Change tracking|Continuous|
|IA.1.076|User identification|user-management|User audit|Weekly|
|IA.1.077|Multi-factor auth|security-hardening|MFA validation|Daily|
|SC.1.175|Encryption in transit|security-hardening|Cipher audit|Daily|
|SC.1.176|Encryption at rest|disk-encryption|Encryption check|Weekly|
|SI.1.210|Malware protection|security-tools|AV status check|Daily|
|SI.1.214|Security monitoring|monitoring|Alert validation|Continuous|

### Appendix B: Network Port Requirements

#### MSP Data Center Ports

```
Inbound:
- 443/tcp  - Ansible Tower Web UI (from admin networks)
- 5432/tcp - PostgreSQL (from Tower instances)
- 8200/tcp - Vault API (from Tower and bastions)
- 9090/tcp - Prometheus (from monitoring networks)
- 3000/tcp - Grafana (from admin networks)
- 5601/tcp - Kibana (from admin networks)

Outbound:
- 22/tcp   - SSH to client bastions
- 443/tcp  - HTTPS for updates and APIs
- 53/tcp   - DNS queries
- 123/udp  - NTP synchronization
- 500/udp  - IPSec IKE
- 4500/udp - IPSec NAT-T
```

#### Client Site Ports

```
Inbound (from MSP):
- 22/tcp   - SSH from MSP bastions
- 500/udp  - IPSec IKE
- 4500/udp - IPSec NAT-T
- 9100/tcp - Node Exporter (from MSP monitoring)
- 5044/tcp - Filebeat to Logstash (MSP logging)

Outbound:
- 443/tcp  - HTTPS for updates
- 53/tcp   - DNS queries
- 123/udp  - NTP synchronization
- 22/tcp   - SSH to MSP (emergency reverse tunnel)
```

### Appendix C: Certificate Management Procedures

#### Certificate Lifecycle Management

```bash
#!/bin/bash
# Certificate management automation

# Generate Certificate Signing Request
generate_csr() {
    local client_id=$1
    local cert_dir="/etc/pki/ansible/clients"
    
    openssl req -new -nodes \
        -keyout "${cert_dir}/${client_id}.key" \
        -out "${cert_dir}/${client_id}.csr" \
        -config <(cat <<EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = State
L = City
O = MSP
OU = Ansible Automation
CN = ${client_id}.msp.internal

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${client_id}.msp.internal
DNS.2 = bastion-${client_id}.msp.com
EOF
    )
}

# Sign certificate with CA
sign_certificate() {
    local client_id=$1
    local cert_dir="/etc/pki/ansible/clients"
    local ca_dir="/etc/pki/CA"
    
    openssl x509 -req \
        -in "${cert_dir}/${client_id}.csr" \
        -CA "${ca_dir}/certs/ca.crt" \
        -CAkey "${ca_dir}/private/ca.key" \
        -CAcreateserial \
        -out "${cert_dir}/${client_id}.crt" \
        -days 365 \
        -extensions v3_req \
        -extfile <(cat <<EOF
[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${client_id}.msp.internal
DNS.2 = bastion-${client_id}.msp.com
EOF
    )
}

# Distribute certificate to client
distribute_certificate() {
    local client_id=$1
    local cert_dir="/etc/pki/ansible/clients"
    local bastion_host="bastion-${client_id}.msp.com"
    
    # Copy certificate and key to bastion
    scp "${cert_dir}/${client_id}.crt" \
        "${cert_dir}/${client_id}.key" \
        "root@${bastion_host}:/etc/ssl/ansible/"
        
    # Set proper permissions
    ssh "root@${bastion_host}" "chmod 600 /etc/ssl/ansible/${client_id}.key"
    ssh "root@${bastion_host}" "chmod 644 /etc/ssl/ansible/${client_id}.crt"
}
```

### Appendix D: Disaster Recovery Checklists

#### Critical System Recovery Priority

1. **Immediate (0-1 hour)**
    
    - [ ] Activate emergency communication channels
    - [ ] Deploy emergency Ansible Tower instance
    - [ ] Establish VPN connectivity to critical client sites
    - [ ] Restore Certificate Authority services
2. **Short-term (1-4 hours)**
    
    - [ ] Restore full Vault cluster functionality
    - [ ] Re-establish monitoring and alerting
    - [ ] Restore client bastion connectivity
    - [ ] Validate CMMC compliance systems
3. **Medium-term (4-24 hours)**
    
    - [ ] Complete infrastructure automation restoration
    - [ ] Restore all client site connectivity
    - [ ] Validate backup and recovery systems
    - [ ] Complete compliance validation
4. **Long-term (24+ hours)**
    
    - [ ] Conduct post-incident review
    - [ ] Update disaster recovery procedures
    - [ ] Implement lessons learned
    - [ ] Generate compliance reports

### Appendix E: Performance Benchmarks

#### Expected Performance Metrics

|Operation|Target Time|Acceptable Time|Alert Threshold|
|---|---|---|---|
|SSH Connection|< 2 seconds|< 5 seconds|> 10 seconds|
|Playbook Execution (10 hosts)|< 5 minutes|< 10 minutes|> 15 minutes|
|Fact Gathering|< 30 seconds|< 60 seconds|> 120 seconds|
|Package Installation|< 2 minutes|< 5 minutes|> 10 minutes|
|Configuration Deployment|< 1 minute|< 3 minutes|> 5 minutes|
|Compliance Validation|< 3 minutes|< 7 minutes|> 10 minutes|

#### Resource Utilization Targets

|Component|CPU Target|Memory Target|Disk I/O Target|
|---|---|---|---|
|Ansible Tower|< 70%|< 80%|< 50 IOPS|
|Vault Cluster|< 60%|< 70%|< 30 IOPS|
|Client Bastions|< 50%|< 60%|< 20 IOPS|
|Monitoring Stack|< 80%|< 85%|< 100 IOPS|

---

## Conclusion

This comprehensive architecture provides a robust, secure, and scalable foundation for MSPs to deliver automated infrastructure management services while maintaining strict CMMC compliance requirements. The design emphasizes security through defense-in-depth strategies, operational efficiency through automation, and business continuity through comprehensive disaster recovery procedures.

Key benefits of this implementation include:

- **Enhanced Security Posture**: Multi-layered security controls meeting CMMC Level 2/3 requirements
- **Operational Efficiency**: Automated management of hundreds of client sites from centralized control
- **Compliance Assurance**: Continuous validation and reporting of compliance controls
- **Scalability**: Architecture designed to grow with business requirements
- **Reliability**: High availability and disaster recovery capabilities ensuring business continuity

Regular reviews and updates of this architecture should be conducted to incorporate new technologies, address emerging threats, and adapt to evolving compliance requirements.