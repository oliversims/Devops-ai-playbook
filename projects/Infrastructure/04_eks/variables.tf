# Input variables for the EKS stack.
# Values are set in terraform.tfvars.

variable "region" {
  description = "AWS region where the cluster is created"
  type        = string
}

variable "tfstate_bucket" {
  description = "S3 bucket for Terraform state (must match provider.tf backend bucket)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster (must match 02_vpc cluster_name)"
  type        = string
}

variable "node_group_name" {
  type        = string
  description = "Name of the managed node group"
}

variable "instance_types" {
  type        = list(string)
  description = "EC2 instance types for worker nodes"
}

variable "capacity_type" {
  type        = string
  description = "ON_DEMAND or SPOT"
}

variable "desired_size" {
  type        = number
  description = "Target number of worker nodes"
}

variable "min_size" {
  type        = number
  description = "Minimum number of worker nodes"
}

variable "max_size" {
  type        = number
  description = "Maximum number of worker nodes"
}

variable "disk_size" {
  type        = number
  description = "Root volume size (GiB) on each worker node"
}
