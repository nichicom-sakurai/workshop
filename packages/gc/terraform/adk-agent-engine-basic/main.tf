# Vertex AI Agent Engine(API 名: Reasoning Engine)。adk-helloworld を inline source
# 方式で deploy します。archive の build / package は Terraform ではなく
# package-agent-engine.sh で行い、Terraform は生成済みの .tar.gz を filebase64 で
# 読むだけにします（infrastructure は Terraform、artifact 生成は script という責務分離。
# cloud-run-service-basic の「image の push は gcloud」と同じ流儀）。
resource "google_vertex_ai_reasoning_engine" "adk_hello" {
  # project は意図的に省略しています。provider の `project`（"nck-sakurai"）を
  # 継承させ、プロジェクトの指定を1か所だけに保つためです。
  display_name = var.display_name
  description  = var.description
  region       = var.region

  spec {
    # agent_framework: OSS フレームワーク名（任意）。ADK で組んだことを明示します。
    agent_framework = "google-adk"

    # source_code_spec は spec の「中」にネストします（research で確認した補正点。
    # トップレベルに source_code_spec は無い）。
    source_code_spec {
      # inline_source.source_archive は .tar.gz を base64 にした文字列を取ります。
      # GCS も pickle も使わない最小経路です（package_spec 方式とは別物）。
      inline_source {
        source_archive = filebase64(var.source_archive_path)
      }

      python_spec {
        # entrypoint_module / entrypoint_object は archive root を起点に解決します。
        # archive root には agent_engine_app.py と hello_world/ が並び、
        # agent_engine_app.py が agent_engine(= AdkApp(root_agent))を公開します。
        # entrypoint_object は raw root_agent ではなく AdkApp インスタンスを指す
        # 必要があります（#1 footgun）。
        entrypoint_module = "agent_engine_app"
        entrypoint_object = "agent_engine"
        # requirements_file は archive root からの相対パス。managed runtime が
        # これを pip install します（依存は archive に同梱しません）。
        requirements_file = "requirements.txt"
        version           = var.python_version
      }
    }
  }

  # deletion_policy は var で切り替えます（default "DELETE"）。学習サンプルは destroy まで
  # 学ぶため通常は DELETE。ただし「呼び出し方」の手順で agent を叩くと create_session で
  # session（child resource）が作られ、DELETE では destroy が
  # 「contains child resources: sessions」で失敗します。その場合は deletion_policy = "FORCE"
  # にして apply → destroy すると child ごと削除できます（cleanup.md 参照）。
  # PREVENT は destroy を止め、ABANDON は API に残したまま state から外します。
  deletion_policy = var.deletion_policy
}
