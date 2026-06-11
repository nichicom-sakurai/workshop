# adk-helloworld

[Google Agent Development Kit (ADK)](https://adk.dev/) を学ぶための、最小の Python HelloWorld agent です。
`hello_world/agent.py` が `root_agent` を 1 つ公開するだけのサンプルで、まず **Gemini API key 方式**でローカル実行（`adk run` / `adk web`）を学び、その後 **Vertex AI 方式**や **Cloud Run deploy** へ発展できる構成にしています。

この nested app は `mise run dev:all` の対象外です（`dev:all` は `packages/` 直下のみを走査します）。

## ファイル構成

| ファイル | 内容 |
| --- | --- |
| `pyproject.toml` | 依存を `google-adk` の固定バージョンに pin。`[tool.uv] package = false` の virtual project |
| `uv.lock` | 依存解決を固定する lockfile（再現可能な install のためコミット） |
| `hello_world/__init__.py` | `from . import agent`。ADK にエージェントを発見させる入口 |
| `hello_world/agent.py` | `root_agent`（HelloWorld agent）の定義本体 |
| `hello_world/.env.template` | API key などのテンプレート。実 `.env` は gitignore 対象（コミットしない） |
| `tests/test_agent.py` | `root_agent` の静的な定義（名前 / model / 指示文）を検証する unittest |
| `agent-engine/agent_engine_app.py` | Agent Engine の entrypoint。`root_agent` を `AdkApp` で包んだ `agent_engine` を公開（archive root 専用・ローカル run では未使用） |
| `agent-engine/requirements.txt` | Agent Engine runtime の依存（`google-adk` + `google-cloud-aiplatform[agent_engines]`）。`google-adk` は `pyproject.toml` と同期 |
| `scripts/package-agent-engine.sh` | Agent Engine 用 source archive（`.tar.gz`）を生成する script。出力 `.build/` は gitignore 対象 |
| `tests/test_agent_engine_packaging.py` | pin 同期と entrypoint 変数名を静的検証するガードテスト（import せずテキスト検査） |

> ADK の規約では、エージェントは Python パッケージ（フォルダ）として置き、
> `__init__.py` が `from . import agent` で本体を読み込み、`agent.py` が `root_agent` を公開します。
> `adk run hello_world` / `adk web` は、この `hello_world/` パッケージの **1 つ上の階層**（このディレクトリ）から実行します。

## 依存関係の検証

```bash
mise exec -- uv lock --directory apps/adk-helloworld --check
```

## テストの実行

`root_agent` の構築（ネットワーク呼び出しなし）を検証するため、API key 無しで通ります。

```bash
mise exec -- uv run --directory apps/adk-helloworld --locked \
  python -m unittest discover -s tests
```

## ローカル実行（Gemini API key 方式・主手順）

### 1. API key を用意して `.env` を作る

[Google AI Studio](https://aistudio.google.com/apikey) で API key を取得し、テンプレートから `.env` を作って key を書き込みます。`.env` は agent パッケージ（`hello_world/`）の中に置きます。

```bash
cp apps/adk-helloworld/hello_world/.env.template \
  apps/adk-helloworld/hello_world/.env
# apps/adk-helloworld/hello_world/.env を編集し、
# GOOGLE_API_KEY=YOUR_API_KEY_HERE を実 key に置き換える
```

> コミットされるのは `.env.template` だけです。実 `.env`（および実 API key）は repository に保存しないでください（`.gitignore` 済み）。

### 2. CLI で対話する（`adk run`）

`hello_world/` の 1 つ上（このディレクトリ）から実行します。`uv run --directory` で cwd をこのディレクトリに合わせています。

```bash
mise exec -- uv run --directory apps/adk-helloworld --locked \
  adk run hello_world
```

`root_agent`（HelloWorld agent）との対話が始まります。終了は `Ctrl+C`。

### 3. Web UI で対話する（`adk web`）

```bash
mise exec -- uv run --directory apps/adk-helloworld --locked \
  adk web
```

`http://localhost:8000` を開き、左上のドロップダウンで `hello_world` を選んで対話します。終了は `Ctrl+C`。

## Vertex AI 方式への切り替え

API key の代わりに Vertex AI 経由で同じ model を呼ぶ場合は、`hello_world/.env` を次の前提に書き換えます（**コードの変更は不要**。`agent.py` は env で切り替わります）。

```bash
# hello_world/.env
GOOGLE_GENAI_USE_VERTEXAI=TRUE
GOOGLE_CLOUD_PROJECT=your-gcp-project-id
GOOGLE_CLOUD_LOCATION=us-central1
```

- API key は不要で、認証は Application Default Credentials (ADC) を使います。事前に `gcloud auth application-default login` を実行しておきます。
- 対象プロジェクトで Vertex AI API を有効化しておきます（`gcloud services enable aiplatform.googleapis.com --project=your-gcp-project-id`）。Terraform で API 有効化を学ぶ場合は、この repo の `packages/gc/terraform/<op>-api-enable/`（`google_project_service`）パターンが参考になります。
- 以降の `adk run` / `adk web` のコマンドは Gemini API key 方式と同じです。

## Cloud Run へ deploy（`adk deploy cloud_run`）

ADK には Cloud Run へ直接 deploy するコマンドが用意されています（このサンプルでは Terraform は追加しません）。Vertex AI 方式の環境変数を前提に、次の形で実行します。

```bash
export GOOGLE_CLOUD_PROJECT="your-gcp-project-id"
export GOOGLE_CLOUD_LOCATION="us-central1"
export GOOGLE_GENAI_USE_VERTEXAI=TRUE

mise exec -- uv run --directory apps/adk-helloworld --locked \
  adk deploy cloud_run \
    --project="${GOOGLE_CLOUD_PROJECT}" \
    --region="${GOOGLE_CLOUD_LOCATION}" \
    --service_name="adk-helloworld" \
    --app_name="hello_world" \
    hello_world
```

- **アクセス制御は private を推奨**: deploy 中に `Allow unauthenticated invocations to [service] (y/N)?` と聞かれたら、安全側の **`N`（既定・認証必須＝private）** を選びます。`y` にすると誰でも叩ける public service になるため、学習・検証では `N` のままにしてください。
- **private service の呼び出し方**: 認証必須のため、呼び出しには ID トークンを付けます。

  ```bash
  TOKEN="$(gcloud auth print-identity-token)"
  curl -H "Authorization: Bearer ${TOKEN}" https://<service-url>/
  ```

- **`--with_ui` は開発確認用**: コマンドに `--with_ui` を付けると ADK の dev UI 付きで deploy されます。ブラウザで動作を確認したいときに便利ですが、**開発確認用**であり本番利用は想定していません。本番相当の deploy では付けません。

## Vertex AI Agent Engine へ deploy（Terraform）

Cloud Run だけでなく、**Vertex AI Agent Engine（API 名: Reasoning Engine）**へ Terraform で deploy する
学習サンプルも用意しています。deploy 本体（`google_vertex_ai_reasoning_engine` の作成）は
[packages/gc/terraform/adk-agent-engine-basic](../../terraform/adk-agent-engine-basic/) 側にあり、
このアプリ側は **deploy に渡す source archive の生成**を担当します
（**infrastructure は Terraform、artifact 生成は script** という責務分離）。

### 仕組み（inline source 方式）

最小の **inline source（`python_spec`）方式**を使います。archive にはソースと依存定義だけを入れ、依存の
インストールは Agent Engine の managed runtime に任せます。

- archive root に `hello_world/`（ローカル run と共通の agent）+ `agent_engine_app.py` + `requirements.txt`
  を並べます。**依存ライブラリは同梱しません**（runtime が `requirements.txt` を pip install）。
- entrypoint は ADK の `root_agent` そのものではなく、それを `AdkApp` で包んだ `agent_engine`
  変数（`agent-engine/agent_engine_app.py`）を指します。raw な agent を指すと runtime で失敗します。
- `agent_engine_app.py` は `vertexai`（`google-cloud-aiplatform[agent_engines]`）を import しますが、
  これは **archive の `requirements.txt` 側にだけ**入れ、ローカルの `.venv`（`pyproject.toml`）には足しません。
  そのためローカルの `adk run` / `adk web` は従来どおり `google-adk` だけで動きます。

### source archive を生成する

```bash
bash apps/adk-helloworld/scripts/package-agent-engine.sh
```

`.build/source.tar.gz` が生成されます（`apps/*/.build/` は gitignore 対象でコミットされません）。
script は `.env*` / `.adk/` / `__pycache__` などローカル runtime/secret 由来のものを archive から除外します。

### deploy する

生成した archive を読んで Agent Engine を作成する Terraform の手順（前提 API の有効化、`init` / `fmt` /
`validate` / `plan` / `apply`、cleanup）は
[adk-agent-engine-basic の README](../../terraform/adk-agent-engine-basic/README.md) を参照してください。

> Agent Engine 用 `requirements.txt` の `google-adk` は `pyproject.toml` の pin と一致させます。
> ズレは `tests/test_agent_engine_packaging.py` が検出します。

## バージョンの注意

依存バージョン（`google-adk` / Python）は `pyproject.toml` と root の [`mise.toml`](../../../../mise.toml)（`[tools]` の `python`）で固定しています。更新するときは `pyproject.toml` の pin と `uv.lock` を合わせて更新してください（`uv lock`）。
Agent Engine 用の依存（`agent-engine/requirements.txt`）も `google-adk` を合わせて更新します。
