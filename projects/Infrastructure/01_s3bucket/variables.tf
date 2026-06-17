# Variables for the state bucket.
# Values are set in terraform.tfvars.

variable "environment_name" {
  description = "Deployment environment (e.g., dev, staging, prod)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
}
