# adk-agent-engine-basic cleanup

`adk-agent-engine-basic` で作成した Vertex AI Agent Engine（reasoning engine）を削除し、
ローカルの生成 artifact を片付ける手順です。Terraform は、作成時と同じ root module / state を使って削除します。

削除専用の `delete.tf` は追加しません。別ファイルで削除を表現すると、作成した resource と state の対応が分かりにくくなるためです。

## 前提

- `apps/adk-helloworld/.build/source.tar.gz`（apply 時に読んだ archive）が残っていること。
  消してしまった場合は `bash apps/adk-helloworld/scripts/package-agent-engine.sh` で
  再生成してから操作します（`filebase64` が plan/destroy の評価で参照します）。
- `terraform init` が済んでいること。

## 削除対象を確認する

まず state 上の管理対象を確認します。

```bash
D=terraform/gc/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" state list
```

`google_vertex_ai_reasoning_engine.adk_hello` が表示されれば、このサンプルのリソースが Terraform 管理下にあります。

## 削除計画を確認する

実際に削除する前に、destroy plan を確認します。

```bash
D=terraform/gc/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" plan -destroy
```

`Plan: 0 to add, 0 to change, 1 to destroy.` のように、削除対象がこのサンプルの1リソースだけであることを確認します。

## リソースを削除する

確認後、`destroy` を実行します。`deletion_policy`（default `DELETE`）のため Agent Engine リソースは削除されます
（呼び出しテストで session を作った場合は下記「session が残って destroy が失敗する場合」を先に参照）。

```bash
D=terraform/gc/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" destroy
```

Terraform が確認プロンプトを出すため、plan の内容に問題がなければ `yes` と入力します。
`-auto-approve` は使いません。

> **destroy も時間がかかります。** Agent Engine の削除は managed runtime の解体を伴うため数分かかることが
> あります（provider の delete timeout は default 60分）。

## session が残って destroy が失敗する場合

[README の「呼び出し方（SDK / REST）」](./README.md#呼び出し方sdk--rest)で agent を叩くと、`create_session`
で session が作られます。session は Agent Engine の **child resource** で、`deletion_policy = "DELETE"` のままだと
destroy が次のエラーで止まります。

```
Error 400: The ReasoningEngine "..." contains child resources: sessions.
Please delete the child resources before deleting the ReasoningEngine, or set force to true ...
```

この場合は `deletion_policy = "FORCE"` にすると child（session）ごと削除できます。`terraform.tfvars` は
apply / destroy の両方で自動読み込みされ（かつ gitignore 対象）るので、そこに1行足すのが簡単です。

```bash
D=terraform/gc/adk-agent-engine-basic
echo 'deletion_policy = "FORCE"' >> "${D}/terraform.tfvars"
mise exec -- terraform -chdir="${D}" apply    # deletion_policy を FORCE に更新（state に反映）
mise exec -- terraform -chdir="${D}" destroy  # session ごと Agent Engine を削除
```

> Terraform を経由せず一発で消したい場合は、REST で直接 force 削除もできます。その後は
> `terraform state rm google_vertex_ai_reasoning_engine.adk_hello` で state を整えます
> （`<RESOURCE_ID>` は `terraform output -raw reasoning_engine_name`）。
>
> ```bash
> curl -s -X DELETE -H "Authorization: Bearer $(gcloud auth print-access-token)" \
>   "https://us-central1-aiplatform.googleapis.com/v1/projects/nck-sakurai/locations/us-central1/reasoningEngines/<RESOURCE_ID>?force=true"
> ```

## 生成 artifact の片付け（ローカル）

`package-agent-engine.sh` が作る build artifact はローカルにだけ残ります（gitignore 対象でコミットはされていません）。
不要なら削除します。

```bash
rm -rf apps/adk-helloworld/.build
```

## 削除後の確認

state に管理対象が残っていないことを確認します。

```bash
D=terraform/gc/adk-agent-engine-basic
mise exec -- terraform -chdir="${D}" state list
```

Cloud Console（Vertex AI → Agent Engine / Reasoning Engine）にこのサンプルのエンジンが
表示されなくなっていれば削除完了です。

## Terraform 管理外に残るもの

前提として [vertex-ai-api-enable](../vertex-ai-api-enable/) で有効化した `aiplatform.googleapis.com` は、
そちらが `disable_on_destroy = false` のため、このサンプルの destroy 後（および vertex-ai-api-enable 側の
destroy 後）も有効なまま残ります（他のワークロードを壊さないため）。
