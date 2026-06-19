# GitOps (ArgoCD), observability, AWS Load Balancer Controller, and external-dns.
# Ingress manifests live in gitops/ingress/ — external-dns creates Route 53 records from them.
# Requires 02_vpc and 04_eks applied first (S3 remote state).
data "aws_route53_zone" "main" {
  name = data.terraform_remote_state.vpc.outputs.domain_name
}

locals {
  cluster_name          = data.terraform_remote_state.eks.outputs.cluster_name
  oidc_issuer           = replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
  external_dns_zone_arn = data.aws_route53_zone.main.arn
}

data "aws_eks_cluster" "this" {
  name = local.cluster_name
}

data "aws_iam_openid_connect_provider" "eks" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

# Official IAM policy for the controller (version matches the Helm chart).
data "http" "alb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.8.2/docs/install/iam_policy.json"

  request_headers = {
    Accept = "application/json"
  }
}

data "aws_iam_policy_document" "alb_controller_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_policy" "alb_controller" {
  name   = "${local.cluster_name}-AWSLoadBalancerControllerIAMPolicy"
  policy = data.http.alb_controller_iam_policy.response_body
}

resource "aws_iam_role" "alb_controller" {
  name               = "${local.cluster_name}-alb-controller"
  assume_role_policy = data.aws_iam_policy_document.alb_controller_assume_role.json
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  role       = aws_iam_role.alb_controller.name
  policy_arn = aws_iam_policy.alb_controller.arn
}

# Watches Ingress resources and provisions ALBs for HTTPS via ACM (from 02_vpc).
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  namespace  = "kube-system"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = "1.8.2"

  values = [
    yamlencode({
      clusterName = local.cluster_name
      region      = var.region
      vpcId       = data.terraform_remote_state.vpc.outputs.vpc_id

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller.arn
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.alb_controller,
    data.terraform_remote_state.eks,
    data.terraform_remote_state.vpc,
  ]
}

# Helm marks the ALB controller ready before its admission webhook has endpoints.
# ArgoCD/monitoring create Services that hit that webhook — wait to avoid race failures.
resource "time_sleep" "wait_for_alb_webhook" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "60s"
}

# Creates Route 53 records from Ingress hostname annotations (gitops/ingress/).
data "aws_iam_policy_document" "external_dns" {
  statement {
    effect = "Allow"
    actions = [
      "route53:ChangeResourceRecordSets",
    ]
    resources = [local.external_dns_zone_arn]
  }

  statement {
    effect = "Allow"
    actions = [
      "route53:ListHostedZones",
      "route53:ListResourceRecordSets",
      "route53:ListTagsForResource",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "external_dns" {
  name   = "${local.cluster_name}-external-dns"
  policy = data.aws_iam_policy_document.external_dns.json
}

data "aws_iam_policy_document" "external_dns_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    effect  = "Allow"

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.eks.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer}:sub"
      values   = ["system:serviceaccount:kube-system:external-dns"]
    }
  }
}

resource "aws_iam_role" "external_dns" {
  name               = "${local.cluster_name}-external-dns"
  assume_role_policy = data.aws_iam_policy_document.external_dns_assume_role.json
}

resource "aws_iam_role_policy_attachment" "external_dns" {
  role       = aws_iam_role.external_dns.name
  policy_arn = aws_iam_policy.external_dns.arn
}

resource "helm_release" "external_dns" {
  name       = "external-dns"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/external-dns/"
  chart      = "external-dns"
  version    = "1.15.0"

  values = [
    yamlencode({
      provider = {
        name = "aws"
      }
      policy       = "sync"
      txtOwnerId   = local.cluster_name
      domainFilters = [
        data.terraform_remote_state.vpc.outputs.domain_name,
      ]
      serviceAccount = {
        create = true
        name   = "external-dns"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.external_dns.arn
        }
      }
    })
  ]

  depends_on = [
    aws_iam_role_policy_attachment.external_dns,
    time_sleep.wait_for_alb_webhook,
    data.terraform_remote_state.vpc,
  ]
}

# Isolated namespace for all ArgoCD components.
resource "kubernetes_namespace_v1" "argocd" {
  metadata {
    name = "argocd"
  }
}

# Isolated namespace for Prometheus, Grafana, and Alertmanager.
resource "kubernetes_namespace_v1" "monitoring" {
  metadata {
    name = "monitoring"
  }
}

# Installs ArgoCD — watches Git and syncs manifests to the cluster.
resource "helm_release" "argocd" {
  name       = "argocd"
  namespace  = kubernetes_namespace_v1.argocd.metadata[0].name
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "6.7.0"

  create_namespace = false

  values = [
    yamlencode({
      server = {
        service = {
          type = "ClusterIP"
        }
      }
      configs = {
        params = {
          "server.insecure" = true
        }
      }
    })
  ]

  depends_on = [
    time_sleep.wait_for_alb_webhook,
    kubernetes_namespace_v1.argocd,
  ]
}

# Installs Prometheus, Grafana, and Alertmanager for cluster monitoring.
resource "helm_release" "monitoring" {
  name       = "kube-prometheus-stack"
  namespace  = kubernetes_namespace_v1.monitoring.metadata[0].name

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
