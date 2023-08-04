terraform {
  required_providers {
    libvirt = {
      source = "dmacvicar/libvirt"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.4.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

provider "kubernetes" {
  config_path = var.kubeconfig_file
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_file
  }
}


