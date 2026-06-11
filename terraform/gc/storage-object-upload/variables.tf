variable "bucket_name" {
  description = "object をアップロードする既存 Cloud Storage bucket の名前。storage-bucket-basic で作成した bucket_name と同じ値を指定してください。"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name は 3〜63文字の小文字・数字・ハイフンで構成し、先頭と末尾をハイフンにできません。この sample は storage-bucket-basic と同じ DNS-safe な名前制約に合わせています。"
  }
}

variable "object_name" {
  description = "bucket 内に作成する object 名。slash を含めると folder 風の path として表示できます。"
  type        = string
  default     = "samples/hello.txt"

  validation {
    condition     = length(trimspace(var.object_name)) > 0 && !startswith(var.object_name, "/") && !endswith(var.object_name, "/")
    error_message = "object_name は空文字にできず、先頭または末尾を slash にできません。例: samples/hello.txt"
  }
}
