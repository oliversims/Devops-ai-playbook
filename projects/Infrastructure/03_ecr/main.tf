# Docker image repositories for each microservice.
# CI pushes images here; EKS nodes pull from these repos.

# One private registry per service name (frontend, gateway, auth, etc.).
resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repositories)

  name         = each.value
  force_delete = true

  image_scanning_configuration {
    scan_on_push = true
  }

  image_tag_mutability = "MUTABLE"
}
