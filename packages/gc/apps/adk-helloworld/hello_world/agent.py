"""Google ADK の最小 HelloWorld agent。

ADK (Agent Development Kit) は「AI エージェント」をコードで組み立てるための
Python ツールキットです。このファイルは ADK が探し出す「入口」になっており、
`root_agent` という名前のエージェントを 1 つ公開します。

ADK の約束ごと（重要・忘れないように）:
  - エージェントは Python パッケージ（フォルダ）として置く（ここでは hello_world/）。
  - パッケージ内の `__init__.py` が `from . import agent` でこのファイルを読み込む。
  - このファイルは `root_agent` という名前の変数を必ず公開する（名前は固定）。
  - `adk run hello_world` / `adk web` は、このパッケージの 1 つ上の階層から実行する。
  - どの model を呼ぶか（Gemini API key 方式 / Vertex AI 方式）は、同じフォルダの
    `.env` に書いた環境変数で切り替わる（コードは共通）。
"""

# google.adk.agents.Agent: 「LLM を使うエージェント」の本体クラス。
# name / model / instruction などを渡して、振る舞いを宣言的に定義する。
from google.adk.agents import Agent

# root_agent: ADK が探す「入口のエージェント」。この変数名は ADK の規約で固定。
root_agent = Agent(
    # name: エージェントの識別子。adk web の選択肢などに表示される。
    name="hello_world",
    # model: 使用する Gemini model の ID。gemini-2.5-flash は軽量・高速な世代。
    # API key 方式（GOOGLE_API_KEY）でも Vertex AI 方式でも、同じ ID で呼べる。
    model="gemini-2.5-flash",
    # description: このエージェントが何をするかの短い説明。
    description="A minimal HelloWorld agent that greets the user.",
    # instruction: model への「振る舞いの指示」（system prompt 相当）。
    # 丸括弧で文字列を改行して並べると、自動で 1 つの文字列に連結される。
    instruction=(
        "You are a friendly HelloWorld assistant. "
        "Greet the user warmly and keep your answer to one or two sentences."
    ),
)
