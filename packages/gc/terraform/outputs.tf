output "project_id" {
  description = "Google Cloud project ID referenced by this Terraform run."
  value       = data.google_project.current.project_id
}

output "project_number" {
  description = "Google Cloud project number for the referenced project."
  value       = data.google_project.current.number
}

output "project_name" {
  description = "Display name of the referenced Google Cloud project."
  value       = data.google_project.current.name
}
