resource "google_project_service" "vertex_ai" {
  # project is intentionally omitted: it inherits the provider's `project`
  # ("nck-sakurai"), keeping the project identity defined in exactly one place.
  #
  # aiplatform.googleapis.com is the Vertex AI API, which also serves the Agent
  # Engine / Reasoning Engine resource that adk-agent-engine-basic creates. For
  # the inline-source (python_spec) deploy path this single API is sufficient
  # (no storage / cloudbuild needed — those are only for the GCS-package or
  # container-image paths).
  service = "aiplatform.googleapis.com"

  # disable_on_destroy = false keeps aiplatform.googleapis.com enabled when this
  # Terraform resource is destroyed. Disabling a project API on `destroy` can
  # break unrelated workloads, so cleanup of this learning sample must not turn
  # the API off. The Service Usage API (serviceusage.googleapis.com) needed to
  # manage this resource is treated as a prerequisite, not managed here.
  disable_on_destroy = false
}
