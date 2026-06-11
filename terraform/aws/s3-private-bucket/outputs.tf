output "bucket_name" {
  description = "作成した S3 bucket の名前。S3 全体で一意な bucket 名です。"
  value       = aws_s3_bucket.this.bucket
}

output "bucket_arn" {
  description = "作成した S3 bucket の ARN。ARN は Amazon Resource Name の略で、AWS 内のリソースを一意に参照する識別子です。"
  value       = aws_s3_bucket.this.arn
}

output "region" {
  description = "この Terraform 実行で使用した AWS region。"
  value       = data.aws_region.current.region
}
