# Artifact Registry の Docker repository。container image の push 先です。
# image の build / push は Terraform ではなく `gcloud builds submit` で行います
# （infrastructure は Terraform、image lifecycle は gcloud という責務分離。README 参照）。
resource "google_artifact_registry_repository" "learning" {
  # project は意図的に省略しています。provider の `project`（"nck-sakurai"）を
  # 継承させ、プロジェクトの指定を1か所だけに保つためです。
  repository_id = var.repository_id
  format        = "DOCKER"
  location      = var.region
  description   = "Cloud Run 学習サンプル用の Docker repository"

  # deletion_policy は default（"DELETE"）のまま: `terraform destroy` は repository 内に
  # image が残っていても中身ごと削除します（Artifact Registry API の DeleteRepository は
  # 内容ごと削除する仕様）。誤削除を防ぎたい本番用途では "PREVENT" を検討してください。
}

# private な Cloud Run service。
# invoker の IAM binding（google_cloud_run_v2_service_iam_member など）を一切作らないことで
# 「project Owner / Editor 以外は呼び出せない」default の状態を保ちます。
# allUsers / allAuthenticatedUsers への公開はこのサンプルでは扱いません。
resource "google_cloud_run_v2_service" "learning" {
  name     = var.service_name
  location = var.region

  # default は true で、その場合 `terraform destroy` が失敗します。
  # 学習サンプルは destroy までを学ぶため、明示的に false にします。
  deletion_protection = false

  # ingress は default（INGRESS_TRAFFIC_ALL）のまま: ネットワーク的には到達できますが、
  # IAM（invoker binding 不在）により認証なしのリクエストは 403 になります。
  # これにより外部から「ID token 付き curl なら 200、なしなら 403」という
  # private 挙動を確認できます（INGRESS_TRAFFIC_INTERNAL_ONLY にすると
  # この外部からの動作確認自体ができなくなります）。

  # 全 revision 合算の instance 数上限。学習サンプルの想定外コストを防ぎます。
  scaling {
    max_instance_count = 1
  }

  template {
    # service_account は意図的に未指定です。この場合 service は Compute Engine の
    # default service account で実行されます（学習サンプルの最小構成）。コンテナ侵害時の
    # 権限範囲を絞りたい本番用途では、role を持たない専用 service account の指定を
    # 検討してください。
    containers {
      # この image は本モジュールが作る repository に存在する必要があるため、初回は
      # repository の先行 apply -> push -> full apply の 2 段階になります（README 参照）。
      image = var.image
    }
  }

  # image は変数で渡されるため repository への参照依存が生まれません。
  # 「repository に push された image を使う」という論理依存を明示し、
  # destroy 時に service -> repository の順で削除されることを保証します。
  depends_on = [google_artifact_registry_repository.learning]
}
