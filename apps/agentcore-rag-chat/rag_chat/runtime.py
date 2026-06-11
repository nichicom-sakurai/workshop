"""AgentCore Runtime の entrypoint が呼ぶ組み立てロジック。

`main.py` の `invoke()` はこの `build_response()` に委譲するだけにし、設定解決・履歴の前置き・
supervisor 実行・Memory 保存をここに集約します。supervisor 生成と Memory は注入可能にして、
本物の Bedrock / Memory を呼ばずに `build_response` を単体テストできるようにしています。
"""

from __future__ import annotations

from collections.abc import Callable
from typing import Any

from rag_chat.agents import AgentDeps, build_supervisor
from rag_chat.config import Config
from rag_chat.memory import ConversationMemory

# payload に session/actor が無いときの既定値（単発の動作確認用）。
DEFAULT_ACTOR_ID = "workshop-user"
DEFAULT_SESSION_ID = "workshop-session"


def get_prompt(payload: dict[str, Any]) -> str:
    """payload から prompt（質問文）を取り出す。無ければ案内文を返す。"""
    prompt = payload.get("prompt") if isinstance(payload, dict) else None
    if isinstance(prompt, str) and prompt.strip():
        return prompt
    return "No prompt found. Send JSON with a prompt field."


def _str_field(payload: dict[str, Any], key: str, default: str) -> str:
    """payload から文字列フィールドを取り出す（空・型不一致なら default）。"""
    value = payload.get(key) if isinstance(payload, dict) else None
    if isinstance(value, str) and value.strip():
        return value.strip()
    return default


def get_actor_id(payload: dict[str, Any]) -> str:
    """会話の actor（利用者）識別子。Memory の actor 単位の分離に使う。"""
    return _str_field(payload, "actor_id", DEFAULT_ACTOR_ID)


def get_session_id(payload: dict[str, Any]) -> str:
    """会話の session 識別子。Memory の session 単位の履歴に使う。"""
    return _str_field(payload, "session_id", DEFAULT_SESSION_ID)


def config_error(missing: list[str]) -> dict[str, str]:
    """必須設定が欠けているときに返すエラー応答（JSON 互換の dict）。"""
    return {
        "status": "error",
        "error": "Missing required configuration: " + ", ".join(missing),
    }


def run_supervisor(supervisor: Any, prompt: str, history: str) -> str:
    """supervisor に履歴付きで質問を渡し、回答文字列を返す。"""
    if history:
        message = f"Previous conversation:\n{history}\n\nUser question: {prompt}"
    else:
        message = prompt
    return str(supervisor(message))


def default_supervisor_factory(config: Config) -> Any:
    """設定から本物の supervisor Agent を生成する（runtime 既定）。"""
    return build_supervisor(AgentDeps(config=config))


def build_response(
    payload: dict[str, Any],
    *,
    config: Config | None = None,
    supervisor_factory: Callable[[Config], Any] | None = None,
    memory: ConversationMemory | None = None,
) -> dict[str, Any]:
    """リクエストを処理し、返す JSON 相当の dict を組み立てる。

    Args:
        payload: AgentCore Runtime から渡る入力（prompt / 任意で actor_id / session_id）。
        config: 実行設定（省略時は環境変数から解決）。
        supervisor_factory: supervisor 生成関数（テストで fake を注入）。
        memory: 会話 Memory（省略時は config.memory_id があれば自動生成、無ければ履歴なし）。
    """
    config = config or Config.from_env()
    missing = config.missing()
    if missing:
        return config_error(missing)

    prompt = get_prompt(payload)
    actor_id = get_actor_id(payload)
    session_id = get_session_id(payload)

    if memory is None and config.memory_id:
        memory = ConversationMemory(config.memory_id, region=config.region)

    # 履歴の取得失敗は会話を止めない（best-effort）。失敗時は履歴なしで続行する。
    history = ""
    if memory is not None:
        try:
            history = memory.recent_history(actor_id, session_id)
        except Exception:
            history = ""

    supervisor = (supervisor_factory or default_supervisor_factory)(config)
    answer = run_supervisor(supervisor, prompt, history)

    # 今回のターンを保存（次回の履歴に使う）。保存失敗も会話を止めない。
    if memory is not None:
        try:
            memory.save_turn(actor_id, session_id, prompt, answer)
        except Exception:
            pass

    return {
        "status": "success",
        "response": answer,
        "session_id": session_id,
        "actor_id": actor_id,
        "model_id": config.model_id,
    }
