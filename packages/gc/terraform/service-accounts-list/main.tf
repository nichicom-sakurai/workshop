data "google_service_accounts" "current" {
  # project is intentionally omitted: it inherits the provider's `project`
  # ("nck-sakurai"), keeping the project identity defined in exactly one place.
  #
  # This is a list-style data source: `accounts` holds every service account in
  # the project. Reading it requires the IAM API (iam.googleapis.com) to be
  # enabled on the project; this sample does not manage that API.
}
