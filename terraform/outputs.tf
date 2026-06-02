output "resource_group_id" {
  description = "ID of the Azure resource group created by this configuration."
  value       = azurerm_resource_group.main.id
}

output "log_analytics_workspace_id" {
  description = "ID of the Azure Log Analytics workspace created by this configuration."
  value       = azurerm_log_analytics_workspace.main.id
}
