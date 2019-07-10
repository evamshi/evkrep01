

#Provider
provider "azurerm" {
    subscription_id = "${var.subscription_id}"
    client_id       = "${var.client_id}"
    client_secret   = "${var.client_secret}"
    tenant_id       = "${var.tenant_id}"
    }

resource "azurerm_resource_group" "test" {
    name            = "${var.prefix}-rg"
    location        = "${var.deployregion}"

    tags = {
        environment = "EVK Terraform Demo"
    }
}

resource "azurerm_virtual_network" "test" {
    name            = "${var.prefix}-VNETwus"
    address_space   = ["192.168.18.0/24"]
    location        = "${var.deployregion}"
    resource_group_name = "${azurerm_resource_group.test.name}"
        
}

resource "azurerm_subnet" "internal01" {
  name                 = "${var.prefix}-IntSubnet01"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "192.168.18.0/27"
}


resource "azurerm_subnet" "external01" {
  name                 = "${var.prefix}-ExtSubnet01"
  resource_group_name  = "${azurerm_resource_group.test.name}"
  virtual_network_name = "${azurerm_virtual_network.test.name}"
  address_prefix       = "192.168.18.32/27"
}
resource "azurerm_public_ip" "test" {
  name            = "${var.prefix}-ELBPIP"
  location        = "${var.deployregion}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  allocation_method   = "Static"
  domain_name_label = "evktest007"
}
output "elbpublic_ip_address" {
  value = "${azurerm_public_ip.test.*.ip_address}"
  description = "The public IP address of the Externla Load Balancer."
}
output "domain_name_label" {
  value = "${azurerm_public_ip.test.domain_name_label}"
}
output "public_elb_ip_dns_name" {
  description = "fqdn to browse the WebSite."
  value       = "${azurerm_public_ip.test.*.fqdn}"
}
resource "azurerm_lb" "test" {
  name            = "${var.prefix}-ELB"
  location        = "${var.deployregion}"
  resource_group_name = "${azurerm_resource_group.test.name}"

  frontend_ip_configuration {
    name                 = "${var.prefix}ELBFEIP"
    public_ip_address_id = "${azurerm_public_ip.test.id}"
  }
}
resource "azurerm_lb_backend_address_pool" "test" {
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id     = "${azurerm_lb.test.id}"
  name                = "${var.prefix}ELBBEPool"
}
resource "azurerm_lb_probe" "test" {
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id     = "${azurerm_lb.test.id}"
  name                = "ssh-running-probe"
  port                = 22
}
resource "azurerm_lb_rule" "mytfelbrule1" {
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id                = "${azurerm_lb.test.id}"
  name                           = "LBRule1"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "${var.prefix}ELBFEIP"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.test.id}"
  probe_id                = "${azurerm_lb_probe.test.id}"

}
resource "azurerm_lb_rule" "mytfelbrule2" {
  resource_group_name = "${azurerm_resource_group.test.name}"
  loadbalancer_id                = "${azurerm_lb.test.id}"
  name                           = "LBRule2"
  protocol                       = "Tcp"
  frontend_port                  = 22
  backend_port                   = 22
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.test.id}"
  frontend_ip_configuration_name = "${var.prefix}ELBFEIP"
    probe_id                = "${azurerm_lb_probe.test.id}"
}


