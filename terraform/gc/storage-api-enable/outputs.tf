output "service" {
  description = "The Google Cloud API service managed by this sample."
  value       = google_project_service.storage.service
}

output "service_id" {
  description = "Resource ID of the managed service, in the form {project}/{service}."
  value       = google_project_service.storage.id
}

output "disable_on_destroy" {
  description = "Whether the API is disabled on destroy. Intentionally false so cleanup never turns off Cloud Storage."
  value       = google_project_service.storage.disable_on_destroy
}
