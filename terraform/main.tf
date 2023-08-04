module "infrastructure" {
  source          = "./modules/kvm-k8s-cluster"
  worker_count    = 2
  vcpu            = 2
  username        = var.username
  dns_domain      = var.dns_domain
  kubeconfig_file = var.kubeconfig_file
}

module "workloads" {
  count  = var.deploy_workloads ? 1 : 0
  source = "./modules/workloads"
}

output "controller_ip" {
  value       = module.infrastructure.controller_ip
  description = "The private IP address of the Kubernetes Controller."
}

output "worker_ips" {
  value       = module.infrastructure.controller_ip
  description = "The private IP address of the Kubernetes worker nodes."
}

output "vm_password" {
  value       = module.infrastructure.password
  description = "Password for the VMs"
}
