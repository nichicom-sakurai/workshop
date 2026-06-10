# packages/aws AgentCore Runtime Terraform design

Date: 2026-06-10
Issue URL: https://github.com/nichicom-sakurai/workshop/issues/14

## Context

`workshop` is a cloud / IaC learning monorepo. AWS Terraform samples currently
live directly under `packages/aws/terraform/<operation>/` as independent root
modules with separate local state.

The selected direction is to add a Terraform-first Amazon Bedrock AgentCore
Runtime sample that deploys a small Strands Agents + Amazon Bedrock LLM agent
using AgentCore direct code deployment.

Confirmed decisions:

- Use Terraform as the primary deployment surface.
- Use direct code deployment with a Python ZIP artifact, not a container image.
- Use Strands Agents with Amazon Bedrock as the model provider.
- Require `model_id` in local `terraform.tfvars`; do not commit or default a
  model ID.
- Build the ZIP artifact explicitly with a packaging script before
  `terraform apply`.
- Keep AgentCore CLI / CDK deploy flow out of this sample.

Research notes:

- AgentCore direct code deployment packages Python code and dependencies into a
  ZIP archive that AgentCore Runtime mounts for execution.
- AgentCore Python direct deployment can use `BedrockAgentCoreApp` entrypoints
  or HTTP endpoints such as `/invocations`.
- AgentCore direct deployment dependencies must be compatible with the Runtime
  execution environment, including Linux arm64 wheels for non-pure-Python
  packages.
- `hashicorp/aws` provider `6.49.0` includes
  `aws_bedrockagentcore_agent_runtime` with `code_configuration`, and includes
  `aws_bedrockagentcore_agent_runtime_endpoint`.
- Strands Agents can invoke Amazon Bedrock models through `BedrockModel` and
  needs Bedrock model invocation permissions.

References:

- https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-get-started-code-deploy-python.html
- https://docs.aws.amazon.com/bedrock-agentcore/latest/devguide/runtime-http-protocol-contract.html
- https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/v6.49.0/website/docs/r/bedrockagentcore_agent_runtime.html.markdown
- https://raw.githubusercontent.com/hashicorp/terraform-provider-aws/v6.49.0/website/docs/r/bedrockagentcore_agent_runtime_endpoint.html.markdown
- https://strandsagents.com/docs/user-guide/concepts/model-providers/amazon-bedrock/

## Boundaries

Never:

- Do not deploy this sample through AgentCore CLI or CDK.
- Do not use ECR or container images in this first AgentCore sample.
- Do not generate packages from Terraform `local-exec` or other apply-time side
  effects.
- Do not hardcode AWS credentials, profile names, account IDs, local paths, or
  default Bedrock model IDs.
- Do not commit local `terraform.tfvars`, state files, `.terraform/`, build
  directories, ZIP artifacts, virtual environments, or credential files.
- Do not add AgentCore Memory, Gateway, Browser, Code Interpreter, policy
  engine, OAuth authorizers, VPC networking, or production environment folders
  in this issue.
- Do not present the IAM policy as production-ready least privilege when the
  sample deliberately keeps model resource scoping simple.

Always:

- Keep the Terraform sample self-contained under
  `packages/aws/terraform/agentcore-runtime-basic/`.
- Keep the agent code self-contained under
  `packages/aws/apps/agentcore-strands-basic/`.
- Keep `model_id` required and local-only via `terraform.tfvars`.
- Provide a committed `terraform.tfvars.template` with placeholders only.
- Keep package creation as an explicit pre-apply command documented in the
  app README and Terraform README.
- Use root `mise.toml` for any new repeatable tooling needed by the sample, with
  exact versions.
- Commit Python dependency lock files if a Python project manager creates them.
- Add the sample to `packages/aws/terraform/README.md`, root `README.md`, and
  `AGENTS.md`.
- Document setup, package, `init`, `fmt`, `validate`, `plan`, `apply`,
  `invoke-agent-runtime`, and `destroy`.
- Make cleanup clear because AgentCore Runtime, S3, IAM, logs, and model
  invocation can create account state or cost.

Ask first:

- Before changing the repo-wide `mise run tf` interface.
- Before adding an AgentCore CLI dependency or generated AgentCore CLI project
  files.
