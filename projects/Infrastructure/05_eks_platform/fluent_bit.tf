# =============================================================================
# AWS for Fluent Bit — forward pod logs to CloudWatch
# =============================================================================
# Log group /eks/boutique/pods matches aiops-assistant fetch_logs Lambda default.
# DaemonSet runs on every node; reads /var/log/containers/*.log.

locals {
  fluent_bit_log_group = "/eks/boutique/pods"
}

# Terraform owns the log group so terraform destroy removes it (Fluent Bit only writes to it).
resource "aws_cloudwatch_log_group" "fluent_bit" {
  name = local.fluent_bit_log_group
}

# Permissions for Fluent Bit to create log groups/streams and write events.
data "aws_iam_policy_document" "fluent_bit" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "fluent_bit" {
  name   = "${local.cluster_name}-fluent-bit-cloudwatch"
  policy = data.aws_iam_policy_document.fluent_bit.json
}

# IRSA — only the Fluent Bit service account in amazon-cloudwatch may assume this role.
data "aws_iam_policy_document" "fluent_bit_assume_role" {
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
      values   = ["system:serviceaccount:amazon-cloudwatch:aws-for-fluent-bit"]
    }
  }
}

resource "aws_iam_role" "fluent_bit" {
  name               = "${local.cluster_name}-fluent-bit"
  assume_role_policy = data.aws_iam_policy_document.fluent_bit_assume_role.json
}

resource "aws_iam_role_policy_attachment" "fluent_bit" {
  role       = aws_iam_role.fluent_bit.name
  policy_arn = aws_iam_policy.fluent_bit.arn
}

# Helm chart: DaemonSet + ConfigMap; ships stdout/stderr from all pods to CloudWatch.
resource "helm_release" "fluent_bit" {
  name       = "aws-for-fluent-bit"
  namespace  = kubernetes_namespace_v1.amazon_cloudwatch.metadata[0].name
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-for-fluent-bit"
  version    = "0.2.0"

  values = [
    yamlencode({
      cloudWatch = {
        enabled = false
      }

      cloudWatchLogs = {
        enabled         = true
        region          = var.region
        logGroupName    = aws_cloudwatch_log_group.fluent_bit.name
        logStreamPrefix = "from-fluent-bit-"
        autoCreateGroup = false
      }

      firehose = {
        enabled = false
      }

      kinesis = {
        enabled = false
      }

      elasticsearch = {
        enabled = false
      }

      serviceAccount = {
        create = true
        name   = "aws-for-fluent-bit"
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.fluent_bit.arn
        }
      }
    })
  ]

  depends_on = [
    aws_cloudwatch_log_group.fluent_bit,
    aws_iam_role_policy_attachment.fluent_bit,
    kubernetes_namespace_v1.amazon_cloudwatch,
    data.terraform_remote_state.eks,
  ]
}
