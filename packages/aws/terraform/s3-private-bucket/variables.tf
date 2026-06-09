variable "bucket_prefix" {
  description = "S3 bucket name prefix. The final name is '<bucket_prefix>-<account_id>-<region>'. Use lowercase letters, numbers, and hyphens only."
  type        = string
  default     = "nck-sakurai-tf-learn"

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,33}[a-z0-9]$", var.bucket_prefix))
    error_message = "bucket_prefix は 3〜35文字の小文字・数字・ハイフンで構成し、先頭と末尾をハイフンにできません。"
  }
}

variable "tags" {
  description = "Tags applied to the learning S3 bucket."
  type        = map(string)
  default = {
    Project   = "workshop"
    Purpose   = "terraform-learning"
    ManagedBy = "terraform"
  }
}
