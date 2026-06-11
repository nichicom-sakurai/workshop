data "google_storage_buckets" "current" {
  # project is intentionally omitted: it inherits the provider's `project`
  # ("nck-sakurai"), keeping the project identity defined in exactly one place.
  #
  # This is a list-style data source: `buckets` holds every Cloud Storage bucket
  # in the project, and an empty list is a valid result. Reading buckets
  # requires the Cloud Storage API (storage.googleapis.com) to be enabled (see
  # the storage-api-enable sample); this sample does not manage that API.
}
