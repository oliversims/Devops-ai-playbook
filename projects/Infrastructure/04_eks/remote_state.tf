# Reads VPC outputs from the 02_vpc stack (subnet_ids for the cluster and node group).

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "02_vpc/terraform.tfstate"
    region = var.region
  }
}
