terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Pin to provider major version 4 to avoid unexpected breaking changes from v5+.
      version = "~> 4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstatesretoolkit"
    container_name       = "tfstate"
    key                  = "azure-db-sre-toolkit.tfstate"
  }
}

provider "azurerm" {
  features {}
}

locals {
  common_tags = {
    project    = "azure-db-sre-toolkit"
    managed_by = "terraform"
    owner      = var.owner
  }
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = local.common_tags
}

resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-azure-db-sre-toolkit"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30

  tags = local.common_tags
}
