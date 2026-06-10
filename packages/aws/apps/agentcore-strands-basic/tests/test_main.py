"""main.py の unittest テスト。

実行 (README の方法): mise exec -- uv run --directory packages/aws/apps/agentcore-strands-basic --locked python -m unittest discover -s tests

unittest の仕組み（要点・忘れないように）:
  - 収集条件: ファイル名 test*.py / クラスは unittest.TestCase を継承 / メソッドは test で始まる
  - 実行順は「メソッド名のアルファベット昇順」で、ファイルの記述順ではない → テストは順序に依存させない
  - 各テストは毎回新しいインスタンスで setUp() → test_xxx() → tearDown() の順に走る（状態を持ち越さない）
  - 末尾の `if __name__ == "__main__"` は直接実行時のみ。discover 経由では走らない
"""

import os
import unittest
from unittest.mock import patch

from main import build_response, get_prompt, missing_model_error


class AgentCoreStrandsBasicTest(unittest.TestCase):
    def test_get_prompt_accepts_prompt_key(self):
        self.assertEqual(get_prompt({"prompt": "Hello"}), "Hello")

    def test_get_prompt_falls_back_to_helpful_message(self):
        self.assertEqual(
            get_prompt({}),
            "No prompt found. Send JSON with a prompt field.",
        )

    def test_missing_model_error_is_json_compatible(self):
        self.assertEqual(
            missing_model_error(),
            {
                "status": "error",
                "error": "BEDROCK_MODEL_ID is not set",
            },
        )

    def test_build_response_uses_injected_responder(self):
        def fake_responder(prompt: str) -> str:
            return f"echo: {prompt}"

        # patch.dict: with の間だけ環境変数を差し替え、抜けると元に戻る（テスト間で環境を汚さない）。
        with patch.dict(os.environ, {"BEDROCK_MODEL_ID": "test-model"}, clear=False):
            self.assertEqual(
                build_response({"prompt": "Hello"}, responder=fake_responder),
                {
                    "status": "success",
                    "response": "echo: Hello",
                    "model_id": "test-model",
                },
            )

    def test_build_response_returns_error_without_model_id(self):
        # clear=True: 既存の環境変数を一時的に全消去 → BEDROCK_MODEL_ID 未設定の状況を再現。
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(build_response({"prompt": "Hello"}), missing_model_error())


# python test_main.py と直接実行したときだけ走る入口（README の discover 経由では走らない）。
if __name__ == "__main__":
    unittest.main()
