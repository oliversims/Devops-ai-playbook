# Repository URLs used by CI/CD to push images and by deploy configs.

# Map of service name → ECR repository URL (one entry per repository).
output "ecr_urls" {
  value = {
    for repo in aws_ecr_repository.repos :
    repo.name => repo.repository_url
  }
}
