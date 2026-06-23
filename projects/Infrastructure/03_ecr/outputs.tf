# Repository URLs used by CI/CD to push images.

output "ecr_urls" {
  description = "Map of service name → ECR repository URL"
  value = {
    for repo in aws_ecr_repository.repos :
    repo.name => repo.repository_url
  }
}
