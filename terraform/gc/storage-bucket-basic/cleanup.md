# storage-bucket-basic cleanup

`storage-bucket-basic` で作成した Cloud Storage bucket を削除する手順です。
Terraform は、作成時と同じ root module / state を使って削除します。

削除専用の `delete.tf` は追加しません。別ファイルで削除を表現すると、作成した resource と state の対応が分かりにくくなるためです。

## 前提

- `terraform/gc/storage-bucket-basic/terraform.tfvars` に、作成時と同じ `bucket_name` が残っていること
- `terraform init` が済んでいること
- bucket に object を追加していないこと

`force_destroy = false` のため、bucket 内に object や cache が残っている場合、`terraform destroy` は失敗します。
この sample 自体は object を作りません。[storage-object-upload](../storage-object-upload/) を実行した場合は、先にその sample の [`cleanup.md`](../storage-object-upload/cleanup.md) で object を削除してください。

## 削除対象を確認する

まず state 上の管理対象を確認します。

```bash
D=terraform/gc/storage-bucket-basic
mise exec -- terraform -chdir="${D}" state list
```

`google_storage_bucket.learning` が表示されれば、この sample の bucket が Terraform 管理下にあります。

## 削除計画を確認する

実際に削除する前に、destroy plan を確認します。

```bash
D=terraform/gc/storage-bucket-basic
mise exec -- terraform -chdir="${D}" plan -destroy
```

`Plan: 0 to add, 0 to change, 1 to destroy.` のように、削除対象がこの sample の bucket だけであることを確認します。

## bucket を削除する

確認後、`destroy` を実行します。

```bash
D=terraform/gc/storage-bucket-basic
mise exec -- terraform -chdir="${D}" destroy
```

Terraform が確認プロンプトを出すため、plan の内容に問題がなければ `yes` と入力します。
`-auto-approve` は使いません。

## 削除後の確認

state に管理対象が残っていないことを確認します。

```bash
D=terraform/gc/storage-bucket-basic
mise exec -- terraform -chdir="${D}" state list
```

削除が完了していれば、`google_storage_bucket.learning` は表示されません。

必要に応じて、Google Cloud 側でも bucket が存在しないことを確認します。

```bash
BUCKET_NAME="<terraform.tfvars に設定した bucket_name>"
gcloud storage buckets describe "gs://${BUCKET_NAME}"
```

削除済みなら `NotFound` 系のエラーになります。

## object が残っていて削除できない場合

`force_destroy = false` のため、bucket 内に object が残っていると削除は失敗します。
この場合は、まず「なぜ object があるのか」を確認してください。

- この sample の手順だけを実行した場合: object は作られないため、手動追加や別 sample の影響を確認する
- [storage-object-upload](../storage-object-upload/) を実行した場合: 先にその sample の `terraform destroy` で object を削除する
- 自分で object を追加した場合: object を削除してから `terraform destroy` を再実行する
