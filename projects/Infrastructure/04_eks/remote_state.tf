# Reads subnet IDs from the 02_vpc stack in S3 (apply 02_vpc before this stack).

data "terraform_remote_state" "vpc" {
  backend = "s3"

  config = {
    bucket = var.tfstate_bucket
    key    = "02_vpc/terraform.tfstate"
    region = var.region
  }
}
