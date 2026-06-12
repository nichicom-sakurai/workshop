# agentcore-rag-chat (mutating)

Amazon Bedrock AgentCore 上に、**supervisor + 3 専門 RAG agent** のチャットを構築する **mutating** サンプルです。3 つの専門 agent はそれぞれ独立した Bedrock Knowledge Base（vector store は **S3 Vectors**）を検索し、supervisor が質問を分類・委譲・統合します。会話履歴は **AgentCore Memory**（short-term）で session / actor 単位に保持します。

アプリ本体は [`apps/agentcore-rag-chat/`](../../../apps/agentcore-rag-chat/)（Python + Strands Agents + bedrock-agentcore）です。

このサンプルは AgentCore Runtime / endpoint / Memory、3 つの Knowledge Base、S3 Vectors の vector bucket と 3 つの index、data source 用 S3 bucket、IAM role 2 つ（runtime 実行用 / KB service 用）を作成します。**AgentCore Runtime・Bedrock model invocation・Knowledge Base・S3 Vectors・Memory は利用量に応じて課金される可能性があります。** 学習後は [`cleanup.md`](./cleanup.md) に従って削除してください。

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `agentcore-rag-chat` に読み替えます。

## 構成図（概念）

```text
invoke(prompt) ──▶ AgentCore Runtime (apps/agentcore-rag-chat)
                      │  ├─ supervisor agent ──┬─▶ aws_service_rag_agent ─▶ Retrieve ─▶ KB(aws-service) ─▶ S3 Vectors index
                      │                        ├─▶ database_rag_agent   ─▶ Retrieve ─▶ KB(database)    ─▶ S3 Vectors index
                      │                        └─▶ document_rag_agent   ─▶ Retrieve ─▶ KB(document)    ─▶ S3 Vectors index
                      └─ AgentCore Memory (short-term: session/actor 単位の会話 event)
```

## 前提

- `mise run bs` または `mise install` が完了していること
- AWS provider が利用できる認証情報と region が設定されていること
- 利用する **generation model と embedding model 両方**への Amazon Bedrock model access が、その region で有効であること（embedding は既定で `amazon.titan-embed-text-v2:0`）
- 対象 region で **S3 Vectors + Bedrock Knowledge Base** が利用可能であること（未対応の region では `apply` が失敗します。利用可能な region で実行するか、別 vector store への置き換えを検討してください）
- [`apps/agentcore-rag-chat/`](../../../apps/agentcore-rag-chat/) の ZIP artifact を作成済みであること

## 1. AgentCore 用 ZIP artifact を作成

```bash
apps/agentcore-rag-chat/scripts/package.sh
```

生成される artifact:

```text
apps/agentcore-rag-chat/dist/agentcore-rag-chat.zip
```

Terraform はこの ZIP を `artifact_zip_path`（この root module ディレクトリからの相対 path）で受け取り、apply 時に S3 へ upload します。`terraform.tfvars.template` の既定値が上記の出力先を指します。

## 2. 変数を設定

```bash
cp terraform/aws/agentcore-rag-chat/terraform.tfvars.template \
   terraform/aws/agentcore-rag-chat/terraform.tfvars
# terraform.tfvars を編集し、model_id を設定
```

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `artifact_zip_path` | ○ | （なし） | package script で作成した ZIP artifact path（この root module からの相対。template の既定値が出力先を指す） |
| `model_id` | ○ | （なし） | supervisor / 専門 agent が使う generation model ID |
| `embedding_model_id` | | `amazon.titan-embed-text-v2:0` | Knowledge Base の embedding model ID |
| `embedding_dimensions` | | `1024` | 埋め込み次元数（KB と S3 Vectors index で共有。model に合わせる） |
| `name_prefix` | | `agentcore-rag` | AgentCore / KB / S3 / IAM の名前に使う prefix |
| `event_expiry_duration` | | `30` | AgentCore Memory の会話 event 保持日数（7〜365） |
| `bedrock_model_resource_arns` | | `["*"]` | runtime role に許可する generation model resource ARN |
| `tags` | | `Project` / `Purpose` / `ManagedBy` | 作成リソースに付与する tag |

`embedding_dimensions` は `embedding_model_id` が対応する値にしてください（`titan-embed-text-v2` は 256 / 512 / 1024）。`bedrock_model_resource_arns = ["*"]` は学習サンプルの portability を優先した default です。embedding model 側の許可は KB service role 内で `embedding_model_id` の ARN に絞っています。

## 3. Terraform を実行

```bash
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat init
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat fmt -check
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat validate
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat plan
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat apply
```

## 4. Knowledge Base を取り込む（ingestion / sync）

`apply` は Knowledge Base・data source・S3 への文書 upload までを行いますが、**ベクトル化（ingestion）は Terraform 管理外**です。`apply` 後（および文書を変更したとき）に各 data source の ingestion job を起動します。

```bash
# 3 ドメイン分の起動コマンドが output に並びます。
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat output start_ingestion_commands
```

出力された `aws bedrock-agent start-ingestion-job ...` を順に実行し、進捗は次で確認します。

```bash
aws bedrock-agent list-ingestion-jobs \
  --knowledge-base-id <kb_id> --data-source-id <ds_id> --region <region>
```

ingestion が `COMPLETE` になるまでは、その KB を引く専門 agent は文書を見つけられません。

## 5. Invoke / ローカル対話

`apply` 後に `invoke_command` output で AWS CLI からの呼び出し例を確認できます。

```bash
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat output -raw invoke_command
```

KB ID / Memory ID を環境変数に渡せば、デプロイ後の Runtime と同じコードパスでローカル対話 CLI も使えます（multi-turn の確認）。

```bash
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat output knowledge_base_ids
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat output -raw memory_id
# 値を AWS_SERVICE_KB_ID / DATABASE_KB_ID / DOCUMENT_KB_ID / AGENTCORE_MEMORY_ID に渡して
# apps/agentcore-rag-chat の chat.py を起動（詳細は app の README 参照）
```

## このサンプルが作るリソース

- `aws_s3_bucket.artifact` / `aws_s3_bucket_public_access_block.artifact` / `aws_s3_object.artifact`（runtime ZIP）
- `aws_s3_bucket.data` / `aws_s3_bucket_public_access_block.data` / `aws_s3_object.data`（KB 用サンプル文書）
- `aws_s3vectors_vector_bucket.this` / `aws_s3vectors_index.this`（3 つ）
- `aws_bedrockagent_knowledge_base.this`（3 つ）/ `aws_bedrockagent_data_source.this`（3 つ）
- `aws_bedrockagentcore_memory.this`
- `aws_bedrockagentcore_agent_runtime.this` / `aws_bedrockagentcore_agent_runtime_endpoint.sample`
- `aws_iam_role.runtime` / `aws_iam_role_policy.runtime`（実行用：artifact 取得 / logs / model invoke / `bedrock:Retrieve` / Memory）
- `aws_iam_role.kb_service` / `aws_iam_role_policy.kb_service`（KB service 用：embedding invoke / S3 data 読み取り / S3 Vectors 読み書き）

検索（query）時の S3 Vectors アクセスは KB が KB service role で代行するため、runtime 実行ロールには S3 Vectors 権限を付けていません。

## cleanup

学習後は [`cleanup.md`](./cleanup.md) の手順で削除します。
