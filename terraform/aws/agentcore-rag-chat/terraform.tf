# Provider requirements:
# この module が必要とする Terraform 本体と provider を宣言します。
# 各サンプルは自己完結のため、agentcore-runtime-basic と同じ provider / version を pin します。
terraform {
  required_version = ">= 1.14.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.49.0"
    }
  }
}
