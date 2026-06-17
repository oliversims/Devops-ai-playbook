# VPC stack — remote state in S3 (unique key per stack).
# If you change the backend key/bucket, use: terraform init -migrate-state
# Do NOT use -reconfigure if you want to keep existing state.

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
    key          = "02_vpc/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region
}
