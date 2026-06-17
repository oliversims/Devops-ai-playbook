# Input variables for the ArgoCD stack.
# Values are set in terraform.tfvars.

variable "region" {
  description = "AWS region (used by remote state and EKS authentication)"
  type        = string
}

variable "tfstate_bucket" {
  description = "S3 bucket for Terraform state (must match provider.tf backend bucket)"
  type        = string
}
