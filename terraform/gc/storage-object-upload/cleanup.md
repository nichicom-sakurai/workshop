# storage-object-upload cleanup

`storage-object-upload` で作成した Cloud Storage object を削除する手順です。
bucket 自体はこの sample の管理対象ではないため削除しません。

## 前提

- `terraform/gc/storage-object-upload/terraform.tfvars` に、作成時と同じ `bucket_name` / `object_name` が残っていること
- `terraform init` が済んでいること
- bucket はまだ削除されていないこと

## 削除対象を確認する

```bash
D=terraform/gc/storage-object-upload
mise exec -- terraform -chdir="${D}" state list
```

`google_storage_bucket_object.hello` が表示されれば、この sample の object が Terraform 管理下にあります。

## 削除計画を確認する

```bash
D=terraform/gc/storage-object-upload
mise exec -- terraform -chdir="${D}" plan -destroy
```

`Plan: 0 to add, 0 to change, 1 to destroy.` のように、削除対象が object だけであることを確認します。

## object を削除する

```bash
D=terraform/gc/storage-object-upload
mise exec -- terraform -chdir="${D}" destroy
```

Terraform が確認プロンプトを出すため、plan の内容に問題がなければ `yes` と入力します。
`-auto-approve` は使いません。

## 削除後の確認

state に管理対象が残っていないことを確認します。

```bash
D=terraform/gc/storage-object-upload
mise exec -- terraform -chdir="${D}" state list
```

削除が完了していれば、`google_storage_bucket_object.hello` は表示されません。

Google Cloud 側でも object が存在しないことを確認できます。

```bash
BUCKET_NAME="<terraform.tfvars に設定した bucket_name>"
OBJECT_NAME="<terraform.tfvars に設定した object_name>"
gcloud storage objects describe "gs://${BUCKET_NAME}/${OBJECT_NAME}"
```

削除済みなら `NotFound` 系のエラーになります。

## cleanup 順序

`storage-bucket-basic` の bucket は `force_destroy = false` のため、bucket 内に object が残っていると削除できません。

削除順序:

1. `storage-object-upload` の `terraform destroy` で object を削除する
2. `storage-bucket-basic` の [`cleanup.md`](../storage-bucket-basic/cleanup.md) で bucket を削除する
