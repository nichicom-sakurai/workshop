# cloud-run-service-basic cleanup

`cloud-run-service-basic` で作成した Cloud Run service と Artifact Registry repository を削除する手順です。
Terraform は、作成時と同じ root module / state を使って削除します。

削除専用の `delete.tf` は追加しません。別ファイルで削除を表現すると、作成した resource と state の対応が分かりにくくなるためです。

## 削除順序の考え方

`terraform destroy` は依存関係の逆順、つまり **service → repository** の順で削除します
（`main.tf` の `depends_on` がこの順序を保証します）。

- **Cloud Run service が先**: image を参照している利用側を先に消します。
- **Artifact Registry repository が後**: repository の削除は **push 済みの image ごと**消えます
  （Artifact Registry の DeleteRepository は repository の中身ごと削除する仕様で、
  bucket の `force_destroy = false` のような「空でないと失敗する」safety はありません）。
  残しておきたい image がある場合は、destroy の前に別の場所へ退避してください。

## 前提

- `terraform/gc/cloud-run-service-basic/terraform.tfvars` に、apply 時と同じ `image` が残っていること
- `terraform init` が済んでいること

## 削除対象を確認する

まず state 上の管理対象を確認します。

```bash
D=terraform/gc/cloud-run-service-basic
mise exec -- terraform -chdir="${D}" state list
```

`google_cloud_run_v2_service.learning` と `google_artifact_registry_repository.learning` が表示されれば、
このサンプルのリソースが Terraform 管理下にあります。

## 削除計画を確認する

実際に削除する前に、destroy plan を確認します。

```bash
D=terraform/gc/cloud-run-service-basic
mise exec -- terraform -chdir="${D}" plan -destroy
```

`Plan: 0 to add, 0 to change, 2 to destroy.` のように、削除対象がこのサンプルの2リソースだけであることを確認します。

## リソースを削除する

確認後、`destroy` を実行します。

```bash
D=terraform/gc/cloud-run-service-basic
mise exec -- terraform -chdir="${D}" destroy
```

Terraform が確認プロンプトを出すため、plan の内容に問題がなければ `yes` と入力します。
`-auto-approve` は使いません。

## 削除後の確認

state に管理対象が残っていないことを確認します。

```bash
D=terraform/gc/cloud-run-service-basic
mise exec -- terraform -chdir="${D}" state list
```

必要に応じて、Google Cloud 側でも削除を確認します。

```bash
gcloud run services list --project nck-sakurai --region=asia-northeast1
gcloud artifacts repositories list --project nck-sakurai --location=asia-northeast1
```

いずれの一覧にも、このサンプルで作成した service / repository が表示されなければ削除完了です。

## Terraform 管理外に残るもの

前提として [cloud-run-api-enable](../cloud-run-api-enable/) で有効化した3つの API（`run.googleapis.com` /
`artifactregistry.googleapis.com` / `cloudbuild.googleapis.com`）は、そちらが `disable_on_destroy = false`
のため、このサンプルの destroy 後も（cloud-run-api-enable 側の destroy 後も）有効なまま残ります
（他のワークロードを壊さないため）。

`gcloud builds submit` の初回実行時に自動作成された Cloud Build の staging bucket
（`nck-sakurai_cloudbuild`）は **Terraform 管理外のため destroy では消えません**。
中身（アップロードされたソースの tarball）も自動削除されないため、不要になったら手動で削除します。

```bash
# 中身ごと bucket を削除する場合
gcloud storage rm --recursive gs://nck-sakurai_cloudbuild
```

> 他のプロジェクトや別の Cloud Build 利用がある場合は、bucket を共有している可能性があります。
> 削除前に中身を確認してください。
