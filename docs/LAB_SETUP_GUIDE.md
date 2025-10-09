# MSP Lab Setup Guide

This guide walks an MSP through a safe lab trial using VMs or containers, with clear paths for connectivity models (pull-based, WireGuard bastion, reverse SSH). Start small, expand as you gain confidence.

## 1) Prerequisites
- Controller: a workstation with Ansible and SSH access to lab VMs
- Optional: Docker (for container-only demo)
- Repo: `git clone https://github.com/sethluby/msp-ansible-platform.git && cd msp-ansible-platform`
- Prevent accidental pushes (optional): `git remote set-url --push origin DISABLED`

## 2) Fast, No-Risk Demo (Containers only)
- Install deps: `ansible-galaxy install -r requirements.yml`
- Run demo: `make quickstart-demo`
- Clean up: `make quickstart-destroy`

## 3) Single VM as a Client (Baseline path)
- Use your existing inventory (e.g., `~/ansible/inventory`) or copy examples from `ansible/inventory/examples/`.
- Create a local vars file (not committed), e.g., `~/.config/msp-ansible/lab.yml`:
  - `client_name: lab`
  - `allow_reboot: false`
  - `send_notifications: false`
  - `msp_syslog_server: ""`
- Verify access: `ansible -i ~/ansible/inventory <vm-hostname> -m ping -b`
- Read-only checks:
  - Users audit (safe): `ansible-playbook -i ~/ansible/inventory ansible/playbooks/user-management.yml --limit <vm-hostname> -e @~/.config/msp-ansible/lab.yml -e user_operation=audit --check`
  - Compliance validation: `ansible-playbook -i ~/ansible/inventory ansible/playbooks/validate-compliance.yml --limit <vm-hostname> -e cmmc_level=level2 -e cmmc_client_id=lab`
- Patching simulation (no changes):
  - `ansible-playbook -i ~/ansible/inventory ansible/playbooks/system-update.yml --limit <vm-hostname> -e @~/.config/msp-ansible/lab.yml -e update_mode=security --check`

## 4) Connectivity Model Paths (choose one)
- Pull-Based (client pulls automation)
  - On the client VM: run `bootstrap/bootstrap-pull-based.sh <client_name> <git_repo_url> <deploy_key>`
  - Configure a periodic pull (script handles cron). Suitable for DMZ/outbound-only.
- WireGuard Bastion (MSP-managed bastion)
  - On an Alpine bastion VM: `bootstrap/bootstrap-bastion-host.sh <client_name> <msp_hub> <client_subnet_cidr> <msp_public_key>`
  - Add the generated public key to your MSP hub; validate VPN connectivity; limit routes to lab subnets.
- Reverse SSH Tunnel (maximum isolation)
  - On client VM: `bootstrap/bootstrap-reverse-tunnel.sh <client_name> <jump_host> <tunnel_port> <host_key>`
  - MSP connects through the established reverse tunnel; no inbound firewall changes at client.

Notes
- Start with “Single VM” baseline before introducing VPN or tunnels.
- All scripts log to `/tmp/*msp*` on the client; review before proceeding.

## 5) CMMC Overlay (optional)
- Integrate ansible-lockdown controls (dry run first):
  - `ansible-playbook -i ~/ansible/inventory ansible/playbooks/integrate-lockdown-compliance.yml --limit <vm-hostname> -e client_name=lab -e client_compliance_framework=cis --check`
- Validate: see `ansible/playbooks/validate-compliance.yml`
- Control mapping: `docs/cmmc-control-mapping.md`

## 6) Safety & Cleanup
- Snapshot VMs before any applying playbooks without `--check`.
- Keep `allow_reboot: false` until you review results.
- Remove lab artifacts: `make quickstart-destroy` (containers) or tear down VMs.

## 7) Expanding the Lab
- Multi-client: duplicate the single VM flow for two+ VMs; use group vars under `ansible/inventory/examples/group_vars/<client>/`.
- Monitoring/backup: enable these roles via vars and converge on test nodes.
- CI locally: `make check` (lint/syntax/pre-commit) for fast feedback.
