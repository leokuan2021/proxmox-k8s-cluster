While I was studying for my CKA certificate, naturally I needed my own Kubernetes cluster to practice on and experiment with. Setting one up with VMs in the cloud was one option but I just so happened to have a NUC that I could repurpose as a testbed, which made the decision easy.

I also needed to learn and practice Terraform and Ansible, so what better way to do all that than spinning up a 3-node Kubernetes cluster with some code? It goes without saying that this is not production grade at all but I believe it's good enough for experimenting at home.

This project assumes Terraform and Ansible have been installed on the workstation from where the Terraform script and Ansible playbook will be run. It also assumes Proxmox has been installed on the target host and an API token has been created which can be used by the workstation to authenticate and communicate with Proxmox. 

Terraform is used at the beginning to provision the VMs, then Ansible takes over and continues with the system configuration and package installation for each of the nodes. It utilizes the kubeadm way to install Kubernetes. Calico, Helm, Kompose, Longhorn and MetalLB are also installed, among other things.

The end result is a 3-node Kubernetes VM cluster with the following parameters:

- Master Node: VMID = 140, hostname = k8s-master, IP = 192.168.1.140
- Worker Node 1: VMID = 146, hostname = k8s-worker1, IP = 192.168.1.146
- Worker Node 2: VMID = 147, hostname = k8s-worker2, IP = 192.168.1.147
- Kubernetes control plane end point = 192.168.1.140:6443 
- Pod network CIDR = 192.168.152.0/23

Note that the user `devops` is created for each one of the 3 nodes and the default SSH key location and filename is used (```~/.ssh/id_rsa```).

------------------------------------------------------------------------------
## Proxmox and Cloud-init
For hypervisor I went with Proxmox since I already had a little experience with it in the past. Installing Proxmox and building VM templates within it are both very straightforward. In order to create a template for VM instances that we can initialize using Terraform, we are going to utilize [Cloud-init](https://pve.proxmox.com/wiki/Cloud-Init_Support).

Cloud-init is a system for configuring OS on first boot. It is typically used on cloud-based systems but can also be used for non-cloud-based systems such as Proxmox or VirtualBox to which you can pass your cloud-init data such as instance metadata, network config and commands to be run as a CD-ROM and have the settings applied to your VMs.

I ran the following commands on the Proxmox host to create the VM template. Official Proxmox documentation can be found [here](https://pve.proxmox.com/pve-docs/chapter-qm.html#_preparing_cloud_init_templates).

## Creating the VM Template
```console
# download the cloud image 
cd /var/lib/vz/template/iso/
wget https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img

# install libguestfs-tools to directly install qemu-guest-agent into the iso
apt-get install libguestfs-tools

# install qemu-guest-agent
virt-customize -a focal-server-cloudimg-amd64.img --install qemu-guest-agent

# create a new VM  
qm create 1000 --name "ubuntu-2004-cloudinit-template" --memory 4096 --cores 2 --net0 virtio,bridge=vmbr0

# import the downloaded disk to local-lvm storage
qm importdisk 1000 focal-server-cloudimg-amd64.img local-lvm

# finally attach the new disk to the VM as scsi drive
qm set 1000 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-1000-disk-0

# configure a CD-ROM drive, which will be used to pass the Cloud-Init data to the VM
qm set 1000 --ide2 local-lvm:cloudinit

# to be able to boot directly from the Cloud-Init image, set the bootdisk parameter to scsi0
qm set 1000 --boot c --bootdisk scsi0

# configure a serial console and use it as a display
qm set 1000 --serial0 socket --vga serial0

# enable the agent
qm set 1000 --agent 1

# convert the VM into a template
qm template 1000
```
------------------------------------------------------------------------------

## Create role and user, set privileges and generate API token
```console
pveum role add terraform-role -privs "VM.Allocate VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Monitor VM.Audit VM.PowerMgmt Datastore.AllocateSpace Datastore.Audit"
pveum user add terraform@pve
pveum aclmod / -user terraform@pve -role terraform-role
pveum user token add terraform@pve terraform-token --privsep=0

# output:
root@host1:/var/lib/vz/template/iso# pveum user token add terraform@pve terraform-token --privsep=0
┌──────────────┬──────────────────────────────────────┐
│ key          │ value                                │
╞══════════════╪══════════════════════════════════════╡
│ full-tokenid │ terraform@pve!terraform-token        │
├──────────────┼──────────────────────────────────────┤
│ info         │ {"privsep":"0"}                      │
├──────────────┼──────────────────────────────────────┤
│ value        │ 87b3a427-5ebd-4451-b5c2-d19ef2008de4 │
└──────────────┴──────────────────────────────────────┘
```

Then on our workstation, we export the following to pass the API token when the TF script is run:
```console
# Export the following variables which our Terraform script will use to authenticate when it communicates with our Proxmox server
export PM_API_TOKEN_ID="terraform@pve!terraform-token"
export PM_API_TOKEN_SECRET="87b3a427-5ebd-4451-b5c2-d19ef2008de4"
```
------------------------------------------------------------------------------
## Running the Terraform Script
From the project root directory, do the following:
```console
terraform init
terraform apply
```
If all goes well, in a few minutes the cluster will be up and running, ready for you to practice your K8s chops on.
