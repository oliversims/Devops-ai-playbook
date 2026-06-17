# Outputs — use tfstate_bucket_id in provider.tf backend blocks for stacks 02–05.

output "tfstate_bucket_arn" {
  description = "ARN of the Terraform remote state S3 bucket"
  value       = aws_s3_bucket.tfstate_bucket.arn
}

output "tfstate_bucket_id" {
  description = "Bucket name — set in provider.tf backend blocks for stacks 02–05"
  value       = aws_s3_bucket.tfstate_bucket.id
}
