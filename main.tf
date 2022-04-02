# Script to provision a 1-master 2-worker Kubernetes cluster. 
#The API uses the HTTPS protocol and the server listens to port 8006. So the base URL for that API is 
#https://pve.proxmox.com/wiki/Proxmox_VE_API





terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "2.9.1"
    }
  }
}

# Ref: https://registry.terraform.io/providers/Telmate/proxmox/latest/docs


provider "proxmox" {
  # make sure to export PM_API_TOKEN_ID and PM_API_TOKEN_SECRET
  pm_tls_insecure = true
  pm_api_url      = var.proxmox_server_api_url

}

# generate cloud-init config files locally

# Create a local copy of the cloud-init file, to transfer to Proxmox
resource "local_file" "cloud_init_master" {
  content  = data.template_file.cloud_init_master.rendered
  filename = "cloud_init_master_generated.cfg"
}

resource "local_file" "cloud_init_worker" {
  count    = var.worker_count
  content  = data.template_file.cloud_init_worker[count.index].rendered
  filename = "cloud_init_worker${count.index}_generated.cfg"
}

# copy config files to Proxmox server

resource "null_resource" "cloud_init_master" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key_path)
    host        = var.proxmox_server_ip
  }

  provisioner "file" {
    source      = local_file.cloud_init_master.filename
    destination = "/var/lib/vz/snippets/cloud_init_master.yaml"
  }
}

resource "null_resource" "cloud_init_worker" {
  count = var.worker_count
  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.private_key_path)
    host        = var.proxmox_server_ip
  }

  provisioner "file" {
    source      = local_file.cloud_init_worker[count.index].filename
    destination = "/var/lib/vz/snippets/cloud_init_worker${count.index}.yaml"
  }
}

resource "proxmox_vm_qemu" "k8s-master" {
  depends_on = [
    null_resource.cloud_init_master
  ]
  name        = "k8s-master"
  target_node = var.proxmox_host
  clone       = var.template_name
  vmid        = var.master_vmid
  cores       = 2
  sockets     = 1
  memory      = 4096

  disk {
    size    = "100G"
    type    = "scsi"
    storage = "local-lvm"
  }

  # disregard network changes
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # Cloud init options
  cicustom  = "user=local:snippets/cloud_init_master.yaml"
  ipconfig0 = var.master_ipconfig0
}

resource "proxmox_vm_qemu" "k8s-worker" {
  count       = var.worker_count
  name        = "k8s-worker-${count.index}"
  target_node = var.proxmox_host
  clone       = var.template_name
  vmid        = count.index + var.worker0_vmid
  cores       = 2
  sockets     = 1
  memory      = 4096
  disk {
    size    = "100G"
    type    = "scsi"
    storage = "local-lvm"
  }

  # disregard network changes
  lifecycle {
    ignore_changes = [
      network,
    ]
  }

  # Cloud init options
  cicustom  = "user=local:snippets/cloud_init_worker${count.index}.yaml"
  ipconfig0 = "ip=192.168.1.14${count.index+6}/24,gw=192.168.1.1"
}


resource "null_resource" "ansible_handover" {
  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Master Done!"]

    connection {
      host        = "192.168.1.140"
      type        = "ssh"
      user        = "devops"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Worker0 Done!"]

    connection {
      host        = "192.168.1.146"
      type        = "ssh"
      user        = "devops"
      private_key = file(var.private_key_path)
    }
  }

  provisioner "remote-exec" {
    inline = ["sudo apt update", "sudo apt install python3 -y", "echo Worker1 Done!"]

    connection {
      host        = "192.168.1.147"
      type        = "ssh"
      user        = "devops"
      private_key = file(var.private_key_path)
    }
  }


  provisioner "local-exec" {
    command = "ansible-playbook -i 'ansible/inventory' --private-key ${var.private_key_path} ansible/k8_cluster_setup.yaml"
  }
}
