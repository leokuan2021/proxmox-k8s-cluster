# Script to provision a 1-master 2-worker Kubernetes cluster. 
# Proxmox server IP in my local network: 192.168.1.39
# Master Node: VMID = 140, hostname = k8s-master, IP = 192.168.1.140/24, GW=192.168.1.1, user: devops
# Worker Node 1: VMID = 146, hostname = k8s-worker1, IP = 192.168.1.146/24, GW=192.168.1.1, user: devops
# Worker Node 2: VMID = 147, hostname = k8s-worker2, IP = 192.168.1.147/24, GW=192.168.1.1, user: devops


variable "proxmox_server_api_url" {
  default = "https://192.168.1.39:8006/api2/json"
}

variable "proxmox_server_ip" {
  default = "192.168.1.39"
}

variable "proxmox_host" {
  default = "host1"
}

variable "template_name" {
  default = "ubuntu-2004-cloudinit-template"
}

variable "master_vmid" {
  default = 140 
}

variable "master_ipconfig0" {
  default = "ip=192.168.1.140/24,gw=192.168.1.1"  
}

variable "worker0_vmid" {
  default = 146 
}

variable "worker_ipconfig0" {
  default = "ip=192.168.1.140/24,gw=192.168.1.1"  
}


variable "worker_count" {
  default = 2
}

variable "private_key_path" {
  default = "~/.ssh/id_rsa"
}
