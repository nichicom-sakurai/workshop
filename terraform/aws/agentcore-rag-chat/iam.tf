# =====================================================================
# (A) AgentCore Runtime 実行ロール
#   アプリ実行時に: artifact ZIP の取得 / logs / generation model invoke /
#   Knowledge Base の検索 (bedrock:Retrieve) / AgentCore Memory の保存・取得。
#   ※ query 時の S3 Vectors アクセスは KB が KB service role で代行するため、
#     このロールに s3vectors 権限は付けない。
# =====================================================================

data "aws_iam_policy_document" "runtime_assume_role" {
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
  assume_role_policy = data.aws_iam_policy_document.runtime_assume_role.json
  tags               = var.tags
}

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
    sid       = "ListRuntimeArtifactBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
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
    # Converse / ConverseStream は bedrock:InvokeModel / InvokeModelWithResponseStream で認可される
    # (bedrock:Converse という IAM action は存在しない)。
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
    ]
    resources = var.bedrock_model_resource_arns
  }

  statement {
    sid    = "RetrieveKnowledgeBases"
    effect = "Allow"
    # 検索は KB 経由 (bedrock:Retrieve)。KB が裏で s3vectors:QueryVectors を実行するため、
    # このロールに s3vectors を付ける必要はない。
    actions   = ["bedrock:Retrieve"]
    resources = [for kb in aws_bedrockagent_knowledge_base.this : kb.arn]
  }

  statement {
    sid    = "AgentCoreMemoryShortTerm"
    effect = "Allow"
    actions = [
      "bedrock-agentcore:CreateEvent",
      "bedrock-agentcore:GetEvent",
      "bedrock-agentcore:ListEvents",
    ]
    resources = [aws_bedrockagentcore_memory.this.arn]
  }
}

resource "aws_iam_role_policy" "runtime" {
  name   = "${var.name_prefix}-runtime-policy"
  role   = aws_iam_role.runtime.id
  policy = data.aws_iam_policy_document.runtime.json
}

# =====================================================================
# (B) Knowledge Base service role
#   Bedrock が assume し、ingestion / query 時に: embedding model invoke /
#   S3 data source 読み取り / S3 Vectors index への読み書き。
# =====================================================================

data "aws_iam_policy_document" "kb_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }

    # confused-deputy 対策: 自 account かつ自分の Knowledge Base からの assume に限定。
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }

    condition {
      test     = "ArnLike"
      variable = "AWS:SourceArn"
      values   = ["arn:aws:bedrock:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:knowledge-base/*"]
    }
  }
}

resource "aws_iam_role" "kb_service" {
  name               = "${var.name_prefix}-kb-service-role"
  assume_role_policy = data.aws_iam_policy_document.kb_assume_role.json
  tags               = var.tags
}

data "aws_iam_policy_document" "kb_service" {
  statement {
    sid    = "ListBedrockModels"
    effect = "Allow"
    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:ListCustomModels",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "InvokeEmbeddingModel"
    effect    = "Allow"
    actions   = ["bedrock:InvokeModel"]
    resources = [local.embedding_model_arn]
  }

  statement {
    sid    = "ReadDataSourceBucket"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetObject",
    ]
    resources = [
      aws_s3_bucket.data.arn,
      "${aws_s3_bucket.data.arn}/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "aws:ResourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }

  statement {
    sid    = "ReadWriteS3VectorsIndexes"
    effect = "Allow"
    # ingestion (PutVectors) と query (QueryVectors。dependent action として GetVectors を要求) を
    # 各ドメインの index ARN にスコープする。
    actions = [
      "s3vectors:PutVectors",
      "s3vectors:GetVectors",
      "s3vectors:DeleteVectors",
      "s3vectors:QueryVectors",
      "s3vectors:GetIndex",
    ]
    resources = [for idx in aws_s3vectors_index.this : idx.index_arn]
  }
}

resource "aws_iam_role_policy" "kb_service" {
  name   = "${var.name_prefix}-kb-service-policy"
  role   = aws_iam_role.kb_service.id
  policy = data.aws_iam_policy_document.kb_service.json
}
