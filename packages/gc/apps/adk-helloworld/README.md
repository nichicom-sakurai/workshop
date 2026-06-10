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

> ADK の規約では、エージェントは Python パッケージ（フォルダ）として置き、
> `__init__.py` が `from . import agent` で本体を読み込み、`agent.py` が `root_agent` を公開します。
> `adk run hello_world` / `adk web` は、この `hello_world/` パッケージの **1 つ上の階層**（このディレクトリ）から実行します。

## 依存関係の検証

```bash
mise exec -- uv lock --directory packages/gc/apps/adk-helloworld --check
```

## テストの実行

`root_agent` の構築（ネットワーク呼び出しなし）を検証するため、API key 無しで通ります。

```bash
mise exec -- uv run --directory packages/gc/apps/adk-helloworld --locked \
  python -m unittest discover -s tests
```

## エディタで import 警告が出る場合（Pylance）

VS Code で `from google.adk import Agent` などに「インポートを解決できません」と警告が出ることがあります。これは **import の書き方の誤りではなく**、Pylance が参照する Python interpreter がこの app の `.venv` を指していないことが原因です（`adk run` やテストは `uv run` 経由で `.venv` を使うため正しく動きます）。

この repo には複数の Python app があり（本 app と `packages/aws/apps/agentcore-strands-basic/`）、フォルダを直接開く single-root では Pylance が workspace 全体で interpreter を 1 つだけ選ぶため、片方の import しか解決しません。これを避けるため、各 Python app を独立フォルダとして開く multi-root workspace ファイル [`workshop.code-workspace`](../../../../workshop.code-workspace) を用意しています。

- 推奨: VS Code で `File → Open Workspace from File…` → リポジトリ直下の `workshop.code-workspace` を開く。各 app フォルダで `.venv` が自動検出され、adk-helloworld と agentcore-strands-basic の import が同時に解決します（`.venv` はテスト実行で作成済み。無ければ上の「テストの実行」を一度回す）。
- 代替（フォルダを直接開いている場合）: `Cmd/Ctrl+Shift+P` → `Python: Select Interpreter` → `packages/gc/apps/adk-helloworld/.venv/bin/python`（ただし他の Python app とは交互の切り替えが必要）。

## ローカル実行（Gemini API key 方式・主手順）

### 1. API key を用意して `.env` を作る

[Google AI Studio](https://aistudio.google.com/apikey) で API key を取得し、テンプレートから `.env` を作って key を書き込みます。`.env` は agent パッケージ（`hello_world/`）の中に置きます。

```bash
cd packages/gc/apps/adk-helloworld
cp hello_world/.env.template hello_world/.env
# hello_world/.env を編集し、GOOGLE_API_KEY=YOUR_API_KEY_HERE を実 key に置き換える
```

> コミットされるのは `.env.template` だけです。実 `.env`（および実 API key）は repository に保存しないでください（`.gitignore` 済み）。

### 2. CLI で対話する（`adk run`）

`hello_world/` の 1 つ上（このディレクトリ）から実行します。`uv run --directory` で cwd をこのディレクトリに合わせています。

```bash
mise exec -- uv run --directory packages/gc/apps/adk-helloworld --locked \
  adk run hello_world
```

`root_agent`（HelloWorld agent）との対話が始まります。終了は `Ctrl+C`。

### 3. Web UI で対話する（`adk web`）

```bash
mise exec -- uv run --directory packages/gc/apps/adk-helloworld --locked \
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

mise exec -- uv run --directory packages/gc/apps/adk-helloworld --locked \
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

## バージョンの注意

依存バージョン（`google-adk` / Python）は `pyproject.toml` と root の [`mise.toml`](../../../../mise.toml)（`[tools]` の `python`）で固定しています。更新するときは `pyproject.toml` の pin と `uv.lock` を合わせて更新してください（`uv lock`）。
