# Credentials and URLs — use after apply and gitops/ingress deploy.

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
  description = "Base domain — subdomains used by gitops/ingress (argo, graf, pro, app)"
  value       = data.terraform_remote_state.vpc.outputs.domain_name
}

output "acm_certificate_arn" {
  description = "Wildcard ACM cert ARN — copy to gitops/ingress/ingress.env"
  value       = data.terraform_remote_state.vpc.outputs.acm_certificate_arn
}

output "app_url" {
  description = "Boutique app (HTTPS) — after deploy-argo-cd.ps1 applies boutique-ingress"
  value       = "https://app.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

output "grafana_url" {
  description = "Grafana UI (HTTPS) — after kubectl apply -k gitops/ingress"
  value       = "https://graf.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

output "argocd_url" {
  description = "ArgoCD UI (HTTPS) — after kubectl apply -k gitops/ingress"
  value       = "https://argo.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

output "prometheus_url" {
  description = "Prometheus UI (HTTPS) — after kubectl apply -k gitops/01_ingress"
  value       = "https://pro.${data.terraform_remote_state.vpc.outputs.domain_name}"
}

output "fluent_bit_log_group" {
  description = "CloudWatch log group for boutique pod logs — used by aiops-assistant fetch_logs"
  value       = aws_cloudwatch_log_group.fluent_bit.name
}
