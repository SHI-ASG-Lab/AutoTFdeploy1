
# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = ">= 2.46.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# Variable Declarations
variable "RG_name" {}

variable "RG_Env_Tag" {}

variable "RG_SP_Name" {}

variable "NSG_name" {}

variable "VNET_name" {}

variable "mgmt_Subnet1_name" {}

variable "int_Subnet2_name" {}

variable "ext_Subnet3_name" {}

variable "VM_NGFW_name" {}

resource "azurerm_resource_group" "example" {
  name     = ${var.RG_name}
  location = "southcentralus"

  tags = {
      Environment = var.RG_Env_Tag
      SP = var.RG_SP_Name
  }
}

resource "azurerm_network_security_group" "NSG1" {
  name                = var.NSG_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

}

# Create a virtual network within the resource group
resource "azurerm_virtual_network" "example" {
  name                = var.VNET_name
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.0.0.0/16"]
}

# Create subnets within the virtual network
resource "azurerm_subnet" "mgmtsubnet" {
    name           = var.mgmt_Subnet1_name
    resource_group_name = azurerm_resource_group.example.name
    virtual_network_name = azurerm_virtual_network.example.name
    address_prefixes = ["10.0.1.0/24"]
}

resource "azurerm_subnet" "intsubnet" {
    name           = var.int_Subnet2_name
    resource_group_name = azurerm_resource_group.example.name
    virtual_network_name = azurerm_virtual_network.example.name
    address_prefixes = ["10.0.2.0/24"]
}

resource "azurerm_subnet" "extsubnet" {
    name           = var.ext_Subnet3_name
    resource_group_name = azurerm_resource_group.example.name
    virtual_network_name = azurerm_virtual_network.example.name
    address_prefixes = ["10.0.3.0/24"]
}

# Associate Subnets with NSG
resource "azurerm_subnet_network_security_group_association" "mgmtSubAssocNsg" {
  subnet_id                 = azurerm_subnet.mgmtsubnet.id
  network_security_group_id = azurerm_network_security_group.NSG1.id
}
###
resource "azurerm_subnet_network_security_group_association" "intSubAssocNsg" {
  subnet_id                 = azurerm_subnet.intsubnet.id
  network_security_group_id = azurerm_network_security_group.NSG1.id
}

resource "azurerm_subnet_network_security_group_association" "extSubAssocNsg" {
  subnet_id                 = azurerm_subnet.extsubnet.id
  network_security_group_id = azurerm_network_security_group.NSG1.id
}

# Create a public IP for the system to use
resource "azurerm_public_ip" "azPubIp" {
  name = "azPubIp1"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location
  allocation_method = "Static"
}

# Create Route Tables and specify routes
resource "azurerm_route_table" "mgmtRtable" {
  name                          = "mgmtRouteTable"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  disable_bgp_route_propagation = true

  route {
    name           = "mgmt2internal"
    address_prefix = "10.0.2.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.2.4"
  }
  route {
    name           = "mgmt2ext"
    address_prefix = "10.0.3.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.3.4"
  }
  tags = {
    RouteTable = "mgmt"
  }
}

resource "azurerm_route_table" "intRtable" {
  name                          = "intRouteTable"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  disable_bgp_route_propagation = true

  route {
    name           = "int2mgmt"
    address_prefix = "10.0.1.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.1.4"
  }
  route {
    name           = "int2ext"
    address_prefix = "10.0.3.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.3.4"
  }
  tags = {
    RouteTable = "mgmt"
  }
}

resource "azurerm_route_table" "extRtable" {
  name                          = "extRouteTable"
  location                      = azurerm_resource_group.example.location
  resource_group_name           = azurerm_resource_group.example.name
  disable_bgp_route_propagation = true

  route {
    name           = "ext2internal"
    address_prefix = "10.0.2.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.2.4"
  }
  route {
    name           = "ext2mgmt"
    address_prefix = "10.0.1.0/24"
    next_hop_type  = "VirtualAppliance"
    next_hop_in_ip_address = "10.0.1.4"
  }
  tags = {
    RouteTable = "mgmt"
  }
}

# Associate Route Tables with Subnets
resource "azurerm_subnet_route_table_association" "mgmtassoc" {
  subnet_id      = azurerm_subnet.mgmtsubnet.id
  route_table_id = azurerm_route_table.mgmtRtable.id
}
resource "azurerm_subnet_route_table_association" "intassoc" {
  subnet_id      = azurerm_subnet.intsubnet.id
  route_table_id = azurerm_route_table.intRtable.id
}
resource "azurerm_subnet_route_table_association" "extassoc" {
  subnet_id      = azurerm_subnet.extsubnet.id
  route_table_id = azurerm_route_table.extRtable.id
}

# Create the NICs and assign to subnets
resource "azurerm_network_interface" "Nic1" {
  name = "mgmt-nic"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location

  ip_configuration {
    name = "mgmt"
    subnet_id = azurerm_subnet.mgmtsubnet.id
    primary = true
    private_ip_address_version = "IPv4"
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.1.4"
    public_ip_address_id = azurerm_public_ip.azPubIp.id

  }
}

resource "azurerm_network_interface" "Nic2" {
  name = "internal-nic"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location

  ip_configuration {
    name = "internal"
    subnet_id = azurerm_subnet.intsubnet.id
    private_ip_address_version = "IPv4"
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.2.4"
    primary = false

  }
}

resource "azurerm_network_interface" "Nic3" {
  name = "external-nic"
  resource_group_name = azurerm_resource_group.example.name
  location = azurerm_resource_group.example.location

  ip_configuration {
    name = "external"
    subnet_id = azurerm_subnet.extsubnet.id
    private_ip_address_version = "IPv4"
    private_ip_address_allocation = "Static"
    private_ip_address = "10.0.3.4"
    primary = false

  }
}

# Create VM with objects defined above
resource "azurerm_virtual_machine" "main" {
  name                  = var.VM_NGFW_name
  location              = azurerm_resource_group.example.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = [azurerm_network_interface.Nic1.id, azurerm_network_interface.Nic2.id, azurerm_network_interface.Nic3.id]
  primary_network_interface_id = azurerm_network_interface.Nic1.id
  vm_size               = "Standard_E8s_v4"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true

  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  plan {
    name = "fortinet_fg-vm_payg_20190624"
    publisher = "fortinet"
    product = "fortinet_fortigate-vm_v5"
  }

  storage_image_reference {
    publisher = "fortinet"
    offer     = "fortinet_fortigate-vm_v5"
    sku       = "fortinet_fg-vm_payg_20190624"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "StandardSSD_LRS"
  }
  os_profile {
    computer_name  = "FortiGate"
    admin_username = "testadmin"
    admin_password = "Password1234!"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = var.RG_Env_Tag
    vendor = "fortinet"
    sp = var.RG_SP_Name
  }
}

# Configure Auto-Shutdown for the VM for each night at 10pm CST.
resource "azurerm_dev_test_global_vm_shutdown_schedule" "sched1" {
  virtual_machine_id = azurerm_virtual_machine.main.id
  location           = azurerm_resource_group.example.location
  enabled            = true

  daily_recurrence_time = "2200"
  timezone              = "Central Standard Time"

  notification_settings {
    enabled         = false
  }
}
