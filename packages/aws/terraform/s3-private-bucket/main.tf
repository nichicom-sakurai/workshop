# Data sources:
# 現在 Terraform が使っている AWS account と region を読み取り、
# 学習用 bucket 名と output に利用します。
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# S3 bucket:
# private bucket を1つ作成し、resource lifecycle（plan / apply / state / destroy）を学びます。
resource "aws_s3_bucket" "this" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = var.tags
}

# Public access block:
# 4つの public access block 設定をすべて true にし、bucket policy や ACL が公開設定へ
# 変わっても public access を制限できるようにします。ACL は Access Control List の略で、
# S3 bucket / object 単位の古いアクセス許可設定です。
resource "aws_s3_bucket_public_access_block" "this" {
  bucket = aws_s3_bucket.this.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
