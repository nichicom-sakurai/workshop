"""memory（AgentCore Memory ラッパ）の unittest。fake client を注入する。"""

import unittest

from rag_chat.memory import ConversationMemory, format_history

EVENTS = [
    {
        "payload": [
            {"conversational": {"role": "USER", "content": {"text": "hi"}}},
            {"conversational": {"role": "ASSISTANT", "content": {"text": "hello"}}},
        ]
    }
]


class FakeMemoryClient:
    def __init__(self, events=None):
        self.events = events or []
        self.created = []
        self.list_kwargs = None

    def create_event(self, **kwargs):
        self.created.append(kwargs)
        return {"eventId": "e1"}

    def list_events(self, **kwargs):
        self.list_kwargs = kwargs
        return self.events


class FormatHistoryTest(unittest.TestCase):
    def test_formats_roles(self):
        text = format_history(EVENTS)
        self.assertIn("User: hi", text)
        self.assertIn("Assistant: hello", text)

    def test_handles_none_and_empty(self):
        self.assertEqual(format_history(None), "")
        self.assertEqual(format_history([]), "")

    def test_ignores_malformed_events(self):
        junk = [{"payload": "not-a-list"}, {"no_payload": True}, "string", {"payload": [{"x": 1}]}]
        self.assertEqual(format_history(junk), "")

    def test_truncates_to_max_chars(self):
        big = [{"payload": [{"conversational": {"role": "USER", "content": {"text": "x" * 100}}}]}]
        self.assertEqual(len(format_history(big, max_chars=20)), 20)


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

    def test_recent_history_formats_and_requests_payload(self):
        client = FakeMemoryClient(events=EVENTS)
        memory = ConversationMemory("mem-1", client=client)
        history = memory.recent_history("actor-1", "session-1", turns=3)
        self.assertIn("User: hi", history)
        self.assertEqual(client.list_kwargs["max_results"], 6)
        self.assertTrue(client.list_kwargs["include_payload"])


if __name__ == "__main__":
    unittest.main()
