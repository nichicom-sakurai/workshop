output "bucket_name" {
  description = "Name of the bucket that contains the uploaded object."
  value       = google_storage_bucket_object.hello.bucket
}

output "content_type" {
  description = "Content-Type assigned to the uploaded object."
  value       = google_storage_bucket_object.hello.content_type
}

output "generation" {
  description = "Generation number assigned by Cloud Storage to the uploaded object."
  value       = google_storage_bucket_object.hello.generation
}

output "object_name" {
  description = "Name of the uploaded object inside the bucket."
  value       = google_storage_bucket_object.hello.output_name
}

output "object_url" {
  description = "gs:// URL of the uploaded object."
  value       = "gs://${google_storage_bucket_object.hello.bucket}/${google_storage_bucket_object.hello.output_name}"
}
