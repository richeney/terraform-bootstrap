resource "azurerm_log_analytics_workspace" "state" {
  name                = data.azurerm_storage_account.state.name
  resource_group_name = data.azurerm_resource_group.state.name
  location            = data.azurerm_resource_group.state.location
  tags                = data.azurerm_resource_group.state.tags


  sku               = "PerGB2018"
  retention_in_days = 30
}

resource "azurerm_monitor_diagnostic_setting" "state" {
  name                       = "key_vault"
  target_resource_id         = azurerm_key_vault.state.id
  storage_account_id         = data.azurerm_storage_account.state.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.state.id


  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"

    retention_policy {
      enabled = false
    }
  }
}

# Define the storage management policy for log retention
resource "azurerm_storage_management_policy" "log_retention" {
  storage_account_id = data.azurerm_storage_account.state.id

  # Define a rule to delete logs after 30 days
  rule {
    name    = "delete_after_30_days"
    enabled = true

    filters {
      blob_types   = ["appendBlob"]
      prefix_match = ["logs/"]
    }
    # Delete after 30 days
    actions {
      base_blob {
        delete_after_days_since_modification_greater_than = 30
      }

   }
 }