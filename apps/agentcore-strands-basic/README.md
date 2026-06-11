# agentcore-strands-basic

Terraform サンプル `terraform/aws/agentcore-runtime-basic/` 用の最小 Python agent です。

このアプリは Amazon Bedrock AgentCore Runtime の direct code deployment ZIP として
package 化されます。`bedrock-agentcore` と `strands-agents` を使い、`BEDROCK_MODEL_ID`
で設定した Amazon Bedrock model を呼び出します。

このアプリは Python アプリ（`package.json` を持たない）のため `mise run dev` の対象ではありません（実行・検証は下記参照）。

## 依存関係の検証

```bash
mise exec -- uv lock --directory apps/agentcore-strands-basic --check
```

## テストの実行

```bash
mise exec -- uv run --directory apps/agentcore-strands-basic --locked \
  python -m unittest discover -s tests
```

## ローカル実行

`main.py` を直接実行すると AgentCore Runtime のローカルサーバー (uvicorn) が起動し、`127.0.0.1:8080` で `POST /invocations`（エントリポイント）と `GET /ping`（ヘルスチェック）を公開します。AgentCore へ deploy する前の動作確認に使います（停止は `Ctrl+C`）。

```bash
mise exec -- uv run --directory apps/agentcore-strands-basic --locked python main.py
```

別ターミナルから呼び出します。

```bash
curl http://127.0.0.1:8080/ping
curl -X POST http://127.0.0.1:8080/invocations \
  -H "Content-Type: application/json" \
  -d '{"prompt":"Hello from local"}'
```

`BEDROCK_MODEL_ID` 未設定のときは `{"status": "error", "error": "BEDROCK_MODEL_ID is not set"}` が返ります（クラッシュしません）。実際に model を呼ぶには、ID と AWS 認証情報・region を渡して起動します。

```bash
mise exec -- uv run --directory apps/agentcore-strands-basic --locked \
  env BEDROCK_MODEL_ID="jp.anthropic.claude-sonnet-4-6" AWS_REGION=ap-northeast-1 AWS_PROFILE=default \
  python main.py
```

`jp.anthropic.claude-sonnet-4-6` は cross-region inference profile 形式の ID です（`jp.` は日本リージョン向けのプレフィックス。APAC 全体向けの `apac.` も使えます）。ap-northeast-1 などでは on-demand 形式の基盤モデル ID（例: `anthropic.claude-sonnet-4-6`）は呼び出せず、`ValidationException`（`on-demand throughput isn't supported`）になるため inference profile 形式が必要です。利用可能な ID の調べ方は [Terraform サンプルの README](../../terraform/aws/agentcore-runtime-basic/README.md) と同ディレクトリの `terraform.tfvars.template` を参照してください。AWS 認証は provider 標準の仕組み（`AWS_PROFILE` または `AWS_ACCESS_KEY_ID` 等）を使います。

## AgentCore Runtime 用に package 化

Terraform を実行する前に ZIP artifact を build します。

```bash
apps/agentcore-strands-basic/scripts/package.sh
```

このスクリプトは次を生成します。

```text
apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip
```

この path を Terraform サンプルへ `artifact_zip_path` として渡します。
