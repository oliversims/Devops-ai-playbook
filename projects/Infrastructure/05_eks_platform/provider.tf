# =============================================================================
# 05_argocd — platform services on EKS
# =============================================================================
# ALB controller, external-dns, ArgoCD, kube-prometheus-stack, Fluent Bit.
# Remote state: reads 02_vpc and 04_eks.
# Apply order: 01_s3bucket → 02_vpc → 04_eks → 05_argocd
#
# HTTPS Ingress manifests are in gitops/ (not managed here).

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    helm = {
      source = "hashicorp/helm"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  backend "s3" {
    bucket       = "tfstate-dev-us-east-1-602rfk"
    key          = "05_argocd/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}

# Authenticates to EKS using AWS CLI (requires: aws eks update-kubeconfig).
provider "kubernetes" {
  host = data.terraform_remote_state.eks.outputs.cluster_endpoint

  cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
  } 
}

provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name]
    }
  }
}
