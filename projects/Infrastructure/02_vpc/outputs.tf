# Exported to 04_eks and 05_argocd via S3 remote state (key: 02_vpc/terraform.tfstate).

output "vpc_id" {
  description = "VPC ID — used by the AWS Load Balancer Controller in 05_argocd"
  value       = aws_vpc.vpc.id
}

output "subnet_ids" {
  description = "Public subnet IDs — used by the EKS cluster and node group in 04_eks"
  value       = aws_subnet.subnets[*].id
}

output "domain_name" {
  description = "Base domain for Route 53 and Ingress hostnames"
  value       = var.domain_name
}

output "acm_certificate_arn" {
  description = "Issued ACM certificate ARN (root + wildcard) — copy to gitops/ingress/ingress.env"
  value       = aws_acm_certificate_validation.main.certificate_arn
}
