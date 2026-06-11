"""agents（agents-as-tools 構成）の unittest。専門 agent の実行は注入した runner に差し替える。"""

import unittest

from rag_chat.agents import (
    SPECIALISTS,
    AgentDeps,
    build_specialist_tools,
    run_specialist,
)
from rag_chat.config import Config


def make_config():
    return Config(
        model_id="test-model",
        region="ap-northeast-1",
        kb_ids={"aws_service": "kb1", "database": "kb2", "document": "kb3"},
        memory_id=None,
    )


class SpecialistsTest(unittest.TestCase):
    def test_three_specialists_with_metadata(self):
        self.assertEqual(set(SPECIALISTS), {"aws_service", "database", "document"})
        for spec in SPECIALISTS.values():
            self.assertTrue(spec.tool_name)
            self.assertTrue(spec.tool_description)
            self.assertTrue(spec.system_prompt)


class RunSpecialistTest(unittest.TestCase):
    def test_uses_injected_runner(self):
        deps = AgentDeps(config=make_config(), specialist_runner=lambda key, query: f"{key}:{query}")
        self.assertEqual(run_specialist("database", "rows?", deps), "database:rows?")


class BuildSpecialistToolsTest(unittest.TestCase):
    def test_returns_three_tools(self):
        deps = AgentDeps(config=make_config(), specialist_runner=lambda key, query: "stub")
        tools = build_specialist_tools(deps)
        self.assertEqual(len(tools), 3)


if __name__ == "__main__":
    unittest.main()
