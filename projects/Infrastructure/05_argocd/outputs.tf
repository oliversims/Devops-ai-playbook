data "kubernetes_secret_v1" "argocd_admin" {
  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = kubernetes_namespace_v1.argocd.metadata[0].name
  }

  depends_on = [helm_release.argocd]
}

data "kubernetes_secret_v1" "grafana" {
  metadata {
    name      = "kube-prometheus-stack-grafana"
    namespace = kubernetes_namespace_v1.monitoring.metadata[0].name
  }

  depends_on = [helm_release.monitoring]
}


output "argocd_username" {
  description = "ArgoCD login user"
  value       = "admin"
}

output "argocd_password" {
  description = "Run: terraform output -raw argocd_password"
  value       = data.kubernetes_secret_v1.argocd_admin.data["password"]
  sensitive   = true
}

output "grafana_username" {
  description = "Grafana login user"
  value       = "admin"
}

output "grafana_password" {
  description = "Run: terraform output -raw grafana_password"
  value       = data.kubernetes_secret_v1.grafana.data["admin-password"]
  sensitive   = true
}
output "domain_name" {
  description = "Base domain — use subdomains for Ingress hosts (e.g. grafana.<domain>)"
  value       = data.terraform_remote_state.vpc.outputs.domain_name
}

output "acm_certificate_arn" {
  description = "Wildcard ACM cert ARN — use on Ingress: alb.ingress.kubernetes.io/certificate-arn"
  value       = data.terraform_remote_state.vpc.outputs.acm_certificate_arn
}

output "app_url" {
  description = "Boutique app (HTTPS) — after gitops/ingress is synced"
  value       = "https://app.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

output "grafana_url" {
  description = "Grafana UI (HTTPS)"
  value       = "https://graf.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

output "argocd_url" {
  description = "ArgoCD UI (HTTPS)"
  value       = "https://argo.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

output "prometheus_url" {
  description = "Prometheus UI (HTTPS)"
  value       = "https://pro.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

