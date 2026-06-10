# agentcore-runtime-basic cleanup

この sample は AWS account 内に AgentCore Runtime、custom endpoint、IAM role / policy、
S3 artifact bucket / object を作成します。学習後は `destroy` してください。

## 削除前に確認

```bash
mise run tf agentcore-runtime-basic state list
mise run tf agentcore-runtime-basic plan -destroy
```

## 削除

```bash
mise run tf agentcore-runtime-basic destroy
```

## destroy が失敗した場合

- AgentCore Runtime / endpoint の作成・削除直後は AWS 側の eventual consistency で一時的に失敗することがあります。数分待って再実行してください。
- S3 bucket が空でない場合は、Terraform state 上の `aws_s3_object.artifact` が削除対象に含まれているか確認してください。
- 手動で追加した endpoint や S3 object は Terraform 管理外です。AWS Console または AWS CLI で確認し、必要に応じて手動削除してください。
- Bedrock model access はこの Terraform sample では作成・削除しません。不要になった model access の扱いは AWS account の運用方針に従ってください。
