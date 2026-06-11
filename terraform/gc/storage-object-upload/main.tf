resource "google_storage_bucket_object" "hello" {
  # bucket は意図的に変数で受け取ります。storage-bucket-basic で作成した
  # bucket 名を渡し、この sample では object だけを管理するためです。
  bucket = var.bucket_name
  name   = var.object_name
  source = "${path.module}/objects/hello.txt"

  content_type  = "text/plain; charset=utf-8"
  cache_control = "private, max-age=0"

  # DELETE を明示し、terraform destroy で object を削除します。bucket 自体は
  # この sample の管理対象ではないため削除しません。
  deletion_policy = "DELETE"
}
