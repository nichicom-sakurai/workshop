# packages/aws Terraform learning design

Date: 2026-06-09
Issue URL: https://github.com/nichicom-sakurai/workshop/issues/7

## Context

`workshop` is a cloud / IaC learning monorepo. `packages/aws` currently has a
minimal Bun skeleton and an AWS Terraform sample collection under
`packages/aws/terraform/`.

The existing AWS Terraform sample is:

- `caller-identity` (`read-only`): reads `aws_caller_identity` and outputs the
  current AWS account ID, caller ARN, and user ID.

The existing local convention is to place each Terraform exercise directly under
`packages/aws/terraform/<operation>/` as an independent root module. This keeps
state separated by exercise and allows each sample to be initialized, planned,
applied, and destroyed independently.

The next learning step should move from read-only provider/data-source learning
to a low-risk resource lifecycle exercise. The selected first mutating sample is
`s3-private-bucket`.

## Boundaries

Never:

- Do not group future examples under a shared `s3/` Terraform root while the repo
  convention is `terraform/<operation>/`.
- Do not commit `.terraform/`, `terraform.tfstate`, `terraform.tfstate.*`, local
  credentials, `.tfvars`, or machine-local configuration.
- Do not create public S3 buckets.
- Do not introduce remote backend, Terraform Cloud, CI, reusable modules, or
  production AWS account structure in this first mutating sample.
- Do not hardcode AWS credentials, personal profile names, account-specific
  secrets, or machine-local paths.

Always:

- Keep each learning exercise as a self-contained root module.
- Add every new sample to `packages/aws/terraform/README.md`.
- Mark mutating samples clearly in the sample table and in the sample README.
- Include `destroy` guidance for every mutating sample.
- Use standard AWS provider credential resolution through environment variables,
  shared config, or the active profile.
- Keep S3 examples private by default and configure S3 Block Public Access.
- Commit `.terraform.lock.hcl` after `terraform init` when provider selections
  change.

Ask first:

- Before adding examples that can create ongoing cost, public exposure, IAM
  privilege changes, cross-account access, or data retention risk.
- Before changing the repo-wide `mise.toml` task interface.
- Before replacing local state with a remote backend.

## Learning Plan

### Stage 0: Existing Foundation

Path: `packages/aws/terraform/caller-identity/`

Purpose:

- Learn AWS provider installation through `terraform init`.
- Learn read-only `data` blocks.
- Learn `output` values.
- Confirm that Terraform and AWS CLI credentials point at the intended identity.

### Stage 1: Resource Lifecycle

Path: `packages/aws/terraform/s3-private-bucket/`

Purpose:

- Learn the resource lifecycle: `plan`, `apply`, inspect outputs, and `destroy`.
- Learn how local state records a managed resource.
- Learn tags and private-by-default S3 settings.
- Learn S3 bucket naming constraints and collision handling.

Expected files:

```text
packages/aws/terraform/s3-private-bucket/
├── terraform.tf
├── providers.tf
├── variables.tf
├── locals.tf
├── main.tf
├── outputs.tf
├── README.md
└── .terraform.lock.hcl
```

Key design:

- `terraform.tf` mirrors the existing provider requirement style from
  `caller-identity`.
- `providers.tf` keeps `provider "aws" {}` empty so credentials and region come
  from the standard AWS provider chain.
- `variables.tf` defines `bucket_prefix` and optional `tags`.
- `locals.tf` builds the bucket name from `bucket_prefix`, current account ID,
  and current region.
- `main.tf` creates:
  - `aws_s3_bucket.this`
  - `aws_s3_bucket_public_access_block.this`
  - read-only data sources for current account and region
- `outputs.tf` exposes bucket name, ARN, and region.
- `README.md` documents prerequisites, cost awareness, commands, collision
  handling, and `destroy`.

Recommended bucket naming:

```text
<bucket_prefix>-<account_id>-<region>
```

This is automatic enough for a learning exercise and still teaches that S3
bucket names are globally unique. If a collision occurs, the user can pass a
different `bucket_prefix` without committing local `.tfvars`.

### Stage 2: Object Lifecycle

Path: `packages/aws/terraform/s3-object/`

Purpose:

- Learn object upload through Terraform.
- Learn dependency ordering between bucket and object resources.
- Learn why `destroy` may fail or behave differently when buckets contain
  objects.

Recommended scope:

- Keep it self-contained by creating its own private bucket in the same root
  module.
- Use a small local sample object committed to the example folder only if the
  content is harmless and intentionally public within the repository.
- Keep `force_destroy` behavior explicit in the README.

### Stage 3: IAM Policy Document Composition

Path: `packages/aws/terraform/iam-policy-document/`

Purpose:

