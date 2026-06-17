# Exported to 04_eks via S3 remote state (key: 02_vpc/terraform.tfstate).

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.vpc.id
}

output "subnet_ids" {
  description = "Subnet IDs used by the EKS cluster and node group"
  value       = aws_subnet.subnets[*].id
}
