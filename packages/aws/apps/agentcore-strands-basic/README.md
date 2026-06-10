# agentcore-strands-basic

Minimal Python agent for the Terraform sample at
`../../terraform/agentcore-runtime-basic/`.

The app is packaged as an Amazon Bedrock AgentCore Runtime direct code
deployment ZIP. It uses `bedrock-agentcore` and `strands-agents` to call an
Amazon Bedrock model configured through `BEDROCK_MODEL_ID`.

This nested app is not run by `mise run dev:all`.

## Verify dependencies

```bash
mise exec -- uv lock --directory packages/aws/apps/agentcore-strands-basic --check
```

## Run tests

```bash
mise exec -- uv run --directory packages/aws/apps/agentcore-strands-basic --locked \
  python -m unittest discover -s tests
```

## Package for AgentCore Runtime

Build the ZIP artifact before running Terraform:

```bash
packages/aws/apps/agentcore-strands-basic/scripts/package.sh
```

The script creates:

```text
packages/aws/apps/agentcore-strands-basic/dist/agentcore-strands-basic.zip
```

Pass that path to the Terraform sample as `artifact_zip_path`.
