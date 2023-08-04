terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
  }
}

resource "libvirt_volume" "os_image_ubuntu" {
  name   = "os_image_ubuntu"
  pool   = "default"
  source = "http://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  #source = "../images/focal-server-cloudimg-amd64.img"
}

resource "libvirt_volume" "os_volume" {
  name              = "os_volume-${count.index}"
  base_volume_id    = libvirt_volume.os_image_ubuntu.id
  size              = 6442450944  // 6 * 1024 * 1024 * 1024
  count             = var.worker_count+1
}

######### Controller #########
# Controller VM
resource "libvirt_domain" "kubernetes_controller" {
  name      = "k8s_controller"
  memory    = var.memory
  vcpu      = var.vcpu
  cloudinit = libvirt_cloudinit_disk.controller_cloudinit.id
  connection {
    type        = "ssh"
    user        = "root"
    host        = self.network_interface[0].addresses[0]
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait"
    ]
  } 
  network_interface {
    network_name = "default"
    wait_for_lease = true    
  }
  console {
    type = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type = "pty"
    target_type = "virtio"
    target_port = "1"
  }
  disk {
    volume_id = element(libvirt_volume.os_volume.*.id, 0)
  }
  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}
# Controller Cloud Config
resource "libvirt_cloudinit_disk" "controller_cloudinit" {
  name = "controller_cloudinit.iso"
  pool = "default"
  user_data = <<EOF
#cloud-config
disable_root: 0
ssh_pwauth: 1
users:
  - name: root
    ssh-authorized-keys:
      - ${file("~/.ssh/id_rsa.pub")}
  - name: ${var.username}
    ssh-authorized-keys:
      - ${file("~/.ssh/id_rsa.pub")}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: '/bin/bash'
    plain_text_passwd: '${random_string.password.result}'
    lock_passwd: false       
growpart:
  mode: auto
  devices: ['/']
package_update: true
package_upgrade: true
packages:
  # Update the apt package index and install packages needed to use the Docker and Kubernetes apt repositories over HTTPS
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
hostname: k8scontroller
fqdn: k8scontroller.${var.dns_domain}
preserve_hostname: true
write_files:
# https://stackoverflow.com/questions/52119985/kubeadm-init-shows-kubelet-isnt-running-or-healthy
- content: |
    {
        "exec-opts": ["native.cgroupdriver=systemd"]
    }
  path: /etc/docker/daemon.json
  owner: root:root
runcmd:
 - hostnamectl set-hostname k8scontroller
 - curl  -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
 - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list
 - apt-get update -y # Update apt package index
#  - apt-get install -y docker.io kubelet kubeadm kubectl
#  - |
#   kubeadm init \
#   --token ${local.token} \
#   --token-ttl 15m \
#   --pod-network-cidr=192.168.0.0/16 \
#   --node-name k8s-controller
#  - mkdir -p /home/${var.username}/.kube
#  - sudo cp -i /etc/kubernetes/admin.conf /home/${var.username}/.kube/config
#  - sudo chown ${var.username}:${var.username} /home/${var.username}/.kube/config
#  - mkdir -p $HOME/.kube
#  - sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
#  - sudo chown $(id -u):$(id -g) $HOME/.kube/config          
#  - kubectl create -f https://docs.projectcalico.org/manifests/tigera-operator.yaml
#  - kubectl create -f https://docs.projectcalico.org/manifests/custom-resources.yaml    
EOF
}
######### End: Controller #########


