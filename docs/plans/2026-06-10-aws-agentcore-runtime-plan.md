# AWS AgentCore Runtime Terraform Implementation Plan

**Goal:** Add a Terraform-first Amazon Bedrock AgentCore Runtime learning sample that deploys a small Strands Agents + Amazon Bedrock LLM agent with direct code deployment.

**Architecture:** The sample is split into a Python app package under `packages/aws/apps/agentcore-strands-basic/` and a Terraform root module under `packages/aws/terraform/agentcore-runtime-basic/`. The learner builds a ZIP artifact explicitly, then Terraform uploads it to S3 and creates IAM, AgentCore Runtime, and an endpoint. Terraform does not resolve Python dependencies during `apply`.

**Tech Stack:** mise, Python 3.13, uv, unittest, shell, Terraform, AWS provider, AWS CLI, Amazon Bedrock AgentCore, Strands Agents.

**Design Document:** `docs/plans/2026-06-10-aws-agentcore-runtime-design.md`

**Related Issue:** https://github.com/nichicom-sakurai/workshop/issues/14

**Recommended Execution:** Batch (HITL) - Python packaging and Terraform resource creation are separable, and the plan has clear checkpoints after package generation, Terraform validation, and documentation.

---

### Task 1: Pin Python Tooling And Ignore Local Artifacts

**Files:**

- Modify: `mise.toml`
- Modify: `.gitignore`

**Step 1: Write the failing check**

Run:

```bash
mise current python uv
```

Expected: FAIL or missing entries for `python` and `uv`.

Run:

```bash
git check-ignore packages/aws/apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip \
  packages/aws/apps/agentcore-strands-basic/.venv \
  packages/aws/apps/agentcore-strands-basic/.build
```

Expected: FAIL because these paths are not ignored yet.

**Step 2: Write minimal implementation**

Modify `mise.toml`:

```toml
[tools]
aws-cli = "2.34.63"
bun = "1.3.14"
terraform = "1.15.5"
python = "3.13.13"
uv = "0.11.19"
```

Append to `.gitignore`:

```gitignore

# Python local runtime files
.venv/
__pycache__/
*.py[cod]
.pytest_cache/

# AgentCore direct deployment build artifacts
packages/aws/apps/*/.build/
packages/aws/apps/*/dist/
*.zip
```

**Step 3: Run checks to verify**

Run:

```bash
mise install
mise current python uv
git check-ignore packages/aws/apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip \
  packages/aws/apps/agentcore-strands-basic/.venv \
  packages/aws/apps/agentcore-strands-basic/.build
```

Expected: PASS. `mise current` shows `python 3.13.13` and `uv 0.11.19`; `git check-ignore` prints the ignored paths.

**Step 4: Commit**

```bash
git add mise.toml .gitignore
git commit -m "chore(aws): AgentCore 用 Python ツールを固定"
```

---

### Task 2: Add Python Agent Package Metadata

**Files:**

- Create: `packages/aws/apps/agentcore-strands-basic/pyproject.toml`
- Create: `packages/aws/apps/agentcore-strands-basic/README.md`
- Create: `packages/aws/apps/agentcore-strands-basic/uv.lock`

**Step 1: Write the failing check**

Run:

```bash
mise exec -- uv lock --directory packages/aws/apps/agentcore-strands-basic --check
```

Expected: FAIL because the Python project does not exist yet.

**Step 2: Write minimal implementation**

Create `packages/aws/apps/agentcore-strands-basic/pyproject.toml`:

```toml
[project]
name = "agentcore-strands-basic"
version = "0.1.0"
description = "Minimal Strands Agents app for Amazon Bedrock AgentCore Runtime direct code deployment."
readme = "README.md"
requires-python = "==3.13.*"
dependencies = [
  "bedrock-agentcore==1.14.0",
  "strands-agents==1.42.0",
]

[tool.uv]
package = false
```

Create `packages/aws/apps/agentcore-strands-basic/README.md`:

````markdown
# agentcore-strands-basic

Minimal Python agent for the Terraform sample at
`../../terraform/agentcore-runtime-basic/`.

The app is packaged as an Amazon Bedrock AgentCore Runtime direct code
deployment ZIP. It uses `bedrock-agentcore` and `strands-agents` to call an
Amazon Bedrock model configured through `BEDROCK_MODEL_ID`.

