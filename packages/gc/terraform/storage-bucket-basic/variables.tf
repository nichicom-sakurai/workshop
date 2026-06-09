variable "bucket_name" {
  description = "Globally unique name for the Cloud Storage bucket to create. Bucket names are unique across all of Google Cloud, so a hardcoded value can fail for unrelated reasons; supply your own (e.g. nck-sakurai-tf-learn-<your-suffix>)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters of lowercase letters, digits, or hyphens, and must not start or end with a hyphen."
  }
}

variable "location" {
  description = "Location of the bucket. A single region keeps latency and cost predictable for a learning bucket."
  type        = string
  default     = "ASIA-NORTHEAST1"
}
