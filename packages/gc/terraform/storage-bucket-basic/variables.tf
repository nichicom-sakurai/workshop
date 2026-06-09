variable "bucket_name" {
  description = "作成する Cloud Storage bucket のグローバルに一意な名前。bucket 名は全 Google Cloud で一意のため、固定値は無関係な理由で失敗し得ます。自分の値を指定してください（例: nck-sakurai-tf-learn-<任意のサフィックス>）。この学習サンプルは意図的に DNS-safe な小文字・ハイフン名のみを受け付けます。GCS 自体はドットやアンダースコアも追加ルールの下で許可しますが、ここでは対象外です。"
  type        = string

  validation {
    # 意図的に GCS より厳格にしています。この学習サンプルは名前を単純な DNS-safe 形式
    # （小文字・数字・ハイフン、3〜63文字、先頭末尾はハイフン不可）に制限します。GCS は
    # ドットやアンダースコアも追加ルールの下で許可しますが、最初の bucket サンプルでは
    # 対象外です。
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name は 3〜63文字の小文字・数字・ハイフンで構成し、先頭と末尾をハイフンにできません。このサンプルは意図的に DNS-safe な名前（ドット/アンダースコアなし）に制限しています（GCS 自体は許可します）。"
  }
}

variable "location" {
  description = "bucket の location。単一リージョンにすると、学習用 bucket のレイテンシとコストが予測しやすくなります。"
  type        = string
  default     = "ASIA-NORTHEAST1"
}
