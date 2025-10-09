variable "client_name" {
  description = "Client short slug (e.g., acme)"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., dev, prod)"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group for per-client LAW (if created)"
  type        = string
}

variable "location" {
  description = "Azure region for LAW (if created)"
  type        = string
}

variable "logging_strategy" {
  description = "Logging mode: none | per_client | central_byo | dual"
  type        = string
  default     = "per_client"
  validation {
    condition     = contains(["none", "per_client", "central_byo", "dual"], var.logging_strategy)
    error_message = "logging_strategy must be one of: none, per_client, central_byo, dual"
  }
}

variable "workspace_name" {
  description = "Optional name for created LAW; defaults to law-<client>-<env>"
  type        = string
  default     = null
}

variable "retention_days" {
  description = "LAW retention in days (when created)"
  type        = number
  default     = 30
}

variable "workspace_resource_id" {
  description = "Existing LAW resource ID for central_byo or dual"
  type        = string
  default     = null
}

variable "central_workspace_resource_id" {
  description = "Explicit central LAW resource ID for dual; falls back to workspace_resource_id"
  type        = string
  default     = null
}

variable "diagnostic_attach_target" {
  description = "For dual, which workspace receives the primary diagnostic settings (client|central)"
  type        = string
  default     = "client"
  validation {
    condition     = contains(["client", "central"], var.diagnostic_attach_target)
    error_message = "diagnostic_attach_target must be client or central"
  }
}

variable "attach_diagnostics_to_both" {
  description = "When dual, also attach diagnostic settings to central workspace"
  type        = bool
  default     = false
}

variable "attach_scopes" {
  description = "Resource IDs to attach diagnostic settings to"
  type        = list(string)
  default     = []
}

variable "diagnostic_categories" {
  description = "Diagnostic categories to enable; must be valid for target resources"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags to apply"
  type        = map(string)
  default     = {}
}

variable "name_prefix" {
  description = "Name prefix for created resources"
  type        = string
  default     = "logging"
}

