"""1 つの Amazon Bedrock Knowledge Base を検索する Strands tool を組み立てる。

ポイント（3 つの異なる KB を 3 つの専門 agent に割り当てる方法）:
  strands_tools の組み込み `retrieve` tool は環境変数 `KNOWLEDGE_BASE_ID` を 1 つしか読まず、
  3 つの異なる KB を扱えません。また `knowledgeBaseId` を tool の引数にすると、どの KB を引くかが
  LLM の入力に漏れてしまいます。そこで「kb_id をクロージャに束縛した自前 @tool」を作り、
  各専門 agent には自分専用の KB だけを引く tool を 1 つ持たせます（kb_id は LLM から不可視）。
"""

from __future__ import annotations

from typing import Any

import boto3
from strands import tool


def format_retrieval_results(response: dict[str, Any]) -> str:
    """bedrock-agent-runtime の retrieve レスポンスから本文チャンクを連結する。

    retrieve は `retrievalResults[].content.text` に本文を返します。スコア順に並んだ
    上位チャンクをそのまま連結し、LLM へ渡す検索結果テキストにします。
    """
    results = response.get("retrievalResults") or []
    chunks: list[str] = []
    for item in results:
        content = item.get("content") if isinstance(item, dict) else None
        text = content.get("text") if isinstance(content, dict) else None
        if isinstance(text, str) and text.strip():
            chunks.append(text.strip())
    if not chunks:
        return "No relevant information was found in this knowledge base."
    return "\n\n".join(chunks)


def search_kb(
    client: Any,
    knowledge_base_id: str,
    query: str,
    *,
    num_results: int = 5,
) -> str:
    """bedrock-agent-runtime client で KB を検索し、整形済みテキストを返す（純粋寄り・テスト容易）。

    client は依存性注入（DI）で受け取るため、テストでは `.retrieve` を持つ fake を渡せます。
    """
    response = client.retrieve(
        knowledgeBaseId=knowledge_base_id,
        retrievalQuery={"text": query},
        retrievalConfiguration={
            "vectorSearchConfiguration": {"numberOfResults": num_results},
        },
    )
    return format_retrieval_results(response)


def make_kb_search_tool(
    knowledge_base_id: str,
    region: str | None,
    *,
    client: Any | None = None,
):
    """指定 KB を引く Strands tool を生成する。kb_id をクロージャに束縛する。

    Args:
        knowledge_base_id: この tool が検索する Knowledge Base の ID。
        region: bedrock-agent-runtime client の region（None なら boto3 の既定解決）。
        client: テスト用に注入する bedrock-agent-runtime 互換 client（省略時は boto3 で生成）。
    """
    runtime_client = client or boto3.client("bedrock-agent-runtime", region_name=region)

    @tool
    def search_knowledge_base(query: str) -> str:
        """Search this agent's dedicated knowledge base and return the most relevant text.

        Args:
            query: A natural-language search query describing what information is needed.
        """
        return search_kb(runtime_client, knowledge_base_id, query)

    return search_knowledge_base
