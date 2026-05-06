variable "rg_name" {
  type = string
}

variable "location" {
  type = string
}

variable "vnet_name" {
  type = string
}

variable "subnet_names" {
  type = list(string)
}

variable "vm_count" {
  type = number
}

variable "admin_username" {
  type = string
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "tags" {
  type = map(string)
}

variable "enable_public_ip" {
  type = bool
}

variable "rdp_allowed_source" {
  type = string
}

variable "custom_subnet_key" {
  type    = string
  default = null
}

variable "custom_vm_name" {
  type    = string
  default = null
}

variable "env_code" {
  type = string
}

variable "custom_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-22h2-pro"
    version   = "latest"
  }
}

locals {
  target_subnet_name = coalesce(var.custom_subnet_key, var.subnet_names[0])
}

data "azurerm_subnet" "target" {
  name                 = local.target_subnet_name
  virtual_network_name = var.vnet_name
  resource_group_name  = var.rg_name
}

resource "azurerm_public_ip" "pip" {
  count               = var.enable_public_ip ? var.vm_count : 0
  name                = "pip-appvmjtk${var.env_code}-${count.index}"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_network_interface" "nic" {
  count               = var.vm_count
  name                = "nic-appvmjtk${var.env_code}-${count.index}"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = data.azurerm_subnet.target.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.enable_public_ip ? azurerm_public_ip.pip[count.index].id : null
  }

  tags = var.tags
}

resource "azurerm_windows_virtual_machine" "vm" {
  count                 = var.vm_count
  name                  = coalesce(var.custom_vm_name, "appvmjtk${var.env_code}-${count.index}")
  location              = var.location
  resource_group_name   = var.rg_name
  size                  = "Standard_B2ms"
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  provision_vm_agent    = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = var.custom_image.publisher
    offer     = var.custom_image.offer
    sku       = var.custom_image.sku
    version   = var.custom_image.version
  }

  boot_diagnostics {
    storage_account_uri = null
  }

  tags = var.tags
}

resource "azurerm_virtual_machine_extension" "ama" {
  count                      = var.vm_count
  name                       = "AzureMonitorWindowsAgent"
  virtual_machine_id         = azurerm_windows_virtual_machine.vm[count.index].id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorWindowsAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
}