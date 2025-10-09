Azure Logging Module (Adjustable)

Purpose
- Provide a pluggable logging strategy per client/environment:
  - `none` — no resources created.
  - `per_client` — create a Log Analytics Workspace (LAW) in the provided RG.
  - `central_byo` — reuse an existing LAW (no creation), suitable for MSP central logging.
  - `dual` — create per-client LAW and optionally also attach diagnostics to a central LAW.

Inputs (key)
- `client_name` (string) — short client slug.
- `environment` (string) — env name (e.g., `dev`, `prod`).
- `resource_group_name` (string) — RG where per-client LAW is created.
- `location` (string) — Azure region.
- `logging_strategy` (string) — one of `none|per_client|central_byo|dual`. Default `per_client`.
- `workspace_name` (string, optional) — override LAW name when created.
- `retention_days` (number) — retention for LAW. Default `30`.
- `workspace_resource_id` (string, optional) — existing LAW for `central_byo`/`dual`.
- `central_workspace_resource_id` (string, optional) — explicit central LAW for `dual`.
- `diagnostic_attach_target` (string) — `client` or `central` for `dual`. Default `client`.
- `attach_diagnostics_to_both` (bool) — when `dual`, also attach to central. Default `false`.
- `attach_scopes` (list(string)) — resource IDs to attach diagnostic settings to.
- `diagnostic_categories` (list(string)) — categories to enable; empty means no logs attached.
- `tags` (map(string)) — extra tags.

Outputs (key)
- `client_workspace_resource_id` — created LAW id (or null).
- `central_workspace_resource_id` — central LAW id (or null).
- `primary_diagnostic_workspace_resource_id` — LAW used for primary diagnostic attachments.
- `workspace_name` — created LAW name (or null).
- `diagnostic_setting_ids_primary` — list of primary diagnostic setting IDs.
- `logging_strategy_effective` — echoed strategy.

Notes
- This module does not provision AMA/DCR by default; use Azure Policy for agent deployment at scale.
- `attach_scopes` and `diagnostic_categories` must both be non-empty to create diagnostic settings.
- For `dual`, setting `attach_diagnostics_to_both = true` creates a second set of diagnostic settings targeting the central workspace.

