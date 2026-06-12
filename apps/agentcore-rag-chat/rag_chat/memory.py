"""AgentCore Memory の short-term（会話 event）を保存・取得する薄いラッパ。

この sample では long-term strategy（要約・意味記憶）は使わず、raw event だけを使います。
1 ターン（user 発話 + assistant 応答）を `create_event` で保存し、次ターンで直近 k ターンを
取り出して supervisor への入力に前置きします。これで session / actor 単位の multi-turn を
AgentCore Memory 経由で実現します。

直近履歴の取得には SDK の `MemoryClient.get_last_k_turns`（「最新の k 会話ターン」を返す
専用 API）を使います。自前で `list_events` を max_results スライスすると、API の並び順
（古い順 / 新しい順）に依存して脆くなるため、ターン取得は SDK の契約に委ねます。

設計方針:
  - MemoryClient は遅延生成し、テストでは fake client を注入できる。
  - 履歴取得・保存の失敗はチャットを止めない（呼び出し側が best-effort で握りつぶす）。
  - turn の payload 形は SDK 依存のため、format_turns は複数の形に耐える best-effort 抽出にする。
"""

from __future__ import annotations

from collections.abc import Iterable, Iterator
from typing import Any

# Memory に保存する role 表記（create_event の messages は (text, role) のタプル列）。
ROLE_USER = "USER"
ROLE_ASSISTANT = "ASSISTANT"

# 表示用ラベル。TOOL はこの sample の save_turn では書き込まないが、get_last_k_turns が
# tool 呼び出しターンを含めて返した場合にも素直に表示できるよう用意しておく。
_ROLE_LABELS = {"USER": "User", "ASSISTANT": "Assistant", "TOOL": "Tool"}


def _iter_turn_messages(turn: Any) -> Iterator[tuple[str, str]]:
    """1 ターン（メッセージ dict のリスト）から (role, text) を best-effort で取り出す。

    get_last_k_turns は各メッセージを `{"role": ..., "content": {"text": ...}}`（会話オブジェクト）
    として返します。SDK バージョンで形が変わっても落ちないよう、型を確認しながら緩く抽出します。
    """
    if not isinstance(turn, list):
        return
    for message in turn:
        if not isinstance(message, dict):
            continue
        role = message.get("role")
        content = message.get("content")
        text = content.get("text") if isinstance(content, dict) else content
        if isinstance(role, str) and isinstance(text, str) and text.strip():
            yield role, text.strip()


def format_turns(turns: Iterable[Any] | None, *, max_chars: int = 4000) -> str:
    """get_last_k_turns の結果を「Role: text」の行に整形する（直近の max_chars 文字に丸める）。"""
    lines: list[str] = []
    for turn in turns or []:
        for role, text in _iter_turn_messages(turn):
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
        """直近 turns 件のターンを整形済みテキストで返す（無ければ空文字列）。"""
        recent = self.client.get_last_k_turns(
            memory_id=self.memory_id,
            actor_id=actor_id,
            session_id=session_id,
            k=turns,
        )
        return format_turns(recent)
