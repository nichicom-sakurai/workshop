locals {
  # APIs that cloud-run-service-basic depends on, enabled here so that sample's
  # root module does not have to. Managed as a set and looped with for_each so
  # adding/removing an API is a one-line change.
  # - run:              create and run the Cloud Run service
  # - artifactregistry: Docker repository the container image is pushed to
  # - cloudbuild:       `gcloud builds submit` that builds / pushes the image
  services = [
    "run.googleapis.com",
    "artifactregistry.googleapis.com",
    "cloudbuild.googleapis.com",
  ]
}

resource "google_project_service" "cloud_run" {
  for_each = toset(local.services)

  # project is intentionally omitted: it inherits the provider's `project`
  # ("nck-sakurai"), keeping the project identity defined in exactly one place.
  service = each.value

  # disable_on_destroy = false keeps these APIs enabled when this Terraform
  # resource is destroyed. Disabling a project API on `destroy` can break
  # unrelated workloads, so cleanup of this learning sample must not turn the
  # APIs off. The Service Usage API (serviceusage.googleapis.com) needed to
  # manage these resources is treated as a prerequisite, not managed here.
  disable_on_destroy = false
}
