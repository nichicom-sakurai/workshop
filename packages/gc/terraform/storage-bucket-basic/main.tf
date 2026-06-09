resource "google_storage_bucket" "learning" {
  # project is intentionally omitted: it inherits the provider's `project`
  # ("nck-sakurai"), keeping the project identity defined in exactly one place.
  name     = var.bucket_name
  location = var.location

  # Private-by-default posture for a learning bucket:
  # - uniform_bucket_level_access disables per-object ACLs (IAM-only access).
  # - public_access_prevention = "enforced" blocks any public access.
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"

  # force_destroy = false (the provider default, set explicitly for clarity)
  # means `terraform destroy` fails if the bucket still contains objects. The
  # first bucket sample uploads no objects, so destroy is safe; a failed destroy
  # on a non-empty bucket is a useful safety lesson rather than silent deletion.
  force_destroy = false
}
