# Sample Terraform Read-only AWS Implementation Plan

**Goal:** Add a read-only Terraform AWS sample under `packages/sample/terraform/`
that teaches provider setup, authentication, state, plan/apply flow, and outputs
without creating or changing AWS resources.

**Architecture:** The sample is a small Terraform root module in
`packages/sample/terraform/`. It uses the official AWS provider and only the
read-only `aws_caller_identity` data source, then exposes identity values through
outputs. Root docs and `.gitignore` are updated so the repository accurately
describes the new Terraform sample and keeps local Terraform runtime files out
of version control.

**Tech Stack:** Terraform 1.14.7 through `mise`, HashiCorp AWS provider 6.49.0,
local Terraform backend, no test runner configured.

**Design Document:** `docs/plans/2026-06-07-sample-terraform-readonly-aws-design.md`

**Related Issue:** none

**Recommended Execution:** Sequential - 5 small tasks with direct dependencies
and low coordination overhead.

---

### Task 1: Terraform Provider Skeleton

**Files:**

- Create: `packages/sample/terraform/terraform.tf`
- Create: `packages/sample/terraform/providers.tf`
- Create via command: `packages/sample/terraform/.terraform.lock.hcl`

**Step 1: Write the failing check**

```bash
test -f packages/sample/terraform/terraform.tf
```

**Step 2: Run check to verify it fails**

Run:

```bash
test -f packages/sample/terraform/terraform.tf
```

Expected: FAIL because `packages/sample/terraform/terraform.tf` does not exist.

**Step 3: Write minimal implementation**

Create `packages/sample/terraform/terraform.tf`:

```hcl
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

Create `packages/sample/terraform/providers.tf`:

```hcl
provider "aws" {}
```

**Step 4: Run verification**

Run:

```bash
mise exec -- terraform -chdir=packages/sample/terraform init
mise exec -- terraform -chdir=packages/sample/terraform fmt -check
mise exec -- terraform -chdir=packages/sample/terraform validate
test -f packages/sample/terraform/.terraform.lock.hcl
```

Expected: PASS. `terraform init` creates `.terraform.lock.hcl`; `validate`
passes with only provider configuration.

**Step 5: Commit**

```bash
git add packages/sample/terraform/terraform.tf \
  packages/sample/terraform/providers.tf \
  packages/sample/terraform/.terraform.lock.hcl
git commit -m "feat(sample): Terraform AWS provider 設定を追加"
```

---

### Task 2: Caller Identity Data Source

**Files:**

- Create: `packages/sample/terraform/main.tf`
- Create: `packages/sample/terraform/outputs.tf`

**Step 1: Write the failing check**

```bash
test -f packages/sample/terraform/main.tf
```

**Step 2: Run check to verify it fails**

Run:

```bash
test -f packages/sample/terraform/main.tf
```

Expected: FAIL because `packages/sample/terraform/main.tf` does not exist.

**Step 3: Write minimal implementation**

Create `packages/sample/terraform/main.tf`:

```hcl
data "aws_caller_identity" "current" {}
```

Create `packages/sample/terraform/outputs.tf`:

```hcl
output "account_id" {
  description = "AWS account ID for the credentials used by this Terraform run."
  value       = data.aws_caller_identity.current.account_id
}

output "caller_arn" {
  description = "ARN for the IAM principal used by this Terraform run."
  value       = data.aws_caller_identity.current.arn
}

output "caller_user_id" {
  description = "Unique user ID for the IAM principal used by this Terraform run."
  value       = data.aws_caller_identity.current.user_id
}
```

**Step 4: Run verification**

Run:

```bash
mise exec -- terraform -chdir=packages/sample/terraform fmt -check
mise exec -- terraform -chdir=packages/sample/terraform validate
```

Expected: PASS.

If valid AWS credentials and region are available, also run:

```bash
mise exec -- terraform -chdir=packages/sample/terraform plan
mise exec -- terraform -chdir=packages/sample/terraform apply
```

Expected: PASS. `apply` prints `account_id`, `caller_arn`, and
`caller_user_id` outputs and creates no AWS resources.

If credentials or region are unavailable, record the exact Terraform error and
continue with the successful `fmt` and `validate` evidence.

**Step 5: Commit**

```bash
git add packages/sample/terraform/main.tf \
  packages/sample/terraform/outputs.tf
git commit -m "feat(sample): AWS caller identity サンプルを追加"
```

---

### Task 3: Sample README

**Files:**

- Create: `packages/sample/terraform/README.md`

**Step 1: Write the failing check**

```bash
test -f packages/sample/terraform/README.md
```

**Step 2: Run check to verify it fails**

Run:

```bash
test -f packages/sample/terraform/README.md
```

Expected: FAIL because `packages/sample/terraform/README.md` does not exist.

**Step 3: Write minimal implementation**

Create `packages/sample/terraform/README.md`:

````markdown
# sample Terraform AWS read-only example

AWS provider の認証と Terraform の基本操作を学ぶための最小サンプルです。
このサンプルは `aws_caller_identity` data source を読むだけで、AWS リソースは作成・変更・削除しません。

## 前提

- `mise run bs` が完了していること
- AWS provider が利用できる認証情報と region が設定されていること

認証情報は Terraform AWS provider の標準の仕組みを使います。例:

```bash
export AWS_PROFILE=your-profile
export AWS_REGION=ap-northeast-1
```

または一時的な環境変数を使います。

```bash
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...
export AWS_REGION=ap-northeast-1
```

シークレット値は repository に保存しないでください。

## 使い方

```bash
mise exec -- terraform -chdir=packages/sample/terraform init
mise exec -- terraform -chdir=packages/sample/terraform fmt -check
mise exec -- terraform -chdir=packages/sample/terraform validate
mise exec -- terraform -chdir=packages/sample/terraform plan
mise exec -- terraform -chdir=packages/sample/terraform apply
```

`apply` が成功すると、現在の認証情報に対応する AWS account ID、caller ARN、user ID が output として表示されます。

## 作成されるもの

- `.terraform.lock.hcl`: provider の選択を固定する lock file。commit 対象です。
- `.terraform/`: provider plugin などの local cache。commit しません。
- `terraform.tfstate*`: local state。commit しません。

このサンプルは AWS リソースを作成しないため、通常は `terraform destroy` で削除する対象はありません。
````

**Step 4: Run verification**

Run:

```bash
rg "aws_caller_identity|AWS リソースは作成|terraform apply|\\.terraform.lock.hcl" \
  packages/sample/terraform/README.md
