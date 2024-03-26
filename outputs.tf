locals {

  azurerm_provider_file = <<PROVIDER
provider "azurerm" {
  version             = "${var.azurerm_version_constraint}"
  storage_use_azuread = true

  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }

  tenant_id       = data.azurerm_key_vault_secret.tenant_id.value
  subscription_id = var.subscription_id
  client_id       = data.azurerm_key_vault_secret.client_id.value
  client_secret   = data.azurerm_key_vault_secret.client_secret.value
}
PROVIDER

  backend_file = <<BACKEND
terraform {
  backend "azurerm" {
    resource_group_name  = "${data.azurerm_resource_group.state.name}"
    storage_account_name = "${data.azurerm_storage_account.state.name}"
    container_name       = "${data.azurerm_storage_container.tfstate.name}"
    key                  = ""
  }
}
BACKEND

  bootstrap_secrets_file = <<BOOTSTRAP_SECRETS
provider "azurerm" {
  // Uses the Azure CLI token (or env vars) unless managed identity is used
  features {}
  alias   = "backend"
  use_msi = false
}

data "azurerm_key_vault_secret" "tenant_id" {
  provider     = azurerm.backend
  key_vault_id = "${azurerm_key_vault.state.id}"
  name         = "tenant-id"
}

data "azurerm_key_vault_secret" "client_id" {
  provider     = azurerm.backend
  key_vault_id = "${azurerm_key_vault.state.id}"
  name         = "client-id"
}

data "azurerm_key_vault_secret" "client_secret" {
  provider     = azurerm.backend
  key_vault_id = "${azurerm_key_vault.state.id}"
  name         = "client-secret"
}
BOOTSTRAP_SECRETS

  readme_file = <<README
# Bootstrap

## Background

The ${var.resource_group_name} resource group contains your Terraform bootstrap resources.

These include:

* a key vault containing the credentials for the service principal
* a storage account that includes
    * a tfstate container for holding your terraform.tfstate files
    * a bootstrap container that contains files to quickstart your Terraform configs
* a log analytics workspace to track access to the key vault

The files in this folder or container can be used in your Terraform root modules if you want to use the service principal and use the storage account to store your Terraform state.

Note that the files are setup for command line terraform execution, and will access the key vault using the user's credentials. The user principal must have a key vault access policy granted to read the secrets, or belong to a security group that does.

Additional information is provided for managed identity scenarios and for CI/CD pipelines.

## Directions

1. Context

  Check that you are in the correct Azure context, i.e. you are logged in as the right user and in the right subscription.

  For example:

  ```bash
  az account show
  az account list --output table
  az account set --subscription <subscriptionId>
  ```

1. Directory

  You should be in your Terraform root module. For example:

  ```bash
  mkdir ~/terraform-test && cd ~/terraform-test
  ```

1. Download the files

  Using the Azure CLI:
  ```bash
  az storage blob download --file azurerm_provider.tf  --account-name ${data.azurerm_storage_account.state.name} --container-name ${azurerm_storage_container.bootstrap.name} --name azurerm_provider.tf --auth-mode login
  az storage blob download --file backend.tf           --account-name ${data.azurerm_storage_account.state.name} --container-name ${azurerm_storage_container.bootstrap.name} --name backend.tf --auth-mode login
  az storage blob download --file bootstrap_secrets.tf --account-name ${data.azurerm_storage_account.state.name} --container-name ${azurerm_storage_container.bootstrap.name} --name bootstrap_secrets.tf --auth-mode login
  ```

