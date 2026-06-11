# agentcore-rag-chat

Terraform サンプル [`terraform/aws/agentcore-rag-chat/`](../../terraform/aws/agentcore-rag-chat/) 用の、supervisor + 3 専門 RAG agent チャット Python app です。

Amazon Bedrock AgentCore Runtime の direct code deployment ZIP として package 化されます。`bedrock-agentcore` / `strands-agents` / `boto3` を使い、次を組み合わせます。

- **supervisor + 3 専門 agent (agents-as-tools)** — supervisor が質問を分類し、専門 agent に委譲して回答を統合します。
  - `aws_service_rag_agent` — AWS サービスの使い方
  - `database_rag_agent` — サンプル業務データ (customers/orders/products)
  - `document_rag_agent` — 社内ドキュメント / ポリシー / FAQ
- **3 つの独立した Bedrock Knowledge Base** — 各専門 agent は自分専用の KB だけを引きます (kb_id を tool のクロージャに束縛し、LLM からは不可視)。
- **AgentCore Memory (short-term)** — 1 ターン (user + assistant) を会話 event として保存し、次ターンで直近履歴を supervisor 入力に前置きして multi-turn を実現します。

> `database_rag_agent` は CSV/Markdown チャンクに対する **意味検索 (vector retrieval)** で答えます。SQL のような厳密な集計・結合 (例: 「C001 の注文件数は?」) は保証されない学習用デモで、本物の structured data Knowledge Base (Redshift / Glue) は対象外です。

このアプリは Python アプリ (`package.json` を持たない) のため `mise run dev` の対象ではありません (実行・検証は下記参照)。

## 構成

```text
main.py            AgentCore Runtime の entry point (@app.entrypoint invoke → build_response に委譲)
chat.py            ローカル対話 CLI (runtime と同じコードパスで multi-turn を試す)
rag_chat/
  config.py        環境変数から実行設定 (generation model / 3 KB ID / Memory ID / region) を読む
  knowledge_base.py  1 つの KB を引く Strands tool を kb_id 束縛で生成
  agents.py        専門 agent を tool 化 (agents-as-tools) し supervisor に束ねる
  memory.py        AgentCore Memory short-term の保存・取得ラッパ
  runtime.py       entrypoint が呼ぶ組み立てロジック (依存は注入可能でテスト容易)
tests/             本物の Bedrock / KB / Memory を呼ばない unittest (fake を注入)
scripts/package.sh AgentCore Runtime 用 ZIP を build
```

## 依存関係の検証

```bash
mise exec -- uv lock --directory apps/agentcore-rag-chat --check
```

## テストの実行

本物の Bedrock / Knowledge Base / Memory を呼ばず、純粋関数と DI (依存性注入) でロジックを検証します。

```bash
mise exec -- uv run --directory apps/agentcore-rag-chat --locked \
  python -m unittest discover -s tests
```

## 環境変数

実行時 (Runtime / ローカル) は次を環境変数で渡します。Terraform sample の `apply` 後の output が値の元になります。

| 変数 | 必須 | 内容 |
| --- | --- | --- |
| `BEDROCK_MODEL_ID` | ○ | supervisor / 専門 agent の generation model ID |
| `AWS_SERVICE_KB_ID` | ○ | AWS サービス用 Knowledge Base ID |
| `DATABASE_KB_ID` | ○ | データ用 Knowledge Base ID |
| `DOCUMENT_KB_ID` | ○ | ドキュメント用 Knowledge Base ID |
| `AGENTCORE_MEMORY_ID` | | 設定すると AgentCore Memory で multi-turn になる (未設定なら単発) |
| `AWS_REGION` / `AWS_DEFAULT_REGION` | | region (boto3 標準の解決) |

必須変数が未設定のとき、`invoke` はクラッシュせず `{"status": "error", "error": "Missing required configuration: ..."}` を返し、`chat.py` は案内を出して正常終了します。

## ローカル実行 (AgentCore ローカルサーバー)

`main.py` を直接実行すると AgentCore Runtime のローカルサーバー (uvicorn) が `127.0.0.1:8080` で起動し、`POST /invocations` と `GET /ping` を公開します (停止は `Ctrl+C`)。

```bash
mise exec -- uv run --directory apps/agentcore-rag-chat --locked python main.py
```

別ターミナルから:

```bash
curl http://127.0.0.1:8080/ping
curl -X POST http://127.0.0.1:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{"prompt":"What is Amazon S3?","session_id":"s1","actor_id":"u1"}'
```

実際に model / KB を呼ぶには、`apply` 後の output を環境変数で渡して起動します (KB ID・Memory ID・model ID・AWS 認証・region)。

## ローカル対話 CLI (multi-turn)

デプロイ後の Runtime と同じコードパスで、複数ターンの会話を試せます。`AGENTCORE_MEMORY_ID` を設定すると AgentCore Memory 経由で前ターンを踏まえた応答になります。

```bash
mise exec -- uv run --directory apps/agentcore-rag-chat --locked \
  env AWS_REGION=ap-northeast-1 AWS_PROFILE=default \
      BEDROCK_MODEL_ID="apac.anthropic.claude-sonnet-4-6" \
      AWS_SERVICE_KB_ID=... DATABASE_KB_ID=... DOCUMENT_KB_ID=... \
      AGENTCORE_MEMORY_ID=... \
  python chat.py
```

`apac.anthropic.claude-...` は cross-region inference profile 形式の ID です。利用可能な ID の調べ方や model access の有効化は [Terraform サンプルの README](../../terraform/aws/agentcore-rag-chat/README.md) を参照してください。AWS 認証は provider 標準の仕組み (`AWS_PROFILE` または `AWS_ACCESS_KEY_ID` 等) を使います。

## AgentCore Runtime 用に package 化

Terraform を実行する前に ZIP artifact を build します。

```bash
apps/agentcore-rag-chat/scripts/package.sh
```

生成物:

```text
apps/agentcore-rag-chat/dist/agentcore-rag-chat.zip
```

この path を Terraform サンプルへ `artifact_zip_path` として渡します (`terraform.tfvars.template` の既定値が出力先を指します)。
