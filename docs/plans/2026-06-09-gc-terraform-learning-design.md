# packages/gc Terraform learning design

Date: 2026-06-09
Issue URL: https://github.com/nichicom-sakurai/workshop/issues/6

## Context

`workshop` is a cloud / IaC learning monorepo. `packages/gc` currently has a
minimal Bun package and one Google Cloud Terraform sample:
`packages/gc/terraform/project-info/`.

The existing Terraform convention is:

- Put each sample directly under `packages/gc/terraform/<operation>/`.
- Treat each sample as an independent root module with its own local state.
- Keep the current samples read-only unless a mutating sample is explicitly
  chosen.
- Commit `.terraform.lock.hcl`, and never commit `.terraform/` or
  `terraform.tfstate*`.

The selected direction is **read-only basics first, then one low-risk mutating
sample**. This teaches Terraform's full lifecycle without jumping directly to
IAM, billing, projects, service account keys, remote backend, or production
patterns.

Research notes:

- Terraform root modules should declare required providers and install them with
  `terraform init`; `init` updates the dependency lock file.
- The Google provider can use the provider-level `project` setting as the
  default project for data sources and resources.
- `google_project` is a read-only data source and already exists in
  `project-info`.
- `google_service_accounts`, `google_storage_buckets`, and
  `google_storage_project_service_account` are read-only data sources suitable
  for beginner samples.
- `google_project_service` manages one enabled API service. In the current
  provider behavior, `disable_on_destroy = false` leaves the API enabled when the
  Terraform resource is destroyed, avoiding accidental service disruption.
- `google_storage_bucket` is a low-risk first resource when configured as a
  private bucket and destroyed after the lesson. Bucket names are globally
  unique, so the sample should take the bucket name as user input rather than
  hardcoding one.

## Boundaries

Never:

- Do not create or delete Google Cloud projects.
- Do not change billing accounts.
- Do not grant IAM roles or create service account keys in this learning phase.
- Do not hardcode credentials, tokens, user email addresses, or machine-local
  paths.
- Do not add remote state, Terraform Cloud / HCP Terraform, workspaces, modules,
  CI, policy-as-code, or scanners yet.
- Do not make public buckets or upload public objects.
- Do not set `force_destroy = true` by default in the first bucket sample.

Always:

- Keep each sample self-contained under
  `packages/gc/terraform/<operation>/`.
- Keep sample names kebab-case and named by target + operation.
- Mark each sample as `read-only` or `mutating` in
  `packages/gc/terraform/README.md`.
- Use `provider "google" { project = "nck-sakurai" }` consistently unless the
  repository later adopts a variable-driven project convention.
- Use `mise exec -- terraform -chdir=packages/gc/terraform/<operation> ...` in
  docs and verification.
- Commit `.terraform.lock.hcl` after `terraform init`.
- Keep local state and local variables ignored.
- For `google_project_service`, set `disable_on_destroy = false` explicitly.
- For bucket creation, use private defaults such as uniform bucket-level access,
  public access prevention, and a user-supplied globally unique bucket name.

Ask first:

- Before adding resource-creating samples beyond the first Cloud Storage bucket.
- Before adding object upload, lifecycle rules, IAM bindings, Pub/Sub, Cloud
  Run, BigQuery, GKE, or any sample that may create billable resources beyond a
  short-lived bucket.
- Before managing APIs other than `storage.googleapis.com`.
- Before adding shared `mise` Terraform tasks for Google Cloud.
- Before introducing remote backend or production-style environment folders.

## Architecture

Selected approach: **Staged read-only to low-risk mutating samples**

Confidence: 86%.

### Learning order

1. `project-info` (existing, read-only)
   - Learn provider configuration, ADC, `google_project`, outputs, and
     `postcondition`.
2. `service-accounts-list` (new, read-only)
   - Learn list-style data sources using `google_service_accounts`.
   - Output service account count and selected non-secret fields.
3. `storage-api-enable` (new, mutating)
   - Learn API enablement using `google_project_service` for
     `storage.googleapis.com`.
   - Set `disable_on_destroy = false` to avoid disabling the API during cleanup.
   - Treat Service Usage API availability as a prerequisite, not as something
     this sample manages.
4. `storage-buckets-list` (new, read-only)
   - Learn Cloud Storage inventory with `google_storage_buckets`.
   - Empty output is valid and should be documented as a normal result.
5. `storage-service-account` (new, read-only)
   - Learn provider-managed service accounts with
     `google_storage_project_service_account`.
   - Explain why a data source is better than constructing the service account
     email from the project number.
6. `storage-bucket-basic` (new, mutating)
   - Learn `plan`, `apply`, `state`, and `destroy` with one private Cloud
     Storage bucket.
   - Use a required `bucket_name` variable and a committed
     `terraform.tfvars.template`; users copy the template to an ignored local
     variables file.
   - Include `cleanup.md` so the deletion flow is documented next to the
     resource-creating sample.
   - Use no uploaded objects in the first version, so `force_destroy = false`
     remains safe.
