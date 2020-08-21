variable "zip_path" {
  default = "../func.zip"
}
variable "func_path" {
  default = "../LocalFunctionProj"
}
variable "location" {
  default = "West US"
}

provider "azurerm" {
  features {}
}
provider "archive" {}

data "archive_file" "init" {
  type        = "zip"
  source_dir  = var.func_path
  output_path = var.zip_path
}

resource "azurerm_resource_group" "rg1" {
  name     = "rg1"
  location = "West US"
}
resource "azurerm_storage_account" "storage" {
  name                     = "testdeploytfsa"
  resource_group_name      = "${azurerm_resource_group.rg1.name}"
  location                 = "${azurerm_resource_group.rg1.location}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "random_string" "storage_name" {
  length  = 16
  special = false
  upper   = false
}
resource "random_string" "function_name" {
  length  = 16
  special = false
  upper   = false
}
resource "random_string" "app_service_plan_name" {
  length  = 16
  special = false
}
resource "random_string" "app_name" {
  length  = 16
  special = false
}

resource "azurerm_storage_container" "storage_container" {
  name                  = "func"
  storage_account_name  = azurerm_storage_account.storage.name
  container_access_type = "private"
}

resource "azurerm_storage_blob" "storage_blob" {
  name                   = "azure.zip"
  storage_account_name   = azurerm_storage_account.storage.name
  storage_container_name = azurerm_storage_container.storage_container.name
  type                   = "Block"
  source                 = var.zip_path
}
data "azurerm_storage_account_sas" "storage_sas" {
  connection_string = azurerm_storage_account.storage.primary_connection_string
  https_only        = false
  resource_types {
    service   = false
    container = false
    object    = true
  }
  services {
    blob  = true
    queue = false
    table = false
    file  = false
  }
  start  = "20200529"
  expiry = "20300529"
  permissions {
    read    = true
    write   = false
    delete  = false
    list    = false
    add     = false
    create  = false
    update  = false
    process = false
  }
}
resource "azurerm_app_service_plan" "plan" {
  name                = random_string.app_service_plan_name.result
  location            = azurerm_resource_group.rg1.location
  resource_group_name = azurerm_resource_group.rg1.name
  kind                = "functionapp"
  reserved            = true
  sku {
    tier = "Dynamic"
    size = "Y1"
  }
}
resource "azurerm_function_app" "function" {
  name                      = random_string.storage_name.result
  location                  = azurerm_resource_group.rg1.location
  resource_group_name       = azurerm_resource_group.rg1.name
  app_service_plan_id       = azurerm_app_service_plan.plan.id
  storage_connection_string = azurerm_storage_account.storage.primary_connection_string
  os_type                   = "linux"
  version                   = "~3"
  app_settings = {
    "FUNCTIONS_WORKER_RUNTIME" = "python"
    "FUNCTION_APP_EDIT_MODE"   = "readonly"
    "FUNCTIONS_EXTENSION_VERSION" : "~3",
    "https_only" = true,
  }
  provisioner "local-exec" {
    command = "az webapp deployment source config-zip --resource-group ${azurerm_resource_group.rg1.name} --name ${random_string.storage_name.result} --src ${var.zip_path}"
  }
}
