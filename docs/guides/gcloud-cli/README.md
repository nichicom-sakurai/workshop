# gcloud CLI 基本コマンド

このリポジトリで使う Google Cloud CLI (`gcloud`) の最小コマンド集です。
`gcloud` は現時点では [`mise.toml`](../../../mise.toml) の管理対象ではないため、インストールは [Google Cloud CLI の公式手順](https://cloud.google.com/sdk/docs/install) を参照してください。

## 前提

- Google Cloud CLI がインストールされていること
- Google Cloud の対象プロジェクトを参照できる Google account があること
- `packages/gc/terraform/project-info/` を動かす場合は、Project ID `nck-sakurai` を参照できること

> [WARNING] `gcloud auth login` で CLI にログインできても、その account に対象 project の IAM 権限がなければ project は表示・参照できません。
> 認証成功と project 権限は分けて確認します。

## 最初に確認するコマンド

```bash
gcloud --version      # gcloud のバージョン確認
gcloud init           # 対話形式でログイン・default project などを初期設定
gcloud help           # help を表示
gcloud info           # SDK の設定・config directory などを確認
gcloud config list    # active configuration の account / project などを確認
```

## ログインとログインユーザー確認

```bash
gcloud auth login                     # browser で Google account にログイン
gcloud auth login --no-launch-browser # browser を自動起動しない環境でログイン

gcloud auth list                      # credential が保存されている account 一覧
gcloud config get account             # active configuration の account
gcloud auth list --filter="status:ACTIVE" --format="value(account)" # active account だけ表示
```

> `gcloud auth login` は Google Cloud CLI 用の認証です。
> Terraform Google provider や Google client libraries が Application Default Credentials (ADC) を使う場合は、後述の `gcloud auth application-default login` も必要です。

## Project の一覧・選択・確認

```bash
gcloud projects list                  # active account で参照できる project 一覧

PROJECT_ID="nck-sakurai"
gcloud config set project "${PROJECT_ID}" # active configuration の default project を設定
gcloud config get project                 # 現在の default project を確認
gcloud projects describe "${PROJECT_ID}"  # project metadata を確認
```

`gcloud projects describe "${PROJECT_ID}"` は project ID を引数で直接指定するため、default project を変更せずに対象 project の参照可否を確認できます。

## Configuration を分ける

複数の project / account を切り替える場合は named configuration を使います。

```bash
gcloud config configurations list                 # configuration 一覧
gcloud config configurations create workshop-gc   # configuration を作成
gcloud config configurations activate workshop-gc # configuration を切り替え

gcloud config set account "user@example.com"      # active account を設定
gcloud config set project "${PROJECT_ID}"         # default project を設定
gcloud config list                                # 設定結果を確認
```

## Terraform / client libraries 用の ADC

Terraform Google provider や Google client libraries は、`gcloud auth login` の credential ではなく ADC を見る構成があります。
このリポジトリの Google Cloud Terraform サンプルでは、ローカル開発用に ADC を使えます。

```bash
gcloud auth application-default login              # ADC を作成
gcloud auth application-default print-access-token >/dev/null # ADC で token を取得できるか確認
gcloud auth application-default revoke             # 不要になった ADC を削除
```

> [WARNING] `print-access-token` の出力は短時間有効な access token です。
> 画面共有・ログ・ドキュメントに貼り付けないでください。

## よく使う確認フロー

`gcloud auth login` 後に project が見えない、または Terraform が権限エラーになる場合は、次の順に確認します。

```bash
PROJECT_ID="nck-sakurai"

gcloud auth list
gcloud config list
gcloud config get account
gcloud config get project
gcloud projects describe "${PROJECT_ID}"
```

`gcloud projects describe` が失敗する場合、主な原因は次のどちらかです。

- `PROJECT_ID` が違う
- active account に対象 project の参照権限がない

## 公式リファレンス

- [gcloud CLI overview](https://cloud.google.com/sdk/gcloud)
- [gcloud auth login](https://cloud.google.com/sdk/gcloud/reference/auth/login)
- [gcloud projects list](https://cloud.google.com/sdk/gcloud/reference/projects/list)
- [gcloud config](https://cloud.google.com/sdk/gcloud/reference/config)
- [gcloud auth application-default login](https://cloud.google.com/sdk/gcloud/reference/auth/application-default/login)
