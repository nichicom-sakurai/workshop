variable "image" {
  description = "deploy する container image の完全 URI（tag 込み）。`gcloud builds submit --tag` に渡した値をそのまま設定します（例: asia-northeast1-docker.pkg.dev/nck-sakurai/cloud-run-rest/cloud-run-rest:a1b2c3d）。"
  type        = string

  validation {
    # Artifact Registry の Docker image URI（<region>-docker.pkg.dev/<project>/<repository>/<image>:<tag>）
    # だけを受け付けます。Docker の tag は大文字なども許可しますが、このサンプルは意図的に
    # short git SHA のような小文字 tag に制限しています（storage-bucket-basic の bucket 名と
    # 同じ「意図的に厳格化」の流儀）。template のプレースホルダ（REPLACE-WITH-...、大文字）を
    # 書き換え忘れたまま進めると apply まで行かずここで止まります。tag なしの URI は push した
    # image と deploy する image の対応が追えなくなるため拒否します（digest 形式
    # <image>@sha256:<hex> は一意性が高いため通ります）。
    condition     = can(regex("^[a-z0-9-]+-docker\\.pkg\\.dev/[^/]+/[^/]+/[^/:]+:[a-z0-9][a-z0-9._-]{0,127}$", var.image))
    error_message = "image は Artifact Registry の tag 付き完全 URI（<region>-docker.pkg.dev/<project>/<repository>/<image>:<tag>、tag は小文字）で指定してください。template のプレースホルダは実際の tag に置き換えます。"
  }

  validation {
    condition     = !endswith(var.image, ":latest")
    error_message = "image の tag に latest は使えません。どの commit の image か追跡できるよう、short git SHA（git rev-parse --short HEAD）など一意な tag を使ってください。"
  }

  validation {
    # このモジュールが作成する repository（var.region / nck-sakurai / var.repository_id）の
    # image だけを受け付けます。typo した URI や別プロジェクトの image が validation を
    # すり抜けて deploy されることを防ぎます（project は providers.tf と同じ値です）。
    condition     = startswith(var.image, "${var.region}-docker.pkg.dev/nck-sakurai/${var.repository_id}/")
    error_message = "image はこのモジュールが作成する repository（${var.region}-docker.pkg.dev/nck-sakurai/${var.repository_id}/...）の URI で指定してください。region / repository_id を変えた場合は image も合わせます。"
  }
}

variable "region" {
  description = "Artifact Registry repository と Cloud Run service を置く region。Cloud Run / Artifact Registry の location は小文字表記（asia-northeast1）です。GCS の location（ASIA-NORTHEAST1 のような大文字表記）と表記が異なる点に注意してください。"
  type        = string
  default     = "asia-northeast1"
}

variable "repository_id" {
  description = "作成する Artifact Registry Docker repository の ID。"
  type        = string
  default     = "cloud-run-rest"
}

variable "service_name" {
  description = "作成する Cloud Run service の名前。"
  type        = string
  default     = "cloud-run-rest"
}