######### Workers #########
# Worker VMs
resource "libvirt_domain" "kubernetes_workers" {
  depends_on = [libvirt_domain.kubernetes_controller]
  count = var.worker_count  

  name      = "k8s_worker_${count.index}"
  memory    = var.memory
  vcpu      = var.vcpu
  cloudinit = element(libvirt_cloudinit_disk.worker_cloudinit.*.id, count.index)
  connection {
    type        = "ssh"
    user        = "root"
    host        = self.network_interface[0].addresses[0]
    private_key = file("~/.ssh/id_rsa")
  }
  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait"
    ]
  }  
  network_interface {
    network_name = "default"
    wait_for_lease = true    
  }
  console {
    type = "pty"
    target_port = "0"
    target_type = "serial"
  }
  console {
    type = "pty"
    target_type = "virtio"
    target_port = "1"
  }
  disk {
    volume_id = element(libvirt_volume.os_volume.*.id, count.index+1)
  }
  graphics {
    type = "spice"
    listen_type = "address"
    autoport = true
  }
}
# Worker Cloud Config
resource "libvirt_cloudinit_disk" "worker_cloudinit" {
  count = var.worker_count

  name = "worker_cloudinit_${count.index}.iso"
  pool = "default"
  user_data = <<EOF
#cloud-config
disable_root: 0
ssh_pwauth: 1
users:
  - name: root
    ssh-authorized-keys:
      - ${file("~/.ssh/id_rsa.pub")}
  - name: ${var.username}
    ssh-authorized-keys:
      - ${file("~/.ssh/id_rsa.pub")}
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo
    shell: '/bin/bash'
    plain_text_passwd: '${random_string.password.result}'
    lock_passwd: false       
growpart:
  mode: auto
  devices: ['/']
package_update: true
package_upgrade: true
packages:
  # Update the apt package index and install packages needed to use the Docker and Kubernetes apt repositories over HTTPS
  - apt-transport-https
  - ca-certificates
  - curl
  - gnupg
  - lsb-release
hostname: k8sworker${count.index}
fqdn: k8sworker${count.index}.${var.dns_domain}
preserve_hostname: true
write_files:
# https://stackoverflow.com/questions/52119985/kubeadm-init-shows-kubelet-isnt-running-or-healthy
- content: |
    {
        "exec-opts": ["native.cgroupdriver=systemd"]
    }
  path: /etc/docker/daemon.json
  owner: root:root
runcmd:
 - hostnamectl set-hostname k8sworker${count.index}
 - curl  -fsSL https://dl.k8s.io/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-archive-keyring.gpg
 - echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" >/etc/apt/sources.list.d/kubernetes.list
 - apt-get update -y # Update apt package index
#  - apt-get install -y docker.io kubelet kubeadm kubectl
#  - | 
#   kubeadm join ${local.controller_ip}:6443 \
#   --token ${local.token} \
#   --discovery-token-unsafe-skip-ca-verification \
#   --node-name k8s-worker-${count.index} 
EOF
}
######### End: Workers #########

#------------------------------------------------------------------------------#
# Random system password
#------------------------------------------------------------------------------#

resource "random_string" "password" {
  length           = 16
  special          = false
}

#------------------------------------------------------------------------------#
# Bootstrap token for kubeadm
#------------------------------------------------------------------------------#

# Generate bootstrap token
# See https://kubernetes.io/docs/reference/access-authn-authz/bootstrap-tokens/
resource "random_string" "token_id" {
  length  = 6
  special = false
  upper   = false
}

resource "random_string" "token_secret" {
  length  = 16
  special = false
  upper   = false
}

#------------------------------------------------------------------------------#
# Download kubeconfig file from master node to local machine
#------------------------------------------------------------------------------#

# resource "null_resource" "download_kubeconfig_file" {
#   depends_on = [libvirt_domain.kubernetes_controller]
#   provisioner "local-exec" {
#     command = <<-EOF
#     alias scp='scp -q -i ${var.private_key_file} -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
#     scp root@${local.controller_ip}:/etc/kubernetes/admin.conf  ${var.kubeconfig_file} >/dev/null
#     EOF
#   }
#   triggers = {
#     controller_id = libvirt_domain.kubernetes_controller.id
#   }
# }

#------------------------------------------------------------------------------#
# locals / outputs
#------------------------------------------------------------------------------#
locals {
  token = "${random_string.token_id.result}.${random_string.token_secret.result}"
  controller_ip = libvirt_domain.kubernetes_controller.network_interface[0].addresses[0]
  worker_ips = libvirt_domain.kubernetes_workers[*].network_interface[0].addresses[0]
}

output "controller_ip" {
  value = local.controller_ip
}

output "worker_ips" {
  value       = local.worker_ips
}

output "password" {
  value = random_string.password.result
}