```

Expected: PASS with matches for all required explanations.

**Step 5: Commit**

```bash
git add packages/sample/terraform/README.md
git commit -m "docs(sample): Terraform 学習手順を追加"
```

---

### Task 4: Terraform Git Ignore Rules

**Files:**

- Modify: `.gitignore`

**Step 1: Write the failing check**

```bash
rg '^\\.terraform/$|^terraform\\.tfstate$|^terraform\\.tfstate\\.\\*$|^\\*\\.tfvars$|^\\*\\.tfvars\\.json$' .gitignore
```

**Step 2: Run check to verify it fails**

Run:

```bash
rg '^\\.terraform/$|^terraform\\.tfstate$|^terraform\\.tfstate\\.\\*$|^\\*\\.tfvars$|^\\*\\.tfvars\\.json$' .gitignore
```

Expected: FAIL or incomplete matches because Terraform runtime ignores are not
yet present.

**Step 3: Write minimal implementation**

Modify `.gitignore` by adding a Terraform section:

```gitignore
# Terraform local runtime files
.terraform/
terraform.tfstate
terraform.tfstate.*
*.tfvars
*.tfvars.json
```

Do not add `.terraform.lock.hcl` to `.gitignore`.

**Step 4: Run verification**

Run:

```bash
rg '^\\.terraform/$|^terraform\\.tfstate$|^terraform\\.tfstate\\.\\*$|^\\*\\.tfvars$|^\\*\\.tfvars\\.json$' .gitignore
if rg '^\\.terraform\\.lock\\.hcl$' .gitignore; then
  exit 1
fi
git check-ignore packages/sample/terraform/.terraform/providers || true
git check-ignore packages/sample/terraform/terraform.tfstate
```

Expected: PASS. The runtime files are ignored and `.terraform.lock.hcl` is not
ignored.

**Step 5: Commit**

```bash
git add .gitignore
git commit -m "chore: Terraform ローカル成果物を除外"
```

---

### Task 5: Root Documentation Alignment

**Files:**

- Modify: `README.md`
- Modify: `AGENTS.md`

**Step 1: Write the failing check**

```bash
rg 'terraform is unused|no `\\.tf` files|no real cloud / IaC code exists' AGENTS.md
```

**Step 2: Run check to verify it fails**

Run:

```bash
rg 'terraform is unused|no `\\.tf` files|no real cloud / IaC code exists' AGENTS.md
```

Expected: PASS with stale wording found, which confirms docs need updating.

**Step 3: Write minimal implementation**

Modify `README.md`:

- In the directory or usage section, mention that `packages/sample/terraform/`
  contains the first Terraform AWS read-only sample.
- Link to `packages/sample/terraform/README.md`.
- State that it reads caller identity and does not create AWS resources.

Modify `AGENTS.md`:

- Update the skeleton-stage wording so it no longer claims there are no `.tf`
  files or that Terraform is unused.
- Add a brief note that `packages/sample/terraform/` is a read-only AWS caller
  identity sample.
- Keep the warning that no test runner / typechecker is configured.
- Keep AI-facing instructions in English.

**Step 4: Run verification**

Run:

```bash
rg "packages/sample/terraform|caller identity|read-only|Terraform" README.md AGENTS.md
if rg 'terraform is unused|no `\\.tf` files|no real cloud / IaC code exists' AGENTS.md; then
  exit 1
fi
```

Expected: PASS. Root docs point to the Terraform sample and stale skeleton
claims are removed.

**Step 5: Commit**

```bash
git add README.md AGENTS.md
git commit -m "docs: Terraform サンプルの案内を更新"
```

---

## Final Verification

After all tasks are complete, run:

```bash
mise exec -- terraform -chdir=packages/sample/terraform fmt -check
mise exec -- terraform -chdir=packages/sample/terraform validate
rg "aws_caller_identity|caller_arn|caller_user_id" packages/sample/terraform
rg "packages/sample/terraform|caller identity|read-only|Terraform" README.md AGENTS.md
git status --short
```

If valid AWS credentials and region are available, also run:

```bash
mise exec -- terraform -chdir=packages/sample/terraform plan
mise exec -- terraform -chdir=packages/sample/terraform apply
```

Expected final state:

- Terraform formatting and validation pass.
- Root docs and sample README describe the read-only sample.
- `.terraform.lock.hcl` is tracked or ready to stage.
- `.terraform/` and `terraform.tfstate*` are ignored.
- `plan` / `apply`, when credentials are available, read AWS caller identity and
  create no AWS resources.
