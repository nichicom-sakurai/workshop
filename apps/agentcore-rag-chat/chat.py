"""ローカルで複数ターンの会話を試す対話 CLI。

デプロイ後の AgentCore Runtime と「同じコードパス」（rag_chat.runtime.build_response）を 1 ターン
ごとに呼びます。session_id / actor_id を固定して渡すので、AGENTCORE_MEMORY_ID を設定していれば
AgentCore Memory 経由で前のターンを踏まえた multi-turn になります（未設定なら毎ターン単発）。

実行（KB / Memory は terraform apply 後の値を環境変数で渡す）:
    mise exec -- uv run --directory apps/agentcore-rag-chat --locked \
      env AWS_REGION=ap-northeast-1 AWS_PROFILE=default \
          BEDROCK_MODEL_ID="apac.anthropic.claude-..." \
          AWS_SERVICE_KB_ID=... DATABASE_KB_ID=... DOCUMENT_KB_ID=... \
          AGENTCORE_MEMORY_ID=... \
      python chat.py

必須環境変数（BEDROCK_MODEL_ID / 3 つの KB ID）が未設定のときは案内を出して正常終了します。
"""

from __future__ import annotations

import os
import uuid

from rag_chat.config import Config
from rag_chat.runtime import build_response


def _print_setup_guidance(missing: list[str]) -> None:
    print("[INFO] agentcore-rag-chat ローカル対話 CLI")
    print("[NG] 必須の環境変数が未設定です: " + ", ".join(missing))
    print("     terraform apply 後の output を環境変数で渡してください:")
    print("       BEDROCK_MODEL_ID / AWS_SERVICE_KB_ID / DATABASE_KB_ID / DOCUMENT_KB_ID")
    print("     任意: AGENTCORE_MEMORY_ID（設定すると multi-turn になります）")
    print("     詳細は README.md を参照してください。")


def main() -> int:
    config = Config.from_env()
    missing = config.missing()
    if missing:
        _print_setup_guidance(missing)
        return 0

    session_id = "local-" + uuid.uuid4().hex[:8]
    actor_id = os.environ.get("RAG_CHAT_ACTOR_ID", "local-user")
    memory_state = "on" if config.memory_id else "off (single-turn)"

    print("[INFO] agentcore-rag-chat 対話 CLI（終了: exit / quit / Ctrl-D）")
    print(f"       model={config.model_id} region={config.region} memory={memory_state}")
    print(f"       session_id={session_id} actor_id={actor_id}")

    while True:
        try:
            line = input("\nyou> ").strip()
        except (EOFError, KeyboardInterrupt):
            print()
            break
        if not line:
            continue
        if line.lower() in {"exit", "quit"}:
            break

        result = build_response(
            {"prompt": line, "session_id": session_id, "actor_id": actor_id},
            config=config,
        )
        if result.get("status") == "success":
            print(f"\nbot> {result.get('response', '')}")
        else:
            print(f"\n[NG] {result.get('error', 'unknown error')}")

    print("[INFO] 終了しました。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
