# adk-agent-engine-basic cleanup

`adk-agent-engine-basic` で作成した Vertex AI Agent Engine（reasoning engine）を削除し、
ローカルの生成 artifact を片付ける手順です。Terraform は、作成時と同じ root module / state を使って削除します。

削除専用の `delete.tf` は追加しません。別ファイルで削除を表現すると、作成した resource と state の対応が分かりにくくなるためです。

## 前提

- `packages/gc/apps/adk-helloworld/.build/source.tar.gz`（apply 時に読んだ archive）が残っていること。
  消してしまった場合は `bash packages/gc/apps/adk-helloworld/scripts/package-agent-engine.sh` で
  再生成してから操作します（`filebase64` が plan/destroy の評価で参照します）。
- `terraform init` が済んでいること。

## 削除対象を確認する

まず state 上の管理対象を確認します。

```bash
D=packages/gc/terraform/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" state list
```

`google_vertex_ai_reasoning_engine.adk_hello` が表示されれば、このサンプルのリソースが Terraform 管理下にあります。

## 削除計画を確認する

実際に削除する前に、destroy plan を確認します。

```bash
D=packages/gc/terraform/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" plan -destroy
```

`Plan: 0 to add, 0 to change, 1 to destroy.` のように、削除対象がこのサンプルの1リソースだけであることを確認します。

## リソースを削除する

確認後、`destroy` を実行します。`deletion_policy = "DELETE"` のため、Agent Engine リソースは削除されます。

```bash
D=packages/gc/terraform/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" destroy
```

Terraform が確認プロンプトを出すため、plan の内容に問題がなければ `yes` と入力します。
`-auto-approve` は使いません。

> **destroy も時間がかかります。** Agent Engine の削除は managed runtime の解体を伴うため数分かかることが
> あります（provider の delete timeout は default 60分）。

## 生成 artifact の片付け（ローカル）

`package-agent-engine.sh` が作る build artifact はローカルにだけ残ります（gitignore 対象でコミットはされていません）。
不要なら削除します。

```bash
rm -rf packages/gc/apps/adk-helloworld/.build
```

## 削除後の確認

state に管理対象が残っていないことを確認します。

```bash
D=packages/gc/terraform/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" state list
```

Cloud Console（Vertex AI → Agent Engine / Reasoning Engine）にこのサンプルのエンジンが
表示されなくなっていれば削除完了です。

## Terraform 管理外に残るもの

前提として [vertex-ai-api-enable](../vertex-ai-api-enable/) で有効化した `aiplatform.googleapis.com` は、
そちらが `disable_on_destroy = false` のため、このサンプルの destroy 後（および vertex-ai-api-enable 側の
destroy 後）も有効なまま残ります（他のワークロードを壊さないため）。
