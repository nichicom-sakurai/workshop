variable "source_archive_path" {
  description = "Agent Engine 用 source archive(.tar.gz)へのパス。filebase64() がこの .tf の場所からの相対パスで読みます。default は package-agent-engine.sh が生成する場所を指します（gitignore 対象のため、plan/apply の前に script を実行してください）。"
  type        = string
  default     = "../../apps/adk-helloworld/.build/source.tar.gz"
}

variable "display_name" {
  description = "作成する Agent Engine(reasoning engine)の表示名。"
  type        = string
  default     = "adk-helloworld"
}

variable "description" {
  description = "Agent Engine の説明。"
  type        = string
  default     = "ADK HelloWorld agent on Vertex AI Agent Engine (inline source)."
}

variable "region" {
  description = "Agent Engine を作成する region。Agent Engine は全 region では使えないため、公式サンプルと同じ us-central1 を default にしています（Cloud Run サンプルの asia-northeast1 とは別の判断）。"
  type        = string
  default     = "us-central1"
}

variable "python_version" {
  description = "Agent Engine の managed runtime が使う Python version（python_spec.version）。app のローカル Python(3.13)に合わせていますが、managed runtime の対応 version は変わり得るため、apply が version で失敗する場合はここを調整します。"
  type        = string
  default     = "3.13"

  validation {
    # provider が受け付ける範囲（3.9〜3.14）。alias ではなく具体 version を要求します。
    condition     = can(regex("^3\\.(9|1[0-4])$", var.python_version))
    error_message = "python_version は 3.9〜3.14 の形式（例: 3.13）で指定してください。"
  }
}

variable "deletion_policy" {
  description = "Agent Engine の削除ポリシー（DELETE / FORCE / PREVENT / ABANDON）。default は DELETE。呼び出しテストで session（child resource）を作ると DELETE では destroy が「contains child resources: sessions」で失敗するため、その場合は FORCE にして child ごと削除します。"
  type        = string
  default     = "DELETE"

  validation {
    condition     = contains(["DELETE", "FORCE", "PREVENT", "ABANDON"], var.deletion_policy)
    error_message = "deletion_policy は DELETE / FORCE / PREVENT / ABANDON のいずれかで指定してください。"
  }
}
