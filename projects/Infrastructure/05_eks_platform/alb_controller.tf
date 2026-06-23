# =============================================================================
# AWS Load Balancer Controller — provisions ALBs from Kubernetes Ingress resources
# =============================================================================
# Ingress manifests live in gitops/ingress/ and gitops/boutique-ingress/ (not Terraform).

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

# Helm marks the controller ready before its admission webhook has endpoints.
# Wait before installing ArgoCD/monitoring to avoid webhook race failures.
resource "time_sleep" "wait_for_alb_webhook" {
  depends_on      = [helm_release.aws_load_balancer_controller]
  create_duration = "60s"
}
