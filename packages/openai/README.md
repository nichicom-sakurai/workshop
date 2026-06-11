# packages/openai

OpenAI Agents SDK ([@openai/agents](https://openai.github.io/openai-agents-js/)) の TypeScript 最小 HelloWorld サンプルです。`Agent` と `run` で 1 回だけ agent を実行する導線を提供します。

学習用の入口に絞っており、複数 agent・handoff・tools・MCP・session・guardrails・tracing などは含みません。

## 実行方法

[セットアップ](../../README.md#セットアップ)済みであれば、リポジトリ直下から次を実行します。

```bash
mise run dev openai
```

`OPENAI_API_KEY` が未設定の場合は設定方法の案内を表示して正常終了 (exit 0) します。`mise run dev:all` でまとめて実行しても、API key 無しで途中失敗しません。

## API key の設定

実際に agent を実行するには OpenAI API key が必要です（[発行ページ](https://platform.openai.com/api-keys)）。次のいずれかで設定します。

```bash
# 方法 1: 環境変数で渡す
export OPENAI_API_KEY=sk-...

# 方法 2: .env ファイル (Bun が同ディレクトリの .env を自動読み込み)
cp packages/openai/.env.template packages/openai/.env
# 続けて .env を編集し OPENAI_API_KEY を設定する
```

`.env` と `*.local` は gitignore 済みです。API key は commit しないでください。

### model の上書き (任意)

model は明示せず SDK 既定を使います。`OPENAI_DEFAULT_MODEL` を設定すると上書きできます。

```bash
export OPENAI_DEFAULT_MODEL=gpt-5
```

## 想定出力

- **API key 未設定時**: `[INFO] OPENAI_API_KEY が未設定のため...` の案内を表示して exit 0 で終了します。
- **API key 設定時**: HelloWorld prompt を 1 回実行し、`finalOutput`（1 文程度の応答）を表示します。

## 注意点

- API key を設定して実行すると OpenAI API の利用料金が発生します。
- 依存 (`@openai/agents` / `zod`) は exact version で pin し、`bun.lock` を commit しています（[package.json](./package.json) を参照）。`zod` は `@openai/agents` が peer dependency として要求するため、利用側で exact pin して宣言しています。
