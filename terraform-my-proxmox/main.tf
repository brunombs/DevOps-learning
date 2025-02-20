terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "3.0.1-rc6" # Versão mais recente estável recomendada quando disponível
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.pm_api_url
  pm_api_token_id     = var.pm_api_token_id
  pm_api_token_secret = var.pm_api_token_secret
  pm_tls_insecure     = true
}

resource "proxmox_vm_qemu" "vm-instance" {
  name        = "vm-instance"
  target_node = "brunolab"
  clone       = "ubuntu-2204-template"
  full_clone  = true
  bios        = "seabios"
  scsihw      = "virtio-scsi-single"
  os_type     = "cloud-init"  # Mantido para sistemas Linux modernos
  cores       = 1
  memory      = 1024
  vm_state    = "running"
  agent       = 1      # Habilita o QEMU Agent

  boot      = "order=scsi0;net0;ide0"
  bootdisk  = "scsi0" # Define o disco principal para evitar problemas no Proxmox


  # Cloud-Init configuration
  ciupgrade  = false
  ciuser     = "root"
  cipassword = "test1234"
  sshkeys    = file("~/SSH/VM1/id_ed25519.pub")
  ipconfig0  = "ip=dhcp"

  # Serial console
  serial {
    id = 0
  }

  provisioner "remote-exec" {
  inline = [
    "sudo apt-get update",
    "sudo apt-get install -y qemu-guest-agent",
    "sudo systemctl start qemu-guest-agent",
    "sudo systemctl enable qemu-guest-agent"
  ]
  
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file("~/SSH/VM1/id_ed25519")
    host        = self.default_ipv4_address
    timeout     = "10m"
  }
}

  # Main disk (SCSI)
  disk {
    type     = "disk"
    storage  = "local-lvm"
    size     = "32G"
    slot     = "scsi0"
    iothread = true
  }

  # Cloud-init drive (IDE0)
  disk {
    type    = "cloudinit"
    storage = "local-lvm"
    slot    = "ide0"
  }

  # Network interface
  network {
    id      = 0
    model   = "virtio"
    bridge  = "vmbr0"
    firewall = true
    # MAC gerado automaticamente pelo Proxmox
  }

  lifecycle {
    ignore_changes = [
      network[0].macaddr,    # Ignora alterações no MAC gerado
      disk,                  # Ignora alterações de tamanho de disco (cuidado!)
      ciuser,                # Ignora alterações no usuário Cloud-Init
      cipassword             # Ignora alterações na senha Cloud-Init
    ]
  }

  timeouts {
    create = "30m"
  }
}

# Output para mostrar o IP da VM
output "vm_ip" {
  description = "The IP address of the VM"
  value       = proxmox_vm_qemu.vm-instance.default_ipv4_address
}

# Output para mostrar informações de SSH
output "ssh_command" {
  description = "Command to SSH into the VM"
  value       = "ssh root@${proxmox_vm_qemu.vm-instance.default_ipv4_address}"
}