This nested app is not run by `mise run dev:all`.

## Verify dependencies

```bash
mise exec -- uv lock --directory packages/aws/apps/agentcore-strands-basic --check
```
````

Generate `uv.lock`:

```bash
mise exec -- uv lock --directory packages/aws/apps/agentcore-strands-basic
```

**Step 3: Run checks to verify**

Run:

```bash
mise exec -- uv lock --directory packages/aws/apps/agentcore-strands-basic --check
```

Expected: PASS.

**Step 4: Commit**

```bash
git add packages/aws/apps/agentcore-strands-basic/pyproject.toml \
  packages/aws/apps/agentcore-strands-basic/README.md \
  packages/aws/apps/agentcore-strands-basic/uv.lock
git commit -m "feat(aws): AgentCore Strands app の依存を追加"
```

---

### Task 3: Add Testable Agent Entrypoint

**Files:**

- Create: `packages/aws/apps/agentcore-strands-basic/main.py`
- Create: `packages/aws/apps/agentcore-strands-basic/tests/test_main.py`

**Step 1: Write the failing test**

Create `packages/aws/apps/agentcore-strands-basic/tests/test_main.py`:

```python
import os
import unittest
from unittest.mock import patch

from main import build_response, get_prompt, missing_model_error


class AgentCoreStrandsBasicTest(unittest.TestCase):
    def test_get_prompt_accepts_prompt_key(self):
        self.assertEqual(get_prompt({"prompt": "Hello"}), "Hello")

    def test_get_prompt_falls_back_to_helpful_message(self):
        self.assertEqual(
            get_prompt({}),
            "No prompt found. Send JSON with a prompt field.",
        )

    def test_missing_model_error_is_json_compatible(self):
        self.assertEqual(
            missing_model_error(),
            {
                "status": "error",
                "error": "BEDROCK_MODEL_ID is not set",
            },
        )

    def test_build_response_uses_injected_responder(self):
        def fake_responder(prompt: str) -> str:
            return f"echo: {prompt}"

        with patch.dict(os.environ, {"BEDROCK_MODEL_ID": "test-model"}, clear=False):
            self.assertEqual(
                build_response({"prompt": "Hello"}, responder=fake_responder),
                {
                    "status": "success",
                    "response": "echo: Hello",
                    "model_id": "test-model",
                },
            )

    def test_build_response_returns_error_without_model_id(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(build_response({"prompt": "Hello"}), missing_model_error())


if __name__ == "__main__":
    unittest.main()
```

**Step 2: Run test to verify it fails**

Run:

```bash
mise exec -- uv run --directory packages/aws/apps/agentcore-strands-basic --locked \
  python -m unittest discover -s tests
```

Expected: FAIL with `ModuleNotFoundError: No module named 'main'`.

**Step 3: Write minimal implementation**

Create `packages/aws/apps/agentcore-strands-basic/main.py`:

```python
import os
from collections.abc import Callable
from typing import Any

from bedrock_agentcore.runtime import BedrockAgentCoreApp
from strands import Agent
from strands.models import BedrockModel


app = BedrockAgentCoreApp()


def get_prompt(payload: dict[str, Any]) -> str:
    prompt = payload.get("prompt")
    if isinstance(prompt, str) and prompt.strip():
        return prompt
    return "No prompt found. Send JSON with a prompt field."


def missing_model_error() -> dict[str, str]:
    return {
        "status": "error",
        "error": "BEDROCK_MODEL_ID is not set",
    }


def invoke_strands(prompt: str) -> str:
    model_id = os.environ["BEDROCK_MODEL_ID"]
    region_name = os.environ.get("AWS_DEFAULT_REGION") or os.environ.get("AWS_REGION")
    model = BedrockModel(model_id=model_id, region_name=region_name)
    agent = Agent(model=model)
    result = agent(prompt)
    content = result.message.get("content", [])
    if content and isinstance(content[0], dict) and "text" in content[0]:
        return str(content[0]["text"])
    return str(result)


def build_response(
    payload: dict[str, Any],
    responder: Callable[[str], str] = invoke_strands,
) -> dict[str, str]:
    model_id = os.environ.get("BEDROCK_MODEL_ID")
    if not model_id:
        return missing_model_error()

    prompt = get_prompt(payload)
    return {
        "status": "success",
        "response": responder(prompt),
        "model_id": model_id,
    }


@app.entrypoint
def agent_invocation(payload: dict[str, Any], context: Any | None = None) -> dict[str, str]:
    return build_response(payload)


if __name__ == "__main__":
    app.run()
```

