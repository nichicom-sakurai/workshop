# Provider requirements:
# Terraform は remote system とやりとりするために provider plugin を使います。
# この block では、この module が必要とする Terraform 本体と provider を宣言します。
# `required_providers` では、provider の local name、source address、version constraint を指定します。
# 参照元: https://developer.hashicorp.com/terraform/language/providers/requirements
terraform {
  required_version = ">= 1.14.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.49.0"
    }
  }
}
