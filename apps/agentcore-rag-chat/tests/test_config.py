"""Config（環境変数の読み取り）の unittest。

実行: mise exec -- uv run --directory apps/agentcore-rag-chat --locked python -m unittest discover -s tests
"""

import unittest

from rag_chat.config import Config

FULL_ENV = {
    "BEDROCK_MODEL_ID": "apac.anthropic.claude-test",
    "AWS_SERVICE_KB_ID": "kb-aws",
    "DATABASE_KB_ID": "kb-db",
    "DOCUMENT_KB_ID": "kb-doc",
    "AWS_REGION": "ap-northeast-1",
    "AGENTCORE_MEMORY_ID": "mem-123",
}


class ConfigTest(unittest.TestCase):
    def test_from_env_full_is_complete(self):
        config = Config.from_env(FULL_ENV)
        self.assertEqual(config.missing(), [])
        self.assertEqual(config.model_id, "apac.anthropic.claude-test")
        self.assertEqual(config.region, "ap-northeast-1")
        self.assertEqual(config.memory_id, "mem-123")
        self.assertEqual(
            config.kb_ids,
            {"aws_service": "kb-aws", "database": "kb-db", "document": "kb-doc"},
        )

    def test_region_prefers_default_region(self):
        env = dict(FULL_ENV, AWS_DEFAULT_REGION="us-east-1")
        self.assertEqual(Config.from_env(env).region, "us-east-1")

    def test_missing_lists_all_required_when_empty(self):
        missing = Config.from_env({}).missing()
        self.assertIn("BEDROCK_MODEL_ID", missing)
        self.assertIn("AWS_SERVICE_KB_ID", missing)
        self.assertIn("DATABASE_KB_ID", missing)
        self.assertIn("DOCUMENT_KB_ID", missing)
        # Memory は任意なので missing には含めない。
        self.assertNotIn("AGENTCORE_MEMORY_ID", missing)

    def test_memory_is_optional(self):
        env = dict(FULL_ENV)
        del env["AGENTCORE_MEMORY_ID"]
        config = Config.from_env(env)
        self.assertEqual(config.missing(), [])
        self.assertIsNone(config.memory_id)


if __name__ == "__main__":
    unittest.main()
