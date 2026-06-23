# =============================================================================
# kube-prometheus-stack — Prometheus, Grafana, Alertmanager
# =============================================================================

resource "helm_release" "monitoring" {
  name      = "kube-prometheus-stack"
  namespace = kubernetes_namespace_v1.monitoring.metadata[0].name

  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "56.21.0"

  timeout          = 600
  create_namespace = false

  values = [
    yamlencode({
      grafana = {
        service = {
          type = "ClusterIP"
        }
        "grafana.ini" = {
          server = {
            root_url = "https://graf.${data.terraform_remote_state.vpc.outputs.domain_name}/"
          }
        }
      }

      prometheus = {
        service = {
          type = "ClusterIP"
        }
      }

      alertmanager = {
        service = {
          type = "ClusterIP"
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_alb_webhook,
    kubernetes_namespace_v1.monitoring,
  ]
}
