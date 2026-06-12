"""supervisor + 3 専門 RAG agent を「agents-as-tools」パターンで組み立てる。

構成:
  - 専門 agent（aws_service / database / document）はそれぞれ専用 KB を引く tool を 1 つ持つ。
  - 各専門 agent を `@tool` 関数として包み、supervisor の tool にする（= agents-as-tools）。
  - supervisor は質問を見て適切な専門 tool を呼び、結果を統合して回答する（分類は LLM が担う）。

テスト容易性:
  本物の Bedrock を呼ばずにロジックを検証できるよう、依存（KB client・model・専門 agent の実行）は
  AgentDeps 経由で注入できます。AgentDeps.specialist_runner を渡すと、専門 agent の実行を
  任意の関数に差し替えられます（tests/test_agents.py 参照）。
"""

from __future__ import annotations

from collections.abc import Callable
from dataclasses import dataclass
from typing import Any

from strands import Agent, tool
from strands.models import BedrockModel

from rag_chat.config import Config
from rag_chat.knowledge_base import make_kb_search_tool


@dataclass(frozen=True)
class Specialist:
    """専門 agent 1 つ分のメタdata（tool 名・説明・system prompt）。"""

    key: str
    tool_name: str
    tool_description: str
    system_prompt: str


# 3 つの専門 agent の定義。tool_description は supervisor（LLM）がルーティング判断に使うため、
# 「いつこの agent を呼ぶか」が伝わる英語にしています（tool 説明は model 向け = 英語）。
SPECIALISTS: dict[str, Specialist] = {
    "aws_service": Specialist(
        key="aws_service",
        tool_name="aws_service_rag_agent",
        # （日本語訳）AWS サービスとその使い方（例: EC2, S3, Lambda, IAM, ネットワーク）に関する
        # 質問に答える。AWS の製品・機能・使い方に関する質問にはこの agent を使う。
        tool_description=(
            "Answer questions about AWS services and how to use them (e.g. EC2, S3, "
            "Lambda, IAM, networking). Use this for AWS product/feature/how-to questions."
        ),
        # （日本語訳）あなたは AWS サービスの専門家。まず必ず search_knowledge_base tool を呼んで
        # AWS サービスのナレッジベースに基づいて回答し、簡潔に答えて文書の記載を引用する。
        # ナレッジベースに関連情報が無ければ、推測せずその旨を率直に伝える。
        system_prompt=(
            "You are an AWS service specialist. Always call your search_knowledge_base "
            "tool first to ground your answer in the AWS service knowledge base, then "
            "answer concisely and cite what the documents say. If the knowledge base has "
            "nothing relevant, say so plainly instead of guessing."
        ),
    ),
    "database": Specialist(
        key="database",
        tool_name="database_rag_agent",
        # （日本語訳）軽量な CSV/Markdown の「データベース」レコードとして保存されたサンプル業務
        # データ（顧客・注文・商品）に関する質問に答える。そのデータ内の特定の行・件数・関連に
        # 関する質問にはこの agent を使う。
        tool_description=(
            "Answer questions about the sample business data (customers, orders, products) "
            "stored as lightweight CSV/Markdown 'database' records. Use this for questions "
            "about specific rows, counts, or relationships in that data."
        ),
        # （日本語訳）あなたは小規模なサンプルデータセットのデータアナリスト。まず必ず
        # search_knowledge_base tool を呼んで関連レコードを取得し、それらのレコードだけに厳密に
        # 基づいて回答する。存在しない行をでっち上げない。
        system_prompt=(
            "You are a data analyst for a small sample dataset. Always call your "
            "search_knowledge_base tool first to retrieve the relevant records, then answer "
            "strictly from those records. Do not invent rows that are not present."
        ),
    ),
    "document": Specialist(
        key="document",
        tool_name="document_rag_agent",
        # （日本語訳）Markdown/PDF 文書として保存された社内文書・ポリシー（ハンドブック・
        # ガイドライン・FAQ）に関する質問に答える。ポリシー・プロセス・FAQ に関する質問には
        # この agent を使う。
        tool_description=(
            "Answer questions about internal documents and policies (handbook, guidelines, "
            "FAQs) stored as Markdown/PDF documents. Use this for policy/process/FAQ questions."
        ),
        # （日本語訳）あなたはドキュメントアシスタント。まず必ず search_knowledge_base tool を
        # 呼んで関連する箇所を見つけ、簡潔に答えて、役立つ場合は文書を引用する。関連情報が
        # 見つからなければその旨を伝える。
        system_prompt=(
            "You are a documentation assistant. Always call your search_knowledge_base tool "
            "first to find the relevant passages, then answer concisely and quote the "
            "document where helpful. If nothing relevant is found, say so."
        ),
    ),
}


