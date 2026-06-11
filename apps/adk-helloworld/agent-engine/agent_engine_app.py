"""Vertex AI Agent Engine 用の entrypoint（reasoning engine の入口オブジェクト）。

このファイルは **Agent Engine runtime からのみ** import される。ローカルの
`adk run` / `adk web` では使われない（あちらは hello_world/__init__.py 経由で
root_agent を見つける）。そのため `pyproject.toml` のローカル依存には vertexai を
足さず、google-adk だけに保つ。vertexai は archive の requirements.txt
（google-cloud-aiplatform[agent_engines]）から runtime 側にだけ入る。

配置の約束ごと（重要）:
  - このファイルは package-agent-engine.sh が **archive の root** に置く
    （`agent-engine/agent_engine_app.py` → archive 直下の `agent_engine_app.py`）。
  - 同じ archive root に `hello_world/` パッケージが並ぶため、下の
    `from hello_world.agent import root_agent` は archive 内で解決する。
    repo 上のこのファイルの場所（agent-engine/）には hello_world/ が無いので、
    ローカルから直接 import してはいけない（archive 文脈専用）。
  - Terraform の python_spec は
    entrypoint_module = "agent_engine_app" / entrypoint_object = "agent_engine"
    でこのモジュールと変数を指す。

#1 footgun（research で確認）:
  google_vertex_ai_reasoning_engine の entrypoint_object は、ADK の root_agent
  そのものではなく **AdkApp で包んだインスタンス**を指す必要がある。raw な
  root_agent を渡すと runtime で import/attribute エラーになる。
"""

# AdkApp: ADK の agent を Agent Engine(reasoning engine) のインターフェースに
# 適合させる薄いラッパー。google-cloud-aiplatform[agent_engines] が提供する
# vertexai.agent_engines モジュールから取得する（古い別名は
# vertexai.preview.reasoning_engines.AdkApp）。
from vertexai.agent_engines import AdkApp

# root_agent はローカル run と共通の定義（hello_world/agent.py）。Agent Engine 用に
# エージェント本体を再定義せず、1 か所（hello_world/agent.py）に保つ。
from hello_world.agent import root_agent

# agent_engine: python_spec.entrypoint_object が指す変数（名前は Terraform 側と固定）。
agent_engine = AdkApp(agent=root_agent)
