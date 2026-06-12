# --- Knowledge Base data source (S3) ---
# 3 ドメイン分のサンプル文書を 1 つの bucket に prefix 分けで置きます
# （aws-service/ · database/ · document/）。各 Knowledge Base の data source は
# inclusion_prefixes で自分のドメインの prefix だけを取り込みます（knowledge-bases.tf）。

resource "aws_s3_bucket" "data" {
  bucket = local.data_bucket_name
  # 学習サンプルなので destroy 時に中身ごと消せるようにする（取り込み済みのサンプル文書のみ）。
  force_destroy = true
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket = aws_s3_bucket.data.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# data/ 配下のサンプル文書をすべて upload する。key は data/ からの相対 path となり、
# 先頭が aws-service/ · database/ · document/ のいずれかになる（= ドメインの prefix）。
resource "aws_s3_object" "data" {
  for_each = fileset("${path.module}/data", "**/*")

  bucket = aws_s3_bucket.data.id
  key    = each.value
  source = "${path.module}/data/${each.value}"
  etag   = filemd5("${path.module}/data/${each.value}")
  tags   = var.tags
}
