locals {
  create_client_workspace = var.logging_strategy == "per_client" || var.logging_strategy == "dual"
  use_central_workspace   = var.logging_strategy == "central_byo" || var.logging_strategy == "dual"

  calculated_workspace_name = coalesce(var.workspace_name, "law-${var.client_name}-${var.environment}")
}

resource "azurerm_log_analytics_workspace" "client" {
  count               = local.create_client_workspace ? 1 : 0
  name                = local.calculated_workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = var.retention_days
  daily_quota_gb      = -1

  tags = merge(
    {
      client = var.client_name
      env    = var.environment
    },
    var.tags,
  )
}

locals {
  client_workspace_id = local.create_client_workspace ? azurerm_log_analytics_workspace.client[0].id : null
  central_workspace_id = local.use_central_workspace ? coalesce(var.central_workspace_resource_id, var.workspace_resource_id) : null

  primary_workspace_id = (
    var.logging_strategy == "per_client" ? local.client_workspace_id :
    var.logging_strategy == "central_byo" ? var.workspace_resource_id :
    var.logging_strategy == "dual" && var.diagnostic_attach_target == "central" ? local.central_workspace_id :
    var.logging_strategy == "dual" ? local.client_workspace_id : null
  )

  enable_primary_diag = length(var.attach_scopes) > 0 && length(var.diagnostic_categories) > 0 && !isnull(local.primary_workspace_id)
  enable_central_diag = var.logging_strategy == "dual" && var.attach_diagnostics_to_both && length(var.attach_scopes) > 0 && length(var.diagnostic_categories) > 0 && !isnull(local.central_workspace_id)
}

resource "azurerm_monitor_diagnostic_setting" "primary" {
  for_each = local.enable_primary_diag ? { for id in var.attach_scopes : id => id } : {}

  name                       = "${var.client_name}-${var.environment}-${substr(sha1(each.value), 0, 8)}"
  target_resource_id         = each.value
  log_analytics_workspace_id = local.primary_workspace_id

  dynamic "log" {
    for_each = var.diagnostic_categories
    content {
      category = log.value
      enabled  = true
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "central" {
  for_each = local.enable_central_diag ? { for id in var.attach_scopes : id => id } : {}

  name                       = "${var.client_name}-${var.environment}-c-${substr(sha1(each.value), 0, 8)}"
  target_resource_id         = each.value
  log_analytics_workspace_id = local.central_workspace_id

  dynamic "log" {
    for_each = var.diagnostic_categories
    content {
      category = log.value
      enabled  = true
    }
  }
}

