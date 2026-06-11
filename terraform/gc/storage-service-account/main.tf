data "google_storage_project_service_account" "current" {
  # No arguments are needed: the data source uses the provider's `project`
  # ("nck-sakurai"). It returns the Cloud Storage service agent that Google
  # manages on the project's behalf (used to grant access for Pub/Sub
  # notifications, CMEK encryption, etc.).
  #
  # Always read this identity from the data source rather than constructing the
  # email from the project number: the exact format is provider/Google-managed
  # and may change, so a hand-built string can silently become wrong. Reading it
  # requires the Cloud Storage API (storage.googleapis.com) to be enabled (see
  # the storage-api-enable sample); this sample does not manage that API.
}
