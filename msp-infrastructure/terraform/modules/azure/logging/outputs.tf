output "client_workspace_resource_id" {
  description = "Resource ID of created per-client LAW (if any)"
  value       = local.client_workspace_id
}

output "central_workspace_resource_id" {
  description = "Resource ID of central LAW provided (if any)"
  value       = local.central_workspace_id
}

output "primary_diagnostic_workspace_resource_id" {
  description = "Resource ID of LAW used for primary diagnostic settings"
  value       = local.primary_workspace_id
}

output "workspace_name" {
  description = "Name of created per-client LAW (if any)"
  value       = local.create_client_workspace ? azurerm_log_analytics_workspace.client[0].name : null
}

output "diagnostic_setting_ids_primary" {
  description = "List of primary diagnostic setting IDs"
  value       = [for ds in azurerm_monitor_diagnostic_setting.primary : ds.id]
}

output "logging_strategy_effective" {
  description = "The configured logging strategy"
  value       = var.logging_strategy
}

