# adk-agent-engine-basic (mutating)

[apps/adk-helloworld](../../../../apps/adk-helloworld/) の ADK agent を **Vertex AI Agent Engine**
（API 名: Reasoning Engine）へ deploy する **mutating** サンプルです。
**infrastructure は Terraform、source archive の生成は `package-agent-engine.sh`** という責務分離を学びます
（cloud-run-service-basic の「image の build/push は `gcloud`」と同じ流儀）。
**実際に課金対象になり得るリソースを作成する**ため、学習後は [`cleanup.md`](./cleanup.md) の手順で `destroy` してください。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `adk-agent-engine-basic` に読み替えます。

## deploy 方式（inline source）

`google_vertex_ai_reasoning_engine` には複数の deploy 方式がありますが、このサンプルは最小の
**inline source（`python_spec`）方式**を使います。

- archive にソース（`hello_world/` + `agent_engine_app.py`）と `requirements.txt` だけを入れ、
  **依存は同梱しません**。Agent Engine の managed runtime が `requirements.txt` を pip install します。
- GCS bucket も `cloudpickle` も使いません（それらは `package_spec` 方式でのみ必要）。そのため前提 API は
  `aiplatform.googleapis.com` だけで足ります。
- entrypoint は ADK の `root_agent` そのものではなく、それを **`AdkApp` で包んだ** `agent_engine`
  変数（`agent_engine_app.py`）を指します。raw な agent を指すと runtime で失敗します。

## 前提（API の有効化）

storage 系・Cloud Run 系と同じく、このサンプルの root module は API を有効化しません。前提となる
`aiplatform.googleapis.com` は専用サンプル [vertex-ai-api-enable](../vertex-ai-api-enable/) で Terraform
管理します。**このサンプルの前に** apply してください。

```bash
mise exec -- terraform -chdir=terraform/gc/vertex-ai-api-enable init
mise exec -- terraform -chdir=terraform/gc/vertex-ai-api-enable apply
```

## 全体の流れ（archive 生成 → apply）

このサンプルは「source archive が apply より先に必要」という、**Terraform の外側で作る artifact への依存**を
持ちます。`package-agent-engine.sh` が生成する `.tar.gz` は gitignore 対象（コミットされない）なので、
clone 直後やクリーン後は **必ず先に生成**してから plan/apply します。

```bash
# 1. source archive を生成（.build/source.tar.gz。gitignore 対象）
bash apps/adk-helloworld/scripts/package-agent-engine.sh
```

> `terraform validate` は archive が無くても通ります（`filebase64` は validate では評価されず、
> plan/apply 時にファイルを読むため）。一方 `plan` / `apply` は archive が必要です。

## 変数の設定

このサンプルは全変数に default があるため、archive を生成済みなら **tfvars 無しでそのまま** plan/apply
できます。default を上書きしたいときだけ [`terraform.tfvars.template`](./terraform.tfvars.template) を
copy して編集します（`terraform.tfvars` は gitignore 対象）。

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `source_archive_path` | | `../../../../apps/adk-helloworld/.build/source.tar.gz` | `filebase64` が読む archive のパス（この `.tf` の場所からの相対パス）。`package-agent-engine.sh` の出力先 |
| `display_name` | | `adk-helloworld` | 作成する Agent Engine の表示名 |
| `description` | | （inline source の説明） | Agent Engine の説明 |
| `region` | | `us-central1` | Agent Engine の region。全 region では使えないため公式サンプルと同じ `us-central1` を default に |
| `python_version` | | `3.13` | managed runtime の Python version（`python_spec.version`、3.9〜3.14） |
| `deletion_policy` | | `DELETE` | 削除ポリシー（`DELETE` / `FORCE` / `PREVENT` / `ABANDON`）。呼び出しテストで session を作ると `DELETE` では destroy が失敗するため、その場合は `FORCE`（[cleanup.md](./cleanup.md) 参照） |

## このサンプルが作るリソース

| リソース | 内容 |
| --- | --- |
| `google_vertex_ai_reasoning_engine.adk_hello` | inline source 方式の Agent Engine。`deletion_policy = "DELETE"`、`spec.source_code_spec.inline_source` に archive を base64 で渡す |

## 操作の流れ

```bash
D=terraform/gc/adk-agent-engine-basic

# 0. 前提 API（vertex-ai-api-enable を先に apply 済みにしておく）

# 1. source archive を生成
bash apps/adk-helloworld/scripts/package-agent-engine.sh

# 2. 初期化・整形チェック・検証
mise exec -- terraform -chdir=$D init
mise exec -- terraform -chdir=$D fmt -check
mise exec -- terraform -chdir=$D validate

# 3. 計画と適用
mise exec -- terraform -chdir=$D plan
mise exec -- terraform -chdir=$D apply
```

