resource "google_project_service" "storage" {
  # project is intentionally omitted: it inherits the provider's `project`
  # ("nck-sakurai"), keeping the project identity defined in exactly one place.
  service = "storage.googleapis.com"

  # disable_on_destroy = false keeps storage.googleapis.com enabled when this
  # Terraform resource is destroyed. Disabling a project API on `destroy` can
  # break unrelated workloads, so cleanup of this learning sample must not turn
  # the API off. The Service Usage API (serviceusage.googleapis.com) needed to
  # manage this resource is treated as a prerequisite, not managed here.
  disable_on_destroy = false
}