resource "azurerm_network_interface_backend_address_pool_association" "test" {
    count                   = "${var.noofvms}"
  network_interface_id    = "${element(azurerm_network_interface.test.*.id, count.index)}"
  ip_configuration_name   = "${element(azurerm_network_interface.test[count.index].ip_configuration.*.name, count.index)}"
  backend_address_pool_id = "${azurerm_lb_backend_address_pool.test.id}"
}
resource "azurerm_network_security_group" "test" {
    name                = "${var.prefix}-NSG"
  location        = "${var.deployregion}"
    resource_group_name = "${azurerm_resource_group.test.name}"
    
    security_rule {
        name                       = "SSH"
        priority                   = 100
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "22"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    security_rule {
        name                       = "HTTP"
        priority                   = 200
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "EVK Terraform Demo"
    }
}
resource "azurerm_network_interface" "test" {
  count               = "${var.noofvms}"
  name                = "${var.prefix}-nic${count.index}"
  location            = "${var.deployregion}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  network_security_group_id = "${azurerm_network_security_group.test.id}"

  ip_configuration {
    name                          = "testfiguration${count.index}"
    subnet_id                     = "${azurerm_subnet.external01.id}"
    private_ip_address_allocation = "Dynamic"
    #public_ip_address_id          = "${azurerm_public_ip.mytfpip01.id}"
      }
  tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_availability_set" "test" {
  name                = "tfwebavs"
  location            = "${var.deployregion}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  managed             = "false"
}
resource "random_id" "test" {
  byte_length = 4
}
resource "azurerm_storage_account" "test" {
  name            = "sg${lower(random_id.test.hex)}"
   location        = "${var.deployregion}"
  resource_group_name = "${azurerm_resource_group.test.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = {
        environment = "EVK Terraform Demo"
        owner       = "evksg"
    }
}
resource "azurerm_storage_container" "test" {
  name            = "${lower(var.prefix)}-evkvhds"
  resource_group_name = "${azurerm_resource_group.test.name}"
  storage_account_name  = "${azurerm_storage_account.test.name}"
  container_access_type = "private"
}
resource "azurerm_virtual_machine" "test" {
  count                 = "${var.noofvms}"
  name                  = "${var.prefix}-vm${count.index}"
  location              = "${var.deployregion}"
  resource_group_name   = "${azurerm_resource_group.test.name}"
 network_interface_ids = ["${element(azurerm_network_interface.test.*.id, count.index)}"]
  availability_set_id   = "${azurerm_availability_set.test.id}"
  vm_size               = "Standard_B1s"

  # Uncomment this line to delete the OS disk automatically when deleting the VM
  delete_os_disk_on_termination = true


  # Uncomment this line to delete the data disks automatically when deleting the VM
  delete_data_disks_on_termination = true

  storage_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "16.04-LTS"
    version   = "latest"
  }
  # Managed Disk
  #storage_os_disk {
   # name              = "VM01-OSDisk"
   #caching           = "ReadWrite"
   # create_option     = "FromImage"
    #managed_disk_type = "Standard_LRS"
  #}

  storage_os_disk {
    name          = "VM01-OSDisk${count.index}"
    vhd_uri       = "${azurerm_storage_account.test.primary_blob_endpoint}${azurerm_storage_container.test.name}/vm${count.index}myosdisk${count.index}.vhd"
    caching       = "ReadWrite"
    create_option = "FromImage"
  }
  boot_diagnostics {
    enabled = "true"
    storage_uri = "${azurerm_storage_account.test.primary_blob_endpoint}"
    }

  # Optional data disks
  storage_data_disk {
    name          = "vm01datadisk${count.index}"
    vhd_uri       = "${azurerm_storage_account.test.primary_blob_endpoint}${azurerm_storage_container.test.name}/vm${count.index}datadisk1.vhd"
    disk_size_gb  = "10"
    create_option = "Empty"
    lun           = 0
  } 
  os_profile {
    computer_name  = "${var.prefix}-vm${count.index}"
    admin_username = "testadmin"
    admin_password = "plokij@12345"
  }
  os_profile_linux_config {
    disable_password_authentication = false
  }
  tags = {
    environment = "staging"
  }
  }
output "Virtual_Machine_Names" {
  value = "${concat(azurerm_virtual_machine.test.*.name,azurerm_network_interface.test.*.private_ip_address)}"
}
output "Virtual_Network_Name" {
  value = "${azurerm_virtual_network.test.*.name}"
  }
  output "Virtual_Network_AddressSpace_Details" {
      value = "${azurerm_virtual_network.test.*.address_space}"
  }
  output "website_Browse" {
  value = "www.evktest007.xyz"
}