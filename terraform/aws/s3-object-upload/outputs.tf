output "bucket_name" {
  description = "object をアップロードした S3 bucket の名前。"
  value       = aws_s3_object.hello.bucket
}

output "content_type" {
  description = "アップロードした object に設定した Content-Type。"
  value       = aws_s3_object.hello.content_type
}

output "etag" {
  description = "アップロードした object の ETag。単一 part upload では通常、object 内容の MD5 ハッシュとして確認に使えます。"
  value       = aws_s3_object.hello.etag
}

output "object_key" {
  description = "bucket 内に作成した object key。S3 上の object の path のように扱われる名前です。"
  value       = aws_s3_object.hello.key
}

output "object_url" {
  description = "アップロードした object の s3:// URL。"
  value       = "s3://${aws_s3_object.hello.bucket}/${aws_s3_object.hello.key}"
}
