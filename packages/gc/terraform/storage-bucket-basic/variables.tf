variable "bucket_name" {
  description = "Globally unique name for the Cloud Storage bucket to create. Bucket names are unique across all of Google Cloud, so a hardcoded value can fail for unrelated reasons; supply your own (e.g. nck-sakurai-tf-learn-<your-suffix>). This learning sample intentionally accepts only DNS-safe lowercase/hyphen names; GCS itself also permits dots and underscores under additional rules, which are out of scope here."
  type        = string

  validation {
    # Intentionally stricter than GCS: this learning sample restricts names to
    # the simple DNS-safe form (lowercase letters, digits, hyphens; 3-63 chars;
    # no leading/trailing hyphen). GCS also allows dots and underscores under
    # extra rules, but those are out of scope for a first bucket sample.
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$", var.bucket_name))
    error_message = "bucket_name must be 3-63 characters of lowercase letters, digits, or hyphens, and must not start or end with a hyphen. This sample intentionally restricts to DNS-safe names (no dots/underscores), which GCS otherwise allows."
  }
}

variable "location" {
  description = "Location of the bucket. A single region keeps latency and cost predictable for a learning bucket."
  type        = string
  default     = "ASIA-NORTHEAST1"
}
