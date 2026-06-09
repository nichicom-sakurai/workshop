# Bucket 名:
# S3 の一般用途 bucket 名は S3 全体で一意である必要があります。
# この学習サンプルでは、読みやすい prefix に現在の account ID と region を組み合わせ、
# 名前衝突を減らしつつ、どの環境で作られる bucket か分かりやすくします。
locals {
  bucket_name = "${var.bucket_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
}
