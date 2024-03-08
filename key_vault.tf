resource "azurerm_key_vault" "state" {
  name                = data.azurerm_storage_account.state.name
  resource_group_name = data.azurerm_resource_group.state.name
  location            = data.azurerm_resource_group.state.location
  tags                = data.azurerm_resource_group.state.tags

  tenant_id                       = data.azurerm_client_config.current.tenant_id
  sku_name                        = "standard"
  enabled_for_deployment          = false
  enabled_for_disk_encryption     = false
  enabled_for_template_deployment = false
  purge_protection_enabled        = false
  soft_delete_retention_days      = var.key_vault_soft_delete_retention

  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    ip_rules                   = ["0.0.0.0/0"]
    virtual_network_subnet_ids = null
  }
}

resource "azurerm_key_vault_access_policy" "terraform_state_owner" {
  key_vault_id = azurerm_key_vault.state.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id

  key_permissions = []

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete"
  ]
}

resource "azurerm_key_vault_access_policy" "terraform_state_service_principal" {
  key_vault_id = azurerm_key_vault.state.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azuread_service_principal.terraform.object_id

  key_permissions = []

  secret_permissions = [
    "Get",
    "List"
  ]
}

resource "azurerm_key_vault_access_policy" "terraform_state_aad_group" {
  for_each = local.terraform_state_aad_group

  key_vault_id = azurerm_key_vault.state.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_group.terraform_state_aad_group[each.value].object_id

  key_permissions = []

  secret_permissions = [
    "Get",
    "List",
    "Set",
    "Delete"
  ]
}

resource "azurerm_key_vault_secret" "tenant_id" {
  depends_on   = [azurerm_key_vault_access_policy.terraform_state_owner]
  name         = "tenant-id"
  key_vault_id = azurerm_key_vault.state.id
  value        = data.azurerm_client_config.current.tenant_id
}

resource "azurerm_key_vault_secret" "client_id" {
  depends_on   = [azurerm_key_vault_access_policy.terraform_state_owner]
  name         = "client-id"
  key_vault_id = azurerm_key_vault.state.id
  value        = azuread_service_principal.terraform.client_id
}

resource "azurerm_key_vault_secret" "client_secret" {
  depends_on   = [azurerm_key_vault_access_policy.terraform_state_owner]
  name         = "client-secret"
  key_vault_id = azurerm_key_vault.state.id
  value        = azuread_service_principal_password.terraform.value
}
