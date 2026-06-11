"""memory（AgentCore Memory ラッパ）の unittest。fake client を注入する。"""

import unittest

from rag_chat.memory import ConversationMemory, format_turns

# get_last_k_turns の戻り値の形（turn = メッセージ dict のリスト）。新しいターンが後ろに来る想定。
TURNS = [
    [
        {"role": "USER", "content": {"text": "hi"}},
        {"role": "ASSISTANT", "content": {"text": "hello"}},
    ],
    [
        {"role": "USER", "content": {"text": "and then?"}},
        {"role": "ASSISTANT", "content": {"text": "sure"}},
    ],
]


class FakeMemoryClient:
    def __init__(self, turns=None):
        self.turns = turns or []
        self.created = []
        self.last_k_kwargs = None

    def create_event(self, **kwargs):
        self.created.append(kwargs)
        return {"eventId": "e1"}

    def get_last_k_turns(self, **kwargs):
        self.last_k_kwargs = kwargs
        return self.turns


class FormatTurnsTest(unittest.TestCase):
    def test_formats_roles_in_order(self):
        text = format_turns(TURNS)
        self.assertEqual(
            text,
            "User: hi\nAssistant: hello\nUser: and then?\nAssistant: sure",
        )

    def test_handles_none_and_empty(self):
        self.assertEqual(format_turns(None), "")
        self.assertEqual(format_turns([]), "")

    def test_ignores_malformed_turns(self):
        junk = ["not-a-list", [{"no_role": 1}], [{"role": "USER", "content": {}}], [{"role": "USER", "content": {"text": "  "}}]]
        self.assertEqual(format_turns(junk), "")

    def test_truncates_to_max_chars(self):
        big = [[{"role": "USER", "content": {"text": "x" * 100}}]]
        self.assertEqual(len(format_turns(big, max_chars=20)), 20)


class ConversationMemoryTest(unittest.TestCase):
    def test_save_turn_calls_create_event(self):
        client = FakeMemoryClient()
        memory = ConversationMemory("mem-1", client=client)
        memory.save_turn("actor-1", "session-1", "question", "answer")
        self.assertEqual(len(client.created), 1)
        call = client.created[0]
        self.assertEqual(call["memory_id"], "mem-1")
        self.assertEqual(call["actor_id"], "actor-1")
        self.assertEqual(call["session_id"], "session-1")
        self.assertEqual(call["messages"], [("question", "USER"), ("answer", "ASSISTANT")])

    def test_recent_history_requests_k_turns_and_formats(self):
        client = FakeMemoryClient(turns=TURNS)
        memory = ConversationMemory("mem-1", client=client)
        history = memory.recent_history("actor-1", "session-1", turns=3)
        self.assertIn("User: hi", history)
        self.assertIn("Assistant: sure", history)
        # 専用 API に k を渡している（自前の max_results スライスをしない）。
        self.assertEqual(client.last_k_kwargs["k"], 3)
        self.assertEqual(client.last_k_kwargs["memory_id"], "mem-1")
        self.assertEqual(client.last_k_kwargs["actor_id"], "actor-1")
        self.assertEqual(client.last_k_kwargs["session_id"], "session-1")


if __name__ == "__main__":
    unittest.main()
