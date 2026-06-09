# s3-object-upload cleanup

`s3-object-upload` で作成した S3 object を削除する手順です。
bucket 自体はこの sample の管理対象ではないため削除しません。

## 前提

- `packages/aws/terraform/s3-object-upload/terraform.tfvars` に、作成時と同じ `bucket_name` / `object_key` が残っていること
- `terraform init` が済んでいること
- bucket はまだ削除されていないこと

## 削除対象を確認する

```bash
mise run tf s3-object-upload state list
```

`aws_s3_object.hello` が表示されれば、この sample の object が Terraform 管理下にあります。

## 削除計画を確認する

```bash
mise run tf s3-object-upload plan -destroy
```

`Plan: 0 to add, 0 to change, 1 to destroy.` のように、削除対象が object だけであることを確認します。

## object を削除する

```bash
mise run tf s3-object-upload destroy
```

Terraform が確認プロンプトを出すため、plan の内容に問題がなければ `yes` と入力します。
`-auto-approve` は使いません。

## 削除後の確認

state に管理対象が残っていないことを確認します。

```bash
mise run tf s3-object-upload state list
```

削除が完了していれば、`aws_s3_object.hello` は表示されません。

AWS 側でも object が存在しないことを確認できます。

```bash
mise exec -- aws s3api head-object \
  --bucket "<terraform.tfvars に設定した bucket_name>" \
  --key "<terraform.tfvars に設定した object_key>"
```

削除済みなら `NotFound` 系のエラーになります。

## cleanup 順序

`s3-private-bucket` の bucket は `force_destroy = false` のため、bucket 内に object が残っていると削除できません。

削除順序:

1. `s3-object-upload` の `terraform destroy` で object を削除する
2. `s3-private-bucket` の cleanup で bucket を削除する
