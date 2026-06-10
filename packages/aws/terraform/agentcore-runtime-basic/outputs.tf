output "artifact_bucket_name" {
  description = "AgentCore Runtime direct code deployment ZIP を upload する S3 bucket 名。"
  value       = aws_s3_bucket.artifact.bucket
}

output "artifact_object_key" {
  description = "AgentCore Runtime direct code deployment ZIP の S3 object key。"
  value       = aws_s3_object.artifact.key
}

output "region" {
  description = "この Terraform 実行で使用した AWS region。"
  value       = data.aws_region.current.region
}

output "agent_runtime_arn" {
  description = "作成した AgentCore Runtime の ARN。"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "agent_runtime_id" {
  description = "作成した AgentCore Runtime の ID。"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "agent_runtime_endpoint_arn" {
  description = "Terraform で作成した sample endpoint の ARN。"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.sample.agent_runtime_endpoint_arn
}

output "agent_runtime_endpoint_name" {
  description = "Terraform で作成した AgentCore Runtime endpoint 名。"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.sample.name
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
    "--payload '{\"prompt\":\"Hello from workshop\"}'",
    "response.json",
  ])
}
