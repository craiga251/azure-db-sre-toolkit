output "resource_group_id" {
  description = "ID of the Azure resource group created by this configuration."
  value       = azurerm_resource_group.main.id
}