**Step 4: Run test to verify it passes**

Run:

```bash
mise exec -- uv run --directory packages/aws/apps/agentcore-strands-basic --locked \
  python -m unittest discover -s tests
```

Expected: PASS.

**Step 5: Commit**

```bash
git add packages/aws/apps/agentcore-strands-basic/main.py \
  packages/aws/apps/agentcore-strands-basic/tests/test_main.py
git commit -m "feat(aws): AgentCore Strands app を追加"
```

---

### Task 4: Add Direct Deployment Package Script

**Files:**

- Create: `packages/aws/apps/agentcore-strands-basic/scripts/package.sh`
- Modify: `packages/aws/apps/agentcore-strands-basic/README.md`

**Step 1: Write the failing check**

Run:

```bash
bash -n packages/aws/apps/agentcore-strands-basic/scripts/package.sh
```

Expected: FAIL because the script does not exist.

**Step 2: Write minimal implementation**

Create `packages/aws/apps/agentcore-strands-basic/scripts/package.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$(cd "${script_dir}/.." && pwd)"
build_dir="${app_dir}/.build/package"
dist_dir="${app_dir}/dist"
requirements_file="${app_dir}/.build/requirements.txt"
artifact_path="${dist_dir}/agentcore-strands-basic.zip"

rm -rf "${app_dir}/.build" "${dist_dir}"
mkdir -p "${build_dir}" "${dist_dir}" "$(dirname "${requirements_file}")"

mise exec -- uv export \
  --directory "${app_dir}" \
  --locked \
  --format requirements-txt \
  --no-hashes \
  --output-file "${requirements_file}"

mise exec -- uv pip install \
  --python-version 3.13 \
  --python-platform aarch64-manylinux2014 \
  --only-binary=:all: \
  --target "${build_dir}" \
  -r "${requirements_file}"

cp "${app_dir}/main.py" "${build_dir}/main.py"
find "${build_dir}" -type d -name "__pycache__" -prune -exec rm -rf {} +
find "${build_dir}" -type f -name "*.pyc" -delete

(cd "${build_dir}" && zip -qr "${artifact_path}" .)

echo "${artifact_path}"
```

Update `packages/aws/apps/agentcore-strands-basic/README.md`:

````markdown
## Package

Build the ZIP artifact before running Terraform:

```bash
packages/aws/apps/agentcore-strands-basic/scripts/package.sh
```

The script prints the generated ZIP path. Copy that value into
`packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars` as
`artifact_zip_path`.
````

**Step 3: Run checks to verify**

Run:

```bash
bash -n packages/aws/apps/agentcore-strands-basic/scripts/package.sh
packages/aws/apps/agentcore-strands-basic/scripts/package.sh
test -f packages/aws/apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip
```

Expected: PASS. The package script prints `packages/aws/apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip`.

**Step 4: Commit**

```bash
git add packages/aws/apps/agentcore-strands-basic/scripts/package.sh \
  packages/aws/apps/agentcore-strands-basic/README.md
git commit -m "feat(aws): AgentCore direct deploy package を生成"
```

---

### Task 5: Add Terraform Skeleton And Input Validation

**Files:**

- Create: `packages/aws/terraform/agentcore-runtime-basic/terraform.tf`
- Create: `packages/aws/terraform/agentcore-runtime-basic/providers.tf`
- Create: `packages/aws/terraform/agentcore-runtime-basic/variables.tf`

**Step 1: Write the failing check**

Run:

```bash
mise run tf agentcore-runtime-basic init
mise run tf agentcore-runtime-basic validate
```

Expected: FAIL because the Terraform root module does not exist.

**Step 2: Write minimal implementation**

Create `packages/aws/terraform/agentcore-runtime-basic/terraform.tf`:

```hcl
# Provider requirements:
# Terraform は remote system とやりとりするために provider plugin を使います。
terraform {
  required_version = ">= 1.14.7"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 6.49.0"
    }
  }
}
```

Create `packages/aws/terraform/agentcore-runtime-basic/providers.tf`:

