variable "resource_group_name" {
  description = "Name of the resource group."
  type        = string
  default     = "terraform"
}

variable "storage_account_name" {
  description = "Storage account name. Re-used for the service principal, workspace, etc."
  type        = string
}

variable "container_name" {
  description = "Name for the container used to store tfstate files."
  type        = string
  default     = "tfstate"
}

variable "location" {
  description = "Azure region to deploy the launchpad in the short form."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Optional map of key:value tags."
  type        = map(any)
  default     = {}
}

variable "terraform_state_aad_group" {
  description = "Name of the optional AAD security group for managing Terraform state and key vault secrets."
  type        = string
  default     = ""
}

variable "service_principal_name" {
  description = "Name for the terraform state service principal. Defaults to the storage account name"
  type        = string
  default     = ""
}

variable "service_principal_rbac_assignments" {
  description = "Optional list of additional roles and scopes for the service principal."
  type = list(object({
    role  = string,
    scope = string
  }))
  default = []
}

variable "azurerm_version_constraint" {
  description = "Specify the azurerm version constraint to be used in the generated azurerm_provider.tf file."
  type        = string
  default     = "~> 2.0"
}

variable "key_vault_soft_delete_retention" {
  description = "Specify the number of days that a secret should be retained in key vault's soft deletion. (7-90)"
  default     = 90
}
