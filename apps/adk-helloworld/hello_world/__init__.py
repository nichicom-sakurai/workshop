# ADK の規約: このパッケージ (hello_world) を import したときに agent モジュール
# (agent.py) を読み込み、その中の root_agent を ADK から発見できるようにする。
# `adk run hello_world` / `adk web` はこの import を起点にエージェントを見つける。
from . import agent
