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

  logging_strategy = "none"

  tags = local.common_tags
}

variable "client_name" { type = string }
variable "environment" { type = string }
variable "resource_group_name" { type = string }
variable "location" { type = string }

output "logging_outputs" {
  value = {
    client_workspace_resource_id             = module.logging.client_workspace_resource_id
    primary_diagnostic_workspace_resource_id = module.logging.primary_diagnostic_workspace_resource_id
    diagnostic_setting_ids_primary           = module.logging.diagnostic_setting_ids_primary
  }
}

