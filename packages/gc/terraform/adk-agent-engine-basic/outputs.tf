output "reasoning_engine_id" {
  description = "作成した Agent Engine(reasoning engine)の Terraform リソース ID。"
  value       = google_vertex_ai_reasoning_engine.adk_hello.id
}

output "reasoning_engine_name" {
  description = "サーバ割り当ての完全リソース名（projects/.../locations/.../reasoningEngines/...）。"
  value       = google_vertex_ai_reasoning_engine.adk_hello.name
}

output "display_name" {
  description = "Agent Engine の表示名。"
  value       = google_vertex_ai_reasoning_engine.adk_hello.display_name
}

output "region" {
  description = "Agent Engine を作成した region。"
  value       = google_vertex_ai_reasoning_engine.adk_hello.region
}
