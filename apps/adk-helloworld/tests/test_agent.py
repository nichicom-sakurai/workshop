"""hello_world/agent.py の unittest テスト。

実行 (README の方法):
  mise exec -- uv run --directory apps/adk-helloworld --locked \
    python -m unittest discover -s tests

このテストは root_agent の「静的な定義」だけを検証する（名前・model の宣言・指示文）。
Agent(...) を構築するだけではネットワーク呼び出しは起きないため、API key 無しで通る。
実際に model を呼ぶ動作確認は README の `adk run` / `adk web` で行う。

unittest の要点（忘れないように）:
  - 収集条件: ファイル名 test*.py / クラスは unittest.TestCase を継承 / メソッドは test で始まる
  - 実行順は「メソッド名のアルファベット昇順」で、ファイルの記述順ではない → 順序に依存させない
  - 各テストは毎回新しいインスタンスで setUp() → test_xxx() → tearDown() の順に走る
  - 末尾の `if __name__ == "__main__"` は直接実行時のみ。discover 経由では走らない
"""

import unittest

# hello_world はこのアプリ直下のエージェントパッケージ。
# uv run --directory <app> 経由では cwd（app ルート）が import path に入るため解決できる。
from hello_world.agent import root_agent


class HelloWorldAgentTest(unittest.TestCase):
    def test_agent_name_is_hello_world(self):
        # adk run / adk web から参照される識別子が固定値であることを確認する。
        self.assertEqual(root_agent.name, "hello_world")

    def test_agent_uses_pinned_gemini_model(self):
        # model は具体 ID で pin する方針（gemini-flash-latest のような alias は使わない）。
        self.assertEqual(root_agent.model, "gemini-2.5-flash-lite")

    def test_agent_has_non_empty_instruction(self):
        # instruction（system prompt 相当）が空でない文字列であることを確認する。
        self.assertIsInstance(root_agent.instruction, str)
        self.assertTrue(root_agent.instruction.strip())

    def test_agent_has_description(self):
        # description が空でないことを確認する（多エージェント構成での振り分けに使う情報）。
        self.assertTrue(root_agent.description.strip())


# python test_agent.py と直接実行したときだけ走る入口（discover 経由では走らない）。
if __name__ == "__main__":
    unittest.main()