1. Edit the backend.tf

  The default value for the key in the backend.tf is an empty string, and you have to set it before running `terraform init`. This has been done intentionally so that there is a deliberate decision on the terraform state file name.

  ***IMPORTANT!***: **Ensure that the name doesn't conflict with any existing Terraform state files in the tfstate container.**

  Set the key value to be the desired name of the terraform statefile. E.g.

  * "terraform.tfstate"
  * "hub.tfstate"
  * "clientname/hub.tfstate"
  * "clientname-hub.tfstate"

  You will now be able to run through the terraform lifecycle commands and start building up your config.

  > If you ran `terraform init` whilst it was empty then see the the [troubleshooting](#troubleshooting) section.

## Managed Identity

If you are using trusted compute with a Managed Identity that has read access to the key vault secrets then set `use_msi = true` in the bootstrap_secrets.tf.

## CI/CD Pipelines

If you are using a CI/CD pipeline then:

* export [environment variables](https://www.terraform.io/docs/providers/azurerm/guides/service_principal_client_secret.html#configuring-the-service-principal-in-terraform)
* Bash commands to export:

  ```bash
  export ARM_TENANT_ID=${data.azurerm_client_config.current.tenant_id}
  export ARM_SUBSCRIPTION_ID=<subscriptionId> # E.g. $(az account show --output tsv --query id)
  export ARM_CLIENT_ID=${azuread_service_principal.terraform.application_id}
  export ARM_CLIENT_SECRET=$(az keyvault secret show --vault-name ${azurerm_key_vault.state.name} --name client-secret --output tsv --query value)
  ```

* remove the matching attributes in azurerm_provider.tf
* the bootstrap_secrets.tf file is not required

## Troubleshooting

#### Ran terraform init before setting the Terraform state file name

1. Edit the backend.tf and change the key value fom an empty string to your desired terraform state file name
1. Clean up the .terraform/terraform.tfstate JSON file. Either
  * Delete the file
  * Edit the file and set the value for .backend.config.key
1. Rerun terraform init

README

}

//==================================================================

output "tenant_id" {
  value = data.azurerm_client_config.current.tenant_id
}

output "subscription_id" {
  // The subscriptionId for the resource group, rather than any RBAC assignments
  value = data.azurerm_client_config.current.subscription_id
}

output "resource_group_name" {
  value = data.azurerm_resource_group.state.name
}

output "storage_account_name" {
  value = data.azurerm_storage_account.state.name
}

output "storage_account_id" {
  value = data.azurerm_storage_account.state.id
}

output "tfstate_container_name" {
  value = data.azurerm_storage_container.tfstate.name
}

output "bootstrap_state_blob_name" {
  value = "boostrap.tfstate"
}

output "app_id" {
  value = azuread_application.terraform.client_id
}

output "app_object_id" {
  value = azuread_application.terraform.object_id
}

output "sp_object_id" {
  value = azuread_service_principal.terraform.id
}

output "client_id" {
  value = azuread_service_principal.terraform.client_id
}

output "rbac_authorizations" {
  value = local.rbac_assignments
}

output "key_vault_name" {
  value = azurerm_key_vault.state.name
}

output "key_vault_id" {
  value = azurerm_key_vault.state.id
}


output "azurerm_provider" {
  value = local.azurerm_provider_file
}

output "backend" {
  value = local.backend_file
}

output "bootstrap_secrets" {
  value = local.bootstrap_secrets_file
}

output "provider_variables" {
  value = <<PROVIDER

  tenant_id     = "${data.azurerm_client_config.current.tenant_id}"
  client_id     = "${azuread_service_principal.terraform.client_id}
  client_secret = data.azurerm_key_vault_secret.client_secret.value
PROVIDER
}

output "environment_variables" {
  value = <<ENVVARS

export ARM_TENANT_ID=${data.azurerm_client_config.current.tenant_id}
export ARM_SUBSCRIPTION_ID=$(az account show --output tsv --query id)
export ARM_CLIENT_ID=${azuread_service_principal.terraform.client_id}
export ARM_CLIENT_SECRET=$(az keyvault secret show --vault-name ${azurerm_key_vault.state.name} --name client-secret --output tsv --query value)
ENVVARS
}

output "az" {
  value = <<AZ
az storage blob download --file azurerm_provider.tf  --account-name ${data.azurerm_storage_account.state.name} --container-name ${azurerm_storage_container.bootstrap.name} --name azurerm_provider.tf --auth-mode login
az storage blob download --file backend.tf           --account-name ${data.azurerm_storage_account.state.name} --container-name ${azurerm_storage_container.bootstrap.name} --name backend.tf --auth-mode login
az storage blob download --file bootstrap_secrets.tf --account-name ${data.azurerm_storage_account.state.name} --container-name ${azurerm_storage_container.bootstrap.name} --name bootstrap_secrets.tf --auth-mode login
AZ
}

//==================================================================


resource "local_file" "azurerm_provider" {
  content              = local.azurerm_provider_file
  filename             = "bootstrap/azurerm_provider.tf"
  file_permission      = 0644
  directory_permission = 0755
}

resource "local_file" "backend" {
  content              = local.backend_file
  filename             = "bootstrap/backend.tf"
  file_permission      = 0644
  directory_permission = 0755
}

resource "local_file" "bootstrap_secrets" {
  content              = local.bootstrap_secrets_file
  filename             = "bootstrap/bootstrap_secrets.tf"
  file_permission      = 0644
  directory_permission = 0755
}

resource "local_file" "readme" {
  content              = local.readme_file
  filename             = "bootstrap/bootstrap_README.md"
  file_permission      = 0644
  directory_permission = 0755
}

//==================================================================

resource "azurerm_storage_blob" "azurerm_provider" {
  name                   = "azurerm_provider.tf"
  storage_account_name   = data.azurerm_storage_account.state.name
  storage_container_name = azurerm_storage_container.bootstrap.name
  type                   = "Block"
  source_content         = local.azurerm_provider_file
}

resource "azurerm_storage_blob" "backend" {
  name                   = "backend.tf"
  storage_account_name   = data.azurerm_storage_account.state.name
  storage_container_name = azurerm_storage_container.bootstrap.name
  type                   = "Block"
  source_content         = local.backend_file
}

resource "azurerm_storage_blob" "bootstrap_secrets" {
  name                   = "bootstrap_secrets.tf"
  storage_account_name   = data.azurerm_storage_account.state.name
  storage_container_name = azurerm_storage_container.bootstrap.name
  type                   = "Block"
  source_content         = local.bootstrap_secrets_file
}

resource "azurerm_storage_blob" "readme" {
  name                   = "bootstrap_README.md"
  storage_account_name   = data.azurerm_storage_account.state.name
  storage_container_name = azurerm_storage_container.bootstrap.name
  type                   = "Block"
  source_content         = local.readme_file
}

//==================================================================
