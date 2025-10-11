vSphere Lab Inventory and Provisioning
=====================================

Purpose
- Environment-specific inventory and variables for a vSphere “on‑prem” lab.
- Reuses global playbooks in `ansible/playbooks/` (no duplicates).
- Cookie‑cutter, variable‑first provisioning of VMs via `community.vmware`.

Key Files
- `ansible/inventory/lab-vsphere/hosts.yml` — lab inventory (groups/hosts)
- `ansible/inventory/lab-vsphere/group_vars/vcenter/main.yml` — vCenter placement + settings
- `ansible/inventory/lab-vsphere/group_vars/all/main.yml` — env defaults (SSH, domain)
- `ansible/inventory/lab-vsphere/group_vars/all/vsphere_provision.yml` — VM specs list (edit here)
- `ansible/inventory/lab-vsphere/vault.yml` — secrets (create from `vault.sample.yml` and encrypt)
- Global playbook: `ansible/playbooks/vsphere-provision.yml`

Prerequisites
- vCenter reachable from your control node
- Templates available (e.g., `ubuntu-22.04-golden`), DHCP or a static plan
- Install collections/roles: `ansible-galaxy install -r requirements.yml --force`

Secrets (Ansible Vault)
1. Copy `vault.sample.yml` to `vault.yml` and fill values.
2. Encrypt: `ansible-vault encrypt ansible/inventory/lab-vsphere/vault.yml`

Required Variables
- vCenter connection: `vcenter_hostname`, `vcenter_username`, `vcenter_password`, `vcenter_validate_certs`
- Placement: `vcenter_datacenter`, `vcenter_cluster`, `vcenter_datastore`, `vcenter_folder`
- VM list: `vsphere_vms` (list of VM specs)

VM Spec Schema (`vsphere_vms`)
- Required per VM: `name`, `template`
- Optional:
  - Sizing: `num_cpus`, `memory_mb`, `disk.size_gb`, `disk.type`, `datastore`, `resource_pool`, `power_on`
  - Networking: `networks` (e.g., `{ name: PG-APPS, type: dhcp, start_connected: true }`)
  - Customization: `hostname`, `domain`, `dns_servers`, `timezone` (extend for Windows as needed)
  - Tags: list of `{ category, name }` (ensure categories exist or add pre‑tasks to create)

Quick Start
1. Edit placement and defaults:
   - `ansible/inventory/lab-vsphere/group_vars/vcenter/main.yml`
   - `ansible/inventory/lab-vsphere/group_vars/all/main.yml`
2. Define VM list:
   - `ansible/inventory/lab-vsphere/group_vars/all/vsphere_provision.yml`
   - See example: `ansible/inventory/examples/group_vars/vsphere_provision/main.yml`
3. Prepare and validate:
   - Install collections/roles: `ansible-galaxy install -r requirements.yml --force`
   - Lint inventory (optional): `yamllint ansible/inventory/lab-vsphere`
   - Preflight (optional):
     `ansible-playbook -i ansible/inventory/lab-vsphere/hosts.yml ansible/playbooks/vsphere-preflight.yml --ask-vault-pass`
4. Dry run (optional):
   - `ansible-playbook -i ansible/inventory/lab-vsphere/hosts.yml ansible/playbooks/vsphere-provision.yml --check`
5. Provision:
   - `ansible-playbook -i ansible/inventory/lab-vsphere/hosts.yml ansible/playbooks/vsphere-provision.yml --ask-vault-pass`

6. Destroy (careful):
   - Option A: define `vsphere_destroy_names` (list) in extra vars or inventory
   - Option B: falls back to names from `vsphere_vms`
   - Run: `ansible-playbook -i ansible/inventory/lab-vsphere/hosts.yml ansible/playbooks/vsphere-destroy.yml -e vsphere_destroy_confirm=true --ask-vault-pass`

Notes
- This inventory is environment‑scoped; copy it to create new environments.
- Keep secrets vaulted; never commit plaintext credentials.
- A destroy playbook is not yet included; we can add one to delete from `vsphere_vms` or by folder/tag.