```hcl
# Provider configuration:
# region や認証情報は Terraform AWS provider の標準の仕組み
# （環境変数 / AWS shared config / profile など）から解決します。
provider "aws" {}
```

Create `packages/aws/terraform/agentcore-runtime-basic/variables.tf`:

```hcl
variable "name_prefix" {
  description = "Name prefix for AgentCore learning resources. Start with a lowercase letter; use lowercase letters, numbers, and hyphens."
  type        = string
  default     = "workshop-agentcore"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix は 3〜32文字の小文字・数字・ハイフンで構成し、英小文字で始まり、末尾をハイフンにできません。"
  }
}

variable "artifact_zip_path" {
  description = "Path to the ZIP artifact generated by packages/aws/apps/agentcore-strands-basic/scripts/package.sh."
  type        = string

  validation {
    condition     = endswith(var.artifact_zip_path, ".zip")
    error_message = "artifact_zip_path には package.sh が生成した .zip file path を指定してください。"
  }
}

variable "model_id" {
  description = "Amazon Bedrock model ID used by the Strands agent. Set this in local terraform.tfvars."
  type        = string

  validation {
    condition     = length(trimspace(var.model_id)) > 0
    error_message = "model_id は必須です。利用可能な Amazon Bedrock model ID を terraform.tfvars に設定してください。"
  }
}

variable "bedrock_model_resource_arns" {
  description = "Model ARNs allowed for bedrock:InvokeModel*. Use [\"*\"] for a learning-only broad policy, or provide exact model ARNs."
  type        = list(string)
  default     = ["*"]

  validation {
    condition     = length(var.bedrock_model_resource_arns) > 0
    error_message = "bedrock_model_resource_arns は空にできません。"
  }
}

variable "tags" {
  description = "Tags applied to learning resources."
  type        = map(string)
  default = {
    Project   = "workshop"
    Purpose   = "terraform-learning"
    ManagedBy = "terraform"
  }
}
```

**Step 3: Run checks to verify**

Run:

```bash
mise run tf agentcore-runtime-basic init
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
```

Expected: PASS. Commit the generated `.terraform.lock.hcl`.

**Step 4: Commit**

```bash
git add packages/aws/terraform/agentcore-runtime-basic/terraform.tf \
  packages/aws/terraform/agentcore-runtime-basic/providers.tf \
  packages/aws/terraform/agentcore-runtime-basic/variables.tf \
  packages/aws/terraform/agentcore-runtime-basic/.terraform.lock.hcl
git commit -m "feat(aws): AgentCore Terraform 入力を追加"
```

---

### Task 6: Manage Artifact Bucket And Object

**Files:**

- Create: `packages/aws/terraform/agentcore-runtime-basic/main.tf`
- Create: `packages/aws/terraform/agentcore-runtime-basic/outputs.tf`

**Step 1: Write the failing check**

Run:

```bash
mise run tf agentcore-runtime-basic validate
```

Expected: PASS, but there are no resources. Confirm with:

```bash
rg "aws_s3_bucket|aws_s3_object" packages/aws/terraform/agentcore-runtime-basic
```

Expected: FAIL because no artifact resources exist yet.

**Step 2: Write minimal implementation**

Create `packages/aws/terraform/agentcore-runtime-basic/main.tf`:

```hcl
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  resource_name    = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.region}"
  artifact_key     = "agentcore-strands-basic/${filesha256(var.artifact_zip_path)}.zip"
  runtime_env_vars = {
    BEDROCK_MODEL_ID  = var.model_id
    AWS_DEFAULT_REGION = data.aws_region.current.region
  }
}

resource "aws_s3_bucket" "artifact" {
  bucket        = local.resource_name
  force_destroy = false
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "artifact" {
  bucket = aws_s3_bucket.artifact.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "artifact" {
  bucket = aws_s3_bucket.artifact.id
  key    = local.artifact_key
  source = var.artifact_zip_path

  content_type = "application/zip"
  etag         = filemd5(var.artifact_zip_path)
  tags         = var.tags
}
```

Create `packages/aws/terraform/agentcore-runtime-basic/outputs.tf`:

