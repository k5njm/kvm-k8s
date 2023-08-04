variable "username" {
  description = "Username to add to the VMs"
  type        = string
}

variable "dns_domain" {
  description = "DNS domain name"
  type        = string
}

variable "deploy_workloads" {
  description = "Deployment of workloads module: true/false"
  type        = bool
}

variable "kubeconfig_file" {
  description = "Deployment of workloads module: true/false"
  type        = string
  default     = "kubeconfig"
}