7. `storage-object-upload` (follow-up, mutating)
   - Learn `google_storage_bucket_object` by uploading one committed local text
     file to the bucket created by `storage-bucket-basic`.
   - Manage only the object in this sample; the bucket remains managed by
     `storage-bucket-basic`.
   - Include `cleanup.md` so learners delete the object before deleting the
     bucket.

### Proposed folder structure

```text
packages/gc/
├── index.ts
├── package.json
└── terraform/
    ├── README.md
    ├── project-info/
    │   ├── README.md
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   └── terraform.tf
    ├── service-accounts-list/
    │   ├── README.md
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   └── terraform.tf
    ├── storage-api-enable/
    │   ├── README.md
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   └── terraform.tf
    ├── storage-buckets-list/
    │   ├── README.md
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   └── terraform.tf
    ├── storage-service-account/
    │   ├── README.md
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   └── terraform.tf
    ├── storage-bucket-basic/
    │   ├── cleanup.md
    │   ├── README.md
    │   ├── main.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   ├── terraform.tf
    │   ├── terraform.tfvars.template
    │   └── variables.tf
    └── storage-object-upload/
        ├── cleanup.md
        ├── README.md
        ├── main.tf
        ├── objects/
        │   └── hello.txt
        ├── outputs.tf
        ├── providers.tf
        ├── terraform.tf
        ├── terraform.tfvars.template
        └── variables.tf
```

Each new sample will also generate `.terraform.lock.hcl` after `terraform init`.
That lock file should be committed for every initialized sample.

### Concrete file-change list

- `packages/gc/terraform/README.md`
  - Add the new samples to the table.
  - Add a learning order section.
  - Clarify which samples mutate the project and which are read-only.
  - Add cleanup expectations for mutating samples.
- `packages/gc/terraform/service-accounts-list/*`
  - Add the read-only service account list sample.
- `packages/gc/terraform/storage-api-enable/*`
  - Add the API enablement sample with `disable_on_destroy = false`.
- `packages/gc/terraform/storage-buckets-list/*`
  - Add the read-only bucket inventory sample.
- `packages/gc/terraform/storage-service-account/*`
  - Add the read-only Cloud Storage service account sample.
- `packages/gc/terraform/storage-bucket-basic/*`
  - Add the private bucket lifecycle sample.
  - Include `terraform.tfvars.template`, not real local values.
  - Include `cleanup.md` with the `terraform plan -destroy` and
    `terraform destroy` flow for deleting the bucket created by this sample.
  - Document that no separate `delete.tf` is added because Terraform deletion
    should use the same root module and state that created the bucket.
- `packages/gc/terraform/storage-object-upload/*`
  - Add the object upload follow-up sample.
  - Include `objects/hello.txt` as the committed local source file.
  - Include `terraform.tfvars.template`, not real local values.
  - Include `cleanup.md` with the `terraform plan -destroy` and
    `terraform destroy` flow for deleting the uploaded object before bucket
    cleanup.
- `docs/guides/gcloud-cli/README.md`
  - If needed, add a short `gcloud services list` / API enablement confirmation
    section that links back to the Terraform samples.

No root `mise.toml` task change is required for this phase because the current
Google Cloud Terraform docs already use direct `mise exec -- terraform`
commands.

## Acceptance Criteria

Given a learner reads `packages/gc/terraform/README.md`, when they inspect the
sample table, then each sample is clearly marked as `read-only` or `mutating`.

Given a learner follows the samples in order, when they run `init`, `fmt
-check`, `validate`, and `plan`, then each sample succeeds with valid Google
Cloud credentials and required project permissions.

Given `service-accounts-list` is applied, when the learner reads the outputs,
then they can see that Terraform can read project service account metadata
without creating resources.

Given `storage-api-enable` is applied, when the learner runs the sample, then it
enables or confirms `storage.googleapis.com` without managing other APIs.

Given `storage-api-enable` is destroyed, when the learner checks the API status,
then the API remains enabled because `disable_on_destroy = false`.

Given `storage-buckets-list` is applied, when the project has no buckets, then
the output handles an empty list as a valid learning result.

Given `storage-service-account` is applied, when the learner reads the outputs,
then they can see the Cloud Storage service account identity returned by the
provider data source.

Given `storage-bucket-basic` is applied with a valid globally unique
`bucket_name`, when the learner checks Cloud Storage, then exactly one private
bucket managed by that sample exists.

Given the learner opens `storage-bucket-basic/cleanup.md`, when they follow the
documented cleanup flow, then they can preview deletion with `terraform plan
-destroy` and remove the bucket with `terraform destroy`.

Given `storage-bucket-basic` is destroyed before adding objects, when the learner
checks Cloud Storage, then the bucket is removed and no extra resources remain.

Given the bucket contains objects or caches, when the learner runs cleanup with
`force_destroy = false`, then the cleanup doc explains that deletion may fail and
that enabling object deletion behavior is a separate follow-up decision.