```hcl
output "artifact_bucket_name" {
  description = "AgentCore direct deployment ZIP を保存する S3 bucket 名。"
  value       = aws_s3_bucket.artifact.bucket
}

output "artifact_object_key" {
  description = "AgentCore direct deployment ZIP の S3 object key。"
  value       = aws_s3_object.artifact.key
}

output "region" {
  description = "この Terraform 実行で使用した AWS region。"
  value       = data.aws_region.current.region
}
```

**Step 3: Run checks to verify**

Run:

```bash
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
```

Expected: PASS.

**Step 4: Commit**

```bash
git add packages/aws/terraform/agentcore-runtime-basic/main.tf \
  packages/aws/terraform/agentcore-runtime-basic/outputs.tf
git commit -m "feat(aws): AgentCore artifact bucket を追加"
```

---

### Task 7: Add AgentCore Runtime Execution IAM

**Files:**

- Create: `packages/aws/terraform/agentcore-runtime-basic/iam.tf`
- Modify: `packages/aws/terraform/agentcore-runtime-basic/main.tf`

**Step 1: Write the failing check**

Run:

```bash
rg "bedrock-agentcore.amazonaws.com|bedrock:InvokeModel" packages/aws/terraform/agentcore-runtime-basic
```

Expected: FAIL because the execution role does not exist.

**Step 2: Write minimal implementation**

Create `packages/aws/terraform/agentcore-runtime-basic/iam.tf`:

```hcl
data "aws_iam_policy_document" "agentcore_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "agentcore_runtime" {
  statement {
    sid    = "ReadDeploymentArtifact"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [aws_s3_object.artifact.arn]
  }

  statement {
    sid    = "ReadDeploymentArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.artifact.arn]
  }

  statement {
    sid    = "WriteRuntimeLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "InvokeBedrockModel"
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = var.bedrock_model_resource_arns
  }
}

resource "aws_iam_role" "agentcore_runtime" {
  name               = "${var.name_prefix}-runtime-role"
  assume_role_policy = data.aws_iam_policy_document.agentcore_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "agentcore_runtime" {
  name   = "${var.name_prefix}-runtime-policy"
  role   = aws_iam_role.agentcore_runtime.id
  policy = data.aws_iam_policy_document.agentcore_runtime.json
}
```

If `local.resource_name` is used for role names and risks exceeding IAM name limits, modify `main.tf` to keep IAM names based on `var.name_prefix` only, as shown above.

**Step 3: Run checks to verify**

Run:

```bash
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
```

Expected: PASS.

**Step 4: Commit**

```bash
git add packages/aws/terraform/agentcore-runtime-basic/iam.tf \
  packages/aws/terraform/agentcore-runtime-basic/main.tf
git commit -m "feat(aws): AgentCore Runtime IAM を追加"
```

---

### Task 8: Create AgentCore Runtime And Endpoint

**Files:**

- Modify: `packages/aws/terraform/agentcore-runtime-basic/main.tf`
- Modify: `packages/aws/terraform/agentcore-runtime-basic/outputs.tf`

**Step 1: Write the failing check**

Run:

```bash
rg "aws_bedrockagentcore_agent_runtime|invoke-agent-runtime" packages/aws/terraform/agentcore-runtime-basic
```

Expected: FAIL because the Runtime and endpoint are not defined yet.

**Step 2: Write minimal implementation**

Append to `packages/aws/terraform/agentcore-runtime-basic/main.tf`:

```hcl
resource "aws_bedrockagentcore_agent_runtime" "this" {
  agent_runtime_name = replace(var.name_prefix, "-", "_")
  description        = "workshop Terraform learning sample for AgentCore Runtime direct code deployment"
  role_arn           = aws_iam_role.agentcore_runtime.arn
  environment_variables = local.runtime_env_vars

  agent_runtime_artifact {
    code_configuration {
      entry_point = ["main.py"]
      runtime     = "PYTHON_3_13"

      code {
        s3 {
          bucket = aws_s3_bucket.artifact.bucket
          prefix = aws_s3_object.artifact.key
        }
      }
    }
  }

  network_configuration {
    network_mode = "PUBLIC"
  }

  protocol_configuration {
    server_protocol = "HTTP"
  }

  tags = var.tags
}

resource "aws_bedrockagentcore_agent_runtime_endpoint" "default" {
  name             = "DEFAULT"
  agent_runtime_id = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
  description      = "Default endpoint for workshop AgentCore Runtime sample."
  tags             = var.tags
}
```