- Before adding a container build, ECR repository, or Dockerfile.
- Before adding Memory, Gateway, Browser, Code Interpreter, OAuth, VPC, or
  observability configuration beyond what AgentCore Runtime creates by default.
- Before broadening this into a production deployment pattern.

## Architecture

Selected approach: **Explicit package + Terraform apply**

Confidence: 84%.

The sample has two cooperating but separate parts:

1. App package:
   `packages/aws/apps/agentcore-strands-basic/`
2. Terraform root module:
   `packages/aws/terraform/agentcore-runtime-basic/`

The learner first builds a ZIP artifact from the app directory. Terraform then
uploads that artifact to a private S3 bucket, creates an AgentCore Runtime
execution role, creates the AgentCore Runtime from the uploaded ZIP, and creates
an endpoint for invocation.

### App Package

Proposed files:

```text
packages/aws/apps/agentcore-strands-basic/
├── README.md
├── main.py
├── pyproject.toml
├── uv.lock
└── scripts/
    └── package.sh
```

Responsibilities:

- `main.py`
  - Defines a small `BedrockAgentCoreApp` entrypoint.
  - Reads the user prompt from the incoming payload.
  - Reads `BEDROCK_MODEL_ID` from environment variables.
  - Uses Strands Agents with a Bedrock model to produce one response.
  - Returns a small JSON-compatible response.
- `pyproject.toml`
  - Declares only the Python dependencies needed by this app, expected to
    include `bedrock-agentcore` and `strands-agents`.
- `uv.lock`
  - Pins the resolved dependency closure for repeatable packaging.
- `scripts/package.sh`
  - Uses `set -euo pipefail`.
  - Cleans and recreates a local build directory.
  - Installs dependencies into the build directory using `uv pip install` with
    Linux arm64-compatible options.
  - Copies `main.py` into the build directory.
  - Removes `__pycache__` and other generated bytecode.
  - Creates a ZIP artifact outside the app source files.
  - Prints the artifact path to pass to Terraform.

The design intentionally keeps packaging outside Terraform. Terraform should
consume an artifact path; it should not perform dependency resolution during
`apply`.

### Terraform Root Module

Proposed files:

```text
packages/aws/terraform/agentcore-runtime-basic/
├── README.md
├── cleanup.md
├── iam.tf
├── main.tf
├── outputs.tf
├── providers.tf
├── terraform.tf
├── terraform.tfvars.template
└── variables.tf
```

Responsibilities:

- `terraform.tf`
  - Mirrors the existing AWS sample provider requirement style.
  - Uses the same pinned AWS provider policy already present in current AWS
    Terraform samples unless implementation research shows a newer minimum is
    required.
- `providers.tf`
  - Keeps `provider "aws" {}` empty so region and credentials come from the
    standard AWS provider chain.
- `variables.tf`
  - Requires `model_id` with no default.
  - Accepts `artifact_zip_path` so the learner passes the output from
    `scripts/package.sh`.
  - Accepts safe naming inputs such as `name_prefix` and optional `tags`.
  - Allows a simple Bedrock model resource ARN list for IAM scoping, defaulting
    conservatively for a learning sample if exact model ARN mapping is not
    practical.
- `main.tf`
  - Reads current caller identity and region.
  - Creates a private artifact S3 bucket and public access block.
  - Uploads the ZIP with `aws_s3_object`.
  - Creates `aws_bedrockagentcore_agent_runtime` using `code_configuration`.
  - Creates `aws_bedrockagentcore_agent_runtime_endpoint`.
  - Sets environment variables such as `BEDROCK_MODEL_ID` and
    `AWS_DEFAULT_REGION` for the runtime.
- `iam.tf`
  - Creates the AgentCore Runtime execution role.
  - Grants the runtime access to the deployment artifact object.
  - Grants CloudWatch Logs permissions needed by the runtime.
  - Grants Bedrock model invocation permissions for the configured sample scope.
- `outputs.tf`
  - Exposes artifact bucket name, runtime ARN, runtime ID, endpoint ARN, and an
    invocation command skeleton.
- `terraform.tfvars.template`
  - Shows placeholders for `model_id` and `artifact_zip_path`.
  - Contains no real account IDs, profile names, secrets, or personal paths.
- `README.md`
  - Documents prerequisites, Bedrock model access, packaging, Terraform
    commands, invocation, expected failures, cost awareness, and cleanup.
