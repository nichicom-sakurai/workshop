# s3-object-upload (mutating)

既存の S3 bucket に local file を1つアップロードする **mutating** サンプルです。
`aws_s3_object` リソースで [`objects/hello.txt`](./objects/hello.txt) を object として作成し、`plan` / `apply` / `destroy` による object lifecycle を学びます。

このサンプルは bucket を作成しません。先に [s3-private-bucket](../s3-private-bucket/) で bucket を作成し、その `bucket_name` をこのサンプルに渡します。

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `s3-object-upload` に読み替えます。

## 変数の設定（必須）

`s3-private-bucket` で作成した bucket 名を指定します。
template を copy して自分の値を設定してください（`terraform.tfvars` は gitignore 対象で commit されません）。

```bash
cp packages/aws/terraform/s3-object-upload/terraform.tfvars.template \
   packages/aws/terraform/s3-object-upload/terraform.tfvars
# terraform.tfvars を編集し、s3-private-bucket と同じ bucket_name を設定
```

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `bucket_name` | ○ | （なし） | `s3-private-bucket` で作成した bucket 名 |
| `object_key` | | `samples/hello.txt` | bucket 内に作成する object key |
| `tags` | | `Project` / `Purpose` / `ManagedBy` | object に付与する tag |

## このサンプルが作る object

- upload 元: [`objects/hello.txt`](./objects/hello.txt)
- upload 先: `s3://<bucket_name>/<object_key>`
- `content_type = "text/plain; charset=utf-8"`
- `cache_control = "private, max-age=0"`
- `etag = filemd5(...)`: local file の内容が変わったときに Terraform が差分を検出できるようにします。

bucket 自体はこのサンプルでは削除しません。bucket を削除する前に、このサンプルの object を先に削除してください。

## 操作の流れ

```bash
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload init
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload fmt -check
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload validate
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload plan      # upload する object を確認
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload apply     # object を1つ作成
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload state list # state 上の object を確認
```

学習後は [`cleanup.md`](./cleanup.md) の手順で object を削除します。

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `bucket_name` | object を作成した bucket 名 |
| `content_type` | object の content type |
| `etag` | object の ETag |
| `object_key` | 作成した object key |
| `object_url` | object の `s3://` URL |

## cleanup

bucket を削除する前に、この sample の object を削除します。

```bash
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload plan -destroy
mise exec -- terraform -chdir=packages/aws/terraform/s3-object-upload destroy
```

その後、bucket が空になった状態で [s3-private-bucket の cleanup](../s3-private-bucket/) を実行します。
