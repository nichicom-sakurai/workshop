"""Amazon Bedrock AgentCore Runtime 上で動く、supervisor + 3 専門 RAG agent のチャット。

処理の流れ:
    リクエスト(JSON) → invoke() → build_response()（rag_chat.runtime）
      → supervisor が質問を分類し専門 RAG agent に委譲 → 各 agent が専用 KB を検索
      → 結果を統合 → 必要なら AgentCore Memory に保存 → 結果(JSON) を返す

entrypoint はこのファイル（AgentCore の entry_point = ["main.py"]）。ロジックは rag_chat
パッケージに置き、ここは薄い委譲だけにしています（テストは rag_chat 側で行う）。
"""

from typing import Any

# BedrockAgentCoreApp: このアプリを AgentCore Runtime 上で動かす土台。
from bedrock_agentcore.runtime import BedrockAgentCoreApp

# 設定解決・組み立てロジックは rag_chat.runtime に集約。
from rag_chat.runtime import build_response

app = BedrockAgentCoreApp()


@app.entrypoint
def invoke(payload: dict[str, Any]) -> dict[str, Any]:
    """AgentCore Runtime から呼ばれる入口。中身は build_response に委譲する。"""
    return build_response(payload)


if __name__ == "__main__":
    # `python main.py` で AgentCore Runtime のローカルサーバー (uvicorn) が起動し、
    # 127.0.0.1:8080 で POST /invocations と GET /ping を公開する。
    # 対話的に複数ターンを試したい場合は chat.py を使う。
    app.run()
