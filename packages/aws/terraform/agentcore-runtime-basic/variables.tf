variable "artifact_zip_path" {
  description = "Path to the AgentCore Runtime direct code deployment ZIP artifact. Build it with packages/aws/apps/agentcore-strands-basic/scripts/package.sh before running plan/apply."
  type        = string

  validation {
    condition     = can(regex("\\.zip$", var.artifact_zip_path))
    error_message = "artifact_zip_path は .zip で終わる path を指定してください。"
  }
}

variable "model_id" {
  description = "Amazon Bedrock model ID used by the Strands agent. Set this in local terraform.tfvars; do not commit real values."
  type        = string
  sensitive   = true

  validation {
    condition     = length(trimspace(var.model_id)) > 0
    error_message = "model_id は空にできません。"
  }
}

variable "name_prefix" {
  description = "Lowercase prefix used for AgentCore Runtime, IAM, and S3 names."
  type        = string
  default     = "agentcore-basic"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix は 3〜32文字の小文字・数字・ハイフンで構成し、英小文字で始まり、末尾をハイフンにできません。"
  }
}

variable "bedrock_model_resource_arns" {
  description = "Bedrock model resource ARNs that the runtime role can invoke. The default wildcard keeps the learning sample portable; narrow it for production."
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.bedrock_model_resource_arns) > 0
    error_message = "bedrock_model_resource_arns は 1件以上指定してください。"
  }
}

variable "tags" {
  description = "Tags applied to resources created by this learning sample."
  type        = map(string)
  default = {
    Project   = "workshop"
    Purpose   = "terraform-learning"
    ManagedBy = "terraform"
  }
}
