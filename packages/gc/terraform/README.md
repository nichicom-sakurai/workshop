# Terraform Google Cloud サンプル集

Google Cloud provider の認証と Terraform の基本操作を学ぶための、自己完結したサンプル集です。
各サンプルは `terraform/` 直下の `<operation>/` に**独立した root module** として置かれ、それぞれ単独で `init` / `plan` / `apply` できます（state もサンプルごとに分離されるため、あるサンプルの操作が他へ波及しません）。

## サンプル一覧

| サンプル | 種別 | 説明 |
| --- | --- | --- |
| [project-info](./project-info/) | read-only | `google_project` data source で project `nck-sakurai` の ID / number / 表示名を読む最小サンプル |

新しいサンプルは `terraform/` 直下にディレクトリを 1 つ足し、この表に 1 行追加します（`<operation>` は `storage-bucket-list` のような kebab-case の「対象 + 操作」）。read-only は名詞 / `*-list` / `*-read`、リソースを作成する mutating はリソース名中心で命名し、本表の「種別」列で区別します。

## 前提

- `mise run bs` が完了していること
- `nck-sakurai` を読める Google Cloud の認証情報があること
- 対象プロジェクトで Cloud Resource Manager API が有効であること（このサンプルでは有効化しません）

認証は Application Default Credentials (ADC) など、Terraform Google provider の標準の仕組みを使います。例:

```bash
gcloud auth application-default login
```

`gcloud` の基本コマンドや active account / project の確認手順は [gcloud CLI 基本コマンド](../../../docs/guides/gcloud-cli/README.md) を参照してください。

シークレット値は repository に保存しないでください。

## 使い方

`<example>` を実際のサンプル名（例: `project-info`）に置き換えて実行します。`tf` ラッパータスクは AWS サンプル専用のため、Google Cloud サンプルは `terraform` を直接呼びます。

```bash
mise exec -- terraform -chdir=packages/gc/terraform/<example> init      # provider plugin を取得し作業ディレクトリを初期化 (最初に一度)
mise exec -- terraform -chdir=packages/gc/terraform/<example> fmt -check # .tf の整形ズレを検出 (書き換えず差分の有無のみ確認)
mise exec -- terraform -chdir=packages/gc/terraform/<example> validate   # 構文・設定の整合性を静的チェック
mise exec -- terraform -chdir=packages/gc/terraform/<example> plan       # 実行計画を表示
mise exec -- terraform -chdir=packages/gc/terraform/<example> apply      # 計画を適用し output を表示
```

## 各サンプルが生成するファイル

- `.terraform.lock.hcl`: provider の選択を固定する lock file。**commit 対象**です。
- `.terraform/`: provider plugin などの local cache。commit しません。
- `terraform.tfstate*`: local state。commit しません。

`.gitignore` はリポジトリ全体で上記 runtime ファイルを（任意のネスト深さで）無視するため、`terraform/` 配下にサンプルを増やしても gitignore の追加設定は不要です。
