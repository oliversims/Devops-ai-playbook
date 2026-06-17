locals {
  cluster_name = data.terraform_remote_state.eks.outputs.cluster_name
}

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

output "configure_kubectl" {
  description = "Run: terraform output -raw configure_kubectl | Invoke-Expression"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${local.cluster_name}"
}

output "argocd_port_forward" {
  description = "Run in a separate terminal — UI: http://localhost:8443 (HTTP, not HTTPS)"
  value       = "kubectl port-forward svc/argocd-server 8443:80 -n argocd"
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

output "prometheus_port_forward" {
  description = "Run in a separate terminal — UI: http://localhost:9090"
  value       = "kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring"
}

output "grafana_port_forward" {
  description = "Run in a separate terminal — UI: http://localhost:8080"
  value       = "kubectl port-forward svc/kube-prometheus-stack-grafana 8080:80 -n monitoring"
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
