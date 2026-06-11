output "bucket_count" {
  description = "Number of Cloud Storage buckets in the project. Zero is a valid result."
  value       = length(data.google_storage_buckets.current.buckets)
}

output "buckets" {
  description = "Non-secret metadata for each bucket (name, location, storage class). Empty when the project has no buckets."
  value = [
    for bucket in data.google_storage_buckets.current.buckets : {
      name          = bucket.name
      location      = bucket.location
      storage_class = bucket.storage_class
    }
  ]
}
