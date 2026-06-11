# agentcore-rag-chat cleanup

この sample は AWS account 内に AgentCore Runtime / endpoint / Memory、3 つの Knowledge Base、
S3 Vectors の vector bucket と 3 つの index、data source 用 S3 bucket / objects、artifact S3
bucket / object、IAM role / policy 2 セットを作成します。学習後は `destroy` してください。

## 削除前に確認

```bash
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat state list
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat plan -destroy
```

## 削除

```bash
mise exec -- terraform -chdir=terraform/aws/agentcore-rag-chat destroy
```

`data` bucket と S3 Vectors の vector bucket は `force_destroy = true` のため、取り込み済みの
サンプル文書やベクトルごと削除できます。artifact bucket は `force_destroy = false` ですが、
upload した object は Terraform state 上にあるので `destroy` 対象に含まれます。

## destroy が失敗した場合

- AgentCore Runtime / endpoint / Memory の作成・削除直後は AWS 側の eventual consistency で
  一時的に失敗することがあります。数分待って再実行してください。
- Knowledge Base の ingestion で作成されたベクトルは S3 Vectors index 内にあります。`destroy` は
  index と vector bucket（`force_destroy = true`）を削除するため通常はそのまま消えますが、
  index 削除が依存関係で詰まる場合は数分待って再実行してください。
- artifact bucket が空でない場合は、state 上の `aws_s3_object.artifact` が削除対象に含まれているか
  確認してください。手動で追加した object は Terraform 管理外なので、必要に応じて手動削除します。
- Bedrock model access（generation / embedding）はこの Terraform sample では作成・削除しません。
  不要になった model access の扱いは AWS account の運用方針に従ってください。
- ingestion job 自体は履歴として残ることがありますが課金対象のリソースではありません。