Append to `packages/aws/terraform/agentcore-runtime-basic/outputs.tf`:

```hcl
output "agent_runtime_arn" {
  description = "作成した AgentCore Runtime の ARN。"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn
}

output "agent_runtime_id" {
  description = "作成した AgentCore Runtime の ID。"
  value       = aws_bedrockagentcore_agent_runtime.this.agent_runtime_id
}

output "agent_runtime_endpoint_arn" {
  description = "作成した AgentCore Runtime endpoint の ARN。"
  value       = aws_bedrockagentcore_agent_runtime_endpoint.default.agent_runtime_endpoint_arn
}

output "invoke_command" {
  description = "AgentCore Runtime を AWS CLI で invoke する例。payload と outfile は必要に応じて変更してください。"
  value = join(" ", [
    "mise exec -- aws bedrock-agentcore invoke-agent-runtime",
    "--agent-runtime-arn '${aws_bedrockagentcore_agent_runtime.this.agent_runtime_arn}'",
    "--qualifier DEFAULT",
    "--content-type application/json",
    "--accept application/json",
    "--runtime-session-id '00000000-0000-4000-8000-000000000000-example'",
    "--payload '{\"prompt\":\"Hello from workshop\"}'",
    "response.json",
  ])
}
```

**Step 3: Run checks to verify**

Run:

```bash
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
```

Expected: PASS. If the provider rejects `name = "DEFAULT"` or `environment_variables` formatting, adjust to the exact provider schema while preserving the same behavior.

**Step 4: Commit**

```bash
git add packages/aws/terraform/agentcore-runtime-basic/main.tf \
  packages/aws/terraform/agentcore-runtime-basic/outputs.tf
git commit -m "feat(aws): AgentCore Runtime と endpoint を追加"
```

---

### Task 9: Document Terraform Sample Usage And Cleanup

**Files:**

- Create: `packages/aws/terraform/agentcore-runtime-basic/README.md`
- Create: `packages/aws/terraform/agentcore-runtime-basic/cleanup.md`
- Create: `packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars.template`

**Step 1: Write the failing check**

Run:

```bash
test -f packages/aws/terraform/agentcore-runtime-basic/README.md
test -f packages/aws/terraform/agentcore-runtime-basic/cleanup.md
test -f packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars.template
```

Expected: FAIL because the docs and template do not exist.

**Step 2: Write minimal implementation**

Create `packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars.template`:

```hcl
# Copy this file to terraform.tfvars and set local values:
#   cp terraform.tfvars.template terraform.tfvars
#
# terraform.tfvars is gitignored, so local model and artifact settings stay out
# of the repository.

artifact_zip_path = "../../../apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip"

# Set a model ID that is enabled in your AWS account and region.
# Example only; do not treat this as a repository default:
# model_id = "us.anthropic.claude-3-7-sonnet-20250219-v1:0"
model_id = "<your-enabled-bedrock-model-id>"

# For a learning sample, the default is ["*"] in variables.tf. To scope down,
# set exact model ARNs here.
# bedrock_model_resource_arns = [
#   "arn:aws:bedrock:<region>::foundation-model/<model-id>",
# ]
```

Create `README.md` with these sections:

````markdown
# agentcore-runtime-basic (mutating)

Terraform-first Amazon Bedrock AgentCore Runtime sample. It deploys the Python
app in `../../apps/agentcore-strands-basic/` with direct code deployment.

## Prerequisites

- `mise run bs` has been run.
- AWS credentials and region are configured.
- Amazon Bedrock model access is enabled for the `model_id` you choose.
- The app ZIP has been generated:

```bash
packages/aws/apps/agentcore-strands-basic/scripts/package.sh
```

## Variables

Copy the template and set local values:

```bash
cp packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars.template \
   packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars
```

`terraform.tfvars` is ignored by git.

## Deploy

```bash
mise run tf agentcore-runtime-basic init
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
mise run tf agentcore-runtime-basic plan
mise run tf agentcore-runtime-basic apply
```

## Invoke

After apply, inspect the command:

```bash
mise run tf agentcore-runtime-basic output invoke_command
```

Run the printed `aws bedrock-agentcore invoke-agent-runtime` command and inspect
the output file.

## Cleanup

Follow `cleanup.md`.
````

Create `cleanup.md`:

