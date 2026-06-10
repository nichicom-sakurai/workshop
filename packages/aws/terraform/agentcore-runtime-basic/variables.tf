variable "artifact_zip_path" {
  description = "AgentCore Runtime の direct code deployment ZIP artifact への、この root module ディレクトリからの相対 path (main.tf で path.module 起点に解決します)。plan / apply の前に packages/aws/apps/agentcore-strands-basic/scripts/package.sh で作成してください。"
  type        = string

  validation {
    condition     = can(regex("\\.zip$", var.artifact_zip_path))
    error_message = "artifact_zip_path は .zip で終わる path を指定してください。"
  }
}

variable "model_id" {
  description = "Strands agent が使う Amazon Bedrock model ID。ローカルの terraform.tfvars に設定し、実際の値は commit しないでください。"
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.model_id)) > 0
    error_message = "model_id は空にできません。"
  }
}

variable "name_prefix" {
  description = "AgentCore Runtime / IAM / S3 の名前に使う小文字の prefix。"
  type        = string
  default     = "agentcore-basic"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix は 3〜32文字の小文字・数字・ハイフンで構成し、英小文字で始まり、末尾をハイフンにできません。"
  }
}

variable "bedrock_model_resource_arns" {
  description = "runtime role が invoke できる Bedrock model resource ARN (Amazon Resource Name)。default の wildcard は学習サンプルの portability のためで、production では絞り込んでください。"
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.bedrock_model_resource_arns) > 0
    error_message = "bedrock_model_resource_arns は 1件以上指定してください。"
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
