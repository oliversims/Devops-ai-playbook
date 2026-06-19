# Exported to 05_argocd via S3 remote state (key: 04_eks/terraform.tfstate).

output "cluster_name" {
  value = aws_eks_cluster.eks.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.eks.endpoint
}

# output "cluster_certificate_authority_data" {
#   value = aws_eks_cluster.eks.certificate_authority[0].data
# }

output "configure_kubectl" {
  description = "Run this to point kubectl at the new EKS cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${aws_eks_cluster.eks.name}"
}
