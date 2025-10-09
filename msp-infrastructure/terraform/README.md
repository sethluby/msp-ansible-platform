Terraform (Azure-first) for MSP Landing Zones

Overview
- Azure-first scaffolding to manage many client environments with adjustable logging.
- Modules live under `modules/azure/`; concrete per-client stacks under `live/clients/<client>/<env>/<stack>/`.
- State is intended to use Azure Storage remote backend (configure via `backend.hcl`).

Key Concepts
- Tenancy by directory, not workspaces: each client/env stack has isolated state.
- Adjustable logging strategies:
  - `none` — no logging resources; outputs become no-ops.
  - `per_client` — create Log Analytics Workspace (LAW) in client RG.
  - `central_byo` — attach diagnostics to an existing, central LAW.
  - `dual` — create per-client LAW and optionally also attach diagnostics to a central LAW.
- Diagnostics attachment is opt-in via `attach_scopes` (resource IDs).

Repo Layout
- `modules/azure/logging` — adjustable LAW + diagnostics module (implemented).
- `modules/azure/{lighthouse,policy,iam,networking,compute,dns,backup,monitoring}` — stubs for future modules.
- `live/clients/exampleco/dev/` — four example stacks (`logging-<strategy>`), showing inputs.

Usage (examples)
1) Change into a stack directory, e.g. `msp-infrastructure/terraform/live/clients/exampleco/dev/logging-per-client`.
2) Create and fill `backend.hcl` with your remote backend config (sample below).
3) Initialize and plan:
   - `terraform init -backend-config=backend.hcl`
   - `terraform plan -var client_name=exampleco -var resource_group_name=rg-exampleco-dev -var location=eastus`

backend.hcl (sample)
storage_account_name = "<state-storage-account>"
container_name       = "tfstate"
key                  = "clients/exampleco/dev/logging-per-client.tfstate"
resource_group_name  = "<state-rg>"
subscription_id      = "<msp-subscription-id>"

Notes
- `attach_scopes` must be resource IDs that support Azure Monitor Diagnostic Settings.
- By default, diagnostics are attached only to the primary target (per-client LAW or central LAW). Set `attach_diagnostics_to_both = true` with strategy `dual` to attach to both.
- AMA/Policies are recommended to be handled via Azure Policy; this module exposes IDs for integration but does not force DCR/DCE creation.
- No resources are created until you `apply`. This scaffold is safe to review/plan.