- Learn Terraform expression composition without creating AWS resources.
- Learn `aws_iam_policy_document` as a read-only policy JSON builder.
- Prepare for later bucket policy examples.

Recommended scope:

- Keep this sample read-only.
- Output generated JSON.
- Avoid creating IAM policies or attaching permissions in this stage.

### Stage 4: S3 Bucket Policy

Path: `packages/aws/terraform/s3-bucket-policy/`

Purpose:

- Learn linking a generated policy document to an S3 bucket.
- Learn least-privilege policy shape and policy attachment.
- Learn the security impact of resource policies.

Recommended scope:

- Create a private bucket in the same root module.
- Attach only a narrow policy that does not grant public access.
- Document that bucket policies are security-sensitive and must be reviewed
  before `apply`.

## Folder Structure

The Terraform learning area should keep the current flat operation layout:

```text
packages/aws/
├── index.ts
├── package.json
└── terraform/
    ├── README.md
    ├── caller-identity/
    ├── s3-private-bucket/
    ├── s3-object/
    ├── iam-policy-document/
    └── s3-bucket-policy/
```

Do not introduce a nested service layout such as
`packages/aws/terraform/s3/bucket/` yet. The flat layout is easier to scan, keeps
state isolation obvious, and matches the existing `tf` task:

```bash
mise run tf <operation> <command>
```

## Architecture

Selected approach: staged independent root modules.

Immediate implementation target:

- Add `packages/aws/terraform/s3-private-bucket/`.
- Update `packages/aws/terraform/README.md` with the new mutating sample row and
  a short roadmap.
- Update root `README.md` only if its directory tree needs to mention the new
  sample explicitly.
- Update `AGENTS.md` only if the agent-facing conventions become inaccurate.

Follow-up targets:

- Add `s3-object` as a separate issue or design step.
- Add `iam-policy-document` before `s3-bucket-policy` so policy JSON composition
  is learned before attaching policies.
- Add `s3-bucket-policy` only after the private bucket and policy document
  concepts are understood.

## Acceptance Criteria

Given a contributor reads `packages/aws/terraform/README.md`, when they inspect
the sample table, then `s3-private-bucket` is listed as a mutating sample and the
later learning order is understandable.

Given valid AWS credentials and region are configured, when the contributor runs
`mise run tf s3-private-bucket init`, `fmt -check`, `validate`, and `plan`, then
each command succeeds.

Given the contributor runs `apply` for `s3-private-bucket`, when they inspect the
outputs, then they can see the created bucket name, bucket ARN, and region.

Given the bucket is created by the sample, when the configuration is inspected,
then S3 Block Public Access is configured and the bucket is private by default.

Given the contributor runs `destroy` for `s3-private-bucket`, when the command
finishes, then the resources created by the sample are removed.

Given `terraform init` has run for the sample, when repository status is
checked, then `.terraform.lock.hcl` is trackable and local runtime files remain
ignored.

## Decisions Made

- Use `s3-private-bucket` as the first mutating sample.
  - Rationale: S3 is a recognizable AWS service and teaches resource lifecycle,
    tags, naming, state, and cleanup without needing multiple services.
  - Confidence: 86%.
- Keep the flat `terraform/<operation>/` layout.
  - Rationale: It matches existing repo convention and keeps each sample's state
    isolated.
  - Confidence: 90%.
- Generate the bucket name from `bucket_prefix`, account ID, and region.
  - Rationale: It avoids most beginner naming collisions while still exposing S3
    global uniqueness as a learning point.
  - Confidence: 78%.
- Keep local state for now.
  - Rationale: This repo is a learning workspace with isolated samples, and
    remote backend setup would distract from the first resource lifecycle
    lesson.
  - Confidence: 74%.
- Use `iam-policy-document` before `s3-bucket-policy`.
  - Rationale: It separates policy JSON composition from security-sensitive
    policy attachment.
  - Confidence: 82%.

## Open Questions

- If a bucket name collision happens in practice, should the implementation
  document only `bucket_prefix` override, or should a later sample introduce the
  `random` provider?
- Should `s3-object` use `force_destroy = true` for convenience, or keep the
  safer default and teach manual cleanup?
- Should the roadmap be kept only in `packages/aws/terraform/README.md`, or also
  mirrored in the root `README.md` tree as examples are added?

## Non-Goals

- Building a production-ready S3 module.
- Adding reusable Terraform modules under `modules/`.
- Adding remote backend, workspaces, Terraform Cloud, or CI.
- Creating public buckets or cross-account policies.
- Managing IAM users, roles, or permission boundaries.
- Changing `packages/gc`.

## References

- Terraform documentation: https://developer.hashicorp.com/terraform
- Terraform AWS provider: https://registry.terraform.io/providers/hashicorp/aws
- S3 Block Public Access:
  https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html
