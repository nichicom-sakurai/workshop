# packages/aws Terraform read-only AWS sample design

Date: 2026-06-07
Issue URL: none

## Context

`workshop` is a cloud / IaC learning monorepo. Tools are pinned in
`mise.toml`, and Terraform is already available through `mise`.

`packages/aws` is currently a minimal Bun package with:

- `package.json`
- `index.ts`

No `.tf` files exist in the repository yet. The first Terraform example should
teach AWS provider setup, authentication, Terraform state, plan/apply flow, and
outputs without creating or changing AWS resources.

Research notes:

- Terraform root modules declare providers through `required_providers`, then
  install them with `terraform init`.
- Terraform creates `.terraform.lock.hcl` during `init`; it should be committed
  so future runs reuse the selected provider version.
- The local backend stores state on disk by default.
- `aws_caller_identity` is a read-only AWS data source that returns the
  authenticated account ID, user ID, and ARN.

## Boundaries

Never:

- Do not create, update, or destroy AWS resources in this first sample.
- Do not hardcode AWS credentials, account IDs, profile names, regions, or
  machine-local paths.
- Do not add a remote backend yet.
- Do not add broad `mise` Terraform tasks until the repository has a settled
  Terraform task convention.

Always:

- Put Terraform files under `packages/aws/terraform/`.
- Keep the sample read-only by using `data "aws_caller_identity" "current" {}`.
- Pin the AWS provider with an explicit version constraint instead of `latest`.
- Document that `.terraform/` and `terraform.tfstate*` are local runtime files,
  while `.terraform.lock.hcl` is expected to be committed after `terraform init`.
- Use `mise exec -- terraform ...` in documented commands.

Ask first:

- Before adding a resource-creating follow-up sample such as `aws_ssm_parameter`.
- Before adding shared Terraform tasks to `mise.toml`.
- Before introducing remote state, workspaces, modules, or CI checks.

## Architecture

Selected approach: Read-only Caller Identity Sample.

Terraform root module:

- `packages/aws/terraform/terraform.tf`
  - Defines `required_version`.
  - Defines `required_providers.aws` with `source = "hashicorp/aws"` and an
    explicit version constraint.
- `packages/aws/terraform/providers.tf`
  - Defines `provider "aws" {}`.
  - Allows credentials and region to come from normal AWS provider inputs such
    as `AWS_PROFILE`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, and
    `AWS_SECRET_ACCESS_KEY`.
- `packages/aws/terraform/main.tf`
  - Defines `data "aws_caller_identity" "current" {}` only.
- `packages/aws/terraform/outputs.tf`
  - Outputs account ID, caller ARN, and user ID from the data source.
- `packages/aws/terraform/README.md`
  - Explains prerequisites, authentication options, and the command flow:
    `init`, `fmt`, `validate`, `plan`, `apply`, and local cleanup.
  - States that `apply` reads AWS identity data but does not create AWS
    resources.

Repository documentation:

- `README.md`
  - Add a short pointer from the project list or usage section to the new sample
    README.
- `AGENTS.md`
  - Update the skeleton-stage warning that says Terraform is unused and no
    `.tf` files exist.
- `.gitignore`
  - Add Terraform runtime ignores if missing:
    `.terraform/`, `terraform.tfstate`, `terraform.tfstate.*`, `*.tfvars`, and
    `*.tfvars.json`.
  - Do not ignore `.terraform.lock.hcl`.

## Acceptance Criteria

Given a user opens `packages/aws/terraform/README.md`, when they follow the
commands with valid AWS credentials, then they can run `terraform init`,
`terraform validate`, `terraform plan`, and `terraform apply` from the sample
directory.

Given `terraform apply` succeeds, when the user inspects Terraform output, then
they see the authenticated AWS account ID, caller ARN, and user ID.

Given the sample is applied, when the user checks AWS resources, then no AWS
resources were created, updated, or destroyed by this sample.

Given `terraform init` has been run, when the user checks repository status,
then `.terraform.lock.hcl` appears as a trackable provider lock file and
`.terraform/` / `terraform.tfstate*` remain ignored.

Given a contributor reads the root documentation, when they compare it with the
repository state, then it no longer claims Terraform is completely unused or
that no `.tf` files exist.

## Decisions Made

- Use read-only `aws_caller_identity` instead of a resource.
  - Rationale: Best fit for first AWS/Terraform lesson because it validates
    provider configuration and authentication without AWS mutation risk.
  - Confidence: 88%.
- Place Terraform under `packages/aws/terraform/`.
  - Rationale: Keeps the existing Bun sample and the IaC sample separate while
    staying inside the requested package.
  - Confidence: 84%.
- Do not add `mise.toml` Terraform tasks yet.
  - Rationale: Existing tasks are package runtime tasks, and a repository-wide
    Terraform task convention is not established.
  - Confidence: 72%.
- Commit `.terraform.lock.hcl` after `terraform init`.
  - Rationale: Terraform documentation recommends committing the dependency lock
    file for repeatable provider selection.
  - Confidence: 91%.

## Open Questions

- Which AWS region should the user prefer for later resource-creating samples?
  This sample can rely on normal provider environment/config values and does not
  need to decide now.
- Whether the next lesson should create a low-risk resource such as an SSM
  Parameter. This is intentionally out of scope for the first sample.

## Non-Goals

- Creating EC2, S3, SSM, IAM, or any other AWS resource.
- Adding remote state, Terraform Cloud/HCP Terraform, workspaces, modules, or CI.
- Installing or requiring the AWS CLI.
- Teaching production AWS account structure, IAM least privilege policy design,
  or cost controls.

## References

- Terraform AWS getting started:
  https://developer.hashicorp.com/terraform/tutorials/aws-get-started/aws-create
- Terraform provider requirements:
  https://developer.hashicorp.com/terraform/language/providers/requirements
- Terraform dependency lock file:
  https://developer.hashicorp.com/terraform/language/files/dependency-lock
- Terraform state backends:
  https://developer.hashicorp.com/terraform/language/state/backends
- AWS provider `aws_caller_identity` data source:
  https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity
