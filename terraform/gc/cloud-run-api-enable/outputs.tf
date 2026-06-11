output "services" {
  description = "The Google Cloud API services managed by this sample."
  value       = [for s in google_project_service.cloud_run : s.service]
}

output "service_ids" {
  description = "Map of API name to resource ID, in the form {project}/{service}."
  value       = { for k, s in google_project_service.cloud_run : k => s.id }
}

output "disable_on_destroy" {
  description = "Map of API name to whether it is disabled on destroy. Intentionally false so cleanup never turns off the Cloud Run stack."
  value       = { for k, s in google_project_service.cloud_run : k => s.disable_on_destroy }
}
