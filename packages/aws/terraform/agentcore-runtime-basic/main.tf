# Data sources:
# 現在 Terraform が使っている AWS account と region を読み取り、
# S3 bucket 名、AgentCore Runtime 名、runtime 環境変数に利用します。
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  artifact_bucket_name = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  artifact_key         = "agentcore-runtime/${filesha256(var.artifact_zip_path)}.zip"
  runtime_env = {
    AWS_DEFAULT_REGION = data.aws_region.current.region
    BEDROCK_MODEL_ID   = var.model_id
  }
  runtime_name = replace(var.name_prefix, "-", "_")
}

# S3 bucket:
# AgentCore Runtime direct code deployment ZIP を置く private bucket を作成します。
resource "aws_s3_bucket" "artifact" {
  bucket        = local.artifact_bucket_name
  force_destroy = false
  tags          = var.tags
}

# Public access block:
# artifact bucket は runtime code package の置き場なので public access を許可しません。
resource "aws_s3_bucket_public_access_block" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 object:
# 明示的に作成した ZIP artifact を upload し、内容変更時は hash によって差分検出します。
resource "aws_s3_object" "artifact" {
  bucket = aws_s3_bucket.artifact.id
  key    = local.artifact_key
  source = var.artifact_zip_path

  content_type = "application/zip"
  etag         = filemd5(var.artifact_zip_path)
  tags         = var.tags
}
