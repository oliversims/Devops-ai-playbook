# =============================================================================
# Shared data sources and locals
# =============================================================================

# Route 53 hosted zone from 02_vpc — external-dns needs the zone ARN to manage DNS records.
data "aws_route53_zone" "main" {
  name = data.terraform_remote_state.vpc.outputs.domain_name
}

# Live EKS cluster from AWS — provides the OIDC issuer URL for IRSA trust policies.
data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

# IAM OIDC provider for this cluster (from 04_eks) — ALB controller and external-dns roles trust this ARN.
data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Short names reused across this stack: cluster name, OIDC issuer (no https://), Route 53 zone ARN.
locals {
  cluster_name          = data.terraform_remote_state.eks.outputs.cluster_name
  oidc_issuer           = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
  external_dns_zone_arn = data.aws_route53_zone.main.arn
}
