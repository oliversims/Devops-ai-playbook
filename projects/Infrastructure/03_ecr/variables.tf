# Input variables for the ECR stack.
# Values are set in terraform.tfvars.

variable "region" {
  description = "AWS region where repositories are created"
  type        = string
}

variable "repositories" {
  description = "One ECR repository is created per service name in this list"
  type        = list(string)
}
