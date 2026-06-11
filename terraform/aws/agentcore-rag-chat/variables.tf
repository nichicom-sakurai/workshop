variable "artifact_zip_path" {
  description = "AgentCore Runtime の direct code deployment ZIP artifact への、この root module ディレクトリからの相対 path (main.tf で path.module 起点に解決します)。plan / apply の前に apps/agentcore-rag-chat/scripts/package.sh で作成してください。"
  type        = string

  validation {
    condition     = can(regex("\\.zip$", var.artifact_zip_path))
    error_message = "artifact_zip_path は .zip で終わる path を指定してください。"
  }
}

variable "model_id" {
  description = "supervisor / 専門 agent が使う Amazon Bedrock generation model ID。ローカルの terraform.tfvars に設定し、実際の値は commit しないでください。"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.model_id)) > 0
    error_message = "model_id は空にできません。"
  }
}

variable "embedding_model_id" {
  description = "Knowledge Base の埋め込みに使う Amazon Bedrock embedding model ID。embedding_dimensions と整合する model を指定してください。"
  type        = string
  default     = "amazon.titan-embed-text-v2:0"

  validation {
    condition     = length(trimspace(var.embedding_model_id)) > 0
    error_message = "embedding_model_id は空にできません。"
  }
}

variable "embedding_dimensions" {
  description = "埋め込みベクトルの次元数。Knowledge Base 側と S3 Vectors index 側で一致させます。embedding_model_id が対応する値にしてください（titan-embed-text-v2 は 256 / 512 / 1024）。"
  type        = number
  default     = 1024

  validation {
    condition     = var.embedding_dimensions > 0 && var.embedding_dimensions <= 4096
    error_message = "embedding_dimensions は 1〜4096 の範囲で指定してください（S3 Vectors の上限）。"
  }
}

variable "name_prefix" {
  description = "AgentCore / Knowledge Base / S3 / IAM の名前に使う小文字の prefix。長くすると S3 bucket 名が 63 文字上限に近づく点に注意してください。"
  type        = string
  default     = "agentcore-rag"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix は 3〜32文字の小文字・数字・ハイフンで構成し、英小文字で始まり、末尾をハイフンにできません。"
  }
}

variable "bedrock_model_resource_arns" {
  description = "runtime role が invoke できる generation model の resource ARN (Amazon Resource Name)。default の wildcard は学習サンプルの portability のためで、production では絞り込んでください。"
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.bedrock_model_resource_arns) > 0
    error_message = "bedrock_model_resource_arns は 1件以上指定してください。"
  }
}

variable "event_expiry_duration" {
  description = "AgentCore Memory が会話 event (short-term) を保持する日数 (7〜365)。"
  type        = number
  default     = 30

  validation {
    condition     = var.event_expiry_duration >= 7 && var.event_expiry_duration <= 365
    error_message = "event_expiry_duration は 7〜365 の範囲で指定してください。"
  }
}

variable "tags" {
  description = "この学習サンプルが作成するリソースに付与する tag。"
  type        = map(string)
  default = {
    Project   = "workshop"
    Purpose   = "terraform-learning"
    ManagedBy = "terraform"
  }
}
