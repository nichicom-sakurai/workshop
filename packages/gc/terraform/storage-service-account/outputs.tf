output "email_address" {
  description = "Email of the Cloud Storage service agent that Google manages for this project."
  value       = data.google_storage_project_service_account.current.email_address
}

output "member" {
  description = "IAM member string (serviceAccount:{email}) for the Cloud Storage service agent, ready to use in IAM bindings."
  value       = data.google_storage_project_service_account.current.member
}
