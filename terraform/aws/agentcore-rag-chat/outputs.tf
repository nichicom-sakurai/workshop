output "region" {
  description = "この Terraform 実行で使用した AWS region。"
  value       = data.aws_region.current.region
}

output "artifact_bucket_name" {
  description = "AgentCore Runtime direct code deployment ZIP を upload する S3 bucket 名。"
  value       = aws_s3_bucket.artifact.bucket
}

output "data_bucket_name" {
  description = "Knowledge Base data source 用のサンプル文書を置く S3 bucket 名。"
  value       = aws_s3_bucket.data.bucket
}

output "vector_bucket_name" {
  description = "S3 Vectors の vector bucket 名。"
  value       = aws_s3vectors_vector_bucket.this.vector_bucket_name
}

output "knowledge_base_ids" {
  description = "ドメインごとの Knowledge Base ID（app の AWS_SERVICE_KB_ID / DATABASE_KB_ID / DOCUMENT_KB_ID に対応）。"
  value       = { for key, kb in aws_bedrockagent_knowledge_base.this : key => kb.id }
}

output "memory_id" {
  description = "AgentCore Memory の ID（app の AGENTCORE_MEMORY_ID に対応）。"
  value       = aws_bedrockagentcore_memory.this.id
}

output "memory_arn" {
  description = "AgentCore Memory の ARN。"
  value       = aws_bedrockagentcore_memory.this.arn
}

output "agent_runtime_arn" {
  description = "作成した AgentCore Runtime の ARN。"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "agent_runtime_id" {
  description = "作成した AgentCore Runtime の ID。"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "agent_runtime_endpoint_name" {
  description = "Terraform で作成した AgentCore Runtime endpoint 名。"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.sample.name
}

output "agent_runtime_endpoint_arn" {
  description = "Terraform で作成した sample endpoint の ARN。"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.sample.agent_runtime_endpoint_arn
}

output "start_ingestion_commands" {
  description = "data source 取り込み（ingestion / sync）を起動する AWS CLI コマンド。apply 後・文書更新後に実行します。"
  value = [
    for key, ds in aws_bedrockagent_data_source.this :
    "aws bedrock-agent start-ingestion-job --knowledge-base-id ${aws_bedrockagent_knowledge_base.this[key].id} --data-source-id ${ds.data_source_id} --region ${data.aws_region.current.region}"
  ]
}

output "invoke_command" {
  description = "sample endpoint 経由で AgentCore Runtime を invoke する AWS CLI コマンド例。"
  value = join(" ", [
    "aws bedrock-agentcore invoke-agent-runtime",
    "--agent-runtime-arn '${aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn}'",
    "--qualifier '${aws_bedrockagentcore_agent_runtime_endpoint.sample.name}'",
    "--content-type application/json",
    "--accept application/json",
    "--cli-binary-format raw-in-base64-out",
    "--payload '{\"prompt\":\"What is Amazon S3?\",\"session_id\":\"s1\",\"actor_id\":\"u1\"}'",
    "response.json",
  ])
}
