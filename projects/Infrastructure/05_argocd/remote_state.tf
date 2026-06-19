# Reads cluster API details from the 04_eks stack in S3 (apply 04_eks before this stack).

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "04_eks/terraform.tfstate"
    region = var.region
  }
}

# VPC outputs — ACM cert, Route 53 zone, and VPC ID for the load balancer controller.
data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "02_vpc/terraform.tfstate"
    region = var.region
  }
}
