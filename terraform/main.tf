terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      # Pin to provider major version 4 to avoid unexpected breaking changes from v5+.
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location

  tags = {
    project    = "azure-db-sre-toolkit"
    managed_by = "terraform"
    owner      = var.owner
  }
}

