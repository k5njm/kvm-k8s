variable "dns_domain" {
  description = "DNS domain name"
  type        = string
}

variable "worker_count" {
  description = "number of virtual-machine of same type that will be created"
  type        = number
  default     = 3
}

variable "memory" {
  description = "The amount of RAM (MB) for a node"
  type        = number
  default     = 2048
}

variable "vcpu" {
  description = "The amount of virtual CPUs for a node"
  type        = number
  default     = 2
}

variable "private_key_file" {
  description = "Path to SSH private key file"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "kubeconfig_file" {
  description = "Path to SSH private key file"
  type        = string
  default     = "./kubeconfig"
}

variable "username" {
  description = "Username to add to the VMs"
  type        = string
}
