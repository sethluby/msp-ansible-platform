# Terraform Overview (Azure-First)

Purpose
- Azure-first Terraform scaffolding to provision client landing zones with adjustable logging and clean handoff to Ansible.
- Designed for MSPs managing hundreds/thousands of clients with isolated state per client/environment.

Where to Find It
- Top-level docs and quickstart: `msp-infrastructure/terraform/README.md`
- Core module (implemented): `msp-infrastructure/terraform/modules/azure/logging`
- Live examples (safe to plan): `msp-infrastructure/terraform/live/clients/exampleco/dev/`

Structure
- `modules/azure/` — reusable modules
  - `logging` — adjustable logging (implemented)
  - `lighthouse, policy, iam, networking, compute, dns, backup, monitoring` — stubs
- `live/clients/<client>/<env>/` — concrete stacks with isolated state
  - `logging-none|per-client|central-byo|dual` — examples showing input toggles

Logging Strategies (Adjustable)
- `none` — no logging resources created; outputs are no-ops
- `per_client` — creates a per‑client Log Analytics Workspace (LAW)
- `central_byo` — reuses an existing central LAW (no creation)
- `dual` — creates per‑client LAW and can also attach diagnostics to a central LAW

Diagnostics Attachment
- Provide `attach_scopes` (list of resource IDs) and `diagnostic_categories` to enable settings.
- For `dual`, control primary target with `diagnostic_attach_target` (`client|central`) and set `attach_diagnostics_to_both=true` to attach to both.

Quick Start (Plan Only)
1) Choose a stack, e.g. `msp-infrastructure/terraform/live/clients/exampleco/dev/logging-per-client`
2) Copy and fill `backend.hcl.example` → `backend.hcl` (Azure Storage backend)
3) Initialize and plan:
   - `terraform init -backend-config=backend.hcl`
   - `terraform plan -var client_name=exampleco -var environment=dev -var resource_group_name=rg-exampleco-dev -var location=eastus`

Safety & Guardrails
- No resources are created until `terraform apply`.
- Each client/environment stack uses a separate backend key to isolate state.
- Agent deployment (AMA/DCR) is intentionally left to Azure Policy; can be added later.

Ansible Integration (Next)
- Terraform outputs will feed Ansible inventory and group vars (bastion endpoints, LAW IDs, Key Vault paths).
- A small mapper script/role will translate Terraform outputs to `ansible/inventory/` and `group_vars/` entries.

Roadmap
- Azure Lighthouse onboarding package
- Policy initiatives (ASB/CIS) and DeployIfNotExists for agents/diagnostics
- Networking and compute modules with Ansible cloud-init handoff
- Optional Managed Grafana/Prometheus integration

