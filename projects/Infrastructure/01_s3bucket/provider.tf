# =============================================================================
# 01_s3bucket — Terraform remote state backend (bootstrap stack)
# =============================================================================
# Apply FIRST with local state. Copy tfstate_bucket_id into other stacks' provider.tf.

terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
