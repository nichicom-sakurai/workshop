output "service_uri" {
  description = "URL of the Cloud Run service. Used for the authenticated curl check."
  value       = google_cloud_run_v2_service.learning.uri
}

output "repository_id" {
  description = "ID of the created Artifact Registry repository."
  value       = google_artifact_registry_repository.learning.repository_id
}

output "service_name" {
  description = "Name of the created Cloud Run service."
  value       = google_cloud_run_v2_service.learning.name
}
