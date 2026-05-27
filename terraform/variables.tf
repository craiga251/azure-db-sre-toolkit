variable "resource_group_name" {
  description = "Name of the Azure resource group to create."
  type        = string
  default     = "rg-azure-db-sre-toolkit"
}

variable "location" {
  description = "Azure region for the resource group."
  type        = string
  default     = "uksouth"
}

variable "owner" {
  description = "Owner tag value for created resources. Set via terraform.tfvars (gitignored)."
  type        = string
}