````markdown
# agentcore-runtime-basic cleanup

Destroy the resources managed by this sample:

```bash
mise run tf agentcore-runtime-basic plan -destroy
mise run tf agentcore-runtime-basic destroy
```

If deletion fails because a runtime session is still active or AWS has not
finished propagating a resource state change, wait a few minutes and retry the
same `destroy` command. Do not manually delete resources unless Terraform state
and the AWS console clearly show a stuck partial deletion.
````

**Step 3: Run checks to verify**

Run:

```bash
rg "AKIA|AWS_SECRET|AWS_PROFILE=|123456789012|nck-sakurai" \
  packages/aws/terraform/agentcore-runtime-basic/README.md \
  packages/aws/terraform/agentcore-runtime-basic/cleanup.md \
  packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars.template
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
```

Expected: `rg` finds no secrets or account-specific values. Terraform checks pass.

**Step 4: Commit**

```bash
git add packages/aws/terraform/agentcore-runtime-basic/README.md \
  packages/aws/terraform/agentcore-runtime-basic/cleanup.md \
  packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars.template
git commit -m "docs(aws): AgentCore Terraform sample の手順を追加"
```

---

### Task 10: Update Repository Discovery Docs

**Files:**

- Modify: `README.md`
- Modify: `AGENTS.md`
- Modify: `packages/aws/terraform/README.md`

**Step 1: Write the failing check**

Run:

```bash
rg "agentcore-runtime-basic|agentcore-strands-basic|AgentCore" README.md AGENTS.md packages/aws/terraform/README.md
```

Expected: FAIL or incomplete mentions.

**Step 2: Write minimal implementation**

Update `README.md`:

- Add `packages/aws/apps/agentcore-strands-basic/` under `packages/aws/`.
- Add `agentcore-runtime-basic` under AWS Terraform samples.
- Note that the nested Python app is not included in `dev:all`.

Update `AGENTS.md`:

- Add the AgentCore app and Terraform sample to the TL;DR and layout sections.
- Mention that the sample uses Python / uv direct code deployment and local ZIP artifacts that must not be committed.
- Mention package-local verification commands.

Update `packages/aws/terraform/README.md`:

- Add a table row:

```markdown
| [agentcore-runtime-basic](./agentcore-runtime-basic/) | mutating | Strands + Amazon Bedrock の Python agent を AgentCore Runtime direct code deployment で deploy する |
```

- Place the sample after lower-risk S3/IAM basics or mark it as advanced.
- Add cleanup warning for AgentCore Runtime resources and Bedrock invocation cost.

**Step 3: Run checks to verify**

Run:

```bash
rg "agentcore-runtime-basic|agentcore-strands-basic|AgentCore" README.md AGENTS.md packages/aws/terraform/README.md
mise run dev aws
git status --porcelain | rg -v 'docs/plans/2026-06-10-aws-agentcore-runtime-(design|plan)\\.md|packages/aws/apps/agentcore-strands-basic|packages/aws/terraform/agentcore-runtime-basic|mise.toml|README.md|AGENTS.md|packages/aws/terraform/README.md|\\.gitignore'
```

Expected: docs mention the new sample, `mise run dev aws` prints `Hello from aws`, and no generated ZIP, build directory, local state, `.tfvars`, credential, or virtualenv file is tracked.

**Step 4: Commit**

```bash
git add README.md AGENTS.md packages/aws/terraform/README.md
git commit -m "docs(aws): AgentCore sample を一覧に追加"
```

---

## Final Verification

Run after all tasks:

```bash
mise current
mise exec -- uv lock --directory packages/aws/apps/agentcore-strands-basic --check
mise exec -- uv run --directory packages/aws/apps/agentcore-strands-basic --locked \
  python -m unittest discover -s tests
bash -n packages/aws/apps/agentcore-strands-basic/scripts/package.sh
packages/aws/apps/agentcore-strands-basic/scripts/package.sh
mise run tf agentcore-runtime-basic init
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
mise run dev aws
git status --porcelain
```

Expected:

- Python tests pass.
- The package script produces a ZIP artifact.
- Terraform init/fmt/validate pass.
- `mise run dev aws` still prints `Hello from aws`.
- `git status --porcelain` does not show generated artifacts, local `.tfvars`, Terraform state, credentials, or virtualenv files.
