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
  runtime_name  = replace(var.name_prefix, "-", "_")
  endpoint_name = "sample"
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

# AgentCore Runtime:
# direct code deployment ZIP を S3 から読み込み、Python 3.13 runtime で main.py を起動します。
resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = local.runtime_name
  description        = "Workshop AgentCore Runtime sample with Strands Agents and Amazon Bedrock."
  role_arn           = aws_iam_role.runtime.arn

  agent_runtime_artifact {
    code_configuration {
      entry_point = ["main.py"]
      runtime     = "PYTHON_3_13"

      code {
        s3 {
          bucket = aws_s3_bucket.artifact.bucket
          prefix = aws_s3_object.artifact.key
        }
      }
    }
  }

  environment_variables = local.runtime_env

  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "HTTP"
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy.runtime,
    aws_s3_bucket_public_access_block.artifact,
    aws_s3_object.artifact,
  ]
}

# AgentCore Runtime Endpoint:
# AgentCore は DEFAULT endpoint も作成しますが、この sample では Terraform 管理の
# custom endpoint を1つ作り、endpoint lifecycle も学習対象にします。
resource "aws_bedrockagentcore_agent_runtime_endpoint" "sample" {
  name             = local.endpoint_name
  agent_runtime_id = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
  description      = "Sample endpoint for the workshop AgentCore Runtime."
  tags             = var.tags
}
