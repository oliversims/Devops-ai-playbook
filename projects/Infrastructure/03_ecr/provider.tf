# =============================================================================
# 03_ecr — container image repositories
# =============================================================================
# Independent of VPC/EKS. Can apply in parallel with 02_vpc or 04_eks.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "tfstate-dev-us-east-1-602rfk"
    key          = "03_ecr/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}
