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
  description = "Name of the managed node group"
  type        = string
}

variable "instance_types" {
  description = "EC2 instance types for worker nodes"
  type        = list(string)
}

variable "capacity_type" {
  description = "ON_DEMAND or SPOT"
  type        = string
}

variable "desired_size" {
  description = "Target number of worker nodes"
  type        = number
}

variable "min_size" {
  description = "Minimum number of worker nodes (cluster autoscaler floor)"
  type        = number
}

variable "max_size" {
  description = "Maximum number of worker nodes (cluster autoscaler ceiling)"
  type        = number
}

variable "disk_size" {
  description = "Root volume size (GiB) on each worker node"
  type        = number
}
