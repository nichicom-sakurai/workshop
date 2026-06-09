# storage-bucket-basic (mutating)

private な Cloud Storage bucket を1つ作成する **mutating** サンプルです。
`google_storage_bucket` リソースで `plan` / `apply` / `state` / `destroy` の lifecycle を学びます。
**実際に課金対象になり得るリソースを作成する**ため、学習後は `destroy` してください。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `storage-bucket-basic` に読み替えます。

## 変数の設定（必須）

bucket 名は**全 Google Cloud で一意**である必要があるため、固定値は埋め込まず変数で受け取ります。
template を copy して自分の値を設定してください（`terraform.tfvars` は gitignore 対象でコミットされません）。

```bash
cp packages/gc/terraform/storage-bucket-basic/terraform.tfvars.template \
   packages/gc/terraform/storage-bucket-basic/terraform.tfvars
# terraform.tfvars を編集し、一意な bucket_name を設定
```

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `bucket_name` | ○ | （なし） | 作成する bucket の一意な名前（小文字・数字・ハイフン、3〜63 文字） |
| `location` | | `ASIA-NORTHEAST1` | bucket の location（単一リージョン） |

## このサンプルが作る bucket

private-by-default の設定です。

- `uniform_bucket_level_access = true`: per-object ACL を無効化し、IAM のみでアクセス制御。
- `public_access_prevention = "enforced"`: 公開アクセスを禁止。
- `force_destroy = false`: bucket 内にオブジェクトが残っていると `destroy` が失敗します。最初のサンプルはオブジェクトを置かないため安全で、空でない bucket の destroy 失敗は「うっかり削除」を防ぐ安全装置として学べます。

## 操作の流れ

```bash
D=packages/gc/terraform/storage-bucket-basic
mise exec -- terraform -chdir=$D init
mise exec -- terraform -chdir=$D plan      # 作成内容を確認
mise exec -- terraform -chdir=$D apply     # bucket を1つ作成
mise exec -- terraform -chdir=$D state list # state 上のリソースを確認
mise exec -- terraform -chdir=$D destroy   # 学習後に削除
```

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `bucket_name` | 作成した bucket の名前 |
| `bucket_url` | bucket の `gs://` URL |
| `location` | bucket の location |

## cleanup

学習が終わったら必ず `destroy` してください（課金とリソース残留を避けるため）。

```bash
mise exec -- terraform -chdir=packages/gc/terraform/storage-bucket-basic destroy
```

> オブジェクトをアップロードする発展サンプルは別途扱います（`force_destroy` と cleanup の前提が変わるため）。
