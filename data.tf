# Source the Cloud-init Config file
data "template_file" "cloud_init_master" {
  template = file("cloud_init_cfg.yaml")
  vars = {
    ssh_public_key = file("~/.ssh/id_rsa.pub")
    node           = "k8s-master"
  }
}

data "template_file" "cloud_init_worker" {
  count    = var.worker_count
  template = file("cloud_init_cfg.yaml")
  vars = {
    ssh_public_key = file("~/.ssh/id_rsa.pub")
    node           = "k8s-worker${count.index}"
  }
}
