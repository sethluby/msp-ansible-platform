locals {
  common_tags = {
    client            = var.client_name
    env               = var.environment
    owner             = "msp"
    data_classification = "internal"
  }
}

module "logging" {
  source = "../../../../../modules/azure/logging"

  client_name         = var.client_name
  environment         = var.environment
  resource_group_name = var.resource_group_name
  location            = var.location

  logging_strategy = "per_client"

  # Attach diagnostics by providing resource IDs and categories
  attach_scopes          = var.attach_scopes
  diagnostic_categories  = var.diagnostic_categories
  attach_diagnostics_to_both = false

  tags = local.common_tags
}

variable "client_name" { type = string }
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }
variable "attach_scopes" { type = list(string) default = [] }
variable "diagnostic_categories" { type = list(string) default = [] }

output "logging_outputs" {
  value = {
    client_workspace_resource_id             = module.logging.client_workspace_resource_id
    primary_diagnostic_workspace_resource_id = module.logging.primary_diagnostic_workspace_resource_id
    diagnostic_setting_ids_primary           = module.logging.diagnostic_setting_ids_primary
  }
}

