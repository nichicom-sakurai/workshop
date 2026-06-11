# storage-object-upload (mutating)

既存の Cloud Storage bucket に local file を1つアップロードする **mutating** サンプルです。
`google_storage_bucket_object` リソースで `objects/hello.txt` を object として作成し、`plan` / `apply` / `destroy` による object lifecycle を学びます。

このサンプルは bucket を作成しません。先に [storage-bucket-basic](../storage-bucket-basic/) で bucket を作成し、その `bucket_name` をこのサンプルに渡します。

対象プロジェクト: `nck-sakurai`（provider の `project` を継承）

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `storage-object-upload` に読み替えます。

## 変数の設定（必須）

`storage-bucket-basic` で作成した bucket 名を指定します。
template を copy して自分の値を設定してください（`terraform.tfvars` は gitignore 対象でコミットされません）。

```bash
cp terraform/gc/storage-object-upload/terraform.tfvars.template \
   terraform/gc/storage-object-upload/terraform.tfvars
# terraform.tfvars を編集し、storage-bucket-basic と同じ bucket_name を設定
```

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `bucket_name` | ○ | （なし） | `storage-bucket-basic` で作成した bucket 名 |
| `object_name` | | `samples/hello.txt` | bucket 内に作成する object 名 |

## このサンプルが作る object

- upload 元: [`objects/hello.txt`](./objects/hello.txt)
- upload 先: `gs://<bucket_name>/<object_name>`
- `content_type = "text/plain; charset=utf-8"`
- `cache_control = "private, max-age=0"`
- `deletion_policy = "DELETE"`: `terraform destroy` で object を削除します。

bucket 自体はこのサンプルでは削除しません。bucket を削除する前に、このサンプルの object を先に削除してください。

## 操作の流れ

```bash
D=terraform/gc/storage-object-upload
mise exec -- terraform -chdir=$D init
mise exec -- terraform -chdir=$D plan      # upload する object を確認
mise exec -- terraform -chdir=$D apply     # object を1つ作成
mise exec -- terraform -chdir=$D state list # state 上の object を確認
```

学習後は [`cleanup.md`](./cleanup.md) の手順で object を削除します。

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `bucket_name` | object を作成した bucket 名 |
| `object_name` | 作成した object 名 |
| `object_url` | object の `gs://` URL |
| `content_type` | object の content type |
| `generation` | Cloud Storage が割り当てた generation |

## cleanup

bucket を削除する前に、この sample の object を削除します。

```bash
mise exec -- terraform -chdir=terraform/gc/storage-object-upload plan -destroy
mise exec -- terraform -chdir=terraform/gc/storage-object-upload destroy
```

その後、bucket が空になった状態で [storage-bucket-basic の cleanup](../storage-bucket-basic/cleanup.md) を実行します。
