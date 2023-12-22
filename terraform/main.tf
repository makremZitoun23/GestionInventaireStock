terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.84.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "tf-data"
    storage_account_name = "tfstatedata2023"
    container_name       = "state-container"
    key                  = "terraform.tfstate"
    use_oidc             = true
  }
}

provider "azurerm" {
  features {}
}

resource "random_string" "vms_pwd" {
  length  = 16
  special = true
}

resource "azurerm_resource_group" "rg_depl" {
  name     = "Test_RG"
  location = var.region
}

resource "azurerm_virtual_machine" "vms_deployment" {
  name                             = var.vms
  location                         = var.region
  resource_group_name              = azurerm_resource_group.rg_depl.name
  vm_size                          = var.vm_size
  network_interface_ids            = [azurerm_network_interface.main.id]
  delete_os_disk_on_termination    = true
  delete_data_disks_on_termination = true
  depends_on                       = [azurerm_network_interface_security_group_association.link-sg, azurerm_public_ip.pubsIps]
  storage_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
  storage_os_disk {
    name              = "myosdisk1"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }
  os_profile {
    computer_name  = "stock-prod"
    admin_username = "azureuser"
    admin_password = random_string.vms_pwd.result
    custom_data = data.template_file.cloud-init.rendered
  }
  os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      path = "/home/azureuser/.ssh/authorized_keys"
      key_data = file("azure_key")
    }
  }
  
  tags = {
    environment = "prod"
  }
}

resource "null_resource" "provisioner" {
  depends_on = [ azurerm_virtual_machine.vms_deployment ]
  provisioner "file" {
    connection {
      type = "ssh"
      user = "azureuser"
      host = data.azurerm_public_ip.vm_pub_ip.ip_address
      private_key = file("./azure_prv_key")
      agent = false
      timeout = "10m"
    }
    source = "./docker-compose.yml"
    destination = "/home/azureuser/docker-compose.yml"
  }
}

resource "null_resource" "remote_provionner" {
  
  connection {
      type = "ssh"
      user = "azureuser"
      host = data.azurerm_public_ip.vm_pub_ip.ip_address
      private_key = file("./azure_prv_key")
      agent = false
  }
provisioner "remote-exec" {
  script = "./run.sh"
  
  #inline = [ "sleep 10 && docker compose up -d " ]
 
}
 depends_on = [ time_sleep.await-docker ]
}

resource "time_sleep" "await-docker" {
  create_duration = "10s"
  depends_on = [ azurerm_virtual_machine.vms_deployment ]
}

output "password" {
  value = random_string.vms_pwd.result
}

output "publicIP" {
  value      = data.azurerm_public_ip.vm_pub_ip.ip_address
}
