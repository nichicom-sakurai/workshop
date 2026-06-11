"""AgentCore Memory の short-term（会話 event）を保存・取得する薄いラッパ。

この sample では long-term strategy（要約・意味記憶）は使わず、raw event だけを使います。
1 ターン（user 発話 + assistant 応答）を `create_event` で保存し、次ターンで `list_events`
から直近の履歴を取り出して supervisor への入力に前置きします。これで session / actor 単位の
multi-turn を AgentCore Memory 経由で実現します。

設計方針:
  - MemoryClient は遅延生成し、テストでは fake client を注入できる。
  - 履歴取得・保存の失敗はチャットを止めない（呼び出し側が best-effort で握りつぶす）。
  - event payload の形は SDK 依存のため、format_history は複数の形に耐える best-effort 抽出にする。
"""

from __future__ import annotations

from collections.abc import Iterable, Iterator
from typing import Any

# Memory に保存する role 表記（create_event の messages は (text, role) のタプル列）。
ROLE_USER = "USER"
ROLE_ASSISTANT = "ASSISTANT"

_ROLE_LABELS = {"USER": "User", "ASSISTANT": "Assistant", "TOOL": "Tool"}


def _iter_messages(event: Any) -> Iterator[tuple[str, str]]:
    """1 つの event から (role, text) を best-effort で取り出す。

    bedrock-agentcore の list_events が返す event は `payload` に会話メッセージを持ちます。
    payload 要素の形（例: {"conversational": {"role": ..., "content": {"text": ...}}}）が
    SDK バージョンで変わっても落ちないよう、型を確認しながら緩く抽出します。
    """
    if not isinstance(event, dict):
        return
    payload = event.get("payload")
    if not isinstance(payload, list):
        return
    for entry in payload:
        if not isinstance(entry, dict):
            continue
        conv = entry.get("conversational")
        if not isinstance(conv, dict):
            continue
        role = conv.get("role")
        content = conv.get("content")
        text = content.get("text") if isinstance(content, dict) else content
        if isinstance(role, str) and isinstance(text, str) and text.strip():
            yield role, text.strip()


def format_history(events: Iterable[Any] | None, *, max_chars: int = 4000) -> str:
    """list_events の結果を「Role: text」の行に整形する（直近の max_chars 文字に丸める）。"""
    lines: list[str] = []
    for event in events or []:
        for role, text in _iter_messages(event):
            lines.append(f"{_ROLE_LABELS.get(role.upper(), role)}: {text}")
    history = "\n".join(lines)
    # 長すぎる履歴は末尾（=新しい会話）優先で切り詰める。
    return history[-max_chars:] if len(history) > max_chars else history


class ConversationMemory:
    """AgentCore Memory への保存・取得を担うラッパ。client は注入可能（テスト容易）。"""

    def __init__(self, memory_id: str, *, client: Any | None = None, region: str | None = None) -> None:
        self.memory_id = memory_id
        self.region = region
        self._client = client

    @property
    def client(self) -> Any:
        """MemoryClient を遅延生成する（import も遅延し、未使用時の依存を避ける）。"""
        if self._client is None:
            from bedrock_agentcore.memory import MemoryClient

            self._client = MemoryClient(region_name=self.region)
        return self._client

    def save_turn(self, actor_id: str, session_id: str, user_text: str, assistant_text: str) -> None:
        """1 ターン（user + assistant）を会話 event として保存する。"""
        self.client.create_event(
            memory_id=self.memory_id,
            actor_id=actor_id,
            session_id=session_id,
            messages=[(user_text, ROLE_USER), (assistant_text, ROLE_ASSISTANT)],
        )

    def recent_history(self, actor_id: str, session_id: str, *, turns: int = 5) -> str:
        """直近の会話履歴を整形済みテキストで返す（無ければ空文字列）。"""
        events = self.client.list_events(
            memory_id=self.memory_id,
            actor_id=actor_id,
            session_id=session_id,
            max_results=turns * 2,
            include_payload=True,
        )
        return format_history(events)
