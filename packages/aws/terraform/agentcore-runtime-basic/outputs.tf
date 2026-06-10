output "artifact_bucket_name" {
  description = "AgentCore Runtime direct code deployment ZIP を upload する S3 bucket 名。"
  value       = aws_s3_bucket.artifact.bucket
}

output "artifact_object_key" {
  description = "AgentCore Runtime direct code deployment ZIP の S3 object key。"
  value       = aws_s3_object.artifact.key
}

output "region" {
  description = "この Terraform 実行で使用した AWS region。"
  value       = data.aws_region.current.region
}