Given `storage-object-upload` is applied with the `bucket_name` from
`storage-bucket-basic`, when the learner checks Cloud Storage, then one object
from `objects/hello.txt` exists at the configured `object_name`.

Given the learner opens `storage-object-upload/cleanup.md`, when they follow the
documented cleanup flow, then they can preview object deletion with `terraform
plan -destroy` and delete the object with `terraform destroy`.

Given both `storage-object-upload` and `storage-bucket-basic` were used, when
the learner cleans up, then the object sample is destroyed before the bucket
sample so `force_destroy = false` does not block bucket cleanup.

Given any sample runs `terraform init`, when repository status is inspected, then
`.terraform.lock.hcl` is trackable and `.terraform/` / `terraform.tfstate*` are
ignored.

## Decisions Made

- Build a staged sequence: read-only samples first, then one bucket resource.
  - Rationale: This preserves the repo's current safety posture while still
    teaching Terraform's create / destroy lifecycle.
  - Confidence: 86%.
- Keep the existing flat `terraform/<operation>/` layout.
  - Rationale: It is already documented in `AGENTS.md` and both AWS / Google
    Cloud Terraform README files.
  - Confidence: 93%.
- Use Cloud Storage as the first resource-creating topic.
  - Rationale: It is simpler and easier to clean up than IAM, Cloud Run, GKE,
    BigQuery, or project management.
  - Confidence: 82%.
- Manage only `storage.googleapis.com` in the first API sample.
  - Rationale: It directly supports the bucket lesson and keeps API management
    understandable.
  - Confidence: 79%.
- Keep `Service Usage API` as a prerequisite.
  - Rationale: Managing the API needed to manage APIs creates a confusing
    bootstrap lesson for beginners.
  - Confidence: 76%.
- Require `bucket_name` input instead of hardcoding a bucket name.
  - Rationale: Cloud Storage bucket names are globally unique, so a committed
    fixed value can fail for unrelated reasons.
  - Confidence: 88%.
- Use `force_destroy = false` for the first bucket sample.
  - Rationale: It avoids accidental object deletion. If users add objects
    manually, the failed destroy is a useful safety lesson.
  - Confidence: 78%.
- Add `storage-bucket-basic/cleanup.md` instead of a separate deletion `.tf`.
  - Rationale: Terraform should destroy resources through the same root module
    and state that created them; the cleanup file documents the command flow
    without creating a second source of truth.
  - Confidence: 84%.
- Add `storage-object-upload` as a separate root module.
  - Rationale: Keeping bucket creation and object upload in separate state files
    makes the lifecycle boundary explicit: object cleanup must happen before
    bucket cleanup when `force_destroy = false`.
  - Confidence: 82%.

## Open Questions

- The default bucket `location` should be confirmed during implementation.
  `ASIA-NORTHEAST1` is a reasonable default for this local learning repo, but
  the implementation should verify the final value against the current provider
  docs and user preference.
- Whether to add object versioning, lifecycle rules, or multiple object upload
  patterns after `storage-object-upload`. These remain separate follow-ups
  because they change cleanup and retention behavior.

## Non-Goals

- Production-ready Google Cloud Terraform architecture.
- Remote backend or encrypted shared state.
- IAM role grants, service account key management, or Workload Identity
  Federation.
- Billing setup, project creation, organization / folder management, or quota
  management.
- CI, static analysis, policy-as-code, drift detection, or cost reporting.
- Multi-environment layout such as `dev` / `stg` / `prod`.
- Module extraction or reusable Terraform module design.

## Verification Plan

For each sample:

```bash
mise exec -- terraform -chdir=packages/gc/terraform/<operation> init
mise exec -- terraform -chdir=packages/gc/terraform/<operation> fmt -check
mise exec -- terraform -chdir=packages/gc/terraform/<operation> validate
mise exec -- terraform -chdir=packages/gc/terraform/<operation> plan
```

For mutating samples only:

```bash
mise exec -- terraform -chdir=packages/gc/terraform/<operation> apply
mise exec -- terraform -chdir=packages/gc/terraform/<operation> plan -destroy
mise exec -- terraform -chdir=packages/gc/terraform/<operation> destroy
```

After verification:

```bash
git status --short
```

Confirm that no `terraform.tfstate*`, `.terraform/`, real `.tfvars`, secrets, or
machine-local files are staged.

## References

- Terraform provider requirements:
  https://developer.hashicorp.com/terraform/language/providers/requirements
- Terraform dependency lock file:
  https://developer.hashicorp.com/terraform/language/files/dependency-lock
- Terraform plan and destroy flow:
  https://developer.hashicorp.com/terraform/tutorials/cli/plan
- Terraform Google provider:
  https://registry.terraform.io/providers/hashicorp/google/latest/docs
- `google_project_service`:
  https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/google_project_service
- `google_storage_bucket`:
  https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/storage_bucket.html
- `google_service_accounts`:
  https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/service_accounts
- `google_storage_project_service_account`:
  https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/storage_project_service_account
