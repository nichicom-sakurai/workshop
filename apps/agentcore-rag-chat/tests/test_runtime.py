"""runtime（entrypoint の組み立てロジック）の unittest。fake supervisor / memory を注入する。"""

import unittest

from rag_chat.config import Config
from rag_chat.runtime import (
    DEFAULT_ACTOR_ID,
    DEFAULT_SESSION_ID,
    build_response,
    config_error,
    get_prompt,
    run_supervisor,
)


def make_config(memory_id=None):
    return Config(
        model_id="test-model",
        region="ap-northeast-1",
        kb_ids={"aws_service": "kb1", "database": "kb2", "document": "kb3"},
        memory_id=memory_id,
    )


class FakeSupervisor:
    """呼ばれたメッセージを記録し、固定の回答を返す callable。"""

    def __init__(self, answer="FAKE ANSWER"):
        self.answer = answer
        self.messages = []

    def __call__(self, message):
        self.messages.append(message)
        return self.answer


class FakeMemory:
    def __init__(self, history=""):
        self._history = history
        self.saved = []

    def recent_history(self, actor_id, session_id):
        return self._history

    def save_turn(self, actor_id, session_id, user_text, assistant_text):
        self.saved.append((actor_id, session_id, user_text, assistant_text))


class GetPromptTest(unittest.TestCase):
    def test_returns_prompt(self):
        self.assertEqual(get_prompt({"prompt": "hello"}), "hello")

    def test_falls_back_when_missing(self):
        self.assertIn("No prompt found", get_prompt({}))


class ConfigErrorTest(unittest.TestCase):
    def test_lists_missing(self):
        error = config_error(["BEDROCK_MODEL_ID", "DATABASE_KB_ID"])
        self.assertEqual(error["status"], "error")
        self.assertIn("BEDROCK_MODEL_ID", error["error"])
        self.assertIn("DATABASE_KB_ID", error["error"])


class RunSupervisorTest(unittest.TestCase):
    def test_prefixes_history(self):
        supervisor = FakeSupervisor()
        run_supervisor(supervisor, "now?", "User: before")
        self.assertIn("Previous conversation:", supervisor.messages[0])
        self.assertIn("User: before", supervisor.messages[0])
        self.assertIn("now?", supervisor.messages[0])

    def test_passes_prompt_directly_without_history(self):
        supervisor = FakeSupervisor()
        run_supervisor(supervisor, "now?", "")
        self.assertEqual(supervisor.messages[0], "now?")


class BuildResponseTest(unittest.TestCase):
    def test_missing_config_returns_error(self):
        empty = Config(model_id="", region=None, kb_ids={"aws_service": "", "database": "", "document": ""}, memory_id=None)
        result = build_response({"prompt": "x"}, config=empty)
        self.assertEqual(result["status"], "error")
        self.assertIn("BEDROCK_MODEL_ID", result["error"])

    def test_success_uses_history_and_saves_turn(self):
        supervisor = FakeSupervisor()
        memory = FakeMemory(history="User: prev\nAssistant: ok")
        result = build_response(
            {"prompt": "hello", "session_id": "s1", "actor_id": "a1"},
            config=make_config("mem"),
            supervisor_factory=lambda config: supervisor,
            memory=memory,
        )
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["response"], "FAKE ANSWER")
        self.assertEqual(result["session_id"], "s1")
        self.assertEqual(result["actor_id"], "a1")
        # 履歴が supervisor 入力に前置きされている。
        self.assertIn("Previous conversation:", supervisor.messages[0])
        self.assertIn("hello", supervisor.messages[0])
        # 今回のターンが保存されている。
        self.assertEqual(memory.saved, [("a1", "s1", "hello", "FAKE ANSWER")])

    def test_success_without_memory_uses_defaults(self):
        supervisor = FakeSupervisor()
        result = build_response(
            {"prompt": "hi"},
            config=make_config(),
            supervisor_factory=lambda config: supervisor,
        )
        self.assertEqual(result["status"], "success")
        self.assertEqual(result["session_id"], DEFAULT_SESSION_ID)
        self.assertEqual(result["actor_id"], DEFAULT_ACTOR_ID)
        # 履歴も Memory も無いので prompt がそのまま渡る。
        self.assertEqual(supervisor.messages[0], "hi")


if __name__ == "__main__":
    unittest.main()
