resource "aws_s3_object" "hello" {
  # bucket は意図的に変数で受け取ります。s3-private-bucket で作成した
  # bucket 名を渡し、この sample では object だけを管理するためです。
  bucket = var.bucket_name
  key    = var.object_key
  source = "${path.module}/objects/hello.txt"

  content_type  = "text/plain; charset=utf-8"
  cache_control = "private, max-age=0"
  etag          = filemd5("${path.module}/objects/hello.txt")
  tags          = var.tags
}
