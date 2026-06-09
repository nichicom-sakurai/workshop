# s3-private-bucket (mutating)

private な S3 bucket を1つ作成する **mutating** サンプルです。
`aws_s3_bucket` と `aws_s3_bucket_public_access_block` で `plan` / `apply` / `state` / `destroy` の lifecycle を学びます。
**実際に課金対象になり得るリソースを作成する**ため、学習後は `destroy` してください。

> 前提（認証情報の設定）と共通コマンド（`init` / `fmt` / `validate` / `plan` / `apply`）は
> [親 README](../README.md) を参照してください。`<example>` を `s3-private-bucket` に読み替えます。

## 変数

bucket 名は S3 全体で一意である必要があります。このサンプルでは `bucket_prefix` に account ID と region を付けて、衝突しにくい名前を自動生成します。

生成される形式:

```text
<bucket_prefix>-<account_id>-<region>
```

| 変数 | 必須 | default | 内容 |
| --- | --- | --- | --- |
| `bucket_prefix` | | `nck-sakurai-tf-learn` | bucket 名の prefix（小文字・数字・ハイフン、3〜35文字） |
| `tags` | | `Project` / `Purpose` / `ManagedBy` | bucket に付与する tag |

bucket 名が衝突した場合は、local な `.tfvars` を作るか `-var` で `bucket_prefix` を変えてください。`.tfvars` は gitignore 対象で、commit しません。

```bash
mise run tf s3-private-bucket plan -var='bucket_prefix=nck-sakurai-tf-learn-01'
```

## このサンプルが作る bucket

private-by-default の設定です。

- `aws_s3_bucket.this`: 学習用 S3 bucket を1つ作成します。
- `force_destroy = false`: bucket 内に object が残っていると `destroy` は失敗します。最初の bucket サンプルでは object を置かないため、削除忘れを防ぐ安全装置として扱います。
- `aws_s3_bucket_public_access_block.this`: public access block の4項目をすべて `true` にします。

public access block の設定:

| 設定 | 値 |
| --- | --- |
| `block_public_acls` | `true` |
| `block_public_policy` | `true` |
| `ignore_public_acls` | `true` |
| `restrict_public_buckets` | `true` |

## 操作の流れ

```bash
mise run tf s3-private-bucket init
mise run tf s3-private-bucket fmt -check
mise run tf s3-private-bucket validate
mise run tf s3-private-bucket plan      # 作成内容を確認
mise run tf s3-private-bucket apply     # bucket を1つ作成
mise run tf s3-private-bucket state list # state 上のリソースを確認
mise run tf s3-private-bucket destroy   # 学習後に削除
```

## 出力 (outputs)

| output | 内容 |
| --- | --- |
| `bucket_name` | 作成した S3 bucket の名前 |
| `bucket_arn` | 作成した S3 bucket の ARN |
| `region` | Terraform AWS provider が使用した region |

## cleanup

学習が終わったら必ず bucket を削除してください（課金とリソース残留を避けるため）。

削除前に destroy plan を確認します。

```bash
mise run tf s3-private-bucket plan -destroy
```

確認後、同じ root module / state で `destroy` します。

```bash
mise run tf s3-private-bucket destroy
```

このサンプルは object を作成しません。将来 object を入れる発展サンプルを実行した場合は、bucket を削除する前に object を削除してください。