- `cleanup.md`
  - Documents `terraform plan -destroy` and `terraform destroy`.
  - Explains any manual checks needed if destroy fails because of active
    runtime sessions or AWS eventual consistency.

### Repository Updates

Concrete file-change list:

- `mise.toml`
  - Add exact Python and uv tool pins only if needed to make package generation
    repeatable from this repo.
- `.gitignore`
  - Ignore app-local build output, ZIP artifacts, `.venv/`, and local Python
    caches if existing ignore rules do not already cover them.
- `README.md`
  - Add `packages/aws/apps/agentcore-strands-basic/` to the layout.
  - Mention the new AgentCore Terraform sample in the AWS sample section.
- `AGENTS.md`
  - Update the AWS package summary and gotchas so agents know the sample has
    Python packaging and direct code deployment.
- `packages/aws/terraform/README.md`
  - Add `agentcore-runtime-basic` as a mutating sample.
  - Add it to the learning sequence after lower-risk S3/IAM basics or clearly
    mark it as an advanced AWS sample.
- `packages/aws/apps/agentcore-strands-basic/*`
  - Add the Strands + Bedrock agent and packaging docs.
- `packages/aws/terraform/agentcore-runtime-basic/*`
  - Add the Terraform root module and docs.

## Acceptance Criteria

- Given the learner runs the app packaging script, when dependencies are
  resolved successfully, then an AgentCore Runtime-compatible ZIP artifact is
  generated and its path is printed.
- Given the learner copies `terraform.tfvars.template` to local
  `terraform.tfvars`, when `model_id` or `artifact_zip_path` is missing, then
  Terraform validation or the README makes the missing setting clear.
- Given a valid local artifact and Bedrock model access, when the learner runs
  `terraform init`, `terraform fmt -check`, `terraform validate`, `terraform
  plan`, and `terraform apply`, then Terraform creates the artifact bucket,
  uploaded object, IAM role, AgentCore Runtime, and runtime endpoint.
- Given deployment succeeds, when the learner invokes the endpoint with AWS CLI
  `bedrock-agentcore invoke-agent-runtime`, then the README provides a concrete
  command using Terraform outputs.
- Given model access, IAM, region, or artifact compatibility is wrong, when
  invocation fails, then the README points to the likely failure class and the
  first commands to inspect it.
- Given the learner has finished, when they follow `cleanup.md`, then
  `terraform destroy` removes the sample-managed resources.
- Given the implementation is complete, when checking repository state, then no
  build artifact, ZIP, local state, local variables, credential, or virtualenv
  file is tracked by git.

## Decisions Made

- **Terraform-first deployment** (probability: 84%):
  Matches the repo's AWS learning-sample convention and keeps the infrastructure
  lifecycle visible.
- **Direct code deployment / CodeZip** (probability: 78%):
  Avoids ECR and container build requirements for the first AgentCore sample.
  It fits a small Strands app and follows AWS guidance for simpler packages.
- **Strands + Bedrock LLM agent** (probability: 72%):
  Gives the sample real AgentCore agent behavior instead of a deterministic
  echo response, accepting the added IAM, model access, and cost considerations.
- **Required local `model_id`** (probability: 82%):
  Avoids baking a time-sensitive or region-sensitive model ID into the repo.
- **Explicit packaging script** (probability: 84%):
  Keeps dependency resolution and platform packaging failures outside
  Terraform `apply`, making errors easier to understand.
- **No AgentCore CLI deploy path** (probability: 80%):
  Keeps ownership clear. AgentCore CLI can be documented as a reference, but it
  should not own resources in this Terraform sample.

## Open Questions

- Which exact Python and uv versions should implementation pin in `mise.toml`?
- Which Bedrock model ID should the learner set in local `terraform.tfvars` for
  their enabled model access and region?
- Whether the initial IAM policy should default Bedrock model resource scope to
  `"*"` for learning ergonomics or require explicit model ARNs from the start.

## Non-Goals

- Production AgentCore deployment architecture.
- AgentCore CLI or CDK resource ownership.
- Container image deployment, Docker, or ECR.
- AgentCore Memory, Gateway, Browser, Code Interpreter, evaluations, policy
  engine, OAuth, or VPC networking.
- Repository-wide Python application framework decisions beyond this one sample.
- Fully automated remote AWS verification in CI.