> **apply は時間がかかります。** Agent Engine の作成は managed runtime の build/deploy を伴うため
> 数分〜十数分かかることがあります（provider の create timeout は default 20分）。途中で中断しないでください。

## 動作確認

作成後、Agent Engine は Cloud Console または出力されたリソース名で確認できます。

```bash
D=terraform/gc/adk-agent-engine-basic
mise exec -- terraform -chdir=$D output -raw reasoning_engine_name
```

Console で見る場合は **Agent Platform → Deployments**（旧 Agent Engine）の一覧で、表示名 `adk-helloworld` を探します。直リンク:

```
https://console.cloud.google.com/agent-platform/runtimes?project=nck-sakurai
```

> 2026 年に Vertex AI は Gemini Enterprise Agent Platform へ改称され、Agent Engine は **Deployments** になりました。
> この一覧は `aiplatform.googleapis.com` だけで表示できます。`apphub.googleapis.com`（App Hub）の有効化を求められるのは
> **Topology（関係グラフ）ビュー専用**で、deploy 済みエンジンの確認には不要です（有効化しなくて構いません）。

## 呼び出し方（SDK / REST）

このサンプルの学習範囲は **Terraform による deploy** までですが、参考として deploy 済みの `adk-helloworld` を実際に叩く方法を載せます。
**実際に Gemini を呼ぶため課金が発生**します。認証は ADC（事前に `gcloud auth application-default login`）。
`<RESOURCE_ID>` は数値 ID（`terraform output -raw reasoning_engine_name`）で、完全名は
`projects/nck-sakurai/locations/us-central1/reasoningEngines/<RESOURCE_ID>` です。

### Python SDK（推奨）

`AdkApp` で deploy したエージェントは、`create_session` で session を作ってから `stream_query` で問い合わせます
（remote では session ID は `remote_session["id"]`。ローカルの `session.id` と取り出し方が違う点に注意）。

```python
import vertexai
from vertexai import agent_engines

vertexai.init(project="nck-sakurai", location="us-central1")

remote_app = agent_engines.get(
    "projects/nck-sakurai/locations/us-central1/reasoningEngines/<RESOURCE_ID>"
)

remote_session = remote_app.create_session(user_id="u_123")
for event in remote_app.stream_query(
    user_id="u_123",
    session_id=remote_session["id"],
    message="こんにちは、自己紹介して",
):
    print(event)
```

依存はアーカイブと同じ（`google-cloud-aiplatform[agent_engines]` + `google-adk`）。ローカル `.venv`
（`pyproject.toml`）には入れていないため、上記コードを `invoke.py` に保存し、使い捨ての環境で実行するのが楽です:

```bash
mise exec -- uv run \
  --with 'google-cloud-aiplatform[agent_engines]==1.157.0' \
  --with 'google-adk==2.2.0' \
  python invoke.py
```

### REST

session 作成（標準メソッドは `:query`）→ ストリーミング問い合わせ（stream 系は `:streamQuery`）の 2 段階です。
`class_method` に AdkApp のメソッド名、`input` にその引数を渡します。

```bash
ENGINE="https://us-central1-aiplatform.googleapis.com/v1/projects/nck-sakurai/locations/us-central1/reasoningEngines/<RESOURCE_ID>"
TOKEN="$(gcloud auth print-access-token)"

# 1. session を作成（返ってくる output の id を控える）
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  "${ENGINE}:query" \
  -d '{"class_method": "create_session", "input": {"user_id": "u_123"}}'

# 2. stream_query で問い合わせ（<SESSION_ID> は手順 1 で返った id）
curl -s -X POST -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
  "${ENGINE}:streamQuery" \
  -d '{"class_method": "async_stream_query", "input": {"user_id": "u_123", "session_id": "<SESSION_ID>", "message": "こんにちは"}}'
```

> ADK には別系統の HTTP API（`.../reasoningEngines/<RESOURCE_ID>/api/run`、ストリーミングは `/api/run_sse`、
> body は `appName` / `userId` / `sessionId` / `newMessage`）もあります。正確な仕様は下記 doc を参照してください。

参考: [Test deployed agents (ADK)](https://google.github.io/adk-docs/deploy/agent-engine/test/) /
[Use an ADK agent (Google Cloud)](https://docs.cloud.google.com/vertex-ai/generative-ai/docs/agent-engine/use/adk)

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `reasoning_engine_id` | Terraform リソース ID |
| `reasoning_engine_name` | サーバ割り当ての完全リソース名（`projects/.../reasoningEngines/...`） |
| `display_name` | 表示名 |
| `region` | 作成した region |

## cleanup

学習が終わったら必ずリソースを削除してください（課金とリソース残留を避けるため）。
`destroy` の手順と、生成した archive（`.build/`）の片付けは [`cleanup.md`](./cleanup.md) にまとめています。
