locals {
  # 3 つの専門ドメイン。
  #   key         = アプリ側の専門 agent 識別子（runtime 環境変数のキーにも対応）
  #   prefix      = S3 オブジェクトのプレフィックス / index 名 / data source の inclusion prefix
  #   description = リソースの説明に使う
  domains = {
    aws_service = { prefix = "aws-service", description = "AWS service documentation" }
    database    = { prefix = "database", description = "Sample business data (customers / orders / products)" }
    document    = { prefix = "document", description = "Internal documents, policies, and FAQs" }
  }

  # bucket 名は account / region を含めて衝突を避ける（name_prefix を長くすると 63 文字上限に近づく）。
  artifact_bucket_name = "${var.name_prefix}-artifact-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  data_bucket_name     = "${var.name_prefix}-data-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  vector_bucket_name   = "${var.name_prefix}-vectors-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"

  # artifact_zip_path は path.module 起点で解決（-chdir / cwd に依存しない）。
  artifact_zip_file = "${path.module}/${var.artifact_zip_path}"
  artifact_key      = "agentcore-runtime/${filesha256(local.artifact_zip_file)}.zip"

  # embedding model の ARN（account 部分は空：foundation model は account 非依存）。
  embedding_model_arn = "arn:aws:bedrock:${data.aws_region.current.region}::foundation-model/${var.embedding_model_id}"

  # AgentCore の名前はハイフン不可（^[a-zA-Z][a-zA-Z0-9_]...）。prefix の "-" を "_" に変換する。
  runtime_name  = replace(var.name_prefix, "-", "_")
  memory_name   = "${replace(var.name_prefix, "-", "_")}_memory"
  endpoint_name = "sample"

  # Runtime に渡す環境変数。app（rag_chat.config）が読む名前と一致させる。
  runtime_env = {
    AWS_DEFAULT_REGION  = data.aws_region.current.region
    BEDROCK_MODEL_ID    = var.model_id
    AWS_SERVICE_KB_ID   = aws_bedrockagent_knowledge_base.this["aws_service"].id
    DATABASE_KB_ID      = aws_bedrockagent_knowledge_base.this["database"].id
    DOCUMENT_KB_ID      = aws_bedrockagent_knowledge_base.this["document"].id
    AGENTCORE_MEMORY_ID = aws_bedrockagentcore_memory.this.id
  }
}
