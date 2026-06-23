# =============================================================================
# Admin credentials — read from Kubernetes secrets after Helm installs
# =============================================================================

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
