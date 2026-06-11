"""環境変数から実行設定を読み取る。

AgentCore Runtime には Terraform が environment_variables を渡します（generation model ID、
3 つの Knowledge Base ID、AgentCore Memory ID、region）。設定の解決を 1 か所に集約し、
未設定の必須項目を `missing()` で列挙できるようにすることで、entrypoint 側を薄く保ちます。
"""

from __future__ import annotations

import os
from collections.abc import Mapping
from dataclasses import dataclass

# 各専門 agent が使う Knowledge Base ID を渡す環境変数名。
# key は内部の専門 agent 識別子、value は Terraform が runtime に渡す環境変数名。
KB_ENV_VARS: dict[str, str] = {
    "aws_service": "AWS_SERVICE_KB_ID",
    "database": "DATABASE_KB_ID",
    "document": "DOCUMENT_KB_ID",
}


@dataclass(frozen=True)
class Config:
    """実行時設定。frozen=True で生成後は不変（取り回しやすく、テストで作りやすい）。"""

    model_id: str
    region: str | None
    kb_ids: dict[str, str]
    memory_id: str | None

    @classmethod
    def from_env(cls, env: Mapping[str, str] | None = None) -> Config:
        """環境変数（既定では os.environ）から設定を組み立てる。

        Args:
            env: 読み取り元。テストでは任意の dict を渡せる（os.environ を汚さない）。
        """
        source = env if env is not None else os.environ
        kb_ids = {key: source.get(var, "") for key, var in KB_ENV_VARS.items()}
        # AgentCore Runtime / boto3 は AWS_DEFAULT_REGION を優先し、無ければ AWS_REGION を使う。
        region = source.get("AWS_DEFAULT_REGION") or source.get("AWS_REGION")
        return cls(
            model_id=source.get("BEDROCK_MODEL_ID", ""),
            region=region or None,
            kb_ids=kb_ids,
            # Memory は任意。未設定でもチャットは動く（履歴を使わないだけ）。
            memory_id=source.get("AGENTCORE_MEMORY_ID") or None,
        )

    def missing(self) -> list[str]:
        """必須項目のうち未設定のものを環境変数名で返す（空なら設定は完全）。"""
        missing: list[str] = []
        if not self.model_id.strip():
            missing.append("BEDROCK_MODEL_ID")
        for key, var in KB_ENV_VARS.items():
            if not self.kb_ids.get(key, "").strip():
                missing.append(var)
        return missing
