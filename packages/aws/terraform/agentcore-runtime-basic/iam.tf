# Trust policy:
# AgentCore Runtime がこの IAM role を assume できるようにします。
data "aws_iam_policy_document" "agentcore_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock-agentcore.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "runtime" {
  name               = "${var.name_prefix}-runtime-role"
  assume_role_policy = data.aws_iam_policy_document.agentcore_assume_role.json
  tags               = var.tags
}

# Runtime policy:
# direct code deployment artifact の取得、runtime logs、Bedrock model invocation を許可します。
data "aws_iam_policy_document" "runtime" {
  statement {
    sid    = "ReadRuntimeArtifact"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
    ]
    resources = [aws_s3_object.artifact.arn]
  }

  statement {
    sid    = "ListRuntimeArtifactBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.artifact.arn]
  }

  statement {
    sid    = "WriteRuntimeLogs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:DescribeLogStreams",
      "logs:PutLogEvents",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "InvokeBedrockModel"
    effect = "Allow"
    actions = [
      "bedrock:Converse",
      "bedrock:ConverseStream",
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = var.bedrock_model_resource_arns
  }
}

resource "aws_iam_role_policy" "runtime" {
  name   = "${var.name_prefix}-runtime-policy"
  role   = aws_iam_role.runtime.id
  policy = data.aws_iam_policy_document.runtime.json
}
