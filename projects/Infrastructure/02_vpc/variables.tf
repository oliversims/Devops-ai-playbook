# Input variables for the VPC stack.
# Values are set in terraform.tfvars.

variable "region" {
  description = "AWS region where the VPC is created"
  type        = string
}

variable "vpc_name" {
  description = "Name tag for the VPC and related resources"
  type        = string
}

variable "vpc_cidr" {
  description = "IP address range for the entire VPC (e.g. 10.1.0.0/16)"
  type        = string
}

variable "subnets" {
  description = "Public subnets used by EKS nodes and load balancers"
  type = list(object({
    name              = string
    cidr_block        = string
    availability_zone = string
  }))
}

variable "cluster_name" {
  description = "EKS cluster name — used to tag subnets (must match 04_eks cluster_name)"
  type        = string
}

variable "domain_name" {
  description = "Your domain name (e.g. example.com). Used for Route 53 and the ACM wildcard certificate."
  type        = string
}
