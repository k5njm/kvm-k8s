
terraform {
  required_providers {
    helm = {
      source = "hashicorp/helm"
      version = "2.4.1"
    }
  }
}

provider "kubernetes" {
  config_path = var.kubeconfig_file
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_file
  }
}

resource "kubernetes_namespace" "homelab" {
  metadata {
    name = "homelab"
  }
}

resource "helm_release" "lychee" {
  name       = "lychee"
  depends_on = [kubernetes_namespace.homelab]
  repository = "https://k8s-at-home.com/charts/"
  chart      = "lychee"
  namespace  = kubernetes_namespace.homelab.metadata.0.name
  
  # set = {
  #   name = "replicaCount"
  #   value = 2
  #  }
}