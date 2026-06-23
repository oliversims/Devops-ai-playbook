# One private ECR repository per microservice. CI pushes images; EKS nodes pull them.

resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repositories)

  name         = each.value
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"
}
