resource "google_storage_bucket" "learning" {
  # project は意図的に省略しています。provider の `project`（"nck-sakurai"）を
  # 継承させ、プロジェクトの指定を1か所だけに保つためです。
  name     = var.bucket_name
  location = var.location

  # 学習用 bucket の private-by-default 設定:
  # - uniform_bucket_level_access は per-object ACL を無効化し、IAM のみでアクセス制御します。
  # - public_access_prevention = "enforced" は公開アクセスを一切ブロックします。
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # force_destroy = false（provider の default を明示）は、bucket 内にオブジェクトが
  # 残っていると `terraform destroy` を失敗させます。最初の bucket サンプルはオブジェクトを
  # 置かないため destroy は安全で、空でない bucket の destroy 失敗は「黙って削除される」
  # よりも有用な安全装置として学べます。
  force_destroy = false
}
