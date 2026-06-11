data "google_project" "current" {
  # project_id is intentionally omitted: it inherits the provider's `project`
  # ("nck-sakurai"), keeping the project identity defined in exactly one place.
  lifecycle {
    postcondition {
      condition     = self.number == "1073157047557"
      error_message = "Resolved project number ${self.number} does not match the expected 1073157047557 for nck-sakurai."
    }
  }
}
