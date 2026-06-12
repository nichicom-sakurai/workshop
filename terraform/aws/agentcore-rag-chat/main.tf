# Data sources:
# 現在 Terraform が使っている AWS account と region を読み取り、bucket 名・ARN・
# runtime 環境変数の組み立てに利用します。
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# --- AgentCore Runtime artifact (ZIP) ---

# direct code deployment ZIP を置く private bucket。
resource "aws_s3_bucket" "artifact" {
  bucket        = local.artifact_bucket_name
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ZIP artifact を upload し、内容変更時は hash で差分検出する。
resource "aws_s3_object" "artifact" {
  bucket = aws_s3_bucket.artifact.id
  key    = local.artifact_key
  source = local.artifact_zip_file

  content_type = "application/zip"
  etag         = filemd5(local.artifact_zip_file)
  tags         = var.tags
}

# --- AgentCore Memory (short-term) ---

# 会話 event（user + assistant のターン）を session / actor 単位で保持する。
# long-term strategy は使わず raw event のみ（event_expiry_duration 日で失効）。
resource "aws_bedrockagentcore_memory" "this" {
  name                  = local.memory_name
  description           = "Short-term conversation memory for the workshop RAG chat sample."
  event_expiry_duration = var.event_expiry_duration
  tags                  = var.tags
}

# --- AgentCore Runtime ---

# direct code deployment ZIP を S3 から読み込み、Python 3.13 runtime で main.py を起動する。
# 環境変数で generation model ID・3 つの KB ID・Memory ID を渡す。
resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = local.runtime_name
  description        = "Workshop AgentCore RAG chat: supervisor + 3 specialist RAG agents."
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

# Terraform 管理の custom endpoint を 1 つ作り、endpoint lifecycle も学習対象にする。
resource "aws_bedrockagentcore_agent_runtime_endpoint" "sample" {
  name             = local.endpoint_name
  agent_runtime_id = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
  description      = "Sample endpoint for the workshop RAG chat runtime."
  tags             = var.tags
}