# （日本語訳）あなたはユーザーの質問を最も適切な専門 agent にルーティングし、その結果を
# 1 つの簡潔な回答に統合する supervisor。専門 agent は次のとおり:
#   - aws_service_rag_agent: AWS サービスおよび使い方に関する質問。
#   - database_rag_agent: サンプル業務データ（顧客/注文/商品）に関する質問。
#   - document_rag_agent: 社内文書・ポリシー・FAQ に関する質問。
# 質問に最適な専門 agent を 1 つ選んでその tool を呼ぶ。質問が明らかに複数ドメインにまたがる
# 場合は、複数の専門 agent を呼んで回答を統合してよい。専門 agent に相談せず自分の事前知識
# だけで回答してはならない。
SUPERVISOR_SYSTEM_PROMPT = (
    "You are a supervisor that routes a user's question to the most appropriate specialist "
    "agent and integrates the result into a single concise answer. The specialists are:\n"
    "- aws_service_rag_agent: AWS services and how-to questions.\n"
    "- database_rag_agent: questions about the sample business data (customers/orders/products).\n"
    "- document_rag_agent: questions about internal documents, policies, and FAQs.\n"
    "Choose the single best specialist for the question and call its tool. If a question "
    "clearly spans more than one domain, you may call multiple specialists and combine their "
    "answers. Never answer from your own prior knowledge without consulting a specialist."
)


@dataclass
class AgentDeps:
    """agent 組み立ての依存。テストでは model_factory / kb_client / specialist_runner を注入する。"""

    config: Config
    kb_client: Any | None = None
    # role（"supervisor" または専門 agent の key）を受け取り model を返す。省略時は BedrockModel。
    model_factory: Callable[[str], Any] | None = None
    # 専門 agent の実行を丸ごと差し替える seam（テスト用）。(spec_key, query) -> 回答文字列。
    specialist_runner: Callable[[str, str], str] | None = None

    def model_for(self, role: str) -> Any:
        """role 用の model を返す。既定では generation model を BedrockModel で生成する。"""
        if self.model_factory is not None:
            return self.model_factory(role)
        return BedrockModel(model_id=self.config.model_id, region_name=self.config.region)


def run_specialist(spec_key: str, query: str, deps: AgentDeps) -> str:
    """1 つの専門 agent を実行して回答文字列を返す。

    deps.specialist_runner が注入されていればそれを使い（テスト時に本物の Bedrock を回避）、
    無ければ専用 KB tool を持つ Agent をその場で生成して質問を処理します。
    """
    if deps.specialist_runner is not None:
        return deps.specialist_runner(spec_key, query)

    spec = SPECIALISTS[spec_key]
    kb_tool = make_kb_search_tool(
        deps.config.kb_ids[spec_key],
        deps.config.region,
        client=deps.kb_client,
    )
    agent = Agent(
        model=deps.model_for(spec_key),
        system_prompt=spec.system_prompt,
        tools=[kb_tool],
    )
    return str(agent(query))


def build_specialist_tools(deps: AgentDeps) -> list[Any]:
    """3 つの専門 agent を supervisor 用の tool に変換して返す（agents-as-tools）。

    各 tool は LLM からは `query` だけを受け取る関数に見えます（kb_id・model などの固定
    コンテキストは run_specialist / クロージャ側に隠蔽）。tool 名・説明は SPECIALISTS と一致。
    """

    # （日本語訳）AWS サービスとその使い方（EC2, S3, Lambda, IAM 等）に関する質問に答える。
    #   query: AWS サービス専門 agent に転送される、ユーザーの AWS 関連の質問。
    @tool
    def aws_service_rag_agent(query: str) -> str:
        """Answer questions about AWS services and how to use them (EC2, S3, Lambda, IAM, etc.).

        Args:
            query: The user's AWS-related question, forwarded to the AWS service specialist.
        """
        return run_specialist("aws_service", query, deps)

    # （日本語訳）サンプル業務データ（顧客・注文・商品）に関する質問に答える。
    #   query: データベース専門 agent に転送される、ユーザーのデータに関する質問。
    @tool
    def database_rag_agent(query: str) -> str:
        """Answer questions about the sample business data (customers, orders, products).

        Args:
            query: The user's data question, forwarded to the database specialist.
        """
        return run_specialist("database", query, deps)

    # （日本語訳）社内文書・ポリシー・FAQ に関する質問に答える。
    #   query: ドキュメント専門 agent に転送される、ユーザーの文書に関する質問。
    @tool
    def document_rag_agent(query: str) -> str:
        """Answer questions about internal documents, policies, and FAQs.

        Args:
            query: The user's document question, forwarded to the document specialist.
        """
        return run_specialist("document", query, deps)

    return [aws_service_rag_agent, database_rag_agent, document_rag_agent]


def build_supervisor(deps: AgentDeps) -> Agent:
    """専門 tool を束ねた supervisor Agent を生成する。"""
    return Agent(
        model=deps.model_for("supervisor"),
        system_prompt=SUPERVISOR_SYSTEM_PROMPT,
        tools=build_specialist_tools(deps),
    )
