# =============================================================================
# 04_eks — EKS cluster, worker nodes, EBS CSI
# =============================================================================
# Remote state: reads subnet IDs from 02_vpc.
# Apply order: 01_s3bucket → 02_vpc → 04_eks

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket       = "tfstate-dev-us-east-1-602rfk"
    key          = "04_eks/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}
