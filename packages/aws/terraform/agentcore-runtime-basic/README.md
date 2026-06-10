# agentcore-runtime-basic (mutating)

Amazon Bedrock AgentCore Runtime に、Strands Agents + Amazon Bedrock の最小
Python agent を direct code deployment ZIP で deploy する **mutating** サンプルです。

このサンプルは AgentCore Runtime、custom endpoint、IAM role / policy、S3 artifact
bucket / object を作成します。AgentCore Runtime と Bedrock model invocation は利用量に
応じて課金される可能性があります。学習後は [`cleanup.md`](./cleanup.md) に従って削除してください。

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `agentcore-runtime-basic` に読み替えます。

## 前提

- `mise run bs` または `mise install` が完了していること
- AWS provider が利用できる認証情報と region が設定されていること
- 利用する Amazon Bedrock model への model access が有効であること
- [`../../apps/agentcore-strands-basic/`](../../apps/agentcore-strands-basic/) の ZIP artifact を作成済みであること

## 1. AgentCore 用 ZIP artifact を作成

```bash
packages/aws/apps/agentcore-strands-basic/scripts/package.sh
```

生成される artifact:

```text
packages/aws/apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip
```

Terraform はこの ZIP を `artifact_zip_path` で受け取り、apply 時に S3 へ upload します。
Terraform の `apply` 中に Python dependency 解決は行いません。

## 2. 変数を設定

template を copy して自分の値を設定してください（`terraform.tfvars` は gitignore 対象で commit されません）。

```bash
cp packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars.template \
   packages/aws/terraform/agentcore-runtime-basic/terraform.tfvars
# terraform.tfvars を編集し、model_id を設定
```

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `artifact_zip_path` | ○ | （なし） | package script で作成した ZIP artifact path |
| `model_id` | ○ | （なし） | Strands agent が使う Amazon Bedrock model ID |
| `name_prefix` | | `agentcore-basic` | S3 / IAM / AgentCore の名前に使う prefix |
| `bedrock_model_resource_arns` | | `["*"]` | runtime role に許可する Bedrock model resource ARN |
| `tags` | | `Project` / `Purpose` / `ManagedBy` | 作成リソースに付与する tag |

`bedrock_model_resource_arns = ["*"]` は学習サンプルの portability を優先した default です。
production では利用する model ARN へ絞ってください。

## 3. Terraform を実行

```bash
mise run tf agentcore-runtime-basic init
mise run tf agentcore-runtime-basic fmt -check
mise run tf agentcore-runtime-basic validate
mise run tf agentcore-runtime-basic plan
mise run tf agentcore-runtime-basic apply
```

## 4. Invoke

`apply` 後に `invoke_command` output を確認できます。

```bash
mise run tf agentcore-runtime-basic output -raw invoke_command
```

手動で実行する場合:

```bash
aws bedrock-agentcore invoke-agent-runtime \
  --agent-runtime-arn "$(mise exec -- terraform -chdir=packages/aws/terraform/agentcore-runtime-basic output -raw agent_runtime_arn)" \
  --qualifier "$(mise exec -- terraform -chdir=packages/aws/terraform/agentcore-runtime-basic output -raw agent_runtime_endpoint_name)" \
  --content-type application/json \
  --accept application/json \
  --cli-binary-format raw-in-base64-out \
  --payload '{"prompt":"Hello from workshop"}' \
  response.json
cat response.json
```

## このサンプルが作るリソース

- `aws_s3_bucket.artifact`
- `aws_s3_bucket_public_access_block.artifact`
- `aws_s3_object.artifact`
- `aws_iam_role.runtime`
- `aws_iam_role_policy.runtime`
- `aws_bedrockagentcore_agent_runtime.this`
- `aws_bedrockagentcore_agent_runtime_endpoint.sample`

AgentCore は Runtime 作成時に `DEFAULT` endpoint も作成します。この Terraform sample では、
custom endpoint の lifecycle も学ぶために `sample` endpoint を Terraform 管理で追加します。

## cleanup

学習後は [`cleanup.md`](./cleanup.md) の手順で削除します。
