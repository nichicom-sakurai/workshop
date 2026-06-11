output "bucket_name" {
  description = "Name of the created Cloud Storage bucket."
  value       = google_storage_bucket.learning.name
}

output "bucket_url" {
  description = "gs:// URL of the created bucket."
  value       = google_storage_bucket.learning.url
}

output "location" {
  description = "Location of the created bucket."
  value       = google_storage_bucket.learning.location
}
